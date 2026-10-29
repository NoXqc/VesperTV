import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_session.dart';
import 'package:nox_iptv/services/archive_playback_preferences.dart';
import 'package:nox_iptv/services/addon_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/stream_resolver.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:nox_iptv/utils/constants.dart';

class _RealHttp extends HttpOverrides {}

const _meta =
    ArchiveMeta(id: 'tt123', type: ArchiveType.movie, name: 'A movie');
ArchiveSource _source(int i) => ArchiveSource(
        manifestUrl: 'https://source$i.example/manifest.json',
        name: 'Source $i',
        searchCatalogsChecked: true,
        imdbResources: const {
          'stream': ['movie', 'series']
        },
        catalogs: const [
          ArchiveCatalog(type: ArchiveType.movie, id: 'movies', name: 'Movies')
        ]);
Future<StorageService> _storage(List<ArchiveSource> sources) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([for (final source in sources) source.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'retry joins the existing request queue instead of exceeding its connection budget',
      () async {
    final sources = List.generate(5, _source),
        gates = List.generate(5, (_) => Completer<void>());
    final started = List.generate(5, (_) => Completer<void>());
    final retryStarted = Completer<void>();
    final storage = await _storage(sources);
    var attempts = 0, active = 0, peak = 0;
    final api = ArchiveApiService(client: MockClient((r) async {
      final i =
          int.parse(RegExp(r'source(\d)').firstMatch(r.url.host)!.group(1)!);
      if (i == 0 && attempts++ == 0) return http.Response('unavailable', 503);
      active++;
      if (active > peak) peak = active;
      if (i == 0) {
        retryStarted.complete();
      } else {
        started[i].complete();
      }
      await gates[i].future;
      active--;
      return http.Response(
          jsonEncode({
            'streams': [
              {'url': 'https://media.example/$i'}
            ]
          }),
          200);
    }));
    final hub = ArchiveService(storage, api: api);
    final session = hub.searchStreams(sources.first, _meta);
    await started[3].future;
    final retry = session.retrySource!(sources.first.key);
    expect(active, 3);
    gates[1].complete();
    await started[4].future;
    gates[2].complete();
    await retryStarted.future;
    expect(peak, 3);
    for (final i in [0, 3, 4]) {
      gates[i].complete();
    }
    await retry;
    await session.done;
    expect(session.options, hasLength(5));
    hub.dispose();
    api.close();
  });
  test('fast source is usable before a slow source; at most three requests run',
      () async {
    final sources = List.generate(4, _source);
    final storage = await _storage(sources);
    final replies = List.generate(4, (_) => Completer<http.Response>());
    final started = List.generate(4, (_) => Completer<void>());
    var active = 0, peak = 0;
    final api = ArchiveApiService(client: MockClient((r) async {
      final i =
          int.parse(RegExp(r'source(\d)').firstMatch(r.url.host)!.group(1)!);
      active++;
      if (active > peak) peak = active;
      started[i].complete();
      final reply = await replies[i].future;
      active--;
      return reply;
    }));
    final hub = ArchiveService(storage, api: api);
    final session = hub.searchStreams(sources.first, _meta);
    await started[2].future;
    expect(started[3].isCompleted, false);
    final usable = Completer<void>();
    session.addListener(() {
      if (session.options.isNotEmpty && !usable.isCompleted) usable.complete();
    });
    replies[1].complete(http.Response(
        jsonEncode({
          'streams': [
            {'url': 'https://media.example/fast.mp4'}
          ]
        }),
        200));
    await usable.future;
    expect(session.options.single.source.name, 'Source 1');
    expect(session.statuses[sources[0].key], ArchiveSourceStatus.loading);
    await started[3].future;
    replies[0].complete(http.Response(
        jsonEncode({
          'streams': [
            {'url': 'https://media.example/slow.mp4'}
          ]
        }),
        200));
    replies[2].complete(http.Response('unavailable', 503));
    replies[3].complete(http.Response('{"streams":[]}', 200));
    await session.done;
    expect(peak, 3);
    expect(session.options.map((o) => o.source.name), ['Source 0', 'Source 1']);
    expect(session.statuses[sources[2].key], ArchiveSourceStatus.failed);
    expect(identical(hub.searchStreams(sources.first, _meta), session), true);
    await storage.setActiveViewerId('another-viewer');
    expect(session.active, false);
    expect(session.options, isEmpty);
    hub.dispose();
    api.close();
  });

  test('all subtitles and safe headers survive parsing and reach playback data',
      () async {
    final storage = await _storage([_source(0)]);
    final hub = ArchiveService(storage);
    final stream = ArchiveStream.fromJson({
      'url': 'https://media.example/file.mkv',
      'behaviorHints': {
        'bingeGroup': 'release-1080',
        'proxyHeaders': {
          'request': {
            'Authorization': 'fixture',
            'User-Agent': 'Vesper test',
            'Host': 'evil',
            'Bad': 'a\r\nb'
          }
        }
      },
      'subtitles': [
        {'url': 'https://subs.example/en.srt', 'lang': 'eng'},
        {'url': 'https://subs.example/fr.srt', 'lang': 'fra'}
      ]
    })!;
    final roundtrip = ArchiveStream.fromJson(stream.toJson())!;
    expect(roundtrip.bingeGroup, 'release-1080');
    expect(roundtrip.requestHeaders,
        {'Authorization': 'fixture', 'User-Agent': 'Vesper test'});
    final channel = hub.channelFor(_source(0), _meta, roundtrip);
    expect(channel.httpHeaders['Authorization'], 'fixture');
    final subtitles = await AddonService(storage).search(channel);
    expect(subtitles.map((s) => s.lang), ['eng', 'fra']);
    expect((await SubtitleTracks.preferredOnline(storage, channel, 'fr'))!.lang,
        'fra');
    expect(channel.toJson().containsKey('httpHeaders'), false);
    hub.dispose();
  });

  test(
      'redirects retain same-origin headers and drop credentials across origins',
      () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => first.close(force: true));
    addTearDown(() => second.close(force: true));
    final received = <String, String?>{};
    first.listen((r) async {
      received['initial'] = r.headers.value('authorization');
      r.response.statusCode = 302;
      r.response.headers
          .set('location', 'http://127.0.0.1:${second.port}/file');
      await r.response.close();
    });
    second.listen((r) async {
      received['final'] = r.headers.value('authorization');
      received['agent'] = r.headers.value('user-agent');
      r.response.statusCode = 206;
      r.response.headers.set('content-range', 'bytes 0-0/100');
      r.response.add([0]);
      await r.response.close();
    });
    final link = await HttpOverrides.runWithHttpOverrides(
        () => resolveLink('http://127.0.0.1:${first.port}/start',
            headers: {'Authorization': 'fixture', 'User-Agent': 'Vesper test'}),
        _RealHttp());
    expect(received,
        {'initial': 'fixture', 'final': null, 'agent': 'Vesper test'});
    expect(link.headers, {'User-Agent': 'Vesper test'});
    expect(link.totalBytes, 100);
  });

  test(
      'preferences do not auto-select an unknown language or unsuitable format',
      () {
    ArchiveStreamOption option(String label) => ArchiveStreamOption(
        source: _source(0),
        stream:
            ArchiveStream(url: 'https://media.example/$label', name: label));
    final options = [
      option('4K HDR English'),
      option('1080p French'),
      option('1080p English'),
      option('720p')
    ];
    const prefs = ArchivePlaybackPreferences(
        autoPlay: true, language: 'en', maxHeight: 1080, avoidHdr: true);
    expect(prefs.ranked(options).map((o) => o.stream.name), ['1080p English']);
  });
}
