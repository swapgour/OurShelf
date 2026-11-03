import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // While the app is in the foreground, FCM doesn't show a system
  // notification on its own — surface it as a SnackBar instead.
  FirebaseMessaging.onMessage.listen((message) {
    final body = message.notification?.body;
    if (body == null) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(body)),
    );
  });

  runApp(const ProviderScope(child: OurShelfApp()));
}
