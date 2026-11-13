import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Media Hub: an eye beside Recently watched (and Continue watching) hides
/// or shows the row's titles (owner, 2026-11-11), per viewer. A hidden row
/// is only its title line: eye + "6 titles · OK shows them".
const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Eye',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular')
  ],
);

List<ArchiveMeta> _titles(String p) => [
      for (var i = 0; i < 6; i++)
        ArchiveMeta(id: '$p$i', type: ArchiveType.movie, name: 'Title $p$i')
    ];

class _Rows extends ArchiveService {
  _Rows(super.storage);
  late final history = ArchiveRow(
    source: _source,
    catalog: const ArchiveCatalog(
        type: ArchiveType.movie, id: 'history', name: 'Recently watched'),
    items: _titles('h'),
    itemSources: List.filled(6, _source),
  );
  late final popular = ArchiveRow(
    source: _source,
    catalog: const ArchiveCatalog(
        type: ArchiveType.movie, id: 'popular', name: 'Popular'),
    items: _titles('p'),
  );
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) =>
      [history, popular];
  @override
  bool canSearch(ArchiveType type) => false;
  @override
  bool isFavorite(ArchiveSource source, ArchiveMeta meta) => false;
  @override
  Future<void> loadMore(ArchiveRow row) async {}
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

/// Recently watched's posters on screen (the hero may still name a title).
int _historyPosters(WidgetTester tester) => tester
    .widgetList<PosterCard>(find.byType(PosterCard))
    .where((c) => c.title.startsWith('Title h'))
    .length;

final _popularPoster =
    find.byWidgetPredicate((w) => w is PosterCard && w.title == 'Title p0');

void main() {
  testWidgets('Up reaches the eye, OK folds the row to its title line',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = _Rows(storage);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        Provider<StorageService>.value(value: storage),
      ],
      child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: ThemeData.dark(),
          home: const ArchiveScreen()),
    ));
    await tester.pump();
    await tester.pump();
    final key = service.history.key;
    final eye = find.byKey(ValueKey('archive-eye-$key'));
    expect(eye, findsOneWidget);
    expect(find.byKey(ValueKey('archive-eye-${service.popular.key}')),
        findsNothing,
        reason: 'only Continue watching / Recently watched');

    // Into the first row (Recently watched), then Up = its eye.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'archive-card');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'archive-row-eye');
    final shownGap =
        tester.getTopLeft(_popularPoster).dy - tester.getTopLeft(eye).dy;
    await _press(tester, LogicalKeyboardKey.enter);
    expect(_focused, 'archive-row-eye', reason: 'focus stays on the eye');
    expect(find.text('6 titles · Tap to show them'), findsOneWidget,
        reason: 'the line beside the eye, no block');
    expect(_historyPosters(tester), 0);
    expect(storage.getHubHiddenRows(), {key});
    final hiddenGap =
        tester.getTopLeft(_popularPoster).dy - tester.getTopLeft(eye).dy;
    expect(hiddenGap, lessThan(shownGap - PosterCard.height),
        reason: 'the next row moves up under the title line');

    // Down = the next row's posters; Up = back on the folded row's eye.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'archive-card');
    expect(
        tester
            .widget<PosterCard>(find.byWidgetPredicate(
                (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false)))
            .title,
        startsWith('Title p'));
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'archive-row-eye');
    await _press(tester, LogicalKeyboardKey.enter);
    expect(_focused, 'archive-row-eye');
    expect(find.byKey(ValueKey('archive-hidden-$key')), findsNothing);
    expect(_historyPosters(tester), greaterThan(0));
    expect(storage.getHubHiddenRows(), isEmpty);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(
        tester
            .widget<PosterCard>(find.byWidgetPredicate(
                (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false)))
            .title,
        startsWith('Title h'),
        reason: 'shown again, Down from the eye = its own posters');

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
  // +772 (Homatics): one OK on the eye opened the row and folded it again.
  // The remote's OK is `select`; a held OK repeats, and every repeat was an
  // ActivateIntent (a toggle). One press, held or not, toggles once.
  testWidgets('one OK on the eye toggles once, even held', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = _Rows(storage);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        Provider<StorageService>.value(value: storage),
      ],
      child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: ThemeData.dark(),
          home: const ArchiveScreen()),
    ));
    await tester.pump();
    await tester.pump();
    final key = service.history.key;
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'archive-row-eye');

    Future<void> ok({int repeats = 0}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 500));
      for (var k = 0; k < repeats; k++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(seconds: 2));
    }

    await ok();
    expect(storage.getHubHiddenRows(), {key});
    expect(_focused, 'archive-row-eye');
    await ok(repeats: 1);
    expect(storage.getHubHiddenRows(), isEmpty, reason: 'shown, not refolded');
    await ok(repeats: 5);
    expect(storage.getHubHiddenRows(), {key});
    expect(_focused, 'archive-row-eye');

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
