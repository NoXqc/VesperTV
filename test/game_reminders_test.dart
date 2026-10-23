import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

SportsGame reminderGame(DateTime start,
        {String id = 'game',
        GameState state = GameState.pre,
        String status = 'Scheduled',
        String leagueId = 'nhl'}) =>
    SportsGame(
        id: id,
        league: SportsLeague(
            id: leagueId,
            espnPath: 'hockey/nhl',
            name: 'NHL',
            shortName: 'NHL',
            logoUrl: ''),
        start: start,
        state: state,
        statusText: status,
        home: const SportsTeam(
            id: 'mtl',
            name: 'Montreal Canadiens',
            shortName: 'Canadiens',
            abbreviation: 'MTL'),
        away: const SportsTeam(
            id: 'buf',
            name: 'Buffalo Sabres',
            shortName: 'Buffalo',
            abbreviation: 'BUF'));

void main() {
  late StorageService storage;
  late GameReminders reminders;
  late DateTime time;
  late SportsGame game;
  Future<void> drain() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    time = DateTime.utc(2026, 10, 23, 19);
    game = reminderGame(time.add(const Duration(hours: 1)));
    reminders = GameReminders(storage, now: () => time);
  });
  tearDown(() => reminders.dispose());

  test('exactly two stages, stored before restart and never repeated',
      () async {
    await reminders.toggle(game);
    expect(reminders.poll(), isEmpty);
    expect(reminders.nextDeadline,
        game.start.subtract(const Duration(minutes: 15)));
    time = reminders.nextDeadline!;
    expect(reminders.poll().single.atStart, isFalse);
    expect(reminders.poll(), isEmpty);
    await drain();
    final reopened = GameReminders(storage, now: () => time);
    expect(reopened.poll(), isEmpty);
    time = game.start;
    expect(reopened.poll().single.atStart, isTrue);
    expect(reopened.poll(), isEmpty);
    await drain();
    final restarted = GameReminders(storage, now: () => time);
    expect(restarted.poll(), isEmpty);
    time = game.start.add(const Duration(minutes: 2));
    expect(restarted.poll(), isEmpty);
    expect(restarted.nextDeadline, isNull);
    reopened.dispose();
    restarted.dispose();
  });

  test(
      'setting within 15 minutes schedules kickoff without a false 15-minute alert',
      () async {
    time = game.start.subtract(const Duration(minutes: 5));
    await reminders.toggle(game);
    expect(reminders.poll(), isEmpty);
    expect(reminders.nextDeadline, game.start);
    time = game.start;
    expect(reminders.poll().single.atStart, isTrue);
    await drain();
  });

  test('late reopening skips old advance alerts but retains upcoming kickoff',
      () async {
    await reminders.toggle(game);
    time = game.start.subtract(const Duration(minutes: 3));
    expect(reminders.poll(), isEmpty);
    expect(reminders.nextDeadline, game.start);
    time = game.start.add(const Duration(seconds: 40));
    expect(reminders.poll().single.atStart, isTrue);
    await drain();
  });

  test('expired games do not produce a backlog after reopening', () async {
    await reminders.toggle(game);
    time = game.start.add(const Duration(minutes: 3));
    final reopened = GameReminders(storage, now: () => time);
    expect(reopened.poll(), isEmpty);
    expect(reopened.isSet(game), isFalse);
    reopened.dispose();
  });

  test('cancel removes both deadlines and survives restart', () async {
    expect(await reminders.toggle(game), isTrue);
    expect(await reminders.toggle(game), isFalse);
    time = game.start;
    expect(reminders.poll(), isEmpty);
    final reopened = GameReminders(storage, now: () => time);
    expect(reopened.isSet(game), isFalse);
    reopened.dispose();
  });

  test('same game ID in different leagues remains independent', () async {
    await reminders.toggle(game);
    await reminders.toggle(reminderGame(game.start, leagueId: 'nba'));
    time = game.start;
    expect(reminders.poll(), hasLength(2));
    await drain();
  });

  test('different timezone representations fire at the same UTC instant',
      () async {
    game = reminderGame(DateTime.parse('2026-10-23T16:00:00-04:00'));
    await reminders.toggle(game);
    time = DateTime.utc(2026, 10, 23, 19, 45);
    expect(reminders.poll().single.atStart, isFalse);
    await drain();
  });

  test(
      'viewer switching preserves each viewer and never reads another reminder',
      () async {
    await reminders.toggle(game);
    await storage.setActiveViewerId('kids');
    reminders.loadViewer();
    expect(reminders.isSet(game), isFalse);
    await reminders.toggle(reminderGame(game.start, id: 'kids-game'));
    await storage.setActiveViewerId('main');
    reminders.loadViewer();
    expect(reminders.isSet(game), isTrue);
    time = game.start;
    expect(reminders.poll().single.reminder.key, GameReminders.gameKey(game));
    await drain();
  });

  test('all viewers reminders are excluded from transfers and old backups',
      () async {
    await reminders.toggle(game);
    await storage.setActiveViewerId('kids');
    await reminders.toggle(game);
    expect(
        storage
            .exportForTransfer()
            .keys
            .any((key) => key.startsWith(AppConstants.keyGameReminders)),
        isFalse);
    expect(
        storage
            .exportForBackup()
            .keys
            .any((key) => key.startsWith(AppConstants.keyGameReminders)),
        isFalse);
    await storage.deleteViewerData('kids');
    expect(storage.getGameReminders(viewerId: 'kids'), isNull);
    expect(storage.getGameReminders(viewerId: 'main'), isNotNull);
  });

  test('schedule changes move both alerts and invalidate queued old notices',
      () async {
    await reminders.toggle(game);
    time = game.start.subtract(const Duration(minutes: 15));
    final old = reminders.poll().single;
    final moved = reminderGame(game.start.add(const Duration(hours: 1)));
    reminders.reconcile([moved]);
    expect(reminders.isCurrent(old.reminder), isFalse);
    expect(reminders.nextDeadline,
        moved.start.subtract(const Duration(minutes: 15)));
    time = reminders.nextDeadline!;
    expect(reminders.poll().single.atStart, isFalse);
    await drain();
  });

  for (final status in ['Postponed', 'Cancelled', 'Suspended']) {
    test('$status games cannot be armed and cancel a saved reminder', () async {
      final cancelled = reminderGame(game.start, status: status);
      expect(reminders.canSet(cancelled), isFalse);
      await reminders.toggle(game);
      reminders.reconcile([cancelled]);
      expect(reminders.isSet(game), isFalse);
      expect(reminders.nextDeadline, isNull);
      await drain();
    });
  }

  test('live, final and past games cannot create reminders', () async {
    for (final value in [
      reminderGame(game.start, state: GameState.live),
      reminderGame(game.start, state: GameState.post),
      reminderGame(time)
    ]) {
      expect(reminders.canSet(value), isFalse);
      await expectLater(reminders.toggle(value), throwsArgumentError);
    }
  });

  test('final schedule removes a reminder without displaying an alert',
      () async {
    await reminders.toggle(game);
    reminders.reconcile([reminderGame(game.start, state: GameState.post)]);
    expect(reminders.poll(), isEmpty);
    expect(reminders.nextDeadline, isNull);
    await drain();
  });

  test('malformed persisted entries cannot break startup', () async {
    await storage.setGameReminders(jsonEncode([
      {},
      {'start': 'bad'},
      1,
      null
    ]));
    final service = GameReminders(storage, now: () => time);
    expect(service.nextDeadline, isNull);
    expect(service.poll(), isEmpty);
    service.dispose();
  });
}
