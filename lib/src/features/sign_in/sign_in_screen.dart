import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../auth/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  late final AnimationController _entrance;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardOffset;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _cardOpacity = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _cardOffset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authRepositoryProvider).signInWithGoogle();
      final user = credential.user;
      if (user != null) {
        await ref.read(userRepositoryProvider).upsertFromAuthUser(user);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(
        () => _error = 'Enter phone number with country code, e.g. +91 98765 43210',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyPhoneNumber(
        phoneNumber: phone,
        onCodeSent: (id) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _codeSent = true;
            _loading = false;
          });
        },
        onFailed: (e) {
          if (!mounted) return;
          setState(() {
            _error = _friendlyError(e);
            _loading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authRepositoryProvider).verifyPhoneCode(
        verificationId: id,
        smsCode: _codeController.text.trim(),
      );
      final user = credential.user;
      if (user != null) {
        await ref.read(userRepositoryProvider).upsertFromAuthUser(user);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: royalGradient),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -60,
            right: -50,
            child: _decorativeCircle(140, 0.12),
          ),
          Positioned(
            bottom: -70,
            left: -60,
            child: _decorativeCircle(180, 0.10),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _cardOpacity,
                  child: SlideTransition(
                    position: _cardOffset,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) => royalGradient.createShader(bounds),
                                  child: const Icon(Icons.shelves, size: 52),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: ourShelfAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    size: 12,
                                    color: Color(0xFF4A148C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'OurShelf',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Your family's kitchen, in sync.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 200),
                                  child: _error != null
                                      ? Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onErrorContainer,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                _PressableScale(
                                  onTap: _loading ? null : _signInWithGoogle,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFC9A227),
                                          Color(0xFFE5C158),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFC9A227,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.login,
                                          color: Color(0xFF2B0A4E),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            color: Color(0xFF2B0A4E),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _phoneController,
                                  enabled: !_codeSent,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone number',
                                    hintText: '+91 98765 43210',
                                    prefixIcon: const Icon(
                                      Icons.phone_iphone,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (!_codeSent)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _loading ? null : _sendCode,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text('Send OTP'),
                                    ),
                                  ),
                                if (_codeSent) ...[
                                  TextField(
                                    controller: _codeController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '6-digit code',
                                      prefixIcon: const Icon(Icons.pin),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _loading ? null : _verifyCode,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text('Verify & continue'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => setState(() {
                                            _codeSent = false;
                                            _verificationId = null;
                                          }),
                                    child: const Text('Change phone number'),
                                  ),
                                ],
                                if (_loading)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

/// Wraps a tappable child with a subtle press-down scale, so primary actions
/// feel physically responsive instead of a flat Material ripple.
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
