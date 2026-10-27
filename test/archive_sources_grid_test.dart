import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/settings/archive_sources_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/refined_finish.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cache extends ArchiveCache {
  @override
  Future<void> deleteSource(String key) async {}
  @override
  Future<void> clear() async {}
}

ArchiveSource _source(int i, {bool listOnly = false, bool server = false}) =>
    ArchiveSource(
      manifestUrl: 'https://source-$i.example/manifest.json',
      name: 'Source $i',
      listOnly: listOnly,
      catalogProviderUrl: !listOnly && !server && i.isEven
          ? ArchiveCatalogProvider.baseUrl
          : null,
      server: server
          ? const MediaServerLogin(
              kind: MediaServerKind.jellyfin,
              userId: 'fixture-user',
              token: 'fixture-token',
              deviceId: 'fixture-device')
          : null,
      catalogs: const [
        ArchiveCatalog(type: ArchiveType.movie, id: 'movies', name: 'Movies'),
        ArchiveCatalog(type: ArchiveType.series, id: 'shows', name: 'TV Shows'),
      ],
    );

String _control(ArchiveSource s, String action) => 'source-${s.key}-$action';

Future<ArchiveService> _open(WidgetTester tester, List<ArchiveSource> sources,
    {Size size = const Size(1280, 720),
    bool tv = true,
    double textScale = 1,
    NavigationMode navigationMode = NavigationMode.traditional,
    String paletteName = 'Dark / Gold',
    bool refined = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode(sources.map((s) => s.toJson()).toList()),
  });
  final storage = StorageService();
  await storage.init();
  final service = ArchiveService(storage,
      cache: _Cache(),
      api: ArchiveApiService(
          client: MockClient(
              (_) async => http.Response('{"metas":[],"streams":[]}', 200))));
  addTearDown(service.dispose);
  final preferences = AppPreferences(storage)
    ..isTelevision = tv
    ..layoutMode = tv ? 'tv' : 'auto'
    ..palette = AppConstants.cyberpunkPalettes
        .firstWhere((p) => p.label == paletteName);
  addTearDown(preferences.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<ArchiveService>.value(value: service),
      ChangeNotifierProvider<AppPreferences>.value(value: preferences),
      Provider<StorageService>.value(value: storage),
    ],
    child: MaterialApp(
      theme: RefinedFinish.apply(
          ThemeData.dark().copyWith(
              colorScheme: buildPaletteColorScheme(
                  preferences.palette, Brightness.dark)),
          refined),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              navigationMode: navigationMode),
          child: child!),
      home: const Scaffold(body: Text('Entry point')),
    ),
  ));
  final context = tester.element(find.text('Entry point'));
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const RepaintBoundary(
          key: ValueKey('preview'), child: ArchiveSourcesScreen())));
  await tester.pumpAndSettle();
  return service;
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _focusControl(WidgetTester tester, String label) async {
  tester.widget<InkWell>(find.byKey(ValueKey(label))).focusNode!.requestFocus();
  await tester.pumpAndSettle();
  expect(_focused, label);
}

void _visible(WidgetTester tester, String label) {
  final rect = tester.getRect(find.byKey(ValueKey(label)));
  expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
  expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
}

