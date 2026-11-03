import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The deployed Worker's URL (see cloudflare-worker/notify.js). Left
/// unconfigured (containing "REPLACE-ME"), [PushTrigger] silently no-ops so
/// the app keeps working without push notifications.
const String kNotifyWorkerUrl = 'https://soft-mouse-184d.swapnil-official025.workers.dev/';

/// Fires a best-effort request to the notify Worker so group members get a
/// push notification — the free, no-billing-account replacement for the
/// Firestore-triggered Cloud Function. Never throws: a slow or failed call
/// must not block the Firestore write that triggered it.
class PushTrigger {
  PushTrigger({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void notifyGroup({
    required String groupId,
    required String excludeUid,
    required String title,
    required String body,
  }) {
    if (kNotifyWorkerUrl.contains('REPLACE-ME')) return;
    unawaited(_send(groupId: groupId, excludeUid: excludeUid, title: title, body: body));
  }

  Future<void> _send({
    required String groupId,
    required String excludeUid,
    required String title,
    required String body,
  }) async {
    try {
      await _client
          .post(
            Uri.parse(kNotifyWorkerUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'groupId': groupId,
              'excludeUid': excludeUid,
              'title': title,
              'body': body,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Best-effort only — push notifications are a nice-to-have.
    }
  }
}
