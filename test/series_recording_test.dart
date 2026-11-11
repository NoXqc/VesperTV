import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/recording_service.dart';

import 'programme_reminders_test.dart' show programmeChannel;

EpgProgram airing(DateTime start,
        {String title = 'The Nightly Show',
        int minutes = 30,
        String? description}) =>
    EpgProgram(
        channelId: 'one',
        title: title,
        description: description,
        start: start,
        stop: start.add(Duration(minutes: minutes)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('vespertv/recorder');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late RecordingService service;
  late DateTime time;
  final calls = <MethodCall>[];

  List<dynamic> lastSchedule() => jsonDecode(calls
      .where((c) => c.method == 'schedule')
      .last
      .arguments['items'] as String) as List;

  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('vesper-series-recording-');
    time = DateTime.now();
    calls.clear();
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'active':
          return <Map<String, Object>>[];
        case 'storage':
          return [
            {
              'path': directory.path,
              'free': 10 << 30,
              'total': 20 << 30,
              'removable': false
            }
          ];
        case 'schedule':
          return true;
        default:
          return null;
      }
    });
    service = RecordingService.forTesting(directory, now: () => time);
    await service.init();
    calls.clear();
  });

  tearDown(() async {
    service.dispose();
    messenger.setMockMethodCallHandler(bridge, null);
    await directory.delete(recursive: true);
  });

  test('a series title ignores what guides add to one airing', () {
    final key = seriesTitleKey('The Nightly Show');
    for (final t in [
      'The Nightly Show (R)',
      'New: The Nightly Show',
      'The Nightly Show [HD]',
      'the nightly show S03E12',
      'The Nightly  Show - S3 E12',
      'THE NIGHTLY SHOW',
    ]) {
      expect(seriesTitleKey(t), key, reason: t);
    }
    expect(seriesTitleKey('The Nightly Show Special'), isNot(key));
    expect(seriesTitleKey('Nightly News'), isNot(key));
    // A title that is only a tag still has a key.
    expect(seriesTitleKey('(Live)'), isNotEmpty);
  });

  test(
      'Record series schedules every matching airing from the guide, survives a restart',
      () async {
    final first = airing(time.add(const Duration(hours: 1)));
    final guide = [
      first,
      airing(time.add(const Duration(hours: 2)), title: 'Something else'),
      airing(time.add(const Duration(days: 1)), title: 'The Nightly Show (R)'),
      airing(time.add(const Duration(days: 2))),
      // Past the horizon: added by a later refresh.
      airing(time.add(const Duration(days: 10))),
    ];
    final r = await service.addSeries(programmeChannel, first, guide);
    expect(r.added, 3);
    expect(r.conflicts, 0);
    expect(service.series.single.title, 'The Nightly Show');
    expect(service.scheduledCount(r.rule), 3);
    expect(lastSchedule(), hasLength(3));
    expect(service.items.every((e) => e.seriesId == r.rule.id), isTrue);
    expect(service.nextOf(r.rule)?.startAt, first.start.toLocal());
    // Holding another airing of the same show finds the same series.
    expect(service.seriesFor(programmeChannel, 'New: The Nightly Show'),
        same(r.rule));
    expect(
        service.seriesFor(
            programmeChannel.copyWith(id: 'p::two'), 'The Nightly Show'),
        isNull);
    final again = await service.addSeries(programmeChannel, first, guide);
    expect(again.added, 0);
    expect(service.series, hasLength(1));

    final reload = RecordingService.forTesting(directory, now: () => time);
    await reload.init();
    expect(reload.series.single.id, r.rule.id);
    expect(reload.scheduledCount(reload.series.single), 3);
    reload.dispose();
  });

  test('skip repeats leaves out an episode the series already has', () async {
    const plot = 'Tonight: the host visits a lighthouse on the coast.';
    final first = airing(time.add(const Duration(hours: 1)), description: plot);
    final guide = [
      first,
      // The late-night repeat of the same episode.
      airing(time.add(const Duration(hours: 5)), description: plot),
      airing(time.add(const Duration(days: 1)),
          description: 'Tonight: a cooking contest in a tiny kitchen.'),
      // No description: can't tell, recorded.
      airing(time.add(const Duration(days: 2))),
    ];
    final r = await service.addSeries(programmeChannel, first, guide,
        skipRepeats: true);
    expect(r.added, 3);
    expect(
        service.items.map((e) => e.startAt),
        isNot(contains(
            time.add(const Duration(hours: 5)).toLocal())));
    await service.stopSeries(r.rule);
    final every = await service.addSeries(programmeChannel, first, guide);
    expect(every.added, 4);
  });

  test(
      'refresh adds new airings, keeps a cancelled one cancelled, follows a moved airing',
      () async {
    final first = airing(time.add(const Duration(hours: 1)));
    final second = airing(time.add(const Duration(days: 1)));
    final r = await service.addSeries(programmeChannel, first, [first, second]);
    expect(r.added, 2);

    // The viewer cancels tomorrow's airing (Recordings tab or the guide).
    final tomorrow = service.items.firstWhere(
        (e) => e.startAt == second.start.toLocal());
    await service.stop(tomorrow);
    expect(service.scheduledCount(r.rule), 1);

    // The guide now lists a third airing and moved the first by an hour.
    final moved = airing(time.add(const Duration(hours: 2)));
    final third = airing(time.add(const Duration(days: 3)));
    final guide = [
      airing(time.add(const Duration(hours: 1)), title: 'Breaking news'),
      moved,
      second,
      third,
    ];
    await service.refreshSeries(
        channels: {programmeChannel.id: programmeChannel},
        programmes: (_) async => guide);
    final starts = service.items.map((e) => e.startAt).toSet();
    expect(starts, {moved.start.toLocal(), third.start.toLocal()});
    expect(lastSchedule(), hasLength(2));

    // A new stream link reaches the scheduled airings.
    final relinked =
        programmeChannel.copyWith(url: 'https://example.test/live/new');
    await service.refreshSeries(
        channels: {relinked.id: relinked}, programmes: (_) async => guide);
    expect(service.items.every((e) => e.url == relinked.url), isTrue);

    // Its channel not loaded (playlist off): nothing changes.
    calls.clear();
    await service.refreshSeries(
        channels: const {}, programmes: (_) async => guide);
    expect(calls.where((c) => c.method == 'schedule'), isEmpty);
    expect(service.items, hasLength(2));
  });

  test(
      'an airing with no free connection is skipped and counted, not forced',
      () async {
    final busy = airing(time.add(const Duration(hours: 1)), title: 'Movie');
    await service.recordProgramme(
        programmeChannel.copyWith(id: 'p::two'), busy);
    final first = airing(time.add(const Duration(hours: 1)));
    final later = airing(time.add(const Duration(days: 1)));
    final r = await service.addSeries(programmeChannel, first, [first, later]);
    expect(r.added, 1);
    expect(r.conflicts, 1);
    final two = await service.addSeries(
        programmeChannel.copyWith(id: 'p::three'),
        airing(time.add(const Duration(hours: 1)), title: 'Other show'),
        [],
        maxConnections: 2);
    expect(two.added, 1);
  });

  test('a series keeps at most its cap of upcoming airings', () async {
    final guide = [
      for (var i = 1; i <= 40; i++) airing(time.add(Duration(hours: 3 * i)))
    ];
    final r = await service.addSeries(programmeChannel, guide.first, guide);
    expect(r.added, RecordingService.seriesMaxScheduled);
    expect(service.scheduledCount(r.rule), RecordingService.seriesMaxScheduled);
  });

  test('Stop series cancels what is scheduled and keeps recordings made',
      () async {
    final first = airing(time.add(const Duration(hours: 1)));
    final r = await service.addSeries(programmeChannel, first,
        [first, airing(time.add(const Duration(days: 1)))]);
    service.items.firstWhere((e) => e.startAt == first.start.toLocal()).state =
        RecState.done;
    await service.stopSeries(r.rule);
    expect(service.series, isEmpty);
    expect(service.items.single.state, RecState.done);
    expect(lastSchedule(), isEmpty);
  });

  test('a series needs a live channel and a programme title', () async {
    final first = airing(time.add(const Duration(hours: 1)));
    expect(
        () => service.addSeries(
            Channel(
                id: 'p::vod',
                rawId: 'vod',
                playlistId: 'p',
                name: 'Movie',
                group: 'Movies',
                url: 'https://example.test/movie.mkv',
                onDemand: true),
            first,
            [first]),
        throwsStateError);
    expect(service.series, isEmpty);
  });
}
