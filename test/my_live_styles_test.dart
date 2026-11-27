import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/live_group_styles.dart';
import 'package:nox_iptv/services/my_live_styles.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/screens/settings/my_live_styles_screen.dart';
import 'package:nox_iptv/widgets/live_style_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Owner, 2026-11-27: "import custom live groups so if users want to build
/// their own they could import it into Vesper".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  Map<String, Object?> style(String id,
          {Object? name, String shape = 'dot', String motion = 'fall'}) =>
      {
        'id': id,
        'name': name ?? 'Style $id',
        'fade': ['#99FF8800', '#00000000'],
        'layers': [
          {
            'shape': shape,
            'motion': motion,
            'count': 8,
            'size': [3, 6]
          }
        ],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    LiveGroupStyles.instance.debugReset();
    MyLiveStyles.instance.debugReset();
    MyLiveStyles.debugClient = null;
    MyLiveStyles.instance.attach(storage);
  });

  tearDown(() {
    MyLiveStyles.debugClient = null;
    MyLiveStyles.instance.debugReset();
    LiveGroupStyles.instance.debugReset();
  });

  List<String> mineIds() =>
      [for (final s in MyLiveStyles.instance.styles) s.id];

  group('a style made ours', () {
    test('id cleaned and prefixed, a name in any language, category mine', () {
      final s = MyLiveStyles.ours({
        ...style('Pumpkin Patch!'),
        'name': {'fr': 'Citrouilles'},
        'category': 'seasonal',
      })!;
      expect(s['id'], 'my-pumpkin-patch');
      expect(s['name'], {'fr': 'Citrouilles', 'en': 'Citrouilles'});
      expect(s['category'], LiveGroupStyles.mineCategory);
      expect(MyLiveStyles.ours({...style('my-rain')})!['id'], 'my-rain',
          reason: 'already ours: not prefixed twice');
      expect(MyLiveStyles.ours({...style('x'), 'name': null})!['name'], 'x');
    });

    test('nothing to draw = left out', () {
      expect(
          MyLiveStyles.ours({
            'id': 'a',
            'name': 'A',
            'layers': [
              {'shape': 'teapot', 'motion': 'fall'}
            ]
          }),
          isNull);
      expect(
          MyLiveStyles.ours({
            'name': 'no id',
            'fade': ['#FF000000']
          }),
          isNull);
      expect(MyLiveStyles.ours('text'), isNull);
    });

    test('the starter file on the site imports whole; the page lists it all',
        () async {
      final result = await MyLiveStyles.instance
          .import(File('docs/styles/starter.json').readAsStringSync());
      expect(result.ids, ['my-autumn-leaves', 'my-night-sky']);
      expect(result.skipped, 0);
      expect([
        for (final s in MyLiveStyles.instance.styles) s.layers.length
      ], [
        1,
        2
      ], reason: 'every layer of the starter is drawn');
      final page = File('docs/styles/make.html').readAsStringSync();
      for (final name in [
        ...LiveStyleLayer.shapes,
        ...LiveStyleLayer.motions,
        ...liveStyleGlyphs.keys,
      ]) {
        expect(page, contains('<code>$name</code>'), reason: name);
      }
    });

    test('no bank style uses the my- prefix', () {
      final bank = LiveGroupStyles.parse(
          File('docs/styles/group-styles.json').readAsStringSync());
      expect(bank, isNotEmpty);
      expect(
          bank.where((s) => s.id.startsWith(MyLiveStyles.idPrefix)), isEmpty);
    });
  });

  group('import text', () {
    test('one style, a pack or a list; first in the gallery, saved', () async {
      LiveGroupStyles.instance.debugUse(LiveGroupStyles.parse(jsonEncode({
        'styles': [style('snowfall')]
      })));
      final one = await MyLiveStyles.instance.import(jsonEncode(style('rain')));
      expect(one.ids, ['my-rain']);
      final pack = await MyLiveStyles.instance.import(jsonEncode({
        'styles': [
          style('a'),
          style('b'),
          {'id': 'bad'}
        ]
      }));
      expect(pack.ids, ['my-a', 'my-b']);
      expect(pack.skipped, 1);
      expect([for (final s in LiveGroupStyles.instance.styles.value) s.id],
          ['my-a', 'my-b', 'my-rain', 'snowfall']);
      expect(LiveGroupStyles.instance.styleOf('style:my-rain')?.isMine, isTrue);
      // A restart reads them back.
      expect(storage.getMyLiveStyles(), isNotEmpty);
      MyLiveStyles.instance.attach(storage);
      expect(mineIds(), ['my-a', 'my-b', 'my-rain']);
    });

    test('the same id again replaces it', () async {
      await MyLiveStyles.instance.import(jsonEncode(style('rain')));
      final again = await MyLiveStyles.instance
          .import(jsonEncode(style('rain', name: 'Heavy rain')));
      expect(again.replaced, 1);
      expect(mineIds(), ['my-rain']);
      expect(MyLiveStyles.instance.styles.single.name, 'Heavy rain');
    });

    test('problems say what is wrong', () async {
      Future<MyStylesProblem?> problem(String text) async {
        try {
          await MyLiveStyles.instance.import(text);
          return null;
        } on MyStylesError catch (e) {
          return e.problem;
        }
      }

      expect(await problem('hello'), MyStylesProblem.notStyles);
      expect(await problem('{"foo": 1}'), MyStylesProblem.notStyles);
      expect(
          await problem(jsonEncode({
            'styles': [
              {
                'id': 'x',
                'name': 'X',
                'layers': [
                  {'shape': 'teapot', 'motion': 'fall'}
                ]
              }
            ]
          })),
          MyStylesProblem.nothingUsable);
      expect(await problem('{"id":"x","name":"${'y' * 210000}"}'),
          MyStylesProblem.tooBig);
      expect(mineIds(), isEmpty);
    });

    test('at most maxStyles: the oldest go', () async {
      await MyLiveStyles.instance.import(jsonEncode(
          [for (var i = 0; i < MyLiveStyles.maxStyles; i++) style('old$i')]));
      await MyLiveStyles.instance.import(jsonEncode(style('new')));
      expect(mineIds().length, MyLiveStyles.maxStyles);
      expect(mineIds().first, 'my-new');
      expect(mineIds(), isNot(contains('my-old${MyLiveStyles.maxStyles - 1}')));
    });

    test('remove one', () async {
      await MyLiveStyles.instance.import(jsonEncode([style('a'), style('b')]));
      await MyLiveStyles.instance.remove('my-a');
      expect(mineIds(), ['my-b']);
      await MyLiveStyles.instance.remove('my-b');
      expect(mineIds(), isEmpty);
      expect(storage.getMyLiveStyles(), isEmpty);
    });
  });

  group('import a link', () {
    const link = 'https://gist.example/raw/my-styles.json';
    var served = '';
    var status = 200;

    setUp(() {
      served = jsonEncode({
        'styles': [style('fog'), style('mist')]
      });
      status = 200;
      MyLiveStyles.debugClient =
          MockClient((r) async => http.Response(served, status));
    });

    test('fetched, kept with its link, refreshed once a run', () async {
      final result = await MyLiveStyles.instance.import(link);
      expect(result.ids, ['my-fog', 'my-mist']);
      expect(MyLiveStyles.instance.linkOf('my-fog'), link);
      expect(MyLiveStyles.instance.countFrom(link), 2);

      // The maker changed the file.
      served = jsonEncode(style('fog', name: 'Thick fog'));
      MyLiveStyles.instance.attach(storage); // a new run
      await MyLiveStyles.instance.refreshLinks();
      expect(mineIds(), ['my-fog']);
      expect(MyLiveStyles.instance.styles.single.name, 'Thick fog');

      // A failed refresh keeps what was there.
      status = 500;
      MyLiveStyles.instance.attach(storage);
      await MyLiveStyles.instance.refreshLinks();
      expect(mineIds(), ['my-fog']);
    });

    test('removing a style from a link removes the link', () async {
      await MyLiveStyles.instance.import(link);
      await MyLiveStyles.instance.import(jsonEncode(style('own')));
      await MyLiveStyles.instance.remove('my-mist');
      expect(mineIds(), ['my-own']);
    });

    test('a dead link says so', () async {
      status = 404;
      await expectLater(
          MyLiveStyles.instance.import(link),
          throwsA(isA<MyStylesError>()
              .having((e) => e.problem, 'problem', MyStylesProblem.download)
              .having((e) => e.detail, 'detail', 'HTTP 404')));
    });
  });

  test('From phone: the styles kind takes long text, a link stays capped', () {
    final long = jsonEncode({
      'styles': [for (var i = 0; i < 40; i++) style('s$i')]
    });
    expect(long.length, greaterThan(4000));
    final r = PairingResult.fromJson({'v': 1, 'mode': 'styles', 'link': long})!;
    expect(r.mode, 'styles');
    expect(r.link, long);
    expect(PairingKind.styles.mode, 'styles');
    expect(PairingKind.styles.isLink, isTrue);
    final capped =
        PairingResult.fromJson({'v': 1, 'mode': 'link', 'link': long})!;
    expect(capped.link.length, 4000);
  });

  test('saved like group colours: synced and transferred', () async {
    expect(storage.exportForSync().containsKey(AppConstants.keyMyLiveStyles),
        isFalse,
        reason: 'nothing saved yet');
    await MyLiveStyles.instance.import(jsonEncode(style('rain')));
    Object? value(Map<String, Object?> export) =>
        (export[AppConstants.keyMyLiveStyles] as Map?)?['v'];
    expect('${value(storage.exportForSync())}', contains('my-rain'));
    expect('${value(storage.exportForTransfer())}', contains('my-rain'));
  });

  testWidgets('the gallery: Your own styles… first, then Your styles',
      (tester) async {
    LiveGroupStyles.instance.debugUse(LiveGroupStyles.parse(jsonEncode({
      'styles': [
        {...style('snowfall'), 'category': 'seasonal', 'name': 'Snowfall'}
      ]
    })));
    await tester.runAsync(() =>
        MyLiveStyles.instance.import(jsonEncode(style('rain', name: 'Rain'))));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showLiveStylePicker(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your own styles…'), findsOneWidget);
    expect(find.text('Your styles'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('Snowfall'), findsOneWidget);
    final yours = tester.getTopLeft(find.text('Your styles')).dy;
    expect(yours, lessThan(tester.getTopLeft(find.text('Seasonal')).dy));
    expect(
        tester.getTopLeft(find.text('Your own styles…')).dy, lessThan(yours));
  });

  // Owner: a small QR code to the how-to page, TV only.
  for (final tv in [true, false]) {
    testWidgets(
        'Your live styles page: how-to QR on ${tv ? 'a TV' : 'a phone'}',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = AppPreferences(storage);
      await prefs.init();
      prefs.isTelevision = tv;
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: const MaterialApp(home: MyLiveStylesScreen()),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('how-to-qr')),
          tv ? findsOneWidget : findsNothing);
      if (tv) {
        final size = tester.getSize(find.byType(QrImageView));
        expect(size.width, MyLiveStylesScreen.qrSize);
      }
      expect(tester.takeException(), isNull);
    });
  }

  group('the live_styles tool (AI apps)', () {
    late VesperToolbox box;

    setUp(() async {
      final temp = await Directory.systemTemp.createTemp('vesper_styles_');
      addTearDown(() => temp.delete(recursive: true));
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      final manager = PlaylistManager(storage, catalog);
      addTearDown(manager.dispose);
      final prefs = AppPreferences(storage);
      await prefs.init();
      box = VesperToolbox(
        playlist: manager,
        playback: PlaybackService(storage, manager),
        epg: EpgService(storage),
        storage: storage,
        prefs: prefs,
        host: _Host(),
      );
      LiveGroupStyles.instance.debugUse(LiveGroupStyles.parse(jsonEncode({
        'styles': [style('snowfall')]
      })));
    });

    test('add, list, remove', () async {
      final added = await box.call('live_styles', {
        'action': 'add',
        'style': style('pumpkins', name: 'Pumpkin patch', shape: 'glyph:cake'),
      });
      expect(added['added'], ['my-pumpkins']);
      expect('${added['next']}', contains('style my-pumpkins'));

      final listed = await box.call('live_styles', {'action': 'list'});
      final ids = [for (final s in listed['styles'] as List) (s as Map)['id']];
      expect(ids, ['my-pumpkins', 'snowfall']);
      expect(((listed['styles'] as List).first as Map)['yours'], isTrue);

      await box.call('live_styles', {'action': 'remove', 'id': 'pumpkins'});
      expect(mineIds(), isEmpty);
    });

    test('a style it cannot draw is refused with the reason', () async {
      final answer = await box.call('live_styles', {
        'action': 'add',
        'style': {
          'id': 'x',
          'name': 'X',
          'layers': [
            {'shape': 'teapot', 'motion': 'fall'}
          ]
        },
      });
      expect('${answer['error']}', contains('known shape and motion'));
      expect(mineIds(), isEmpty);
    });

    test('a scene is added; what was left out comes back (scene_notes)',
        () async {
      final answer = await box.call('live_styles', {
        'action': 'add',
        'style': {
          'id': 'walker',
          'name': 'Walker',
          'scene': {
            'sprites': {
              'dot': {
                'palette': {'r': '#FF0000'},
                'frames': [
                  ['rr', 'rr']
                ],
              },
            },
            'actors': [
              {
                'sprite': 'dot',
                'at': [0.5, 1]
              },
              {
                'sprite': 'ghost',
                'at': [0.2, 1]
              },
            ],
          },
        },
      });
      expect(answer['added'], ['my-walker']);
      expect('${answer['scene_notes']}', contains('"ghost": no such sprite'));
      expect(MyLiveStyles.instance.styles.single.scene?.actors.length, 1);
    });

    test('a scene with nothing to draw is refused with its notes (as text)',
        () async {
      final answer = await box.call('live_styles', {
        'action': 'add',
        'style': jsonEncode({
          'id': 'empty',
          'name': 'Empty',
          'scene': {
            'sprites': <String, Object?>{},
            'actors': [
              {
                'sprite': 'ghost',
                'at': [0.5, 1]
              },
            ],
          },
        }),
      });
      expect('${answer['error']}', contains('"ghost": no such sprite'));
      expect('${answer['error']}', contains('scene with a sprite'));
      expect(mineIds(), isEmpty);
    });

    test('the description has the scene format and the editor', () {
      final tool = vesperTools.firstWhere((t) => t.name == 'live_styles');
      for (final words in [
        'SCENES',
        '"engine": 2',
        '"sprites"',
        '"actors"',
        '"path"',
        'original characters',
        'scene_notes',
        'vespertv.app/styles/editor.html',
      ]) {
        expect(tool.description, contains(words), reason: words);
      }
    });

    test('the description lists the shapes and motions', () {
      final tool = vesperTools.firstWhere((t) => t.name == 'live_styles');
      for (final shape in LiveStyleLayer.shapes) {
        expect(tool.description, contains(shape));
      }
      for (final motion in LiveStyleLayer.motions) {
        expect(tool.description, contains(motion));
      }
    });
  });
}

class _Host implements VesperHost {
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async =>
      true;
  @override
  Future<void> playChannel(Channel channel) async {}
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async => true;
  @override
  void showMessage(String text) {}
}
