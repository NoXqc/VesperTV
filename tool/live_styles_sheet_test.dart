// Renders every style of docs/styles/group-styles.json at four moments into
// one PNG, to look at a new or changed style before it goes on the site:
//   flutter test tool/live_styles_sheet_test.dart --dart-define=OUT=<folder>
// Not part of the test suite (tool/, not test/). Uses the Flutter SDK's
// Roboto + MaterialIcons fonts (the test font draws boxes).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/live_group_styles.dart';
import 'package:nox_iptv/widgets/live_style_view.dart';

const out = String.fromEnvironment('OUT');
const fonts = String.fromEnvironment('FONTS',
    defaultValue: 'C:/src/flutter/bin/cache/artifacts/material_fonts');

Future<void> _load(String family, String file) async {
  final bytes = File('$fonts/$file').readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

void main() {
  testWidgets('live styles sheet', (tester) async {
    if (out.isEmpty) fail('Pass --dart-define=OUT=<folder>');
    await tester.runAsync(() async {
      await _load('MaterialIcons', 'materialicons-regular.otf');
      await _load('Roboto', 'roboto-regular.ttf');
    });
    final styles = LiveGroupStyles.parse(
        File('docs/styles/group-styles.json').readAsStringSync());
    const times = [2.6, 3.0, 3.4, 3.8];
    tester.view.physicalSize = Size(1100, 60.0 + styles.length * 52);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final clocks = [for (final t in times) ValueNotifier<double>(t)];
    // Scenes: the rest moment, then 1.5 / 3 / 4.5 s after the remote came.
    final sceneClocks = [
      for (final e in const [null, 1.5, 3.0, 4.5]) ValueNotifier<double?>(e)
    ];
    Widget row(LiveGroupStyle s, int i) => Container(
          width: 260,
          height: 44,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8)),
          child: Stack(alignment: Alignment.centerLeft, children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                    painter: LiveStylePainter(s, clocks[i],
                        sceneElapsed: s.scene == null ? null : sceneClocks[i])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.grid_view_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s.names['en']!,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white,
                            fontSize: 15))),
                const Text('128',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white54,
                        fontSize: 13)),
              ]),
            ),
          ]),
        );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF0B0B10),
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            for (final s in styles)
              Row(children: [
                for (var i = 0; i < times.length; i++) row(s, i),
              ]),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/live_styles_sheet.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
