import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_resume_source.dart';
import 'package:nox_iptv/services/storage_service.dart';

const debrid = ArchiveSource(
    manifestUrl: 'https://addon.example/private/manifest.json', name: 'Debrid');
const torbox = ArchiveSource(
    manifestUrl: 'https://torbox.example/manifest.json', name: 'TorBox');
const movieId = 'archive::arc_vod_provider_tt123';
ArchiveStreamOption option(ArchiveSource source, String url,
        {String? name = '4K', String? title = 'movie.mkv'}) =>
    ArchiveStreamOption(
        source: source,
        stream: ArchiveStream(url: url, name: name, title: title));

void main() {
  late StorageService storage;
  late ArchiveResumeSource resume;
  late List<String> probes;
  late ArchiveStreamOption picked;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.setLastPosition(movieId, 120000);
    probes = [];
    resume = ArchiveResumeSource(storage, movieId, probe: (url) async {
      probes.add(url);
      return '$url/resolved';
    });
    picked = option(torbox, 'https://stream.example/movie?token=old');
    await resume.remember(picked);
  });

  test(
      'restart restores exact choice after options reorder, not the first source',
      () async {
    final other = option(debrid, 'https://other.example/movie');
    final reopened =
        ArchiveResumeSource(storage, movieId, probe: (url) async => url);
    final result = await reopened.restore([other, picked]);
    expect(result.picked, same(picked));
    expect(result.url, picked.stream.url);
  });
  test('fresh signed URL matches same provider and full file description',
      () async {
    final fresh = option(torbox, 'https://cdn.example/movie?token=new');
    final result =
        await resume.restore([option(debrid, 'https://other/movie'), fresh]);
    expect(result.picked, same(fresh));
    expect(probes, [fresh.stream.url]);
    expect(result.url, '${fresh.stream.url}/resolved');
  });
  test('same quality with a different file does not silently replace selection',
      () async {
    final different =
        option(torbox, 'https://cdn/other', title: 'different-cut.mkv');
    expect((await resume.restore([different])).picked, isNull);
    expect(probes, isEmpty);
  });
  test('ambiguous descriptions fall back to picker', () async {
    final result = await resume.restore(
        [option(torbox, 'https://cdn/a'), option(torbox, 'https://cdn/b')]);
    expect(result.picked, isNull);
    expect(result.options, hasLength(2));
    expect(probes, isEmpty);
  });
  test('missing provider falls back without reusing stale URL', () async {
    final alternative = option(debrid, 'https://cdn/alternative');
    final result = await resume.restore([alternative]);
    expect(result.picked, isNull);
    expect(result.options, [alternative]);
    expect(probes, isEmpty);
  });
  test('unavailable selected stream is excluded from fallback choices',
      () async {
    resume = ArchiveResumeSource(storage, movieId, probe: (_) async => null);
    final alternative = option(debrid, 'https://cdn/alternative');
    final result = await resume.restore([picked, alternative]);
    expect(result.picked, isNull);
    expect(result.options, [alternative]);
    expect((await resume.restore([picked])).options, isEmpty);
  });
  test('play from beginning and fully watched movies retain normal picker',
      () async {
    await storage.setLastPosition(movieId, 0);
    expect((await resume.restore([picked])).picked, isNull);
    await storage.setLastPosition(movieId, 96000);
    await storage.setLastDuration(movieId, 100000);
    expect((await resume.restore([picked])).picked, isNull);
    expect(probes, isEmpty);
  });
  test('another movie and viewer do not inherit the selection', () async {
    await storage.setLastPosition('another', 1000);
    expect(
        (await ArchiveResumeSource(storage, 'another').restore([picked]))
            .picked,
        isNull);
    await storage.setActiveViewerId('kids');
    await storage.setLastPosition(movieId, 1000);
    expect(
        (await ArchiveResumeSource(storage, movieId).restore([picked])).picked,
        isNull);
    expect(storage.getArchiveResumeSource(movieId), isNull);
  });
  test('late probe cannot resume or save into a different viewer', () async {
    final pending = Completer<String?>();
    resume =
        ArchiveResumeSource(storage, movieId, probe: (_) => pending.future);
    final restoring = resume.restore([picked]);
    await storage.setActiveViewerId('kids');
    pending.complete('https://cdn/movie');
    expect((await restoring).picked, isNull);
    await resume.remember(picked);
    expect(storage.getArchiveResumeSource(movieId), isNull);
  });
  test(
      'stored identifiers contain no signed URL, manifest credentials or names',
      () {
    final raw = storage.getArchiveResumeSource(movieId)!;
    for (final value in ['https', 'private', 'token', 'movie.mkv', 'TorBox']) {
      expect(raw, isNot(contains(value)));
    }
  });
  test('selecting a replacement makes it the source for later resumes',
      () async {
    final replacement =
        option(debrid, 'https://cdn/replacement', title: 'replacement.mkv');
    await resume.remember(replacement);
    expect((await resume.restore([picked, replacement])).picked,
        same(replacement));
  });
  test('corrupt preference falls back safely', () async {
    await storage.setArchiveResumeSource(movieId, '{bad json');
    expect((await resume.restore([picked])).picked, isNull);
    expect(probes, isEmpty);
  });
  test('streams without labels require exact link identity', () async {
    final unlabeled =
        option(torbox, 'https://cdn/no-label', name: null, title: null);
    await resume.remember(unlabeled);
    expect((await resume.restore([unlabeled])).picked, same(unlabeled));
    expect(
        (await resume.restore([
          option(torbox, 'https://cdn/changed', name: null, title: null)
        ]))
            .picked,
        isNull);
  });

  group('fresh stream availability', () {
    late HttpServer server;
    late String base;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) {
        final response = request.response;
        switch (request.uri.path) {
          case '/redirect':
            response.statusCode = 302;
            response.headers.set('location', '/file');
          case '/file':
            expect(request.headers.value('range'), 'bytes=0-0');
            response.statusCode = 206;
            response.add([0]);
          case '/loop':
            response.statusCode = 302;
            response.headers.set('location', '/loop');
          default:
            response.statusCode = 404;
        }
        response.close();
      });
    });
    tearDown(() => server.close(force: true));
    test('follows redirects once and returns playable CDN URL', () async {
      expect(await probeArchiveResumeUrl('$base/redirect'), '$base/file');
    });
    test('HTTP errors and redirect loops mark original unavailable', () async {
      expect(await probeArchiveResumeUrl('$base/missing'), isNull);
      expect(await probeArchiveResumeUrl('$base/loop'), isNull);
      expect(await probeArchiveResumeUrl('file:///movie'), isNull);
    });
  });
}
