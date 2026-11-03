import 'dart:convert';

import 'package:http/http.dart' as http;

import '../notifications/push_trigger.dart' show kNotifyWorkerUrl;

/// One turn of the conversation, sent back to the Worker so follow-up
/// questions ("and what about last month?") have context.
class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Talks to the same Cloudflare Worker used for push notifications (see
/// cloudflare-worker/notify.js) — one extra `type: 'ask'` request type, no
/// new backend. The Worker reads the group's own Firestore data and asks a
/// Groq model to answer using only that data.
class AskAiClient {
  AskAiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get isConfigured => !kNotifyWorkerUrl.contains('REPLACE-ME');

  Future<String> ask({
    required String groupId,
    required String question,
    List<ChatTurn> history = const [],
  }) async {
    if (!isConfigured) {
      throw StateError("Ask AI isn't set up yet — the backend URL is unconfigured.");
    }
    final res = await _client
        .post(
          Uri.parse(kNotifyWorkerUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': 'ask',
            'groupId': groupId,
            'question': question,
            'history': history.map((h) => h.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Ask AI failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['answer'] as String? ?? "I couldn't come up with an answer.";
  }
}
