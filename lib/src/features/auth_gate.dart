import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'shell/app_shell.dart';
import 'sign_in/sign_in_screen.dart';

/// Shows the sign-in screen or the home screen depending on Firebase Auth
/// state, and a splash while the initial state is still loading.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) return const SignInScreen();
        // Idempotent per uid — safe to call on every rebuild.
        ref.read(notificationServiceProvider).registerForUser(user.uid);
        return const AppShell();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Something went wrong: $error')),
      ),
    );
  }
}
