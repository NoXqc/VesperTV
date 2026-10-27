import 'dart:async' show Completer;
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
        String leagueId = 'nhl',
        String? homeLogo}) =>
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
        home: SportsTeam(
            logoUrl: homeLogo,
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

  test('team opt-in adds future games, persists and avoids duplicate opponents',
      () async {
    reminders.dispose();
    var calls = 0;
    final next = reminderGame(time.add(const Duration(days: 2)), id: 'next');
    reminders = GameReminders(storage,
        now: () => time,
        loadSchedule: (league, id) async {
          calls++;
          return SportsTeamSchedule(
              league: game.league, team: game.home, games: [game, next]);
        });
    const team = FollowedTeam('nhl', 'mtl');
    await reminders.setTeam(team, true);
    expect(reminders.isSet(game), isTrue);
    expect(reminders.isSet(next), isTrue);
    expect(calls, 1);
    await reminders.refreshSchedules();
    expect(calls, 1);
    await reminders.setTeam(const FollowedTeam('nhl', 'buf'), true);
    time = game.start.subtract(const Duration(minutes: 15));
    expect(reminders.poll(), hasLength(1));
    await drain();
    final reopened = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    expect(reopened.teamEnabled(team), isTrue);
    expect(reopened.isSet(next), isTrue);
    expect(reopened.poll(), isEmpty);
    reopened.dispose();
  });

  test('later foreground refresh discovers games added to a team schedule',
      () async {
    reminders.dispose();
    final next = reminderGame(time.add(const Duration(days: 4)), id: 'new');
    var games = [game];
    reminders = GameReminders(storage,
        now: () => time,
        loadSchedule: (league, _) async =>
            SportsTeamSchedule(league: league, team: game.home, games: games));
    await reminders.setTeam(const FollowedTeam('nhl', 'mtl'), true);
    games = [game, next];
    time = time.add(const Duration(minutes: 30));
    await reminders.refreshSchedules();
    expect(reminders.isSet(next), isTrue);
    expect(reminders.teamEnabled(const FollowedTeam('nhl', 'mtl')), isTrue);
  });

  test('one-game cancellation stays skipped while team continues', () async {
    reminders.dispose();
    reminders = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    const team = FollowedTeam('nhl', 'mtl');
    await reminders.setTeam(team, true, games: [game]);
    await reminders.toggle(game);
    final next = reminderGame(time.add(const Duration(days: 2)), id: 'next');
    reminders.reconcile([game, next]);
    expect(reminders.isSet(game), isFalse);
    expect(reminders.isSet(next), isTrue);
    await drain();
    final reopened = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    reopened.reconcile([game]);
    expect(reopened.isSet(game), isFalse);
    reopened.dispose();
  });

  test('disabling a team retains manual reminders and the other team',
      () async {
    reminders.dispose();
    reminders = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    await reminders.toggle(game);
    final next = reminderGame(time.add(const Duration(days: 2)), id: 'next');
    const home = FollowedTeam('nhl', 'mtl');
    const away = FollowedTeam('nhl', 'buf');
    await reminders.setTeam(home, true, games: [game, next]);
    await reminders.setTeam(away, true, games: [game, next]);
    await reminders.setTeam(home, false);
    expect(reminders.isSet(next), isTrue);
    await reminders.setTeam(away, false);
    expect(reminders.isSet(next), isFalse);
    expect(reminders.isSet(game), isTrue);
  });

  test('late schedule response cannot populate another viewer', () async {
    reminders.dispose();
    final pending = Completer<SportsTeamSchedule?>();
    reminders = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) => pending.future);
    final enabling = reminders.setTeam(const FollowedTeam('nhl', 'mtl'), true);
    await drain();
    await storage.setActiveViewerId('kids');
    reminders.loadViewer();
    pending.complete(SportsTeamSchedule(
        league: game.league, team: game.home, games: [game]));
    await enabling;
    expect(reminders.hasTeamReminders, isFalse);
    expect(reminders.isSet(game), isFalse);
  });

  test('automatic logo uses enabled away team before another followed team',
      () async {
    reminders.dispose();
    await storage.setSportsFollowedTeams(['nhl|mtl', 'nhl|buf']);
    reminders = GameReminders(storage,
        now: () => time, loadSchedule: (_, __) async => null);
    final branded = SportsGame(
        id: game.id,
        league: game.league,
        start: game.start,
        state: GameState.pre,
        statusText: 'Scheduled',
        home: const SportsTeam(
            id: 'mtl',
            name: 'Montreal',
            shortName: 'MTL',
            abbreviation: 'MTL',
            logoUrl: 'https://example.com/home.png'),
        away: const SportsTeam(
            id: 'buf',
            name: 'Buffalo',
            shortName: 'BUF',
            abbreviation: 'BUF',
            logoUrl: 'https://example.com/away.png'));
    await reminders
        .setTeam(const FollowedTeam('nhl', 'buf'), true, games: [branded]);
    time = branded.start.subtract(const Duration(minutes: 15));
    final entry = reminders.poll().single.reminder;
    expect(entry.logoUrl, 'https://example.com/away.png');
    expect(GameReminder.parse(entry.toJson())!.logoUrl, entry.logoUrl);
  });

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
  for (final lead in [15, 60, 1440, 10080]) {
    test('$lead-minute choice persists and sends advance plus kickoff once',
        () async {
      game = reminderGame(time.add(Duration(minutes: lead + 60)));
      await reminders.setReminder(game, leadMinutes: lead);
      expect(reminders.leadMinutesFor(game), lead);
      expect(
          reminders.nextDeadline, game.start.subtract(Duration(minutes: lead)));
      final reopened = GameReminders(storage, now: () => time);
      expect(reopened.leadMinutesFor(game), lead);
      reopened.dispose();
      time = reminders.nextDeadline!;
      final advance = reminders.poll().single;
      expect(advance.atStart, isFalse);
      expect(advance.reminder.leadMinutes, lead);
      expect(advance.validAt(time), isTrue);
      expect(reminders.poll(), isEmpty);
      await drain();
      final restored = GameReminders(storage, now: () => time);
      expect(restored.poll(), isEmpty);
      expect(restored.nextDeadline, game.start);
      time = game.start;
      expect(restored.poll().single.atStart, isTrue);
      expect(restored.poll(), isEmpty);
      await drain();
      restored.dispose();
    });
  }

  test('kickoff-only schedules exactly one notification', () async {
    await reminders.setReminder(game, leadMinutes: 0);
    expect(reminders.nextDeadline, game.start);
    time = game.start.subtract(const Duration(minutes: 15));
    expect(reminders.poll(), isEmpty);
    time = game.start;
    expect(reminders.poll().single.atStart, isTrue);
    expect(reminders.poll(), isEmpty);
    await drain();
  });

  test('legacy and malformed timing values safely retain the old default', () {
    final old =
        GameReminder(key: 'old', home: 'A', away: 'B', start: game.start)
            .toJson()
          ..remove('leadMinutes');
    expect(GameReminder.parse(old)!.leadMinutes, 15);
    for (final value in ['60', -1, 999, 15.0, null]) {
      expect(
          GameReminder.parse({...old, 'leadMinutes': value})!.leadMinutes, 15);
    }
  });

  test('editing timing invalidates queued notice and skips elapsed deadlines',
      () async {
    await reminders.toggle(game);
    time = game.start.subtract(const Duration(minutes: 15));
    final old = reminders.poll().single;
    await reminders.setReminder(game, leadMinutes: 60);
    expect(reminders.isCurrent(old.reminder), isFalse);
    expect(reminders.poll(), isEmpty);
    expect(reminders.nextDeadline, game.start);
    await reminders.setReminder(game, leadMinutes: 60);
    expect(reminders.poll(), isEmpty);
    await drain();
  });

  test('rescheduled match preserves chosen time and replaces old deadline',
      () async {
    game = reminderGame(time.add(const Duration(days: 8)));
    await reminders.setReminder(game, leadMinutes: 10080);
    final moved = reminderGame(game.start.add(const Duration(days: 1)));
    reminders.reconcile([moved]);
    expect(reminders.leadMinutesFor(moved), 10080);
    expect(
        reminders.nextDeadline, moved.start.subtract(const Duration(days: 7)));
    await drain();
  });

  test(
      'timing override for one automatic team game survives stopping team reminders',
      () async {
    await storage.setSportsFollowedTeams(['nhl|mtl']);
    await reminders
        .setTeam(const FollowedTeam('nhl', 'mtl'), true, games: [game]);
    await reminders.setReminder(game, leadMinutes: 60);
    await reminders.setTeam(const FollowedTeam('nhl', 'mtl'), false);
    expect(reminders.isSet(game), isTrue);
    expect(reminders.leadMinutesFor(game), 60);
  });

  test(
      'custom timing remains per viewer; invalid selections leave state intact',
      () async {
    await reminders.setReminder(game, leadMinutes: 60);
    await expectLater(
        reminders.setReminder(game, leadMinutes: 7), throwsArgumentError);
    expect(reminders.leadMinutesFor(game), 60);
    await storage.setActiveViewerId('kids');
    reminders.loadViewer();
    expect(reminders.isSet(game), isFalse);
    await storage.setActiveViewerId('main');
    reminders.loadViewer();
    expect(reminders.leadMinutesFor(game), 60);
  });
}
