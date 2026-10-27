import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/game_reminder_menu_tile.dart';
import 'package:nox_iptv/widgets/game_reminder_overlay.dart';
import 'package:nox_iptv/widgets/game_reminder_timing_menu.dart';

import 'game_reminders_test.dart' show reminderGame;

class ReminderViewers extends ViewerProfileService {
  ReminderViewers(
      this.store, PlaylistManager playlist, PlaybackService playback)
      : super(store, playlist, playback);
  final StorageService store;
  String id = 'main';
  @override
  ViewerProfile get active => ViewerProfile(
      id: id,
      name: id,
      colorIndex: 0,
      isRestricted: false,
      createdAt: DateTime(2026));
  Future<void> change(String next) async {
    await store.setActiveViewerId(next);
    id = next;
    notifyListeners();
  }
}

void main() {
  late StorageService storage;
  late GameReminders reminders;
  late ReminderViewers viewers;
  late PlaylistManager playlist;
  late PlaybackService playback;
  late DateTime time;
  late GlobalKey<NavigatorState> navigator;
  late FocusNode streamFocus;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    time = DateTime.utc(2026, 10, 23, 19);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    playlist = PlaylistManager(storage, CatalogDatabase());
    playback = PlaybackService(storage, playlist);
    viewers = ReminderViewers(storage, playlist, playback);
    navigator = GlobalKey<NavigatorState>();
    streamFocus = FocusNode(debugLabel: 'stream-controls');
  });

  tearDown(() {
    reminders.dispose();
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    streamFocus.dispose();
  });

  Future<void> mount(WidgetTester tester, {Widget? page}) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GameReminders>.value(value: reminders),
          ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(body: page ?? const Text('Sports')),
          builder: (context, child) =>
              Stack(children: [child!, const GameReminderOverlay()]),
        )));
    await tester.pump();
  }

  testWidgets('team menu enables all games and can stop them', (tester) async {
    await storage.setSportsFollowedTeams(['nhl|mtl']);
    reminders = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await mount(tester, page: GameReminderMenuTile(game: game, onTap: () {}));
    await tester.tap(find.text('Remind me for every game: Canadiens'));
    await tester.pump();
    expect(find.text('Stop team reminders: Canadiens'), findsOneWidget);
    expect(reminders.isSet(game), isTrue);
    await tester.tap(find.text('Stop team reminders: Canadiens'));
    await tester.pump();
    expect(reminders.isSet(game), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'popup paints faded team logo behind text and handles image failure',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)),
        homeLogo: 'https://example.com/logo.png');
    await reminders.toggle(game);
    await mount(tester);
    time = game.start.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 45));
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    final image =
        tester.widget<Image>(find.byKey(const ValueKey('reminder-watermark')));
    final crest =
        tester.widget<Image>(find.byKey(const ValueKey('reminder-crest')));
    expect((crest.image as NetworkImage).url, 'https://example.com/logo.png');
    expect((image.image as NetworkImage).url, 'https://example.com/logo.png');
    final fade = tester.widget<Opacity>(find
        .ancestor(
            of: find.byKey(const ValueKey('reminder-watermark')),
            matching: find.byType(Opacity))
        .first);
    expect(fade.opacity, 0.28);
    expect(image.errorBuilder, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('alerts appear above a pushed stream without taking focus',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await reminders.toggle(game);
    await mount(tester);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
            body: TextButton(
                focusNode: streamFocus,
                autofocus: true,
                onPressed: () {},
                child: const Text('Stream controls')))));
    await tester.pumpAndSettle();
    expect(streamFocus.hasFocus, isTrue);
    time = game.start.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 45));
    expect(find.text('Your team: Canadiens vs Buffalo'), findsOneWidget);
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    expect(find.text('Stream controls'), findsOneWidget);
    expect(streamFocus.hasFocus, isTrue);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Starts in 15 minutes'), findsNothing);
    time = game.start;
    await tester
        .pump(const Duration(minutes: 15) - const Duration(seconds: 12));
    expect(find.text('Is about to start'), findsOneWidget);
    expect(streamFocus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancellation removes a visible notice and its kickoff alarm',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await reminders.toggle(game);
    await mount(tester);
    time = game.start.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 45));
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    await reminders.toggle(game);
    await tester.pump();
    expect(find.text('Starts in 15 minutes'), findsNothing);
    time = game.start;
    await tester.pump(const Duration(minutes: 15));
    expect(find.text('Is about to start'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching viewer immediately clears visible and queued notices',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await reminders.toggle(game);
    await reminders.toggle(reminderGame(game.start, id: 'another'));
    await mount(tester);
    time = game.start.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 45));
    expect(find.text('Starts in 15 minutes'), findsOneWidget);
    await viewers.change('kids');
    await tester.pump();
    expect(find.text('Starts in 15 minutes'), findsNothing);
    time = game.start;
    await tester.pump(const Duration(minutes: 15));
    expect(find.text('Is about to start'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background suspends notices; resume skips stale advance alert',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await reminders.toggle(game);
    await mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    time = game.start.subtract(const Duration(minutes: 3));
    await tester.pump(const Duration(minutes: 57));
    expect(find.text('Starts in 15 minutes'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Starts in 15 minutes'), findsNothing);
    time = game.start;
    await tester.pump(const Duration(minutes: 3));
    expect(find.text('Is about to start'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reminder menu toggles to cancel and hides for started games',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await mount(tester,
        page: GameReminderMenuTile(
            game: game, onTap: () => reminders.toggle(game)));
    expect(find.text('Remind me'), findsOneWidget);
    await tester.tap(find.text('Remind me'));
    await tester.pump();
    expect(find.text('Cancel reminder'), findsOneWidget);
    await tester.tap(find.text('Cancel reminder'));
    await tester.pump();
    expect(find.text('Remind me'), findsOneWidget);
    time = game.start;
    await mount(tester, page: GameReminderMenuTile(game: game, onTap: () {}));
    expect(find.text('Remind me'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phone-sized popup fits and dismisses without leaving the stream',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = reminderGame(time.add(const Duration(hours: 1)));
    await reminders.toggle(game);
    await mount(tester, page: const Text('Stream'));
    time = game.start.subtract(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 45));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
    await tester.pump();
    expect(find.text('Starts in 15 minutes'), findsNothing);
    expect(find.text('Stream'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final choice in [
    (60, 'Starts in 1 hour'),
    (1440, 'Starts in 1 day'),
    (10080, 'Starts in 1 week')
  ]) {
    testWidgets('custom popup says ${choice.$2} and retains the existing card',
        (tester) async {
      reminders = GameReminders(storage, now: () => time);
      final game = reminderGame(time.add(Duration(minutes: choice.$1 + 60)));
      await reminders.setReminder(game, leadMinutes: choice.$1);
      await mount(tester);
      time = game.start.subtract(Duration(minutes: choice.$1));
      await tester.pump(const Duration(hours: 1));
      await tester.pump();
      expect(find.text(choice.$2), findsOneWidget);
      expect(find.textContaining('Canadiens'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'timing menu offers all choices, returns selection and Back cancels',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(days: 8)));
    int? picked;
    await mount(tester,
        page: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  picked = await showGameReminderTimingMenu(
                      context, game, reminders);
                },
                child: const Text('Choose timing'))));
    await tester.tap(find.text('Choose timing'));
    await tester.pumpAndSettle();
    for (final label in [
      '15 minutes before',
      '1 hour before',
      '1 day before',
      '1 week before',
      'At game time only'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.ensureVisible(find.text('1 week before'));
    await tester.tap(find.text('1 week before'));
    await tester.pumpAndSettle();
    expect(picked, 10080);
    picked = null;
    await tester.tap(find.text('Choose timing'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Choose timing'), findsOneWidget);
    expect(reminders.isSet(game), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('phone timing menu disables elapsed choices and fits large text',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(minutes: 10)));
    tester.view.physicalSize = const Size(360, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? picked;
    await mount(tester,
        page: Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  picked = await showGameReminderTimingMenu(
                      context, game, reminders);
                },
                child: const Text('Choose timing'))));
    await tester.tap(find.text('Choose timing'));
    await tester.pumpAndSettle();
    final menuContext = tester.element(find.byType(Dialog));
    final rect = tester.getRect(find.byType(Dialog));
    expect(rect.width, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('15 minutes before'));
    await tester.tap(find.text('15 minutes before'));
    await tester.pump();
    expect(picked, isNull);
    expect(find.byType(Dialog), findsOneWidget);
    expect(MediaQuery.sizeOf(menuContext).width, 360);
    await tester.ensureVisible(find.text('At game time only'));
    expect(Focus.of(tester.element(find.text('At game time only'))).hasFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('held remote OK cannot accidentally choose a reminder time',
      (tester) async {
    reminders = GameReminders(storage, now: () => time);
    final game = reminderGame(time.add(const Duration(days: 8)));
    int? picked;
    await mount(tester,
        page: Builder(
            builder: (context) => TextButton(
                autofocus: true,
                onPressed: () async {
                  picked = await showGameReminderTimingMenu(
                      context, game, reminders);
                },
                child: const Text('Choose timing'))));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, 15);
    await tester.pumpWidget(const SizedBox());
  });
}
