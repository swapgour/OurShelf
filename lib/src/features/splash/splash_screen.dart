import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../widgets/jar_shelf_icon.dart';
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

  // Two rings of sparkles orbiting the logo — this doubles as the splash's
  // loading indicator, so there's no separate dots/bar/ribbon widget below
  // the text.
  late final AnimationController _orbitOuter;
  late final AnimationController _orbitInner;

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

    _orbitOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();

    _orbitInner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
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
    _orbitOuter.dispose();
    _orbitInner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: royalGradient),
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
                child: Listenable.merge([_entrance, _pulse, _shimmer, _orbitOuter, _orbitInner]).let(
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
                                child: SizedBox(
                                  width: 128,
                                  height: 128,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      // Two rings of sparkles orbiting the
                                      // logo — this IS the splash's loading
                                      // indicator, so nothing separate is
                                      // needed below the title/tagline.
                                      ..._outerSparkles(),
                                      ..._innerSparkles(),
                                      Container(
                                        width: 100,
                                        height: 100,
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
                                        padding: const EdgeInsets.all(22),
                                        child: const JarShelfIcon(size: 56),
                                      ),
                                    ],
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

  static const _sparkleGold = Color(0xFFE9B52E);
  static const _sparklePaleGold = Color(0xFFFFE9A8);

  /// One sparkle at the given orbit [radius]/[angle] (radians, 0 = up),
  /// twinkling via the shared [_pulse] controller with a per-sparkle phase
  /// offset so they don't all flicker in lockstep — same staggering idiom
  /// as the drifting background bubbles above.
  Widget _sparkle({required double radius, required double angle, required double size, required Color color, required double phase}) {
    final tw = (_pulse.value + phase) % 1.0;
    final twinkle = math.sin(tw * math.pi).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(radius * math.sin(angle), -radius * math.cos(angle)),
      child: Opacity(
        opacity: 0.3 + 0.7 * twinkle,
        child: Transform.scale(
          scale: 0.65 + 0.45 * twinkle,
          child: Icon(Icons.auto_awesome, size: size, color: color),
        ),
      ),
    );
  }

  List<Widget> _outerSparkles() {
    const count = 6;
    final base = _orbitOuter.value * 2 * math.pi;
    return List.generate(count, (i) {
      final angle = base + i * (2 * math.pi / count);
      return _sparkle(
        radius: 76,
        angle: angle,
        size: 17,
        color: i.isEven ? _sparkleGold : _sparklePaleGold,
        phase: i * 0.16,
      );
    });
  }

  List<Widget> _innerSparkles() {
    const count = 3;
    final base = math.pi / 6 - _orbitInner.value * 2 * math.pi;
    return List.generate(count, (i) {
      final angle = base + i * (2 * math.pi / count);
      return _sparkle(
        radius: 34,
        angle: angle,
        size: 10,
        color: Colors.white,
        phase: 0.3 + i * 0.22,
      );
    });
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
