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
  test('largest file skips whole-season packs (LOG-7QUQAW)', () {
    ArchiveStreamOption file(String name, int bytes, {bool hint = true}) =>
        ArchiveStreamOption(
            source: source,
            stream: ArchiveStream(
                url: 'https://example.com/$bytes',
                fileName: hint ? name : null,
                title: hint ? null : name,
                sizeBytes: bytes));
    bool pack(String name, {bool hint = true}) =>
        archiveStreamIsSeasonPack(file(name, 1, hint: hint));

    // Real AIOStreams file names for Dark Matter S2E7.
    for (final name in [
      'Dark Matter 2024 S02 1080p ATVP WEB DL DDP5 1 Atmos H 264-Kitsune',
      'Dark.Matter.2026.S02E01-E09.2160p.ATVP.WEB-DL.HDR.H265.Master5',
      'Dark.Matter.S01E07-09.2160p.ATVP.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-G66',
      'Dark.Matter.S01.COMPLETE.2160p.ATVP.WEB-DL.DV.HDR10.PLUS.Atmos.H265',
      'Dark Matter Season 2 2160p REMUX',
    ]) {
      expect(pack(name), isTrue, reason: name);
    }
    for (final name in [
      'Dark.Matter.S02E07.WEBDL.1080p.2xUkr.Eng.mkv',
      'Dark.Matter.2024.2x07.La.Piramide.ITA.ENG.1080p.ATVP.WEBRip.AAC.x265-Pir8.mkv',
      'Dark.Matter.S02.Dub.EP-7.mp4',
      'Materia oscura [4k 2160p][Cap.207].mkv',
      'dark.matter.2024.s02e07.dv.2160p.web.h265-cakes.mkv',
      'Interstellar.2014.2160p.UHD.BluRay.REMUX.HDR.HEVC.Atmos-EPSiLON.mkv',
      'Movie.2023.1080p.WEB-DL.DDP5.1.H.264-FLUX.mkv',
    ]) {
      expect(pack(name), isFalse, reason: name);
    }
    // Without a file name the label is read; a folder/file line naming the
    // episode keeps it a single file.
    expect(
        pack(
            '[TB⚡] 2160p 📁 Dark.Matter.S02E01-E09.1080p/'
            'Dark.Matter.S02E07.1080p.mkv',
            hint: false),
        isFalse);

    final season = file('Dark Matter 2024 S02 2160p REMUX', 111439505299);
    final episode = file('Dark.Matter.S02E07.2160p.mkv', 12147002240);
    final smaller = file('Dark.Matter.S02E07.1080p.mkv', 5480000000);
    expect(largestArchiveStream([season, smaller, episode]), same(episode));
    // Only packs have a size: the biggest of them, as before.
    expect(largestArchiveStream([season, option('https://example.com/x')]),
        same(season));
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
