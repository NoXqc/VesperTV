import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/settings/archive_sources_screen.dart';
import 'package:nox_iptv/services/addon_service.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings > Media Hub sources as one add-on list (owner, 2026-11-11,
/// like Stremio / Nuvio): rail of filters, one row per add-on, OK = on/off,
/// Right = its options.
class _Cache extends ArchiveCache {
  @override
  Future<void> deleteSource(String key) async {}
  @override
  Future<void> clear() async {}
}

const _streams = ArchiveSource(
  manifestUrl: 'https://torrentio.example/manifest.json',
  name: 'Torrentio',
  description: 'Torrent streams for movies and shows.',
  version: '0.0.15',
  catalogProviderUrl: ArchiveCatalogProvider.baseUrl,
  catalogs: [ArchiveCatalog(type: ArchiveType.movie, id: 'top', name: 'Popular')],
);
const _lists = ArchiveSource(
  manifestUrl: 'https://catalogs.example/manifest.json',
  name: 'Streaming Catalogs',
  listOnly: true,
  catalogs: [
    ArchiveCatalog(type: ArchiveType.series, id: 'nfx', name: 'Netflix'),
  ],
);

Future<(ArchiveService, StorageService)> _open(WidgetTester tester,
    {Size size = const Size(1280, 720), bool tv = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([_streams.toJson(), _lists.toJson()]),
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
    ..layoutMode = tv ? 'tv' : 'auto';
  addTearDown(preferences.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<ArchiveService>.value(value: service),
      ChangeNotifierProvider<AppPreferences>.value(value: preferences),
      Provider<StorageService>.value(value: storage),
    ],
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
          colorScheme: buildPaletteColorScheme(
              AppConstants.cyberpunkPalettes.first, Brightness.dark)),
      home: const ArchiveSourcesScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return (service, storage);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('TV: the rail counts, OK flips a source, Right opens options',
      (tester) async {
    final (service, _) = await _open(tester);
    expect(_focused, 'sources-all');
    // All: the two sources, Cinemeta and OpenSubtitles.
    expect(find.text('Torrentio'), findsOneWidget);
    expect(find.text('v0.0.15'), findsOneWidget);
    expect(find.text('Streaming Catalogs'), findsOneWidget);
    expect(find.text('Cinemeta'), findsOneWidget);
    expect(find.text('OpenSubtitles v3'), findsOneWidget);
    expect(find.text('Media servers'), findsNothing,
        reason: 'an empty filter stays out of the rail');

    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'source-row');
    await _key(tester, LogicalKeyboardKey.select);
    expect(service.sources.first.enabled, isFalse);
    await _key(tester, LogicalKeyboardKey.select);
    expect(service.sources.first.enabled, isTrue);

    // Right = its ⋯ button, OK = the options panel.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'source-more');
    await _key(tester, LogicalKeyboardKey.select);
    expect(find.text('Show under Other'), findsOneWidget);
    expect(find.text('View source URL'), findsOneWidget);
    await tester.tap(find.text('Show under Other'));
    await tester.pumpAndSettle();
    expect(service.sources.first.underOther, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Show under Other'), findsNothing);
    expect(find.text('Under Other'), findsWidgets,
        reason: 'the row shows its new tag');

    // Left from the ⋯ goes back to the row, Left again to the rail.
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'source-row');
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'sources-all');
  });

  testWidgets('filters, Cinemeta and a subtitle add-on switch in place',
      (tester) async {
    final (service, storage) = await _open(tester);
    // Down to Streams: only Torrentio.
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'sources-streams');
    expect(find.text('Torrentio'), findsOneWidget);
    expect(find.text('Streaming Catalogs'), findsNothing);
    // Catalogs & lists: the list-only add-on and Cinemeta (built in, no ⋯).
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Streaming Catalogs'), findsOneWidget);
    expect(find.text('Built in'), findsOneWidget);
    await tester.tap(find.text('Cinemeta'));
    await tester.pumpAndSettle();
    expect(service.showCinemetaCatalog, isFalse);
    // Subtitles: OpenSubtitles turns on for the device.
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('OpenSubtitles v3'), findsOneWidget);
    await tester.tap(find.text('OpenSubtitles v3'));
    await tester.pumpAndSettle();
    expect(AddonService(storage).addons.first.enabled, isTrue);
  });

  testWidgets('Remove asks, then the row goes', (tester) async {
    final (service, _) = await _open(tester);
    await tester.tap(find.byKey(ValueKey(
        'source-more-src:${_lists.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove Streaming Catalogs?'), findsOneWidget);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(service.sources.map((s) => s.name), ['Torrentio']);
    expect(find.text('Streaming Catalogs'), findsNothing);
  });

  testWidgets('Add a source and Manage from phone panes', (tester) async {
    await _open(tester);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'sources-add');
    expect(find.text('Source link (ends with manifest.json)'), findsOneWidget);
    expect(find.text('Import from Stremio'), findsOneWidget);
    expect(find.byKey(const ValueKey('source-tool-manage')), findsOneWidget);
    // Manage from phone: nothing starts until OK on Show the code.
    for (var i = 0; i < 6; i++) {
      await _key(tester, LogicalKeyboardKey.arrowDown);
      if (_focused == 'sources-phone') break;
    }
    expect(_focused, 'sources-phone');
    expect(find.byKey(const ValueKey('sources-phone-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('sources-phone-qr')), findsNothing);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'sources-phone-start');
    await _key(tester, LogicalKeyboardKey.enter);
    // No Vesper link in a test: it says so instead of a code.
    expect(find.text('Not available right now. Try again in a moment.'),
        findsOneWidget);
  });

  testWidgets('phone: chips, the switch flips, the row opens its options',
      (tester) async {
    final (service, _) = await _open(tester,
        size: const Size(390, 844), tv: false);
    expect(find.byType(ChoiceChip), findsWidgets);
    await tester.tap(find.byKey(ValueKey('source-switch-src:${_streams.key}')));
    await tester.pumpAndSettle();
    expect(service.sources.first.enabled, isFalse);
    await tester.tap(find.text('Torrentio'));
    await tester.pumpAndSettle();
    expect(find.text('Show under Other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
