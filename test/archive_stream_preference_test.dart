import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_size.dart';
import 'package:nox_iptv/services/archive_resume_source.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const source = ArchiveSource(
    manifestUrl: 'https://example.com/manifest.json', name: 'Example');
ArchiveStreamOption option(String url, {String? title, int? bytes}) =>
    ArchiveStreamOption(
        source: source,
        stream: ArchiveStream(url: url, title: title, sizeBytes: bytes));

void main() {
  test(
      'largest selection handles bytes, decimal labels, binary units and unknown sizes',
      () {
    final a = option('https://example.com/a', title: 'File 4.5 GB');
    final b = option('https://example.com/b', title: 'File 4,5 GiB');
    final c = option('https://example.com/c', bytes: 6000000000);
    expect(largestArchiveStream([a, b, c]), same(c));
    expect(largestArchiveStream([a, b]), same(b));
    expect(
        largestArchiveStream([option('https://example.com/unknown')]), isNull);
    expect(archiveStreamBytes(option('https://example.com/d', title: '900 MB')),
        900000000);
    final parsed = ArchiveStream.fromJson({
      'url': 'https://example.com/e',
      'behaviorHints': {'videoSize': 7000000000}
    })!;
    expect(parsed.sizeBytes, 7000000000);
    expect(
        ArchiveStream.fromJson(parsed.toJson())!.sizeBytes, parsed.sizeBytes);
    expect(
        ArchiveStream.fromJson({
          'url': 'https://example.com/e',
          'behaviorHints': {'videoSize': 'invalid'}
        })!
            .sizeBytes,
        isNull);
  });
  test(
      'episodes retain independent provider choices and auto-play preferences are per viewer',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final one = ArchiveService.channelId(source, 'tt123:1:1', episode: true);
    final two = ArchiveService.channelId(source, 'tt123:1:2', episode: true);
    final a = option('https://example.com/a', title: 'File A');
    final b = option('https://example.com/b', title: 'File B');
    await storage.setLastPosition(one, 1000);
    await storage.setLastPosition(two, 2000);
    final first = ArchiveResumeSource(storage, one, probe: (url) async => url);
    final second = ArchiveResumeSource(storage, two, probe: (url) async => url);
    await first.remember(a);
    await second.remember(b);
    expect((await first.restore([b, a])).picked, same(a));
    expect((await second.restore([a, b])).picked, same(b));
    await storage.setArchiveAutoLargest(true);
    await storage.setSportsPreferQuality(false);
    await storage.setActiveViewerId('viewer_other');
    expect(storage.getArchiveAutoLargest(), isFalse);
    expect(storage.getSportsPreferQuality(), isTrue);
    expect((await first.restore([a, b])).picked, isNull);
  });

  test(
      'TV episode resume matches a fresh selected-source link and falls back if unavailable',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = ArchiveService(storage);
    addTearDown(service.dispose);
    const show =
        ArchiveMeta(id: 'tt123', type: ArchiveType.series, name: 'Show');
    const episode =
        ArchiveVideo(id: 'tt123:2:3', title: 'Episode', season: 2, episode: 3);
    final id = service
        .channelFor(source, show, const ArchiveStream(), episode: episode)
        .id;
    expect(id, ArchiveService.channelId(source, episode.id, episode: true));
    await storage.setLastPosition(id, 180000);
    final old = option('https://cdn.example.com/file?signature=old',
        title: 'Selected episode file');
    final fresh = option('https://cdn.example.com/file?signature=new',
        title: 'Selected episode file');
    final other = option('https://cdn.example.com/alternative',
        title: 'Different episode file');
    final resume = ArchiveResumeSource(storage, id, probe: (url) async => url);
    await resume.remember(old);
    expect((await resume.restore([other, fresh])).picked, same(fresh));
    final unavailable =
        ArchiveResumeSource(storage, id, probe: (_) async => null);
    final fallback = await unavailable.restore([other, fresh]);
    expect(fallback.picked, isNull);
    expect(fallback.options, [other]);
    expect(storage.getLastPosition(id), 180000);
  });
}
