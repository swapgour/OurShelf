import 'package:flutter/material.dart';

/// OurShelf's brand mark: two gradient-shaded pantry jars (glass body, gold
/// lid, highlight streak) standing on a bevelled gold shelf plank, with a
/// soft grounding shadow. Shared by the splash screen, the Home screen
/// header, and the generated Android launcher icon (see
/// `tool/export_icon.dart`) so all three stay in sync from one definition.
class JarShelfIcon extends StatelessWidget {
  const JarShelfIcon({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: JarShelfPainter());
  }
}

/// Coordinates are drawn in a fixed 40x40 space and scaled to fit whatever
/// size the [CustomPaint] is given.
class JarShelfPainter extends CustomPainter {
  const JarShelfPainter();

  static const jarGlass = [Color(0xFFC9A8E8), Color(0xFF8052A5), Color(0xFF351653)];
  static const lidGold = [Color(0xFFFFE9A8), Color(0xFFE9B52E), Color(0xFFB9850F)];
  static const lidGoldDark = [Color(0xFFC9972E), Color(0xFF8A6410)];
  static const plankGold = [Color(0xFFF0C14B), Color(0xFFB9850F)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);

    final shadowRect = Rect.fromCenter(center: const Offset(20, 37.5), width: 32, height: 6);
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0)],
        ).createShader(shadowRect),
    );

    _drawJar(canvas, const Offset(3, 12), 0.5);
    _drawJar(canvas, const Offset(13.6, 7.68), 0.62);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 33.6, 32, 1.8), const Radius.circular(0.9)),
      Paint()..color = const Color(0xFF6B4A0A).withValues(alpha: 0.5),
    );
    final frontRect = const Rect.fromLTWH(4, 29.5, 32, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frontRect, const Radius.circular(1.8)),
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: plankGold)
            .createShader(frontRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(5, 28.8, 30, 1.4), const Radius.circular(0.7)),
      Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.9),
    );

    canvas.restore();
  }

  void _drawJar(Canvas canvas, Offset translate, double scale) {
    canvas.save();
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);

    final rimRect = Rect.fromCenter(center: const Offset(20, 9), width: 20, height: 6.8);
    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: lidGoldDark)
            .createShader(rimRect),
    );

    final lidRect = const Rect.fromLTWH(10, 4, 20, 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, const Radius.circular(2.5)),
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: lidGold)
            .createShader(lidRect),
    );

    final body = Path()
      ..moveTo(12, 12)
      ..quadraticBezierTo(11, 12, 11, 14)
      ..lineTo(10, 32)
      ..quadraticBezierTo(10, 36, 14, 36)
      ..lineTo(26, 36)
      ..quadraticBezierTo(30, 36, 30, 32)
      ..lineTo(29, 14)
      ..quadraticBezierTo(29, 12, 28, 12)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: jarGlass)
            .createShader(body.getBounds()),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    final highlight = Path()
      ..moveTo(14, 15)
      ..quadraticBezierTo(13, 20, 13.5, 30)
      ..quadraticBezierTo(13.5, 33, 15, 34);
    canvas.drawPath(
      highlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant JarShelfPainter oldDelegate) => false;
}
