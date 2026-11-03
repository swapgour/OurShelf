import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../auth_gate.dart';

/// The app's animated splash: the background glows and drifting bubbles
/// float continuously, the logo spins in with an elastic bounce then keeps
/// a gentle breathing pulse, and the title/tagline slide up and shimmer —
/// all running until hand-off to [AuthGate]. Shown once per app launch.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot entrance: logo spins/bounces in, then text slides up and fades.
  late final AnimationController _entrance;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotation;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textOffset;

  // Loops forever while the splash is on screen, so there's always motion.
  late final AnimationController _pulse;
  late final AnimationController _drift;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        weight: 70,
        tween: Tween(
          begin: 0.3,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
      ),
      TweenSequenceItem(
        weight: 30,
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
      ),
    ]).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.6, curve: Curves.linear),
      ),
    );
    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    final textCurve = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
    );
    _textOpacity = textCurve;
    _textOffset = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(textCurve);
    _entrance.forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _drift.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: royalGradient),
        child: Stack(
          children: [
            // Softly drifting translucent bubbles for continuous ambient motion.
            AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                return Stack(
                  children: List.generate(6, (i) {
                    final t = _drift.value * 2 * math.pi;
                    final phase = i * (math.pi / 3);
                    final dx =
                        size.width * (0.15 + 0.7 * ((i * 37) % 100) / 100) +
                        18 * math.sin(t + phase);
                    final dy =
                        size.height * (0.1 + 0.75 * ((i * 61) % 100) / 100) +
                        24 * math.cos(t * 0.8 + phase);
                    final radius = 14.0 + (i % 3) * 10;
                    return Positioned(
                      left: dx,
                      top: dy,
                      child: Opacity(
                        opacity: 0.10 + 0.05 * math.sin(t + phase),
                        child: Container(
                          width: radius * 2,
                          height: radius * 2,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            SafeArea(
              child: Center(
                child: Listenable.merge([_entrance, _pulse, _shimmer]).let(
                  (listenable) => AnimatedBuilder(
                    animation: listenable,
                    builder: (context, _) {
                      final pulseScale = 1.0 + 0.045 * _pulse.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value,
                              child: Transform.scale(
                                scale: _logoScale.value * pulseScale,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 24 + 10 * _pulse.value,
                                        spreadRadius: 1 + 2 * _pulse.value,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shopping_basket,
                                    size: 64,
                                    color: Color(0xFF4A148C),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Opacity(
                            opacity: _textOpacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _textOffset.value.dy * 40),
                              child: Column(
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      final shimmerX =
                                          _shimmer.value * 2 - 0.5;
                                      return LinearGradient(
                                        begin: Alignment(
                                          shimmerX - 0.3,
                                          0,
                                        ),
                                        end: Alignment(shimmerX + 0.3, 0),
                                        colors: const [
                                          Colors.white,
                                          Color(0xFFFFE0B2),
                                          Colors.white,
                                        ],
                                      ).createShader(bounds);
                                    },
                                    child: const Text(
                                      'OurShelf',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Your family's kitchen, in sync.",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 44),
                          Opacity(
                            opacity: _textOpacity.value,
                            child: _BouncingDots(controller: _pulse),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots that bounce in a staggered wave — a livelier loader than a
/// static spinner, and visibly "alive" even in a single screenshot.
class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (controller.value + i * 0.2) % 1.0;
              final bounce = math.sin(t * math.pi).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.translate(
                  offset: Offset(0, -8 * bounce),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6 + 0.4 * bounce),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
