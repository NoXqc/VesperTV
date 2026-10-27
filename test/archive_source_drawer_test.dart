import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/archive_playback_sources.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/widgets/archive_source_drawer.dart';
import 'package:nox_iptv/widgets/gold_tag.dart';

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
    await tester.pumpAndSettle();
    expect(find.byType(GoldTag), findsOneWidget);
    expect(find.text('Current stream'), findsOneWidget);
    final currentRow = tester
        .widgetList<Container>(find.ancestor(
            of: find.byType(GoldTag), matching: find.byType(Container)))
        .firstWhere((w) =>
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(12));
    final border = (currentRow.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, Colors.amber);
    expect(border.top.width, 1.2);
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
  ArchiveStreamOption file(String url,
          {String? hash,
          String? filename,
          int bytes = 39700000000,
          String title = 'Movie 39.7 GB',
          ArchiveSource source = _source}) =>
      ArchiveStreamOption(
          source: source,
          stream: ArchiveStream(
              url: url,
              name: '4K WEB-DL',
              title: title,
              sizeBytes: bytes,
              fileName: filename,
              videoHash: hash));

  test(
      'current source matches a unique stable hash after URL/description refresh',
      () {
    final playing =
        file('https://example.com/old', hash: 'AbCd', title: 'Old seed count');
    final refreshed = file('https://example.com/fresh',
        hash: 'abcd', title: 'New seed count');
    final other = file('https://example.com/other', hash: 'different');
    expect(archiveCurrentStreamIndex([other, refreshed], playing), 1);
  });
  test('current source matches a unique stable filename after URL refresh', () {
    final playing = file('https://example.com/old', filename: 'movie.mkv');
    final refreshed = file('https://example.com/fresh',
        filename: 'movie.mkv', title: 'Fresh labels');
    expect(archiveCurrentStreamIndex([refreshed], playing), 0);
  });
  test('current source never crosses providers or known file/size conflicts',
      () {
    final playing =
        file('https://example.com/same', filename: 'large.mkv', hash: 'a');
    const otherSource = ArchiveSource(
        manifestUrl: 'https://other.example/manifest.json', name: 'Other');
    for (final candidate in [
      file('https://example.com/same', source: otherSource),
      file('https://example.com/same', bytes: 7000000000),
      file('https://example.com/same', hash: 'b'),
      file('https://example.com/same', filename: 'different.mkv'),
    ]) {
      expect(archiveCurrentStreamIndex([candidate], playing), -1);
    }
  });
  test(
      'duplicate labels and ambiguous stable identities never guess a current source',
      () {
    final first = file('https://example.com/one');
    final second = file('https://example.com/two');
    expect(
        archiveCurrentStreamIndex(
            [first, second], file('https://example.com/old')),
        -1);
    expect(archiveCurrentStreamIndex([first], null), -1);
    expect(
        archiveCurrentStreamIndex([
          file('https://example.com/one', hash: 'a'),
          file('https://example.com/two', hash: 'a')
        ], file('https://example.com/old', hash: 'a')),
        -1);
  });

  testWidgets(
      'an unmatched playing source stays visible with exactly one Current tag',
      (tester) async {
    final playing = file('https://example.com/old');
    final first = file('https://example.com/fresh-one');
    final second = file('https://example.com/fresh-two');
    ArchiveStreamOption? chosen;
    final sources = ArchivePlaybackSources(
        load: (_) async => [first, second],
        current: (_) => playing,
        select: (id, option) async {
          chosen = option;
          return Channel(
              id: id,
              rawId: id,
              playlistId: '',
              name: 'Movie',
              group: '',
              url: option.stream.url);
        },
        remember: (_, __) async {});
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showArchiveSourceDrawer(context,
                        sources: sources, channelId: 'movie'),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(GoldTag), findsOneWidget);
    expect(find.text('Current stream'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chosen, isNull); // Current closes the drawer without restarting.
    expect(find.text('Stream sources'), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(GoldTag), findsOneWidget);
    // The retained current row is first; moving down selects the first fresh
    // option, never confuses it with the currently playing source.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.byType(GoldTag), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chosen, same(first));
    expect(tester.takeException(), isNull);
  });
}
