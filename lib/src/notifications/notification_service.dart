import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/user_repository.dart';

/// Registers this device for push notifications and keeps the stored FCM
/// token fresh. The actual notifications are sent by the notify Cloudflare
/// Worker (see cloudflare-worker/notify.js), triggered directly by
/// [PushTrigger] from the repository write paths — not by a Firebase Cloud
/// Function, which would require a Blaze billing account.
class NotificationService {
  NotificationService({FirebaseMessaging? messaging, UserRepository? userRepository})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _userRepository = userRepository ?? UserRepository();

  final FirebaseMessaging _messaging;
  final UserRepository _userRepository;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _registeredUid;

  Future<void> registerForUser(String uid) async {
    if (_registeredUid == uid) return;
    _registeredUid = uid;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // Deliberately using the classic token API, not register()/onRegistered:
    // the latter yields a Firebase Installation ID for FCM's newer
    // "direct send" flow, which the Admin SDK's sendEachForMulticast (used
    // by the Cloud Function) doesn't send to — it needs real device tokens.
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    if (token != null) {
      await _userRepository.addFcmToken(uid: uid, token: token);
    }

    unawaited(_tokenRefreshSub?.cancel());
    // ignore: deprecated_member_use
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _userRepository.addFcmToken(uid: uid, token: newToken);
    });
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
  }
}
