import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/widgets/archive_stream_picker.dart';
import 'package:nox_iptv/widgets/archive_playback_settings.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:nox_iptv/widgets/archive_discovery_panel.dart';
import 'package:nox_iptv/widgets/archive_row_settings.dart';
import 'package:nox_iptv/services/archive_discovery_service.dart';

const _fast = ArchiveSource(
    manifestUrl: 'https://fast.example/manifest.json', name: 'Fast provider');
const _slow = ArchiveSource(
    manifestUrl: 'https://slow.example/manifest.json', name: 'Slow provider');

class _Discovery extends ArchiveDiscoveryService {
  static const titles = [
    ArchiveMeta(
        id: 'tt10',
        type: ArchiveType.movie,
        name: 'The next chapter',
        year: '2025'),
    ArchiveMeta(
        id: 'tt11',
        type: ArchiveType.movie,
        name: 'The final chapter',
        year: '2026'),
  ];
  @override
  Future<ArchiveDiscovery> discover(
          ArchiveMeta meta, String key, String language) async =>
      const ArchiveDiscovery(
          collectionName: 'The collection',
          collection: titles,
          related: titles,
          cast: [
            ArchivePerson(id: 1, name: 'Alex Morgan', role: 'The captain'),
            ArchivePerson(id: 2, name: 'Sam Rivers', role: 'The explorer')
          ]);
  @override
  Future<List<ArchiveMeta>> credits(
          ArchivePerson person, String key, String language) async =>
      titles;
}

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([_fast.toJson(), _slow.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (Platform.environment['MEDIAHUB_EXPERIENCE_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('build/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'Roboto': Platform.environment['MEDIAHUB_PREVIEW_FONT'],
      'MaterialIcons': Platform.environment['MEDIAHUB_PREVIEW_ICONS']
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(
            ByteData.sublistView(await File(entry.value!).readAsBytes())));
      await loader.load();
    }
  });
  testWidgets(
      'late source results keep the selected stream focused; Back exits',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await _storage();
    final hub = ArchiveService(storage);
    final session = ArchiveStreamSession(isCurrent: () => true);
    session.addSource(_slow.key, _slow.name);
    session.addSource(_fast.key, _fast.name);
    session.finish(_fast.key, [
      const ArchiveStreamOption(
          source: _fast,
          stream: ArchiveStream(
              url: 'https://media.example/fast.mkv',
              name: '1080p · English',
              title: 'H.264 · SDR · 4.2 GB',
              sizeBytes: 4200000000))
    ]);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: hub)
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
                builder: (ctx) => Scaffold(
                    body: Center(
                        child: ElevatedButton(
                            onPressed: () => showModalBottomSheet<void>(
                                context: ctx,
                                isScrollControlled: true,
                                constraints: const BoxConstraints(
                                    maxHeight: 580, maxWidth: 900),
                                builder: (_) => RepaintBoundary(
                                    key: const ValueKey('preview'),
                                    child: ArchiveStreamPicker(
                                        options: session.options,
                                        session: session))),
                            child: const Text('Open streams'))))))));
    await tester.tap(find.text('Open streams'));
    await tester.pump(const Duration(milliseconds: 350));
    final first =
        tester.widget<TvMenuTile>(find.byType(TvMenuTile).first).focusNode!;
    first.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, first);
    session.finish(_slow.key, [
      const ArchiveStreamOption(
          source: _slow,
          stream: ArchiveStream(
              url: 'https://media.example/slow.mkv',
              name: '4K · French',
              title: 'HEVC · HDR10 · 16 GB',
              sizeBytes: 16000000000))
    ]);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, first);
    expect(tester.widget<TvMenuTile>(find.byType(TvMenuTile).first).title,
        '1080p · English');
    await _capture(tester, 'media-hub-stream-picker');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open streams'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    hub.dispose();
  });

  testWidgets(
      'discovery remote navigation crosses rows, opens credits and restores focus',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await _storage();
    await storage.setTmdbApiKey('fixture-key');
    final hub = ArchiveService(storage);
    final entry = FocusNode(debugLabel: 'discovery-entry'),
        top = FocusNode(debugLabel: 'title-actions');
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: hub)
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: RepaintBoundary(
                key: const ValueKey('preview'),
                child: Scaffold(
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('A journey beyond',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold)),
                              OutlinedButton(
                                  focusNode: top,
                                  onPressed: () {},
                                  child: const Text('Play')),
                              ArchiveDiscoveryPanel(
                                  source: _fast,
                                  meta: const ArchiveMeta(
                                      id: 'tt1',
                                      name: 'A journey beyond',
                                      type: ArchiveType.movie),
                                  discovery: _Discovery(),
                                  entryNode: entry,
                                  // Like the real pages: back on Play shows
                                  // the header again.
                                  onReturn: () {
                                    top.requestFocus();
                                    Scrollable.ensureVisible(top.context!);
                                  }),
                            ])))))));
    await tester.pumpAndSettle();
    entry.requestFocus();
    await tester.pumpAndSettle();
    await _capture(tester, 'media-hub-discovery');
    // The page scrolls to whatever has focus, and never down on an Up
    // (owner, +521/+522: rows didn't come into view; Up to Explore more
    // scrolled to the cast row).
    double page() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    Future<void> key(LogicalKeyboardKey key) async {
      final before = page();
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      final r = FocusManager.instance.primaryFocus!.rect;
      expect(r.top >= 0 && r.bottom <= 720, isTrue,
          reason: '${FocusManager.instance.primaryFocus} at $r');
      if (key == LogicalKeyboardKey.arrowUp) {
        expect(page(), lessThanOrEqualTo(before));
      }
    }

    await key(LogicalKeyboardKey.arrowDown);
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'discovery-collection');
    await key(LogicalKeyboardKey.arrowRight);
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'discovery-related');
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'discovery-cast');
    await key(LogicalKeyboardKey.select);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('The next chapter'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'discovery-cast');
    await _capture(tester, 'media-hub-discovery-cast');
    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus, top);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    entry.dispose();
    top.dispose();
    hub.dispose();
  });

  for (final size in const [Size(1280, 720), Size(390, 760)]) {
    testWidgets(
        'row customization fits ${size.width} and keeps hidden rows recoverable',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await _storage();
      final hub = ArchiveService(storage);
      await hub.recordWatched(
          _fast,
          const ArchiveMeta(
              id: 'tt1', name: 'A journey beyond', type: ArchiveType.movie));
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: hub)
          ],
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: Builder(
                  builder: (ctx) => Scaffold(
                      body: Center(
                          child: ElevatedButton(
                              onPressed: () => showArchiveRowSettings(
                                  ctx, ArchiveType.movie),
                              child: const Text('Customize'))))))));
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Hide row').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show row'), findsOneWidget);
      await tester.tap(find.byTooltip('Show row'));
      await tester.pumpAndSettle();
      expect(hub.rows(ArchiveType.movie).first.continuations, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      hub.dispose();
    });
    testWidgets(
        'playback preferences fit ${size.width} and save to the active viewer',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = await _storage();
      final hub = ArchiveService(storage);
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: hub)
          ],
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: Builder(
                  builder: (ctx) => RepaintBoundary(
                      key: const ValueKey('preview'),
                      child: Scaffold(
                          body: Center(
                              child: ElevatedButton(
                                  onPressed: () =>
                                      showArchivePlaybackSettings(ctx),
                                  child: const Text('Preferences')))))))));
      await tester.tap(find.text('Preferences'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto-play preferred stream'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
          jsonDecode(storage.getArchiveOptionsJson('playback')!)['auto'], true);
      await storage.setActiveViewerId('other');
      expect(storage.getArchiveOptionsJson('playback'), null);
      await tester.pumpWidget(const SizedBox());
      hub.dispose();
    });
  }
}
