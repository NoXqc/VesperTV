import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/programme_reminders.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/programme_reminder_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_reminder_overlay_test.dart' show ReminderViewers;
import 'programme_reminders_test.dart' show programme, programmeChannel;

void main() {
  late StorageService storage;
  late PlaylistManager playlist;
  late PlaybackService playback;
  late ReminderViewers viewers;
  late FocusNode videoFocus;
  late DateTime time;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    playlist = PlaylistManager(storage, CatalogDatabase());
    playback = PlaybackService(storage, playlist);
    viewers = ReminderViewers(storage, playlist, playback);
    videoFocus = FocusNode();
    time = DateTime.utc(2026, 10, 28, 18);
  });
  tearDown(() {
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    videoFocus.dispose();
  });
  Future<void> mount(WidgetTester tester, ProgrammeReminders reminders) =>
      tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<ProgrammeReminders>.value(value: reminders),
            ChangeNotifierProvider<ViewerProfileService>.value(value: viewers)
          ],
          child: MaterialApp(
              builder: (context, child) => Stack(children: [
                    if (child != null) child,
                    const ProgrammeReminderOverlay()
                  ]),
              home: Scaffold(
                  body: TextButton(
                      focusNode: videoFocus,
                      autofocus: true,
                      onPressed: () {},
                      child: const Text('Video'))))));
  testWidgets(
      'advance/start notices overlay playback without taking D-pad focus or tuning',
      (tester) async {
    final reminders = ProgrammeReminders(storage, now: () => time);
    final show = programme(time.add(const Duration(minutes: 20)));
    await reminders.toggle(programmeChannel, show);
    await mount(tester, reminders);
    await tester.pump();
    expect(videoFocus.hasFocus, isTrue);
    time = show.start.subtract(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 15));
    await tester.pump();
    expect(find.text('Starts in 5 minutes'), findsOneWidget);
    expect(find.text(show.title), findsOneWidget);
    expect(videoFocus.hasFocus, isTrue);
    expect(playback.currentChannel, isNull);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text(show.title), findsNothing);
    time = show.start;
    await tester.pump(const Duration(minutes: 4, seconds: 48));
    await tester.pump();
    expect(find.text('On now'), findsOneWidget);
    expect(videoFocus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    reminders.dispose();
  });
  testWidgets(
      'background/viewer changes clear notices and stale ones never replay',
      (tester) async {
    final reminders = ProgrammeReminders(storage, now: () => time);
    final show = programme(time.add(const Duration(minutes: 20)));
    await reminders.toggle(programmeChannel, show);
    await mount(tester, reminders);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    time = show.start.add(const Duration(minutes: 3));
    await tester.pump(const Duration(minutes: 23));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(show.title), findsNothing);
    final later = programme(time.add(const Duration(minutes: 10)),
        title: 'Next viewer programme');
    await reminders.toggle(programmeChannel, later);
    await tester.pump();
    await viewers.change('other');
    await tester.pump();
    time = later.start;
    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(find.text(later.title), findsNothing);
    await tester.pumpWidget(const SizedBox());
    reminders.dispose();
  });
}
