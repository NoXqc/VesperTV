import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Rail search',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular')
  ],
);

class _Service extends ArchiveService {
  _Service(super.storage, {this.searchable = true, this.empty = false});
  final bool searchable;
  final bool empty;
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) => empty
      ? const []
      : [
          ArchiveRow(source: _source, catalog: _source.catalogs.first, items: [
            const ArchiveMeta(
                id: 'm1', type: ArchiveType.movie, name: 'Title 1')
          ])
        ];
  @override
  bool canSearch(ArchiveType type) => searchable;
  @override
  Future<void> loadMore(ArchiveRow row) async {}
  @override
  bool isFavorite(ArchiveSource source, ArchiveMeta meta) => false;
}

Future<_Service> _pump(WidgetTester tester,
    {Size size = const Size(1280, 720),
    double textScale = 1,
    bool searchable = true,
    bool empty = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final service = _Service(storage, searchable: searchable, empty: empty);
  final prefs = AppPreferences(storage)
    ..isTelevision = true
    ..layoutMode = 'auto'
    ..palette = AppConstants.cyberpunkPalettes.first;
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
          theme: ThemeData.dark().copyWith(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: const ArchiveScreen())));
  await tester.pump();
  await tester.pump();
  return service;
}

void main() {
  testWidgets('Search sits in the rail and pulls out Movies / TV Shows',
      (tester) async {
    final service = await _pump(tester);
    // One Search entry, in the rail; the top bar no longer has one.
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Search movies'), findsNothing);
    final rail = tester.getRect(find.text('Search'));
    expect(rail.left, lessThan(250));

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    // The pull-out: its title plus the two categories (also in the rail).
    expect(find.text('Search'), findsNWidgets(2));
    expect(find.text('TV Shows'), findsNWidgets(2));
    final menuItem = tester.getRect(find.text('TV Shows').last);
    expect(menuItem.left, greaterThan(rail.right),
        reason: 'the menu opens beside the button');

    await tester.tap(find.text('TV Shows').last);
    await tester.pumpAndSettle();
    expect(find.text('Search TV shows'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('rail Up and Down visit adjacent entries without losing focus',
      (tester) async {
    final service = await _pump(tester);
    expect(
        Focus.of(tester.element(find.text('Movies'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Movies'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Search'))).hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('rail arrow boundaries stay on visible entries', (tester) async {
    final service = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Search'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Search'))).hasPrimaryFocus, isTrue,
        reason: 'Up at the top must not focus the rail wrapper');
    for (final label in [
      'Movies',
      'TV Shows',
      'Watch list',
      'Refresh',
      'Media Hub sources',
      'Connect Jellyfin / Emby'
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text(label))).hasPrimaryFocus, isTrue,
          reason: label);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Connect Jellyfin / Emby')))
            .hasPrimaryFocus,
        isTrue,
        reason: 'End focus: ${FocusManager.instance.primaryFocus}; '
            'widget: ${FocusManager.instance.primaryFocus?.context?.widget}');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('held Down advances one rail entry per repeat', (tester) async {
    final service = await _pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Watch list'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Watch list'))).hasPrimaryFocus,
        isTrue);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('no search entry: Up stays on Movies and Down enters shows',
      (tester) async {
    final service = await _pump(tester, searchable: false);
    expect(find.text('Search'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Movies'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('return from rows and top bar restores an operable rail entry',
      (tester) async {
    final service = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'archive-card');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Watch list'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'archive-bar-row');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Watch list'))).hasPrimaryFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('short TV viewport reveals every rail entry at large text',
      (tester) async {
    final service =
        await _pump(tester, size: const Size(960, 360), textScale: 1.6);
    for (final label in [
      'TV Shows',
      'Watch list',
      'Refresh',
      'Media Hub sources',
      'Connect Jellyfin / Emby'
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final entry = find.text(label);
      expect(Focus.of(tester.element(entry)).hasPrimaryFocus, isTrue,
          reason: label);
      final rect = tester.getRect(entry);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(360));
    }
    for (final label in [
      'Media Hub sources',
      'Refresh',
      'Watch list',
      'TV Shows',
      'Movies',
      'Search'
    ]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final entry = find.text(label);
      expect(Focus.of(tester.element(entry)).hasPrimaryFocus, isTrue,
          reason: label);
      expect(tester.getRect(entry).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(entry).bottom, lessThanOrEqualTo(360));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('empty catalog Right uses Refresh and Up returns through the bar',
      (tester) async {
    final service = await _pump(tester, empty: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'archive-empty-action');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'archive-bar-manage');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
        Focus.of(tester.element(find.text('Movies'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('TV Shows'))).hasPrimaryFocus,
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('the rail is icons only while the rows have focus',
      (tester) async {
    final service = await _pump(tester);
    expect(find.text('TV Shows'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('TV Shows'), findsNothing);
    expect(find.text('Media Hub'), findsNothing);
    expect(find.byIcon(Icons.video_library), findsOneWidget);
    // Closed, the rows take the room back; open, the rail pushes them
    // aside instead of lying over the posters.
    final closed = tester.getRect(find.text('Title 1').first);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('TV Shows'), findsOneWidget);
    final open = tester.getRect(find.text('Title 1').first);
    expect(open.left, greaterThan(closed.left));
    final rail = tester.getRect(find.text('TV Shows'));
    expect(open.left, greaterThan(rail.right));

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
