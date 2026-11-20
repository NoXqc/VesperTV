import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/desktop_row_scroller.dart';
import 'package:nox_iptv/widgets/detail_header.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Media Hub rows on a computer (owner, 2026-11-19): hover previews the
/// backdrop after a short rest, a click widens the card at once without
/// moving the row, the mouse drags the row, arrows page it.

const _source = ArchiveSource(
  manifestUrl: 'https://example.com/manifest.json',
  name: 'Mouse rows',
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
            for (var i = 0; i < 30; i++)
              ArchiveMeta(
                  id: 'm$r-$i',
                  type: ArchiveType.movie,
                  name: 'Title $r-$i',
                  // Every fifth title has no backdrop: it stays a poster.
                  backgroundUrl: i % 5 == 4 ? null : 'https://img.test/$r-$i',
                  year: '2026')
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
  Future<void> loadMore(ArchiveRow row, {bool notify = true}) async {}
}

final _computer = TargetPlatformVariant.only(TargetPlatform.windows);

Finder _card(String title) =>
    find.byWidgetPredicate((w) => w is PosterCard && w.title == title);

Finder get _focusedPoster => find.byWidgetPredicate(
    (w) => w is PosterCard && (w.focusNode?.hasFocus ?? false));

Iterable<String> _wide(WidgetTester tester) => tester
    .widgetList<PosterCard>(find.byType(PosterCard))
    .where((c) => c.wideWidth != null)
    .map((c) => c.title);

String? _backdrop(WidgetTester tester) {
  final f = find.byType(DetailBackdrop);
  return f.evaluate().isEmpty ? null : tester.widget<DetailBackdrop>(f).url;
}

ScrollPosition _row(WidgetTester tester, int r) => tester
    .state<ScrollableState>(find
        .ancestor(
            of: find
                .byWidgetPredicate(
                    (w) => w is PosterCard && w.title.startsWith('Title $r-'))
                .first,
            matching: find.byType(Scrollable))
        .first)
    .position;

Future<_Rows> _open(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.physicalSize = const Size(1280, 720);
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

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _click(WidgetTester tester, TestGesture mouse, Offset at) async {
  await mouse.moveTo(at);
  await tester.pump();
  await mouse.down(at);
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await tester.pump();
}

Future<void> _drag(
    WidgetTester tester, TestGesture mouse, Offset from, double dx) async {
  await mouse.moveTo(from);
  await tester.pump();
  await mouse.down(from);
  final step = dx.sign * 10;
  for (var moved = 0.0; moved.abs() < dx.abs(); moved += step) {
    await mouse.moveBy(Offset(step, 0));
    await tester.pump();
  }
  await mouse.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hover shows the backdrop only after a short rest',
      variant: _computer, (tester) async {
    final service = await _open(tester);
    final mouse = await _mouse(tester);
    // Sweeping across posters swaps nothing.
    for (final i in [1, 2]) {
      await mouse.moveTo(tester.getCenter(_card('Title 0-$i')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_backdrop(tester), isNull);
    }
    await mouse.moveTo(tester.getCenter(_card('Title 0-3')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_backdrop(tester), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_backdrop(tester), 'https://img.test/0-3');
    // Hover alone doesn't select, widen or scroll.
    expect(_focusedPoster, findsNothing);
    expect(_wide(tester), isEmpty);
    expect(_row(tester, 0).pixels, 0);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('leaving the posters brings back the selected title',
      variant: _computer, (tester) async {
    final service = await _open(tester);
    final mouse = await _mouse(tester);
    await _click(tester, mouse, tester.getCenter(_card('Title 0-1')));
    await tester.pumpAndSettle();
    expect(_backdrop(tester), 'https://img.test/0-1');
    await mouse.moveTo(tester.getCenter(_card('Title 1-2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_backdrop(tester), 'https://img.test/1-2');
    // The selection didn't move.
    expect(tester.widget<PosterCard>(_focusedPoster).title, 'Title 0-1');
    await mouse.moveTo(const Offset(640, 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_backdrop(tester), 'https://img.test/0-1');
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('a click selects and widens at once, the row stays put',
      variant: _computer, (tester) async {
    final service = await _open(tester);
    final mouse = await _mouse(tester);
    await _click(tester, mouse, tester.getCenter(_card('Title 0-2')));
    expect(tester.widget<PosterCard>(_focusedPoster).title, 'Title 0-2');
    // No 2 s rest needed.
    expect(_wide(tester), ['Title 0-2']);
    await tester.pumpAndSettle();
    expect(_row(tester, 0).pixels, 0);

    // A later card: the wide one left of it shrinks back without sliding
    // the clicked card out from under the pointer.
    await _drag(tester, mouse, tester.getCenter(_card('Title 0-6')), -300);
    final before = tester.getRect(_card('Title 0-7')).left;
    await _click(tester, mouse, tester.getCenter(_card('Title 0-7')));
    await tester.pumpAndSettle();
    expect(tester.widget<PosterCard>(_focusedPoster).title, 'Title 0-7');
    expect(_wide(tester), ['Title 0-7']);
    expect(tester.getRect(_card('Title 0-7')).left, closeTo(before, 1));
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('a mouse drag scrolls the row and opens nothing',
      variant: _computer, (tester) async {
    final service = await _open(tester);
    final mouse = await _mouse(tester);
    await _drag(tester, mouse, tester.getCenter(_card('Title 0-3')), -300);
    expect(_row(tester, 0).pixels, greaterThan(250));
    expect(_focusedPoster, findsNothing);
    // A tiny wobble is still a click.
    final at = tester.getCenter(_card('Title 0-5'));
    await mouse.moveTo(at);
    await tester.pump();
    await mouse.down(at);
    await mouse.moveBy(const Offset(3, 1));
    await tester.pump();
    await mouse.up();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<PosterCard>(_focusedPoster).title, 'Title 0-5');
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('arrows show on hover, only toward more, and page the row',
      variant: _computer, (tester) async {
    final service = await _open(tester);
    final mouse = await _mouse(tester);
    final row = find.byType(DesktopRowScroller).first;
    Finder arrow(IconData icon) =>
        find.descendant(of: row, matching: find.byIcon(icon));
    double shown(IconData icon) => tester
        .widget<AnimatedOpacity>(find
            .ancestor(of: arrow(icon), matching: find.byType(AnimatedOpacity))
            .first)
        .opacity;

    expect(shown(Icons.chevron_right_rounded), 0);
    await mouse.moveTo(tester.getCenter(_card('Title 0-2')));
    await tester.pumpAndSettle();
    expect(shown(Icons.chevron_right_rounded), 1);
    expect(shown(Icons.chevron_left_rounded), 0);

    final viewport = _row(tester, 0).viewportDimension;
    await _click(
        tester, mouse, tester.getCenter(arrow(Icons.chevron_right_rounded)));
    await tester.pumpAndSettle();
    expect(_row(tester, 0).pixels, closeTo(viewport * 0.8, 1));
    expect(shown(Icons.chevron_left_rounded), 1);
    // The arrow is not a card click.
    expect(_focusedPoster, findsNothing);

    await _click(
        tester, mouse, tester.getCenter(arrow(Icons.chevron_left_rounded)));
    await tester.pumpAndSettle();
    expect(_row(tester, 0).pixels, 0);
    expect(shown(Icons.chevron_left_rounded), 0);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
