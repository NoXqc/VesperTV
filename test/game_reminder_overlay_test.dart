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
}
