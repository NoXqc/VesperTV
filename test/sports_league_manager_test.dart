import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_league_manager_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/goals_alerts.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
  });

  tearDown(() {
    prefs.dispose();
    L10n.code = 'en';
  });

  Future<void> open(WidgetTester tester,
      {Size size = const Size(960, 540), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
        ChangeNotifierProvider<GoalsAlerts>(
            create: (_) => GoalsAlerts(storage)),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: const SportsLeagueManagerScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder row(String key) => find.byKey(ValueKey(key));

  TvMenuTile tile(WidgetTester tester, String key) =>
      tester.widget<TvMenuTile>(find.descendant(
          of: row(key), matching: find.byType(TvMenuTile), matchRoot: true));

  String focused(WidgetTester tester) => tester
      .widgetList<TvMenuTile>(find.byType(TvMenuTile))
      .singleWhere((tile) => tile.focusNode?.hasFocus ?? false)
      .title;

  void visibleFocus(WidgetTester tester, String key) {
    final widget = tile(tester, key);
    expect(widget.focusNode!.hasFocus, isTrue, reason: key);
    final target = find.byWidget(widget);
    final viewport = find
        .ancestor(of: target, matching: find.byType(SingleChildScrollView))
        .first;
    final bounds = tester.getRect(viewport);
    final rect = tester.getRect(target);
    expect(rect.top, greaterThanOrEqualTo(bounds.top - 1), reason: key);
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 1), reason: key);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> downTo(WidgetTester tester, String key) async {
    for (var i = 0; i < 200; i++) {
      if (tile(tester, key).focusNode!.hasFocus) {
        visibleFocus(tester, key);
        return;
      }
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    fail('Could not reach $key with Down');
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('bank sports start collapsed and cover every league exactly once',
      (tester) async {
    await open(tester);
    expect(find.text('Football 🏈'), findsOneWidget);
    expect(find.text('Football ⚽'), findsOneWidget);
    expect(find.text('Hockey 🏒'), findsOneWidget);
    expect(find.text('Europe'), findsNothing);
    expect(find.text('England'), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is TvMenuTile &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('bank:')),
        findsNothing);
    final headers = tester
        .widgetList<TvMenuTile>(find.byType(TvMenuTile))
        .where((tile) => tile.key.toString().contains('bank-sport:'))
        .map((tile) => tile.key!)
        .toList();
    for (final key in headers) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }
    final ids = tester
        .widgetList<TvMenuTile>(find.byType(TvMenuTile))
        .where((tile) => tile.key is ValueKey<String>)
        .map((tile) => (tile.key! as ValueKey<String>).value)
        .where((key) => key.startsWith('bank:'))
        .map((key) => key.substring(5))
        .toList();
    expect(ids, unorderedEquals(kSportsLeagueBank.map((l) => l.id)));
    expect(ids.toSet().length, ids.length);
    expect(storage.getSportsAddedLeagues(), isEmpty);
    for (final league in kSportsLeagues) {
      expect(row('yours:${league.id}'), findsOneWidget);
    }
    await close(tester);
  });

  for (final scale in [1.0, 1.4]) {
    testWidgets('remote traverses a long expanded sport down and back; $scale',
        (tester) async {
      await open(tester, scale: scale);
      await press(tester, LogicalKeyboardKey.arrowRight);
      visibleFocus(tester, 'bank-sport:football');
      await press(tester, LogicalKeyboardKey.arrowDown);
      visibleFocus(tester, 'bank-sport:soccer');
      await press(tester, LogicalKeyboardKey.select);
      visibleFocus(tester, 'bank-sport:soccer');
      final soccer =
          kSportsLeagueBank.where((l) => l.sport == 'soccer').toList();
      for (final league in soccer) {
        await press(tester, LogicalKeyboardKey.arrowDown);
        visibleFocus(tester, 'bank:${league.id}');
      }
      await press(tester, LogicalKeyboardKey.arrowDown);
      visibleFocus(tester, 'bank-sport:hockey');
      for (final league in soccer.reversed) {
        await press(tester, LogicalKeyboardKey.arrowUp);
        visibleFocus(tester, 'bank:${league.id}');
      }
      await press(tester, LogicalKeyboardKey.arrowUp);
      visibleFocus(tester, 'bank-sport:soccer');
      await press(tester, LogicalKeyboardKey.select);
      expect(row('bank:${soccer.first.id}'), findsNothing);
      await press(tester, LogicalKeyboardKey.arrowDown);
      visibleFocus(tester, 'bank-sport:hockey');
      await press(tester, LogicalKeyboardKey.arrowUp);
      visibleFocus(tester, 'bank-sport:soccer');
      await close(tester);
    });
  }

  testWidgets('lower sport expands below the viewport and the selector returns',
      (tester) async {
    await open(tester, size: const Size(960, 420), scale: 1.4);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await downTo(tester, 'bank-sport:cricket');
    await press(tester, LogicalKeyboardKey.select);
    visibleFocus(tester, 'bank-sport:cricket');
    final cricket =
        kSportsLeagueBank.where((l) => l.sport == 'cricket').toList();
    for (final league in cricket) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      visibleFocus(tester, 'bank:${league.id}');
    }
    await press(tester, LogicalKeyboardKey.arrowDown);
    visibleFocus(tester, 'bank-sport:darts');
    await press(tester, LogicalKeyboardKey.arrowUp);
    visibleFocus(tester, 'bank:${cricket.last.id}');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    visibleFocus(tester, 'yours:${kSportsLeagues.first.id}');
    await press(tester, LogicalKeyboardKey.arrowRight);
    visibleFocus(tester, 'bank:${cricket.last.id}');
    for (final league in cricket.reversed.skip(1)) {
      await press(tester, LogicalKeyboardKey.arrowUp);
      visibleFocus(tester, 'bank:${league.id}');
    }
    await press(tester, LogicalKeyboardKey.arrowUp);
    visibleFocus(tester, 'bank-sport:cricket');
    await press(tester, LogicalKeyboardKey.select);
    visibleFocus(tester, 'bank-sport:cricket');
    await close(tester);
  });

  testWidgets('adding a league keeps bank focus and removes an exhausted sport',
      (tester) async {
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    final football = kSportsLeagueBank.where((l) => l.sport == 'football');
    for (final league in football) {
      // After adding the first one, the following league takes its slot.
      if (focused(tester) == 'Football 🏈') {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      visibleFocus(tester, 'bank:${league.id}');
      await press(tester, LogicalKeyboardKey.select);
      expect(storage.getSportsAddedLeagues(), contains(league.id));
      expect(storage.getSportsLeagues(), contains(league.id));
      expect(row('yours:${league.id}'), findsOneWidget);
    }
    expect(row('bank-sport:football'), findsNothing);
    visibleFocus(tester, 'bank-sport:soccer');
    await close(tester);
  });

  testWidgets('phone selector crosses from active leagues to bank and back',
      (tester) async {
    await open(tester, size: const Size(390, 700), scale: 1.4);
    await downTo(tester, 'bank-sport:cricket');
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    final first = kSportsLeagueBank.firstWhere((l) => l.sport == 'cricket');
    visibleFocus(tester, 'bank:${first.id}');
    await press(tester, LogicalKeyboardKey.arrowUp);
    visibleFocus(tester, 'bank-sport:cricket');
    await press(tester, LogicalKeyboardKey.select);
    for (var i = 0; i < 50; i++) {
      if (tile(tester, 'yours:${kSportsLeagues.first.id}')
          .focusNode!
          .hasFocus) {
        break;
      }
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    visibleFocus(tester, 'yours:${kSportsLeagues.first.id}');
    await close(tester);
  });

  testWidgets('adding the final bank league moves focus to its active row',
      (tester) async {
    final last = kSportsLeagueBank.last;
    await storage.setSportsAddedLeagues(kSportsLeagueBank
        .where((l) => l.id != last.id)
        .map((l) => l.id)
        .toList());
    await open(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    visibleFocus(tester, 'bank:${last.id}');
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('Every league is added.'), findsOneWidget);
    visibleFocus(tester, 'yours:${last.id}');
    await press(tester, LogicalKeyboardKey.arrowUp);
    visibleFocus(
        tester, 'yours:${kSportsLeagueBank[kSportsLeagueBank.length - 2].id}');
    await close(tester);
  });

  testWidgets('sending a league back restores its sport without losing focus',
      (tester) async {
    final added = kSportsLeagueBank.firstWhere((l) => l.sport == 'football');
    await storage.setSportsAddedLeagues([added.id]);
    await storage.setSportsLeagues([...kDefaultSportsLeagueIds, added.id]);
    await open(tester);
    await downTo(tester, 'yours:${added.id}');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send back to the league bank'));
    await tester.pumpAndSettle();
    expect(storage.getSportsAddedLeagues(), isNot(contains(added.id)));
    visibleFocus(tester, 'yours:${kSportsLeagues.last.id}');
    await press(tester, LogicalKeyboardKey.arrowRight);
    visibleFocus(tester, 'bank-sport:football');
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    visibleFocus(tester, 'bank:${added.id}');
    await close(tester);
  });
}