void main() {
  setUpAll(() async {
    // Optional local visual review with real fonts; normal CI uses Ahem.
    for (final entry in {
      'Roboto': Platform.environment['MEDIAHUB_PREVIEW_FONT'],
      'MaterialIcons': Platform.environment['MEDIAHUB_PREVIEW_ICONS'],
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(
            ByteData.sublistView(await File(entry.value!).readAsBytes())));
      await loader.load();
    }
  });
  testWidgets('TV wrapped connectors enter the off-screen source grid',
      (tester) async {
    final sources = [for (var i = 0; i < 13; i++) _source(i)];
    await _open(tester, sources,
        size: const Size(960, 540),
        navigationMode: NavigationMode.directional,
        refined: true);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'source-add');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'source-trackers');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, _control(sources.first, 'enabled'));
    _visible(tester, _focused!);
    final card = tester
        .getRect(find.byKey(ValueKey('source-card-${sources.first.key}')));
    expect(card.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(card.bottom, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'release-style absent diagnostic labels still build and navigate every card control',
      (tester) async {
    final sources = [for (var i = 0; i < 13; i++) _source(i)];
    final service = await _open(tester, sources,
        size: const Size(960, 540),
        navigationMode: NavigationMode.directional,
        refined: true);
    final first = tester
        .widget<InkWell>(
            find.byKey(ValueKey(_control(sources.first, 'enabled'))))
        .focusNode!;
    final url = tester
        .widget<InkWell>(find.byKey(ValueKey(_control(sources.first, 'url'))))
        .focusNode!;
    final other = tester
        .widget<InkWell>(find.byKey(ValueKey(_control(sources.first, 'other'))))
        .focusNode!;
    for (final focus in tester.allWidgets.whereType<Focus>()) {
      focus.focusNode?.debugLabel = null;
    }
    expect([first.debugLabel, url.debugLabel, other.debugLabel],
        everyElement(isNull));
    await service.setEnabled(
        sources.last, false); // Rebuild with no diagnostic keys.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _key(tester, LogicalKeyboardKey.arrowDown); // Add
    await _key(tester, LogicalKeyboardKey.arrowDown); // Trakt / Simkl
    await _key(tester, LogicalKeyboardKey.arrowDown); // First card
    expect(FocusManager.instance.primaryFocus, same(first));
    _visible(tester, _control(sources.first, 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus, same(url));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus, same(other));
    await _key(tester, LogicalKeyboardKey.select);
    expect(service.sources.first.underOther, isTrue);
    expect(FocusManager.instance.primaryFocus, same(other));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final polished in [false, true]) {
    testWidgets(
        'Neon Green TV cards retain dark palette shading, finish $polished',
        (tester) async {
      final source = _source(0);
      await _open(tester, [source, _source(1)],
          size: const Size(960, 540),
          navigationMode: NavigationMode.directional,
          paletteName: 'Neon Green',
          refined: polished);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, _control(source, 'enabled'));
      _visible(tester, _focused!);
      final card =
          tester.getRect(find.byKey(ValueKey('source-card-${source.key}')));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('preview')));
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset =
            ((card.top + 10).round() * image.width + card.center.dx.round()) *
                4;
        final red = data!.getUint8(offset);
        final green = data.getUint8(offset + 1);
        final blue = data.getUint8(offset + 2);
        expect(green, greaterThan(red * 1.3));
        expect(green, greaterThan(blue * 1.3));
        expect((red + green + blue) / 3, lessThan(65));
        if (Platform.environment['MEDIAHUB_GRID_PREVIEW'] == '1') {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('Logs/mediahub-source-grid-green-${polished ? 'on' : 'off'}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('top connectors, card columns, partial rows and scrolling',
      (tester) async {
    final sources = [for (var i = 0; i < 8; i++) _source(i)];
    await _open(tester, sources);
    expect(_focused, 'source-link');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'source-add');
    for (final expected in ['phone', 'import', 'server', 'trackers']) {
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused, 'source-$expected');
    }
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, _control(sources[2], 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, _control(sources[2], 'enabled'));
    for (final expected in ['url', 'other']) {
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused, _control(sources[2], expected));
    }
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, _control(sources[1], 'other'));
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, _control(sources[5], 'enabled'));
    for (var i = 0; i < 3; i++) {
      await _key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, _control(sources[7], 'enabled'));
    _visible(tester, _focused!);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, _control(sources[7], 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, _control(sources[6], 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, _control(sources[3], 'other'));
    _visible(tester, _focused!);
    for (var i = 0; i < 20; i++) {
      await _key(tester, LogicalKeyboardKey.arrowUp);
    }
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'source-link');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('roles, toggle state, URL dialog and focus survive rebuilds',
      (tester) async {
    final stream = _source(0);
    final own = _source(1);
    final list = _source(2, listOnly: true);
    final server = _source(3, server: true);
    final service = await _open(tester, [stream, own, list, server]);
    expect(find.text('Streams only'), findsOneWidget);
    expect(find.text('Catalogs + streams'), findsOneWidget);
    expect(find.text('Catalogs only'), findsNWidgets(2));
    expect(find.text('Media server'), findsOneWidget);
    expect(find.text('Catalogs from Cinemeta'), findsOneWidget);
    expect(find.byKey(ValueKey(_control(server, 'other'))), findsNothing);
    await _focusControl(tester, _control(stream, 'enabled'));
    await _key(tester, LogicalKeyboardKey.select);
    expect(service.sources.first.enabled, isFalse);
    expect(_focused, _control(stream, 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text(stream.manifestUrl), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_focused, _control(stream, 'url'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(service.sources.first.underOther, isTrue);
    expect(_focused, _control(stream, 'other'));
    await _focusControl(tester, 'source-cinemeta');
    await _key(tester, LogicalKeyboardKey.select);
    expect(service.showCinemetaCatalog, isFalse);
    expect(_focused, 'source-cinemeta');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tracker cards omit URL and Other; resize retains focused control',
      (tester) async {
    final sources = [for (var i = 0; i < 6; i++) _source(i)];
    const tracker = ArchiveSource(
        manifestUrl: 'tracker://fixture',
        name: 'Fixture tracker',
        tracker: TrackerLogin(kind: TrackerKind.trakt, accessToken: 'fixture'));
    await _open(tester, [...sources, tracker]);
    expect(find.text('Tracker lists'), findsOneWidget);
    expect(find.byKey(ValueKey(_control(tracker, 'url'))), findsNothing);
    expect(find.byKey(ValueKey(_control(tracker, 'other'))), findsNothing);
    await _focusControl(tester, _control(sources[1], 'url'));
    tester.view.physicalSize = const Size(960, 540);
    await tester.pumpAndSettle();
    expect(_focused, _control(sources[1], 'url'));
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, _control(sources[1], 'url'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, _control(sources[3], 'enabled'));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(_focused, _control(sources[3], 'enabled'));
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, _control(sources[3], 'enabled'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    expect(_focused, _control(sources[3], 'other'));
    _visible(tester, _focused!);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('hold remove cancel/confirm and clear keep usable focus',
      (tester) async {
    final sources = [_source(0), _source(1)];
    final service = await _open(tester, sources);
    Future<void> hold() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
    }

    await _focusControl(tester, _control(sources[1], 'enabled'));
    await hold();
    expect(find.text('Remove Source 1?'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter); // Cancel is default.
    expect(service.sources.length, 2);
    expect(_focused, _control(sources[1], 'enabled'));
    await hold();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(service.sources.length, 1);
    expect(_focused, _control(sources.first, 'enabled'));
    await _focusControl(tester, 'source-cinemeta');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'source-clear');
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(service.sources, isEmpty);
    expect(_focused, 'source-link');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, scale, language) in [
    (const Size(960, 540), 1.0, 'en'),
    (const Size(390, 844), 1.0, 'en'),
    (const Size(600, 800), 1.5, 'fr'),
    (const Size(1280, 720), 1.5, 'el'),
  ]) {
    testWidgets('responsive cards ${size.width} scale $scale $language',
        (tester) async {
      await L10n.apply(language);
      addTearDown(() => L10n.apply('en'));
      final sources = [
        _source(0),
        _source(1, server: true),
        _source(2, listOnly: true),
      ];
      await _open(tester, sources,
          size: size, textScale: scale, tv: size.width >= 960, refined: true);
      await _focusControl(tester, _control(sources.first, 'enabled'));
      final original = _focused;
      // Every source and footer remains reachable below the viewport.
      for (var i = 0; i < 20 && _focused != 'source-clear'; i++) {
        await _key(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_focused, 'source-clear');
      for (var i = 0; i < 20 && _focused != original; i++) {
        await _key(tester, LogicalKeyboardKey.arrowUp);
      }
      expect(_focused, original);
      _visible(tester, original!);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('empty state, keyboard exit and entry-point return',
      (tester) async {
    await _open(tester, []);
    expect(find.text('No playback sources yet.'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.select);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    await tester.enterText(find.byType(TextField), 'fixture');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_focused, 'source-add');
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'source-link');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 8 && _focused != 'source-cinemeta'; i++) {
      await _key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focused, 'source-cinemeta');
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.text('Entry point'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('card alignment and optional preview', (tester) async {
    final sources = [
      _source(0),
      _source(1),
      _source(2, server: true),
      _source(3, listOnly: true),
    ];
    await _open(tester, sources, refined: true);
    final first =
        tester.getRect(find.byKey(ValueKey('source-card-${sources[0].key}')));
    final second =
        tester.getRect(find.byKey(ValueKey('source-card-${sources[1].key}')));
    expect(first.top, second.top);
    expect(first.height, second.height);
    expect(tester.getRect(find.byType(TextField)).bottom, lessThan(first.top));
    if (Platform.environment['MEDIAHUB_GRID_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('preview')));
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('Logs/mediahub-source-grid.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
