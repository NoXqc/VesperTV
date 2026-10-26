import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_resume_source.dart';
import 'package:nox_iptv/services/archive_stream_size.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/media_file_info_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source =
    ArchiveSource(manifestUrl: 'https://example.com/manifest.json', name: 'TB');
const _id = 'archive::arc_vod_test';
ArchiveStreamOption _file(String url, int gb,
        {String title = 'Movie',
        String filename = 'movie.mkv',
        String? videoHash}) =>
    ArchiveStreamOption(
      source: _source,
      stream: ArchiveStream.fromJson({
        'url': url,
        'name': 'TB+ 4K',
        'title': title,
        'behaviorHints': {
          'filename': filename,
          'videoSize': gb * 1000000000,
          if (videoHash != null) 'videoHash': videoHash
        },
      })!,
    );

void main() {
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.setLastPosition(_id, 120000);
  });

  testWidgets(
      '47 GB choice survives fresh link/description and popup shows that same file',
      (tester) async {
    final resume = ArchiveResumeSource(storage, _id, probe: (url) async => url);
    final old = _file('https://cdn.example/old', 47,
        title: 'Seeds 80', filename: 'movie-remux.mkv');
    await resume.remember(old);
    final smaller =
        _file('https://cdn.example/small', 7, filename: 'movie-small.mkv');
    final fresh = _file('https://cdn.example/fresh', 47,
        title: 'Seeds 92', filename: 'movie-remux.mkv');
    final restored = await resume.restore([smaller, fresh]);
    expect(restored.picked, same(fresh));
    expect(restored.reason, ArchiveResumeReason.fileIdentity);
    final requests = ValueNotifier<int>(0);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Stack(children: [
      MediaFileInfoOverlay(
          info: archiveMediaFileInfo(restored.picked!), requests: requests),
    ]))));
    requests.value++;
    await tester.pump();
    expect(find.text('File size: 47.0 GB'), findsOneWidget);
    expect(find.text('File size: 7.0 GB'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    requests.dispose();
    final saved = storage.getArchiveResumeSource(_id)!;
    expect(saved, isNot(contains('movie-remux.mkv')));
    expect(saved, isNot(contains('https://')));
  });

  test(
      'known size conflict cannot resume a smaller file using the same URL/name',
      () async {
    final resume = ArchiveResumeSource(storage, _id, probe: (url) async => url);
    await resume.remember(_file('https://cdn.example/same', 47));
    final wrong = _file('https://cdn.example/same', 7);
    final result = await resume.restore([wrong]);
    expect(result.picked, isNull);
    expect(result.reason, ArchiveResumeReason.unmatched);
  });

  test('rounded display sizes do not invalidate an unchanged file URL',
      () async {
    final resume = ArchiveResumeSource(storage, _id, probe: (url) async => url);
    const old = ArchiveStreamOption(
        source: _source,
        stream: ArchiveStream(
            url: 'https://cdn.example/same',
            fileName: 'movie.mkv',
            sizeBytes: 46999123456));
    const refreshed = ArchiveStreamOption(
        source: _source,
        stream: ArchiveStream(
            url: 'https://cdn.example/same',
            fileName: 'movie.mkv',
            title: '47 GB'));
    await resume.remember(old);
    expect((await resume.restore([refreshed])).picked, same(refreshed));
  });

  test(
      'video hash identifies a renamed file, but duplicate identities remain ambiguous',
      () async {
    final resume = ArchiveResumeSource(storage, _id, probe: (url) async => url);
    await resume.remember(_file('https://cdn.example/old', 47,
        title: 'Old', videoHash: 'AB1234'));
    final renamed = _file('https://cdn.example/new', 47,
        title: 'New', filename: 'renamed.mkv', videoHash: 'ab1234');
    expect((await resume.restore([renamed])).picked, same(renamed));
    final duplicate = _file('https://cdn.example/duplicate', 47,
        title: 'Another', videoHash: 'ab1234');
    expect((await resume.restore([renamed, duplicate])).picked, isNull);
  });

  test(
      'largest-file preference and popup both recognize sizes in the source name',
      () {
    const large = ArchiveStreamOption(
        source: _source,
        stream: ArchiveStream(
            url: 'https://cdn.example/large', name: 'TB+ 4K 47 GB'));
    const small = ArchiveStreamOption(
        source: _source,
        stream: ArchiveStream(url: 'https://cdn.example/small', title: '7 GB'));
    expect(largestArchiveStream([small, large]), same(large));
    expect(archiveMediaFileInfo(large).formattedSize, '47.0 GB');
  });

  test(
      'structured bytes remain authoritative but conflicting text can be diagnosed',
      () {
    final stream = _file('https://cdn.example/file', 7, title: '47 GB');
    expect(archiveStreamBytes(stream), 7000000000);
    expect(archiveStreamLabelBytes(stream), 47000000000);
    final roundTrip = ArchiveStream.fromJson(stream.stream.toJson())!;
    expect(roundTrip.fileName, stream.stream.fileName);
    expect(roundTrip.sizeBytes, stream.stream.sizeBytes);
  });
}
