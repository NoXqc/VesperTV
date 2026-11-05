import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Wide cards',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular')
  ],
);

class _Rows extends ArchiveService {
  _Rows(super.storage);
  final entries = [
    for (var r = 0; r < 3; r++)
      ArchiveRow(
          source: _source,
          catalog: ArchiveCatalog(
              type: ArchiveType.movie, id: 'catalog$r', name: 'Catalog $r'),
          items: [
            for (var i = 0; i < 14; i++)
              ArchiveMeta(
                  id: 'm$r-$i',
                  type: ArchiveType.movie,
                  name: 'Title $r-$i',
                  // Every fifth title has no backdrop: it stays a poster.
                  backgroundUrl: i % 5 == 4 ? null : 'https://img.test/$r-$i',
                  rating: '7.6',
                  year: '2026',
                  genres: const ['Horror'])
          ]),
  ];
  @override
  List<ArchiveSource> get enabledSources => [_source];
  @override
  List<ArchiveSource> get sources => [_source];
  @override
  Future<void> open() async {}
  @override
  List<ArchiveRow> rows(ArchiveType type, {bool includeHidden = false}) =>
      entries;
  @override
  bool canSearch(ArchiveType type) => false;
  @override
  bool isFavorite(ArchiveSource source, ArchiveMeta meta) => false;
  @override
  Future<void> loadMore(ArchiveRow row) async {}
}

PosterCard _focusedCard(WidgetTester tester) =>
    tester.widget<PosterCard>(find.byWidgetPredicate(
        (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false)));

Iterable<PosterCard> _wideCards(WidgetTester tester) => tester
    .widgetList<PosterCard>(find.byType(PosterCard))
    .where((c) => c.wideWidth != null);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key,
    [int times = 1]) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump();
  }
}

Future<_Rows> _open(WidgetTester tester,
    {Size size = const Size(1280, 720)}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final service = _Rows(storage);
  await tester.pumpWidget(ChangeNotifierProvider<ArchiveService>.value(
      value: service,
      child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: ThemeData.dark(),
          home: const ArchiveScreen())));
  await tester.pump();
  await tester.pump();
  return service;
}

Finder get _focusedPoster => find.byWidgetPredicate(
    (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false));

double _rowOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find
        .ancestor(of: _focusedPoster, matching: find.byType(Scrollable))
        .first)
    .position
    .pixels;

void main() {
  testWidgets(
      'row scroll starts with each selection and exposes upcoming posters',
      (tester) async {
    final service = await _open(tester, size: const Size(960, 720));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final anchor = tester.getRect(_focusedPoster).left;
    const slot = PosterCard.width + 12 + 8;
    for (var i = 1; i <= 5; i++) {
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_focusedCard(tester).title, 'Title 0-$i');
      expect(_rowOffset(tester), closeTo(i * slot, 0.1));
      expect(tester.getRect(_focusedPoster).left, closeTo(anchor, 0.1));
      expect(_wideCards(tester), isEmpty);
    }
    // Reverse direction: the selector stays anchored instead of crossing the row.
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_focusedCard(tester).title, 'Title 0-4');
    expect(_rowOffset(tester), closeTo(4 * slot, 0.1));
    expect(tester.getRect(_focusedPoster).left, closeTo(anchor, 0.1));
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('moving at 1.9 seconds starts a complete new dwell period',
      (tester) async {
    final service = await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 1900));
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_wideCards(tester), isEmpty,
        reason: 'the previous timer was cancelled');
    await tester.pump(const Duration(milliseconds: 1899));
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_wideCards(tester).map((c) => c.title), ['Title 0-1']);
    final node = _focusedCard(tester).focusNode;
    service.notifyListeners();
    await tester.pump();
    expect(_focusedCard(tester).focusNode, same(node));
    expect(_wideCards(tester).length, 1);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('the floating bar and rail cancel pending or expanded cards',
      (tester) async {
    final service = await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(seconds: 5));
    expect(_wideCards(tester), isEmpty);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 2));
    expect(_wideCards(tester).length, 1);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 5));
    expect(_wideCards(tester), isEmpty);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('background cancels the dwell; returning waits two seconds again',
      (tester) async {
    final service = await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(_wideCards(tester), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_wideCards(tester).length, 1);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('covering the Hub cancels expansion until a fresh return dwell',
      (tester) async {
    final service = await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covered'))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(_wideCards(tester), isEmpty);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(_wideCards(tester).length, 1);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('a replaced title cannot inherit the old pending expansion',
      (tester) async {
    final service = await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));
    service.entries.first.items[0] = const ArchiveMeta(
        id: 'replacement',
        type: ArchiveType.movie,
        name: 'Replacement',
        backgroundUrl: 'https://img.test/new');
    service.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_wideCards(tester), isEmpty);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('portrait rows stay compact even after a long dwell',
      (tester) async {
    final service = await _open(tester, size: const Size(420, 900));
    final card = tester.widget<PosterCard>(find.byType(PosterCard).first);
    card.focusNode!.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(_wideCards(tester), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('the focused card goes wide, one at a time, and stays on screen',
      (tester) async {
    final service = await _open(tester);

    // The rail has focus: no wide card yet.
    expect(_wideCards(tester), isEmpty);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedCard(tester).title, 'Title 0-0');
    expect(_focusedCard(tester).wideWidth, isNull,
        reason: 'moving focus must leave posters compact');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_focusedCard(tester).wideWidth, PosterCard.wideCardWidth);
    expect(_wideCards(tester).length, 1);
    // Hero: info line with the type, genre and year, and the IMDb badge.
    expect(find.text('Movie  •  Horror  •  2026'), findsOneWidget);
    expect(find.text('IMDb'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowRight, 3);
    expect(_focusedCard(tester).title, 'Title 0-3');
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(_wideCards(tester).map((c) => c.title), ['Title 0-3']);

    // A title without a backdrop stays a poster.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedCard(tester).title, 'Title 0-4');
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(_wideCards(tester), isEmpty);

    // To the end of the row: the wide last card is fully on screen.
    await _press(tester, LogicalKeyboardKey.arrowRight, 9);
    await tester.pump();
    expect(_focusedCard(tester).title, 'Title 0-13');
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    final rect = tester.getRect(find.byWidgetPredicate(
        (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false)));
    expect(rect.right, lessThanOrEqualTo(1280));
    expect(rect.left, greaterThanOrEqualTo(80));

    // Changing rows cancels the old wide card and starts a fresh delay.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedCard(tester).title, startsWith('Title 1-'));
    expect(_wideCards(tester), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(_wideCards(tester).length, 1);
    expect(_wideCards(tester).single.title, startsWith('Title 1-'));

    // Back to the rail: nothing is wide.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_wideCards(tester), isEmpty);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
