import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/episode_airing.dart';
import 'package:nox_iptv/services/episode_alerts.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    now = DateTime(2026, 11, 5, 20);
  });

  FollowedShow show() => FollowedShow(
      key: FollowedShow.iptvKey('p', 7),
      title: 'Show ABC',
      playlistId: 'p',
      seriesId: 7);

  EpisodeStatus status(int s, int e, {List<(int, int)>? all}) =>
      EpisodeStatus(season: s, episode: e, count: all);

  test('following sets a silent baseline; a newer episode alerts once',
      () async {
    final alerts = EpisodeAlerts(storage, now: () => now);
    var latest = status(1, 2);
    final posted = <EpisodeNotice>[];
    alerts
      ..lookup = ((_) async => latest)
      ..systemNotify = ((n) async => posted.add(n));
    await alerts.follow(show());
    await Future<void>.delayed(Duration.zero);
    expect(alerts.notices, isEmpty);
    expect(alerts.show(show().key)!.lastEpisode, 2);

    // Not due yet: nothing is fetched.
    latest = status(1, 3);
    await alerts.checkAll();
    expect(alerts.notices, isEmpty);

    now = now.add(const Duration(hours: 4));
    await alerts.checkAll();
    expect(alerts.notices.single.code, 'S1 E3');
    expect(posted.single.title, 'Show ABC');

    // Same episode again: no second alert.
    now = now.add(const Duration(hours: 4));
    await alerts.checkAll();
    expect(posted, hasLength(1));

    // Saved per viewer and reloaded.
    final again = EpisodeAlerts(storage, now: () => now);
    expect(again.notices.single.code, 'S1 E3');
    await again.dismiss(show().key);
    expect(again.notices, isEmpty);
    expect(again.isFollowing(show().key), isTrue);
  });

  test('a whole new season counts every new episode', () async {
    final alerts = EpisodeAlerts(storage, now: () => now);
    var latest = status(1, 10);
    alerts.lookup = (_) async => latest;
    await alerts.follow(show());
    await Future<void>.delayed(Duration.zero);
    latest = status(2, 8, all: [
      for (var e = 1; e <= 10; e++) (1, e),
      for (var e = 1; e <= 8; e++) (2, e),
    ]);
    await alerts.checkAll(force: true);
    final notice = alerts.notices.single;
    expect(notice.code, 'S2 E8');
    expect(notice.count, 8);
  });

  test('no answer (playlist not loaded) never alerts or resets', () async {
    final alerts = EpisodeAlerts(storage, now: () => now);
    EpisodeStatus? latest = status(3, 1);
    alerts.lookup = (_) async => latest;
    await alerts.follow(show());
    await Future<void>.delayed(Duration.zero);
    latest = null;
    await alerts.checkAll(force: true);
    expect(alerts.notices, isEmpty);
    expect(alerts.show(show().key)!.lastSeason, 3);
  });

  test('unfollowing removes the show and its card', () async {
    final alerts = EpisodeAlerts(storage, now: () => now);
    var latest = status(1, 1);
    alerts.lookup = (_) async => latest;
    await alerts.follow(show());
    await Future<void>.delayed(Duration.zero);
    latest = status(1, 2);
    await alerts.checkAll(force: true);
    expect(alerts.notices, hasLength(1));
    await alerts.unfollow(show().key);
    expect(alerts.notices, isEmpty);
    expect(alerts.isFollowing(show().key), isFalse);
  });

  test('the next scheduled episode round-trips for the Airs in tag',
      () async {
    final alerts = EpisodeAlerts(storage, now: () => now);
    alerts.lookup = (_) async => EpisodeStatus(
        season: 1,
        episode: 7,
        next: EpisodeAiring.parse('2026-11-10', season: 1, episode: 8));
    await alerts.follow(show());
    await Future<void>.delayed(Duration.zero);
    final saved = EpisodeAlerts(storage, now: () => now).show(show().key)!;
    expect(saved.next!.episode, 8);
    expect(saved.next!.upcoming(now), isTrue);
  });
}
