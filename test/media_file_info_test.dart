import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/media_file_info.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_size.dart';
import 'package:nox_iptv/widgets/media_file_info_overlay.dart';

void main() {
  const provider = ArchiveSource(
      manifestUrl: 'https://example.com/manifest.json',
      name: 'Selected add-on');
  test('selected provider metadata uses structured size then labelled size',
      () {
    final info = archiveMediaFileInfo(const ArchiveStreamOption(
        source: provider,
        stream: ArchiveStream(
            url: 'https://example.com/file',
            name: ' TB+\n4K ',
            title: '7 GB',
            sizeBytes: 3200000000)));
    expect(info.source, 'TB+ 4K');
    expect(info.formattedSize, '3.2 GB');
    final privateLabel = archiveMediaFileInfo(const ArchiveStreamOption(
        source: provider,
        stream: ArchiveStream(
            name: 'TB+ https://example.com/private?token=dummy')));
    expect(privateLabel.source, 'TB+');
    final labelled = archiveMediaFileInfo(const ArchiveStreamOption(
        source: provider, stream: ArchiveStream(title: 'Movie file 2,5 GB')));
    expect(labelled.source, 'Selected add-on');
    expect(labelled.formattedSize, '2.5 GB');
    expect(
        archiveMediaFileInfo(const ArchiveStreamOption(
                source: provider, stream: ArchiveStream()))
            .formattedSize,
        isNull);
  });

  test(
      'redirect copies preserve file info without adding it to saved channel JSON',
      () {
    const info = MediaFileInfo(source: 'TB+', sizeBytes: 3200000000);
    final original = Channel(
        id: 'arc::one',
        rawId: 'arc_vod_one',
        playlistId: 'arc',
        name: 'Movie',
        group: '',
        url: 'https://example.com/old',
        mediaFileInfo: info);
    final fresh = original.copyWith(url: 'https://example.com/fresh');
    expect(fresh.mediaFileInfo, same(info));
    expect(fresh.toJson().containsKey('mediaFileInfo'), isFalse);
    expect(fresh.toJson().values, isNot(contains(info)));
  });

  testWidgets('cue auto-hides, restarts its timeout and keeps focus',
      (tester) async {
    final requests = ValueNotifier<int>(0);
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Focus(
                autofocus: true,
                focusNode: focus,
                child: Stack(children: [
                  MediaFileInfoOverlay(
                      info: const MediaFileInfo(
                          source: 'TB+', sizeBytes: 3200000000),
                      requests: requests)
                ])))));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
    requests.value++;
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Source: TB+'), findsOneWidget);
    expect(find.text('File size: 3.2 GB'), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.pump(const Duration(seconds: 4));
    requests.value++;
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
    await tester.pumpWidget(const SizedBox.shrink());
    requests.dispose();
    focus.dispose();
  });

  testWidgets(
      'next file hides stale info and unknown sizes fit a phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = ValueNotifier<int>(0);
    Future<void> show(MediaFileInfo info) => tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 640), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: Stack(children: [
              MediaFileInfoOverlay(info: info, requests: requests)
            ])))));
    await show(const MediaFileInfo(source: 'TB+', sizeBytes: 3200000000));
    requests.value++;
    await tester.pump();
    await show(const MediaFileInfo(
        source: 'Another provider with a long source label'));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0);
    requests.value++;
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('File size unavailable'), findsOneWidget);
    expect(find.text('Source: TB+'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    requests.dispose();
  });
}
