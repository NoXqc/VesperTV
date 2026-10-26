import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/desktop_vod_progress.dart';
import 'package:nox_iptv/services/storage_service.dart';

Channel item(String raw, {bool transient = false, bool onDemand = false}) =>
    Channel(
        id: 'p::$raw',
        rawId: raw,
        playlistId: 'p',
        name: 'Test',
        group: 'Test',
        url: 'https://example.com/file',
        transientPlayback: transient,
        onDemand: onDemand);

void main() {
  late StorageService storage;
  late DesktopVodProgress progress;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    progress = DesktopVodProgress(storage);
  });

  test(
      'Windows movie and episode progress survives reopening and feeds watched state',
      () async {
    for (final raw in ['xt_vod_1', 'xt_ep_1', 'arc_vod_1', 'arc_ep_1']) {
      final channel = item(raw);
      await progress.save(
          channel, const Duration(minutes: 5), const Duration(minutes: 30));
      final reopened = DesktopVodProgress(storage);
      expect(reopened.resumePosition(channel), const Duration(minutes: 5));
      expect(storage.getWatchedFraction(channel.id), closeTo(1 / 6, 0.001));
      expect(storage.isFullyWatched(channel.id), isFalse);
      await reopened.save(
          channel, const Duration(minutes: 29), const Duration(minutes: 30));
      expect(storage.isFullyWatched(channel.id), isTrue);
      expect(reopened.resumePosition(channel), Duration.zero);
    }
  });

  test('live and transient playback never write or read a movie resume point',
      () async {
    for (final channel in [
      item('station'),
      item('arc_vod_trailer', transient: true)
    ]) {
      await storage.setLastPosition(channel.id, 50000);
      await progress.save(
          channel, const Duration(seconds: 60), const Duration(minutes: 5));
      expect(storage.getLastPosition(channel.id), 50000);
      expect(progress.resumePosition(channel), Duration.zero);
    }
    final m3uMovie = item('ordinary-id', onDemand: true);
    await progress.save(
        m3uMovie, const Duration(seconds: 25), const Duration(minutes: 90));
    expect(progress.resumePosition(m3uMovie), const Duration(seconds: 25));
  });

  test('loading with unknown duration cannot erase an existing resume point',
      () async {
    final channel = item('arc_ep_1');
    await progress.save(
        channel, const Duration(minutes: 12), const Duration(minutes: 30));
    await progress.save(channel, Duration.zero, Duration.zero);
    expect(progress.resumePosition(channel), const Duration(minutes: 12));
  });

  test('tracker fraction is converted only after actual duration is known',
      () async {
    final channel = item('arc_ep_1');
    await storage.setResumeFraction(channel.id, 0.4);
    expect(progress.resumePosition(channel), isNull);
    await progress.save(channel, Duration.zero, const Duration(minutes: 30));
    expect(storage.isResumeFraction(channel.id), isTrue);
    expect(
        progress.resumePosition(channel, duration: const Duration(minutes: 30)),
        const Duration(minutes: 12));
    await storage.clearResumeFraction(channel.id);
    await progress.save(
        channel, const Duration(minutes: 12), const Duration(minutes: 30));
    expect(progress.resumePosition(channel), const Duration(minutes: 12));
  });

  test(
      'late saves from previous viewer cannot overwrite another viewer progress',
      () async {
    final channel = item('arc_ep_1');
    await progress.save(
        channel, const Duration(minutes: 5), const Duration(minutes: 30));
    await storage.setActiveViewerId('other');
    await progress.save(
        channel, const Duration(minutes: 6), const Duration(minutes: 30));
    expect(storage.getLastPosition(channel.id), 0);
    final other = DesktopVodProgress(storage);
    await other.save(
        channel, const Duration(minutes: 2), const Duration(minutes: 30));
    expect(other.resumePosition(channel), const Duration(minutes: 2));
  });
}
