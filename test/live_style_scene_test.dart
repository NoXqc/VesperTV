import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/device_memory_service.dart';
import 'package:nox_iptv/services/live_group_styles.dart';
import 'package:nox_iptv/services/live_style_scene.dart';
import 'package:nox_iptv/services/my_live_styles.dart';
import 'package:nox_iptv/widgets/live_style_view.dart';

/// Sprite scenes (engine 2): owner, 2026-11-27: "loop on focus, rest when
/// out of focus", an editor page and the AI connector.
void main() {
  Map<String, Object?> sceneJson({
    double length = 8,
    double rest = 2,
    List<Object?>? actors,
  }) =>
      {
        'length': length,
        'rest': rest,
        'grid': 22,
        'sprites': {
          'dot': {
            'palette': {'r': '#FF0000', 'g': '#00FF00'},
            'frames': {
              'walk': [
                ['rr', 'rr'],
                ['gg', 'gg'],
              ],
              'still': [
                ['gr', 'rg'],
              ],
            },
            'fps': 2,
          },
          'box': {
            'palette': {'b': '#0000FF'},
            'frames': [
              ['bbb', 'b.b', 'bbb'],
            ],
          },
        },
        'actors': actors ??
            [
              {
                'sprite': 'box',
                'at': [0.5, 1.0]
              },
              {
                'sprite': 'dot',
                'path': [
                  {'t': 0, 'x': 0, 'y': 1, 'play': 'walk'},
                  {'t': 4, 'x': 1, 'y': 1, 'arc': 0.5},
                  {'t': 6, 'x': 0.5, 'y': 0.5, 'play': 'still', 'flip': true},
                ],
              },
            ],
      };

  group('parse', () {
    test('sprites, frame sets, palette, actors', () {
      final notes = <String>[];
      final scene = LiveStyleScene.fromJson(sceneJson(), notes: notes)!;
      expect(notes, isEmpty);
      expect(scene.length, 8);
      expect(scene.rest, 2);
      final dot = scene.sprites['dot']!;
      expect((dot.width, dot.height), (2, 2));
      expect(dot.sets.keys, ['walk', 'still']);
      expect(dot.sets['walk']![0], List.filled(4, 0xFFFF0000));
      final box = scene.sprites['box']!;
      expect(box.firstSet, 'default');
      expect(box.sets['default']![0][4], 0, reason: '"." is clear');
      expect(scene.actors.length, 2);
    });

    test('what is wrong is left out and said', () {
      final notes = <String>[];
      final scene = LiveStyleScene.fromJson(
          sceneJson(actors: [
            {
              'sprite': 'ghost',
              'at': [0.5, 1]
            },
            {'sprite': 'box'},
            {
              'sprite': 'dot',
              'path': [
                {'t': 0, 'x': 0, 'y': 1, 'play': 'fly'},
              ],
            },
          ]),
          notes: notes)!;
      expect(scene.actors.length, 1);
      expect(notes.join('\n'), contains('"ghost": no such sprite'));
      expect(notes.join('\n'), contains('no "at" and no "path"'));
      expect(notes.join('\n'), contains('frame set "fly" not in the sprite'));
      // Nothing to draw at all: no scene.
      expect(
          LiveStyleScene.fromJson(sceneJson(actors: [
            {
              'sprite': 'ghost',
              'at': [0.5, 1]
            },
          ])),
          isNull);
      expect(LiveStyleScene.check('nope'), ['scene is not an object']);
    });

    test('limits: frames cut to 32 x 32, unknown colours clear', () {
      final notes = <String>[];
      final scene = LiveStyleScene.fromJson({
        'sprites': {
          'big': {
            'palette': {'x': '#FFFFFF'},
            'frames': [
              [for (var i = 0; i < 40; i++) 'x' * 40],
            ],
          },
          'odd': {
            'palette': {'x': 'red'},
            'frames': [
              ['xz'],
            ],
          },
        },
        'actors': [
          {
            'sprite': 'big',
            'at': [0.5, 1]
          },
          {
            'sprite': 'odd',
            'at': [0.5, 1]
          },
        ],
      }, notes: notes)!;
      expect((scene.sprites['big']!.width, scene.sprites['big']!.height),
          (32, 32));
      expect(scene.sprites['odd']!.sets['default']![0], [0, 0]);
      final all = notes.join('\n');
      expect(all, contains('over 32 x 32'));
      expect(all, contains('colour "red"'));
      expect(all, contains('"z" not in its palette'));
    });

    test('a style may be a scene alone; engine 2 is drawn, 3 is not', () {
      final style = LiveGroupStyle.fromJson({
        'id': 'scene-only',
        'name': 'Scene only',
        'engine': 2,
        'scene': sceneJson(),
      });
      expect(style?.scene, isNotNull);
      expect(
          LiveGroupStyle.fromJson({
            'id': 'later',
            'name': 'Later',
            'engine': 3,
            'scene': sceneJson(),
          }),
          isNull);
    });

    test('an imported scene is marked engine 2 for older apps', () {
      final ours = MyLiveStyles.ours({
        'id': 'walker',
        'name': 'Walker',
        'scene': sceneJson(),
      })!;
      expect(ours['engine'], 2);
    });
  });

  group('timeline', () {
    final scene = LiveStyleScene.fromJson(sceneJson())!;
    LiveScenePlacement dotAt(double t) =>
        scene.at(t).firstWhere((p) => p.sprite == scene.sprites['dot']);

    test('straight between points, a hop peaking halfway', () {
      expect(dotAt(2).x, closeTo(0.5, 1e-9));
      expect(dotAt(2).y, closeTo(1, 1e-9));
      // 4 -> 6: x 1 -> 0.5, y 1 -> 0.5 with a 0.5 row hop.
      final mid = dotAt(5);
      expect(mid.x, closeTo(0.75, 1e-9));
      expect(mid.y, closeTo(0.75 - 0.5, 1e-9));
    });

    test('before the first point and after the last it stays', () {
      expect(dotAt(7.9).x, closeTo(0.5, 1e-9));
      expect(dotAt(7.9).y, closeTo(0.5, 1e-9));
    });

    test('frame sets and facing hold until the next point', () {
      expect(dotAt(1).set, 'walk');
      expect(dotAt(1).flip, isFalse);
      expect(dotAt(6.5).set, 'still');
      expect(dotAt(6.5).flip, isTrue);
    });

    test('frames step at fps, the loop wraps', () {
      expect(dotAt(0.1).frame, 0);
      expect(dotAt(0.6).frame, 1, reason: '2 fps');
      expect(dotAt(1.1).frame, 0);
      expect(scene.at(10).length, scene.at(2).length);
      final wrapped =
          scene.at(10).firstWhere((p) => p.sprite == scene.sprites['dot']);
      expect(wrapped.x, closeTo(0.5, 1e-9),
          reason: '10 s = 2 s of an 8 s loop');
    });

    test('eases', () {
      final eased = LiveStyleScene.fromJson(sceneJson(actors: [
        {
          'sprite': 'box',
          'path': [
            {'t': 0, 'x': 0, 'y': 1, 'ease': 'in'},
            {'t': 2, 'x': 1, 'y': 1, 'ease': 'out'},
            {'t': 4, 'x': 0, 'y': 1, 'ease': 'inout'},
            {'t': 6, 'x': 1, 'y': 1},
          ],
        },
      ]))!;
      double x(double t) => eased.at(t).single.x;
      expect(x(1), closeTo(0.25, 1e-9), reason: 'in: slow start');
      expect(x(3), closeTo(0.25, 1e-9), reason: 'out: fast start back');
      expect(x(5), closeTo(0.5, 1e-9), reason: 'inout: halfway at half');
    });

    test('show windows, also across the loop end', () {
      final s = LiveStyleScene.fromJson(sceneJson(actors: [
        {
          'sprite': 'box',
          'at': [0.5, 1],
          'show': [1, 2],
        },
        {
          'sprite': 'box',
          'at': [0.2, 1],
          'show': [
            [7, 1],
          ],
        },
      ]))!;
      expect(s.at(1.5).map((p) => p.x), [0.5]);
      expect(s.at(7.5).map((p) => p.x), [0.2]);
      expect(s.at(0.5).map((p) => p.x), [0.2]);
      expect(s.at(3), isEmpty);
    });
  });

  testWidgets('drawn crisp: each sprite pixel whole device pixels',
      (tester) async {
    final scene = LiveStyleScene.fromJson(sceneJson(actors: [
      {
        'sprite': 'box',
        'at': [0.5, 1.0]
      },
    ]))!;
    // A 44 px row, grid 22: 2 px a sprite pixel; the 3 x 3 box = 6 x 6 px,
    // feet on the bottom, middle at x 50.
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      paintScene(Canvas(recorder), const Size(100, 44), scene, 0, 1);
      return recorder.endRecording().toImage(100, 44);
    });
    final bytes = (await tester.runAsync(
        () async => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    Color at(int x, int y) {
      final i = (y * 100 + x) * 4;
      return Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i),
          bytes.getUint8(i + 1), bytes.getUint8(i + 2));
    }

    const blue = Color(0xFF0000FF);
    expect(at(47, 38), blue, reason: 'top left of the box');
    expect(at(52, 43), blue, reason: 'bottom right');
    expect(at(49, 40).a, 0, reason: 'the "." in the middle is clear');
    expect(at(46, 38).a, 0);
    expect(at(53, 43).a, 0);
    expect(at(47, 37).a, 0);
  });

  group('moves while focused, rests out of focus', () {
    final style = LiveGroupStyle.fromJson({
      'id': 'walker',
      'name': 'Walker',
      'engine': 2,
      'fade': ['#80FF0000', '#00000000'],
      'scene': sceneJson(rest: 2),
    })!;

    setUp(() => DeviceTypeService.television = true);
    tearDown(() => DeviceTypeService.television = false);

    double? elapsed(WidgetTester tester) => (tester
            .widget<CustomPaint>(find
                .descendant(
                    of: find.byType(LiveStyleBackground),
                    matching: find.byType(CustomPaint))
                .first)
            .painter! as LiveStylePainter)
        .sceneElapsed!
        .value;

    test('a visit plays whole loops', () {
      final scene = style.scene!;
      expect(LiveStyleBackground.visitFor(const Duration(seconds: 30), scene),
          const Duration(seconds: 32));
      expect(LiveStyleBackground.visitFor(const Duration(seconds: 12), scene),
          const Duration(seconds: 16));
      expect(LiveStyleBackground.visitFor(const Duration(seconds: 30), null),
          const Duration(seconds: 30),
          reason: 'particles keep the 30 s visit');
    });

    testWidgets('moves even when the device has animations off',
        (tester) async {
      // LOG-D6MCDD (onn 4K Pro): the box's animation scale at 0 made Flutter
      // report disableAnimations, and every live style stayed still.
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 260,
            height: 44,
            child: LiveStyleBackground(
                colorId: style.colorId, style: style, animate: true),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(elapsed(tester), closeTo(2, 0.1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('loop on focus, back to the rest moment after', (tester) async {
      Widget row(bool focused) => MaterialApp(
            home: SizedBox(
              width: 260,
              height: 44,
              child: LiveStyleBackground(
                  colorId: style.colorId, style: style, animate: focused),
            ),
          );
      await tester.pumpWidget(row(false));
      await tester.pump();
      expect(elapsed(tester), isNull, reason: 'still: the rest moment');

      await tester.pumpWidget(row(true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(elapsed(tester), closeTo(3, 0.1));
      await tester.pump(const Duration(seconds: 7));
      expect(elapsed(tester), closeTo(10, 0.1),
          reason: 'still going past one 8 s loop');
      // The 30 s visit is 4 whole loops (32 s): past 30 s it still moves,
      // then it stops on the rest moment.
      await tester.pump(const Duration(seconds: 21));
      expect(elapsed(tester), closeTo(31, 0.1));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(elapsed(tester), isNull, reason: 'whole loops, then rest');

      await tester.pumpWidget(row(false));
      await tester.pump();
      await tester.pump();
      expect(elapsed(tester), isNull, reason: 'out of focus: rest');
    });
  });

  test("the site's example scene is drawn whole; the page lists the keys", () {
    final page = File('docs/styles/make.html').readAsStringSync();
    final pre = RegExp(r'<pre id="scene-example">([\s\S]*?)</pre>')
        .firstMatch(page)!
        .group(1)!;
    final text = pre
        .replaceFirst(RegExp(r'<button[\s\S]*?</button>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    final json = jsonDecode(text) as Map<String, Object?>;
    expect(json['engine'], 2);
    expect(LiveStyleScene.check(json['scene']), isEmpty);
    final scene = LiveGroupStyle.fromJson(json)!.scene!;
    expect(scene.at(scene.rest), isNotEmpty);
    for (final key in [
      'length',
      'rest',
      'grid',
      'sprites',
      'palette',
      'frames',
      'fps',
      'actors',
      'path',
      'show',
      'engine',
    ]) {
      expect(page, contains('<code>$key</code>'), reason: key);
    }
  });

  test('the bank\'s scenes are drawn whole and need engine 2', () {
    final raw =
        (jsonDecode(File('docs/styles/group-styles.json').readAsStringSync())
            as Map)['styles'] as List;
    final scenes = [
      for (final s in raw)
        if ((s as Map)['scene'] != null) s
    ];
    expect(scenes.map((s) => s['id']),
        containsAll(['fox-trail', 'rocket-ride', 'sleigh-ride', 'slapshot']));
    for (final s in scenes) {
      expect(s['engine'], 2, reason: '${s['id']}');
      expect(LiveStyleScene.check(s['scene']), isEmpty, reason: '${s['id']}');
      final scene = LiveStyleScene.fromJson(s['scene'])!;
      // The rest moment shows something.
      expect(scene.at(scene.rest), isNotEmpty, reason: '${s['id']}');
    }
  });
}
