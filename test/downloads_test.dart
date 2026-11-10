import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = MethodChannel('vespertv/recorder');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late RecordingService service;
  late DateTime time;
  final calls = <MethodCall>[];
  var active = <Map<String, Object>>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vesper-downloads-');
    time = DateTime(2026, 11, 9, 21, 0);
    calls.clear();
    active = [];
    messenger.setMockMethodCallHandler(bridge, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'active':
          return active;
        case 'storage':
          return [
            {
              'path': '${directory.path}/Recordings',
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

  List<Map<String, dynamic>> lastSchedule() => [
        for (final m in jsonDecode(calls
            .where((c) => c.method == 'schedule')
            .last
            .arguments['items'] as String) as List)
          Map<String, dynamic>.from(m as Map)
      ];

  const movie = DownloadItem(
    sourceId: 'p1::xt_vod_42',
    title: 'Some Movie',
    url: 'http://provider.example/movie/u/p/42.mkv',
    headers: {'User-Agent': 'Test'},
    playlistId: 'p1',
    maxConnections: 1,
    poster: 'http://img.example/42.jpg',
    durationSec: 7200,
  );

  test('a download goes to the native scheduler with what it needs', () async {
    final at = time.add(const Duration(hours: 5));
    final [entry] = await service.download([movie], at: at);
    expect(entry.isDownload, isTrue);
    expect(entry.isChannel, isFalse);
    expect(entry.path, endsWith('.mkv'));
    expect(entry.path, startsWith('${directory.path}/Recordings/'));
    final item = lastSchedule().single;
    expect(item['kind'], 'download');
    expect(item['url'], movie.url);
    expect(item['account'], 'p1');
    expect(item['maxConnections'], 1);
    expect(item['durationSec'], 7200);
    expect(item['headers'], {'User-Agent': 'Test'});
    expect(item['startAt'], at.millisecondsSinceEpoch);
    // No end: it runs until the file is complete.
    expect(item['endAt'], 0);
    expect(item['statusPath'], '${entry.path}.status');
    // Same title again: the existing download, not a second one.
    expect((await service.download([movie])).single, same(entry));
    expect(service.downloadFor(movie.sourceId), same(entry));
  });

  test('a season keeps its order and stays out of live recording checks',
      () async {
    final episodes = [
      for (var i = 1; i <= 3; i++)
        DownloadItem(
            sourceId: 'p1::xt_ep_$i',
            title: 'S01E0$i',
            group: 'Show',
            url: 'http://provider.example/series/u/p/$i.mp4',
            playlistId: 'p1'),
    ];
    final entries = await service.download(episodes);
    expect([for (final e in entries) e.title], ['S01E01', 'S01E02', 'S01E03']);
    expect(entries[0].startAt.isBefore(entries[1].startAt), isTrue);
    expect(entries[1].startAt.isBefore(entries[2].startAt), isTrue);
    expect(entries.first.path, endsWith('.mp4'));

    // Running downloads are never the "recording" of a channel (no
    // recorder tap, no Stop-recording popup).
    for (final e in entries) {
      e.state = RecState.recording;
    }
    final episode = Channel(
        id: 'p1::xt_ep_1',
        rawId: 'xt_ep_1',
        playlistId: 'p1',
        name: 'S01E01',
        group: '',
        url: episodes.first.url);
    expect(service.recordingOf(episode), isNull);
    expect(service.conflictFor(episode, const []), isNull);
  });

  test('status: a download the process lost is interrupted and resumes',
      () async {
    final [entry] = await service.download([movie]);
    final status = File(service.statusPathOf(entry));
    await status.parent.create(recursive: true);
    await status.writeAsString(jsonEncode({
      'state': 'downloading',
      'bytes': 300,
      'total': 1200,
      'note': '',
      'updatedAt': time.add(const Duration(seconds: 5)).millisecondsSinceEpoch,
    }));
    active = [];
    await service.refreshStatus();
    expect(entry.state, RecState.interrupted);
    expect(entry.bytes, 300);
    expect(entry.totalBytes, 1200);
    expect(entry.progress, 0.25);

    // Resume: the old status file no longer counts until the recorder
    // writes a new one.
    time = time.add(const Duration(minutes: 1));
    await service.resumeDownload(entry);
    await service.refreshStatus();
    expect(entry.state, RecState.scheduled);
    expect(lastSchedule().single['id'], entry.id);

    await status.writeAsString(jsonEncode({
      'state': 'paused',
      'note': 'connection',
      'bytes': 400,
      'total': 1200,
      'updatedAt': time.add(const Duration(seconds: 5)).millisecondsSinceEpoch,
    }));
    active = [
      {'id': entry.id, 'bytes': 400}
    ];
    await service.refreshStatus();
    expect(entry.state, RecState.queued);
    expect(entry.note, 'connection');

    await status.writeAsString(jsonEncode({
      'state': 'done',
      'bytes': 1200,
      'total': 1200,
      'updatedAt': time.add(const Duration(seconds: 9)).millisecondsSinceEpoch,
    }));
    active = [];
    await service.refreshStatus();
    expect(entry.complete, isTrue);
    // Finished: no longer handed to the scheduler.
    await service.updateSettings(service.settings);
    expect(lastSchedule(), isEmpty);
  });

  test('network folder: paths, status beside the app, cap only on device',
      () async {
    const config = NetworkFolderConfig(
        host: '192.168.1.20', share: 'Media', folder: 'VesperTV');
    expect(config.base, 'smb://192.168.1.20/Media/VesperTV');
    expect(config.display, r'\\192.168.1.20\Media\VesperTV');
    await service.updateSettings(
        service.settings.copyWith(network: config, folder: config.base));
    expect(calls.where((c) => c.method == 'networkFolder').single.arguments,
        {'config': jsonEncode(config.toJson())});
    final vols = await service.volumes();
    expect(vols.last.network, isTrue);
    expect((await service.currentVolume())!.network, isTrue);

    final [entry] = await service.download([movie]);
    expect(entry.path, startsWith('smb://192.168.1.20/Media/VesperTV/'));
    expect(entry.onNetwork, isTrue);
    expect(service.statusPathOf(entry),
        '${directory.path}/recording_status/${entry.id}.status');
    entry
      ..bytes = 30 << 30
      ..state = RecState.done;
    // The device's space cap doesn't count the NAS.
    expect(service.usedBytes, 0);
    final item = lastSchedule().single;
    expect(item.containsKey('maxBytes'), isFalse);

    await service.updateSettings(
        service.settings.copyWith(clearNetwork: true, clearFolder: true));
    expect(calls.where((c) => c.method == 'networkFolder').last.arguments,
        {'config': null});
  });

  test('a network recording carries a device fallback', () async {
    // recordChannel times itself with the real clock.
    time = DateTime.now();
    const config = NetworkFolderConfig(host: 'nas', share: 'TV');
    await service.updateSettings(
        service.settings.copyWith(network: config, folder: config.base));
    final channel = Channel(
        id: 'p1::espn',
        rawId: 'espn',
        playlistId: 'p1',
        name: 'ESPN',
        group: 'Sports',
        url: 'http://provider.example/live/u/p/1.ts');
    final entry = await service.recordChannel(channel);
    expect(entry.path, startsWith('smb://nas/TV/'));
    final item = lastSchedule().single;
    expect(item['fallbackPath'],
        '${directory.path}/Recordings/${entry.path.split('/').last}');
    expect(item['account'], 'p1');
  });

  test('recordings play a network file through the local server', () async {
    final channel = Channel(
        id: 'rec_x',
        rawId: 'rec_x',
        playlistId: '',
        name: 'Movie',
        group: '',
        url: 'smb://nas/TV/movie.mkv');
    await service.playbackUrl(channel);
    expect(calls.last.method, 'playUrl');
    expect(calls.last.arguments, {'path': 'smb://nas/TV/movie.mkv'});
    final local = Channel(
        id: 'rec_y',
        rawId: 'rec_y',
        playlistId: '',
        name: 'Movie',
        group: '',
        url: '/data/movie.mkv');
    expect(await service.playbackUrl(local), isNull);
  });

  test('what plays reaches the downloads (only when it changes)', () async {
    service.playerChanged(playing: true, account: 'p1');
    service.playerChanged(playing: true, account: 'p1');
    service.multiviewChanged(['p1', 'p2']);
    await Future<void>.delayed(Duration.zero);
    final policies = calls.where((c) => c.method == 'policy').toList();
    expect(policies.length, 2);
    expect(policies.last.arguments['streams'], {'p1': 2, 'p2': 1});
    expect(policies.last.arguments['speed'], 'watch');
  });

  test('address field, next start, file extension, native states', () {
    expect(NetworkFolderConfig.parseAddress(r'\\nas\Media\Films'),
        (host: 'nas', share: 'Media', folder: 'Films'));
    expect(NetworkFolderConfig.parseAddress('smb://10.0.0.5/TV'),
        (host: '10.0.0.5', share: 'TV', folder: ''));
    expect(NetworkFolderConfig.parseAddress('nas.local'),
        (host: 'nas.local', share: '', folder: ''));
    expect(NetworkFolderConfig.parseAddress('  '), isNull);

    final evening = DateTime(2026, 11, 9, 21, 0);
    expect(
        RecordingService.nextStart(120, evening), DateTime(2026, 11, 10, 2, 0));
    expect(RecordingService.nextStart(23 * 60, evening),
        DateTime(2026, 11, 9, 23, 0));

    expect(movie.extension, 'mkv');
    expect(
        const DownloadItem(
                sourceId: 'a', title: 'a', url: 'http://x/stream?id=1')
            .extension,
        'mkv');
    expect(
        const DownloadItem(sourceId: 'a', title: 'a', url: 'http://x/a.MP4')
            .extension,
        'mp4');

    expect(RecState.fromNative('downloading'), RecState.recording);
    expect(RecState.fromNative('paused'), RecState.queued);
    expect(RecState.fromNative('queued'), RecState.queued);
  });

  test('download entries survive a restart', () async {
    final [entry] = await service.download([movie]);
    entry
      ..totalBytes = 5000
      ..note = 'queue';
    final copy = RecordingEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>);
    expect(copy.isDownload, isTrue);
    expect(copy.poster, movie.poster);
    expect(copy.durationSec, 7200);
    expect(copy.totalBytes, 5000);
    expect(copy.headers, {'User-Agent': 'Test'});
    expect(copy.maxConnections, 1);
    expect(copy.note, 'queue');
    expect(copy.channelId, movie.sourceId);
    // An older recording without these fields still reads.
    final old = RecordingEntry.fromJson({'id': 'r1', 'path': '/x.ts'});
    expect(old.isDownload, isFalse);
    expect(old.headers, isEmpty);
  });
}
