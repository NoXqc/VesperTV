import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/live_group_styles.dart';
import 'package:nox_iptv/widgets/live_style_view.dart';

/// Live group styles (owner, 2026-11-26): the bank on the site, read as
/// data (fade + particle layers), drawn by LiveStylePainter.
void main() {
  final bankFile = File('docs/styles/group-styles.json');
  const languages = ['en', 'fr', 'es', 'it', 'el', 'de', 'pl', 'uk', 'pt'];

  tearDown(() {
    LiveGroupStyles.debugClient = null;
    LiveGroupStyles.debugFolder = null;
    LiveGroupStyles.instance.debugReset();
  });

  test('the bank on the site reads whole: every style, layer and name', () {
    final body = bankFile.readAsStringSync();
    final raw = (jsonDecode(body) as Map)['styles'] as List;
    final styles = LiveGroupStyles.parse(body);
    expect(styles.length, raw.length, reason: 'no style left out');
    expect(styles.map((s) => s.id).toSet().length, styles.length);
    for (var i = 0; i < styles.length; i++) {
      final style = styles[i];
      expect(style.layers.length, (raw[i]['layers'] as List).length,
          reason: '${style.id}: every layer uses a shape and motion we draw');
      expect(['seasonal', 'vesper', 'sports', 'fun'], contains(style.category),
          reason: style.id);
      for (final l in languages) {
        expect(style.names[l], isNotNull, reason: '${style.id} in $l');
      }
      expect(style.fade.last.a, 0,
          reason:
              '${style.id}: the fade ends clear (the count stays readable)');
    }
    // What the owner asked for.
    for (final id in [
      'christmas',
      'shooting-stars',
      'soccer',
      'hockey',
      'football',
      'basketball',
    ]) {
      expect(styles.any((s) => s.id == id), isTrue, reason: id);
    }
  });

  test('unknown shapes, motions and newer engines are left out', () {
    final styles = LiveGroupStyles.parse(jsonEncode({
      'styles': [
        {
          'id': 'mixed',
          'name': 'Mixed',
          'fade': ['#80FF0000', '#00000000'],
          'layers': [
            {'shape': 'dot', 'motion': 'fall'},
            {'shape': 'dragon', 'motion': 'fall'},
            {'shape': 'dot', 'motion': 'teleport'},
            {'shape': 'glyph:not_an_icon', 'motion': 'rise'},
            {'shape': 'glyph:sports_soccer', 'motion': 'roll'},
          ],
        },
        {
          'id': 'future',
          'name': 'Future',
          'engine': 99,
          'fade': ['#FF0000']
        },
        {
          'id': 'Bad Id',
          'name': 'Bad',
          'fade': ['#FF0000']
        },
        {
          'id': 'nameless',
          'fade': ['#FF0000']
        },
        {
          'id': 'mixed',
          'name': 'Twice',
          'fade': ['#FF0000']
        },
      ],
    }));
    expect(styles.map((s) => s.id), ['mixed']);
    expect(styles.single.layers.map((l) => l.shape),
        ['dot', 'glyph:sports_soccer']);
    expect(styles.single.names['en'], 'Mixed');
    expect(LiveGroupStyles.parse('not json'), isEmpty);
  });

  test('colours: #RRGGBB and #AARRGGBB', () {
    expect(liveStyleColor('#FF5252'), const Color(0xFFFF5252));
    expect(liveStyleColor('#80FF5252'), const Color(0x80FF5252));
    expect(liveStyleColor('#F00'), isNull);
    expect(liveStyleColor('red'), isNull);
    expect(liveStyleColor(12), isNull);
  });

  test('saved ids: style:<id> names a style, a colour id does not', () {
    LiveGroupStyles.instance
        .debugUse(LiveGroupStyles.parse(bankFile.readAsStringSync()));
    expect(LiveGroupStyles.isStyleId('style:snowfall'), isTrue);
    expect(LiveGroupStyles.isStyleId('red'), isFalse);
    expect(LiveGroupStyles.isStyleId(null), isFalse);
    expect(LiveGroupStyles.instance.styleOf('style:snowfall')?.id, 'snowfall');
    expect(LiveGroupStyles.instance.styleOf('red'), isNull);
    expect(LiveGroupStyles.instance.styleOf('style:gone'), isNull);
  });

  test('downloaded once, kept in a file, read back without the network',
      () async {
    final folder = Directory.systemTemp.createTempSync('live_styles');
    addTearDown(() => folder.deleteSync(recursive: true));
    LiveGroupStyles.debugFolder = folder.path;
    var asked = 0;
    LiveGroupStyles.debugClient = MockClient((request) async {
      asked++;
      expect(request.url.toString(), LiveGroupStyles.bankUrl);
      return http.Response.bytes(utf8.encode(bankFile.readAsStringSync()), 200);
    });
    final styles = await LiveGroupStyles.instance.load();
    expect(styles, isNotEmpty);
    expect(File('${folder.path}/live_group_styles.json').existsSync(), isTrue);
    await LiveGroupStyles.instance.load();
    expect(asked, 1, reason: 'once a run');

    // A new run with the site out of reach: the saved bank.
    LiveGroupStyles.instance.debugReset();
    LiveGroupStyles.debugClient =
        MockClient((_) async => http.Response('down', 503));
    final again = await LiveGroupStyles.instance.load();
    expect(again.length, styles.length);

    // Nothing saved and no site: the picker says so (throws).
    LiveGroupStyles.instance.debugReset();
    File('${folder.path}/live_group_styles.json').deleteSync();
    await expectLater(LiveGroupStyles.instance.load(), throwsA(anything));
  });

  test('a row naming a style the saved bank lacks downloads it once', () async {
    final folder = Directory.systemTemp.createTempSync('live_styles');
    addTearDown(() => folder.deleteSync(recursive: true));
    LiveGroupStyles.debugFolder = folder.path;
    // Saved today, but without "christmas" (synced from a newer bank).
    File('${folder.path}/live_group_styles.json').writeAsStringSync(jsonEncode({
      'styles': [
        {
          'id': 'snowfall',
          'name': 'Snowfall',
          'fade': ['#FF0000']
        },
      ],
    }));
    var asked = 0;
    LiveGroupStyles.debugClient = MockClient((_) async {
      asked++;
      return http.Response.bytes(utf8.encode(bankFile.readAsStringSync()), 200);
    });
    LiveGroupStyles.instance.ensureLoaded(wanted: 'style:snowfall');
    await _until(() => LiveGroupStyles.instance.styles.value.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(asked, 0, reason: 'a fresh file that has it: no download');

    LiveGroupStyles.instance.ensureLoaded(wanted: 'style:christmas');
    await _until(
        () => LiveGroupStyles.instance.styleOf('style:christmas') != null);
    expect(asked, 1);
    LiveGroupStyles.instance.ensureLoaded(wanted: 'style:not-in-bank');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(asked, 1, reason: 'at most once a run');
  });

  testWidgets('every bank style paints at any time, still until focused',
      (tester) async {
    final styles = LiveGroupStyles.parse(bankFile.readAsStringSync());
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget page(bool animate) => MaterialApp(
          home: Scaffold(
            body: Column(children: [
              Focus(focusNode: focus, child: const SizedBox(width: 1)),
              for (final s in styles)
                SizedBox(
                  width: 260,
                  height: 30,
                  child: LiveStyleBackground(
                      colorId: s.colorId, style: s, animate: animate),
                ),
            ]),
          ),
        );
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(false));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse,
        reason: 'a still row asks for no frames');

    double clock() => (tester
            .widget<CustomPaint>(find
                .descendant(
                    of: find.byType(LiveStyleBackground).first,
                    matching: find.byType(CustomPaint))
                .first)
            .painter! as LiveStylePainter)
        .time
        .value;
    final still = clock();
    await tester.pumpWidget(page(true));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 97));
    }
    expect(tester.takeException(), isNull);
    expect(clock(), greaterThan(still + 3), reason: 'moving');

    await tester.pumpWidget(page(false));
    await tester.pump();
    await tester.pump();
    final stopped = clock();
    await tester.pump(const Duration(seconds: 1));
    expect(clock(), stopped, reason: 'stops when the remote leaves');
    expect(tester.binding.hasScheduledFrame, isFalse);

    // A long rest: it moves 30 s, then settles until the next visit.
    await tester.pumpWidget(page(true));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final settled = clock();
    expect(settled, closeTo(stopped + 30, 0.2));
    await tester.pump(const Duration(seconds: 2));
    expect(clock(), settled, reason: 'settled while the remote stays');
    await tester.pumpWidget(page(false));
    await tester.pump();
    await tester.pumpWidget(page(true));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(clock(), greaterThan(settled), reason: 'moves on the next visit');
    await tester.pumpWidget(page(false));
    await tester.pump();
  });
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue);
}
