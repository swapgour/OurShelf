// One-off dev utility, not a real test — run with `flutter test
// tool/export_icon.dart` to (re)generate the PNG sources that
// flutter_launcher_icons reads (see pubspec.yaml's flutter_launcher_icons
// section), whenever lib/src/widgets/jar_shelf_icon.dart changes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourshelf/src/widgets/jar_shelf_icon.dart';

Future<void> _exportPng({
  required String path,
  required int size,
  List<Color>? background,
  required double contentFraction,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();

  if (background != null) {
    final rect = Rect.fromLTWH(0, 0, s, s);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: background,
        ).createShader(rect),
    );
  }

  final iconSize = s * contentFraction;
  final offset = (s - iconSize) / 2;
  canvas.save();
  canvas.translate(offset, offset);
  const JarShelfPainter().paint(canvas, Size.square(iconSize));
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path');
}

void main() {
  testWidgets('export launcher icon sources', (tester) async {
    // picture.toImage()/toByteData() resolve through the engine's real
    // event loop, which testWidgets' default fake-async zone never ticks —
    // runAsync escapes to a real zone so those futures actually complete.
    await tester.runAsync(() async {
      // Legacy/full-bleed icon (Play Store listing, pre-adaptive-icon
      // Android): royal gradient background baked in, generous fill.
      await _exportPng(
        path: 'assets/icon/icon.png',
        size: 1024,
        background: const [Color(0xFF351653), Color(0xFF54277D), Color(0xFFE9B52E)],
        contentFraction: 0.72,
      );

      // Adaptive icon foreground layer: transparent background, kept
      // inside the ~66% safe zone so circular/squircle Android masks
      // don't clip it.
      await _exportPng(
        path: 'assets/icon/icon_foreground.png',
        size: 1024,
        contentFraction: 0.58,
      );
    });
  });
}
