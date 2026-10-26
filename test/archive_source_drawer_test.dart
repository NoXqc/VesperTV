import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/archive_playback_sources.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/widgets/archive_source_drawer.dart';

const _source = ArchiveSource(
    manifestUrl: 'https://example.com/manifest.json', name: 'Torrentio');
const _first = ArchiveStreamOption(
    source: _source,
    stream: ArchiveStream(
        url: 'https://example.com/one',
        name: '[TB+] Torrentio 4K',
        title: 'Movie.2160p.DV.HDR10+.HEVC https://example.com/?secret=hidden',
        sizeBytes: 26300000000));
const _second = ArchiveStreamOption(
    source: _source,
    stream: ArchiveStream(
        url: 'https://example.com/two', name: 'Other 1080p', title: 'x264'));

void main() {
  test('format labels use advertised metadata and never a signed URL', () {
    expect(
        archiveStreamFormats(_first), ['4K', 'Dolby Vision', 'HDR10+', 'HEVC']);
    expect(archiveStreamFormats(_second), ['1080p', 'H.264']);
    expect(
        archiveStreamFormats(const ArchiveStreamOption(
            source: _source,
            stream: ArchiveStream(url: 'https://example.com/4k-hdr-hevc'))),
        isEmpty);
    expect(archiveStreamLabel(_first.stream.title!), isNot(contains('hidden')));
  });

  testWidgets(
      'drawer shows sizes/formats and selects using D-pad without seeking',
      (tester) async {
    ArchiveSourceSelection? result;
    String? requestedId;
    var selections = 0;
    final sources = ArchivePlaybackSources(
      load: (id) async {
        requestedId = id;
        return [_first, _second];
      },
      current: (_) => _first,
      select: (id, option) async {
        selections++;
        return Channel(
            id: id,
            rawId: id,
            playlistId: '',
            name: 'Movie',
            url: option.stream.url,
            group: '');
      },
      remember: (_, __) async {},
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showArchiveSourceDrawer(context,
                          sources: sources, channelId: 'episode-2');
                    },
                    child: const Text('Open')),
              )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(requestedId, 'episode-2');
    expect(find.text('Current stream'), findsOneWidget);
    expect(find.text('File size: 26.3 GB'), findsOneWidget);
    expect(find.text('Size unknown'), findsOneWidget);
    expect(find.text('4K · Dolby Vision · HDR10+ · HEVC'), findsOneWidget);
    expect(find.textContaining('secret=hidden'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, 1);
    expect(result?.option, same(_second));
    expect(result?.channel.id, 'episode-2');
  });

  testWidgets('Left closes while a lookup is pending without choosing a source',
      (tester) async {
    final pending = Completer<List<ArchiveStreamOption>>();
    var selections = 0;
    final sources = ArchivePlaybackSources(
      load: (_) => pending.future,
      current: (_) => null,
      select: (_, __) async {
        selections++;
        return null;
      },
      remember: (_, __) async {},
    );
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showArchiveSourceDrawer(context,
                        sources: sources, channelId: 'movie'),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    pending.complete([_first]);
    await tester.pump();
    expect(find.text('Stream sources'), findsNothing);
    expect(selections, 0);
    expect(tester.takeException(), isNull);
  });
}
