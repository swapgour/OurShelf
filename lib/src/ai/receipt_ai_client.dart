import 'dart:convert';

import 'package:http/http.dart' as http;

import '../notifications/push_trigger.dart' show kNotifyWorkerUrl;

/// One item the AI extracted from a scanned receipt/order's raw OCR text.
class AiParsedItem {
  const AiParsedItem({required this.name, this.quantity, this.unit, this.price});

  final String name;
  final String? quantity;
  final String? unit;
  final double? price;
}

/// Sends raw OCR lines from a scanned receipt/bill/order PDF to the same
/// Cloudflare Worker used for Ask AI, which hands them to a free Groq model
/// to extract a clean item list — far more reliable than regex heuristics
/// on messy, out-of-order OCR text (receipts, and especially multi-column
/// app order-confirmation PDFs, vary wildly in layout).
class ReceiptAiClient {
  ReceiptAiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => !kNotifyWorkerUrl.contains('REPLACE-ME');

  Future<List<AiParsedItem>> parseItems(List<String> rawLines) async {
    if (!isConfigured) {
      throw StateError("Ask AI isn't set up yet — the backend URL is unconfigured.");
    }
    final res = await _client
        .post(
          Uri.parse(kNotifyWorkerUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'type': 'parse_items', 'rawLines': rawLines}),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('AI parsing failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (m) => AiParsedItem(
            name: (m['name'] as String? ?? '').trim(),
            quantity: (m['quantity'] as String?)?.trim(),
            unit: (m['unit'] as String?)?.trim(),
            price: (m['price'] as num?)?.toDouble(),
          ),
        )
        .where((i) => i.name.isNotEmpty)
        .toList();
  }
}
