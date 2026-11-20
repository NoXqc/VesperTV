import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/settings/stream_badges_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/stream_badges.dart';
import 'package:nox_iptv/widgets/gold_tag.dart';
import 'package:nox_iptv/widgets/stream_badge_row.dart';

// Patterns copied from a real Nuvio pack (eclipsia, gitea.com/eclipsia/nuvio-badge).
const _patterns = {
  '4K': r'(?i)^(?=.*(?:2160[pi]?|4k|uhd))(?!.*(?:1080[pi]?|720[pi]?))',
  'FHD': r'(?i)\b1080[pi]?\b|\bfhd\b|\bfull[ ._-]?hd\b',
  'Remux': '(?i)^(?=(?:[\\s\\S]*)(?:\\b|(?<=hd))remux\\b)'
      '(?![\\s\\S]*(?:5★|4★|3★|2★|1★))',
  'HEVC': r'(?i)\b(?:x?\.?265|hevc|h\.?265)\b',
  'DTS:X': r'(?i)\bdts[-_.: ]?x\b',
  '7.1': r'[^0-9][7-8][. ][01](?![0-9])',
  '5.1': r'^(?=.*[^0-9]5[. ][01](?![0-9]))(?!.*[^0-9][7-8][. ][01](?![0-9]))',
  'PRIME': '(?i)(?:⁠⁢|\\b(?:amzn|amazon(?:\\s*prime)?|prime\\s*video)\\b)',
  'ENG':
      r'(?i)(?<![^\s\[(_\-.,])(english|eng)(?![ .\-_]?sub(title)?s?)(?=[\s\)\]_.\-,]|$)',
};

List<String> _names(String text) {
  final names = _patterns.keys.toList();
  return [
    for (final i in matchStreamBadges(_patterns.values.toList(), [text]).single)
      names[i],
  ];
}

void main() {
  group('parseBadgeColor', () {
    test('reads #AARRGGBB, #RRGGBB and #RGB as ARGB', () {
      expect(parseBadgeColor('#FF858283'), 0xFF858283);
      expect(parseBadgeColor('#80FF0000'), 0x80FF0000);
      expect(parseBadgeColor('#636366'), 0xFF636366);
      expect(parseBadgeColor('#abc'), 0xFFAABBCC);
    });

    test('transparent, missing or unreadable = null', () {
      expect(parseBadgeColor('#00000000'), isNull);
      expect(parseBadgeColor('#00FFFFFF'), isNull);
      expect(parseBadgeColor(null), isNull);
      expect(parseBadgeColor('red'), isNull);
      expect(parseBadgeColor('#12345'), isNull);
    });
  });

  group('streamBadgeRegExp', () {
    test('a leading (?i) becomes case-insensitive matching', () {
      final re = streamBadgeRegExp(r'(?i)\bhevc\b')!;
      expect(re.isCaseSensitive, isFalse);
      expect(re.hasMatch('Movie.2024.HEVC.mkv'), isTrue);
    });

    test('without flags it stays case-sensitive', () {
      final re = streamBadgeRegExp(r'\bHDR\b')!;
      expect(re.hasMatch('hdr'), isFalse);
      expect(re.hasMatch('HDR'), isTrue);
    });

    test('a later (?i) or (?i: still runs, case-insensitive', () {
      expect(streamBadgeRegExp(r'foo|(?i)bar')!.hasMatch('BAR'), isTrue);
      expect(streamBadgeRegExp(r'x(?i:atmos)')!.hasMatch('xATMOS'), isTrue);
    });

    test('Java-only syntax is left out instead of throwing', () {
      expect(streamBadgeRegExp(r'(?x) a b # comment'), isNull);
      expect(streamBadgeRegExp(r'a*+b'), isNull); // possessive
      expect(streamBadgeRegExp('('), isNull);
      expect(streamBadgeRegExp('(?i)'), isNull);
    });

    test('\\p{..} classes run in unicode mode', () {
      expect(streamBadgeRegExp(r'^\p{Lu}+$')!.hasMatch('ÉTÉ'), isTrue);
    });

    test('every sample pack pattern compiles', () {
      for (final p in _patterns.values) {
        expect(streamBadgeRegExp(p), isNotNull, reason: p);
      }
    });
  });

  group('matchStreamBadges', () {
    test('a 4K remux with DTS:X 7.1', () {
      expect(
        _names(
          'Torrentio 4k The.Matrix.1999.2160p.UHD.BluRay.REMUX.DV.HEVC.'
          'DTS-X.7.1-FGT.mkv 💾 62.1 GB',
        ),
        ['4K', 'Remux', 'HEVC', 'DTS:X', '7.1'],
      );
    });

    test('a 1080p Amazon web file in English 5.1', () {
      expect(
        _names('Oppenheimer 2023 1080p AMZN WEB-DL DDP5.1 H.264 ENG'),
        ['FHD', 'PRIME', 'ENG', '5.1']..sort(_order),
      );
    });

    test('a formatter marker character alone matches its badge', () {
      expect(_names('Some stream ⁠⁢'), ['PRIME']);
    });

    test('rated releases (stars) are not plain Remux', () {
      expect(_names('Film 2160p REMUX 5★'), ['4K']);
    });
  });

  test('streamBadgeText puts name, title and file name on one line', () {
    expect(
      streamBadgeText(
        name: 'Torrentio\n4k',
        title: 'Film.mkv\n💾 2 GB',
        fileName: 'Film.mkv',
      ),
      'Torrentio 4k Film.mkv 💾 2 GB',
    );
    expect(
      streamBadgeText(name: 'A', title: null, fileName: 'B.mkv'),
      'A B.mkv',
    );
  });

  group('StreamBadgePack.parse', () {
    String pack(
      List<Map<String, Object?>> filters, [
      List<Map<String, Object?>>? groups,
    ]) =>
        jsonEncode({'groups': groups ?? [], 'filters': filters});

    test('enabled filters in group order, then pack order', () {
      final parsed = StreamBadgePack.parse(
        pack(
          [
            {
              'id': 'a',
              'name': 'Atmos',
              'groupId': 'audio',
              'pattern': 'atmos',
            },
            {'id': 'r', 'name': '4K', 'groupId': 'res', 'pattern': '2160p'},
            {'id': 'h', 'name': 'HDR', 'groupId': 'res', 'pattern': 'HDR'},
            {
              'id': 'x',
              'name': 'Off',
              'groupId': 'res',
              'pattern': 'x',
              'isEnabled': false,
            },
            {'id': 'n', 'name': 'None', 'groupId': 'zzz', 'pattern': 'n'},
          ],
          [
            {'id': 'res', 'name': 'Resolution'},
            {'id': 'audio', 'name': 'Audio'},
          ],
        ),
      );
      expect(parsed.badges.map((b) => b.id), ['r', 'h', 'a', 'n']);
      expect(parsed.groups.map((g) => g.name), ['Resolution', 'Audio']);
      expect(parsed.skipped, 0);
    });

    test('unusable patterns are counted, not fatal', () {
      final parsed = StreamBadgePack.parse(
        pack([
          {'id': 'ok', 'name': 'OK', 'pattern': 'ok'},
          {'id': 'bad', 'name': 'Bad', 'pattern': '('},
          {'id': 'empty', 'name': 'Empty', 'pattern': ''},
        ]),
      );
      expect(parsed.badges.map((b) => b.id), ['ok']);
      expect(parsed.skipped, 2);
    });

    test('colours, picture links and data: pictures', () {
      final parsed = StreamBadgePack.parse(
        pack([
          {
            'id': 'i',
            'name': 'Img',
            'pattern': 'x',
            'imageURL': 'data:image/png;base64,AAEC',
            'tagColor': '#00000000',
            'borderColor': '#636366',
          },
          {
            'id': 'n',
            'name': 'Net',
            'pattern': 'x',
            'imageURL': 'https://a.b/c.png',
          },
          {'id': 't', 'name': 'Text', 'pattern': 'x', 'textColor': '#FF00FF00'},
        ]),
      );
      final img = parsed.badges[0];
      expect(img.imageBytes, [0, 1, 2]);
      expect(identical(img.imageBytes, img.imageBytes), isTrue);
      expect(img.tagColor, isNull);
      expect(img.borderColor, 0xFF636366);
      expect(parsed.badges[1].networkImage, 'https://a.b/c.png');
      expect(parsed.badges[1].imageBytes, isNull);
      expect(parsed.badges[2].imageUrl, isNull);
      expect(parsed.badges[2].textColor, 0xFF00FF00);
    });

    test('a bare list of filters is a pack too', () {
      final parsed = StreamBadgePack.parse(
        jsonEncode([
          {'id': 'a', 'name': 'A', 'pattern': 'a'},
        ]),
      );
      expect(parsed.badges.single.name, 'A');
    });

    test('anything else is not a pack', () {
      expect(() => StreamBadgePack.parse('<html>'), throwsFormatException);
      expect(
        () => StreamBadgePack.parse('{"name": "x"}'),
        throwsFormatException,
      );
      expect(() => StreamBadgePack.parse(pack([])), throwsFormatException);
    });
  });

  test('the OK popup keeps only the quality groups', () {
    // The eclipsia pack's groups, plus names other packs use.
    final kept = [
      for (final g in [
        'Resolution',
        'Release',
        'Visual',
        'Encoder',
        'Audio',
        'Channels',
        'Streaming',
        'Special Tags',
        'Language',
        'Cached',
        'Video Codec',
        'Source',
        'HDR',
      ])
        if (streamBadgeQualityGroup(g)) g,
    ];
    expect(kept, [
      'Resolution',
      'Release',
      'Visual',
      'Encoder',
      'Video Codec',
      'Source',
      'HDR'
    ]);
  });

  testWidgets('without a pack the row shows the built-in gold tags', (
    tester,
  ) async {
    const option = ArchiveStreamOption(
      source: ArchiveSource(
        name: 'Torrentio',
        manifestUrl: 'https://t/manifest.json',
      ),
      stream: ArchiveStream(
        url: 'https://x/y.mkv',
        name: 'Torrentio 4k',
        title: 'Film 2160p HDR10 HEVC',
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreamBadgeRow(option: option)),
      ),
    );
    final tags = tester.widgetList<GoldTag>(find.byType(GoldTag));
    expect(tags.map((t) => t.label), ['4K', 'HDR10', 'HEVC']);
  });

  test('a link that is not a pack leaves the Media Hub Add error alone',
      () async {
    expect(
        await StreamBadges.instance.useIfPack('ftp://x/badges.json'), isNull);
    expect(await StreamBadges.instance.useIfPack('not a link'), isNull);
    expect(StreamBadges.instance.pack.value, isNull);
  });

  // Owner: a pack added from Media Hub sources couldn't be turned off or on
  // there. Off keeps the pack; Remove forgets it.
  group('the switch', () {
    late StorageService storage;
    final badges = StreamBadges.instance;
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      badges.attach(storage);
    });

    test('off keeps the pack, on brings it back', () async {
      await storage.setStreamBadgesUrl('https://x/GOLD-NONAMES.json');
      expect(badges.on, isTrue);
      expect(badges.enabled, isTrue);
      await badges.setOn(false);
      expect(badges.enabled, isFalse);
      expect(storage.getStreamBadgesUrl(), 'https://x/GOLD-NONAMES.json');
      await badges.setOn(true);
      expect(badges.enabled, isTrue);
      await badges.remove();
      expect(storage.getStreamBadgesUrl(), isEmpty);
    });

    testWidgets('Media Hub sources pane: switch, change, remove', (
      tester,
    ) async {
      Future<void> pump() async {
        await tester.pumpWidget(
          Provider<StorageService>.value(
            value: storage,
            child: const MaterialApp(home: Scaffold(body: StreamBadgesPane())),
          ),
        );
        await tester.pump();
      }

      await pump();
      expect(find.text('Add a badge pack'), findsOneWidget);
      expect(find.text('Show stream badges'), findsNothing);

      // As a pack pasted in Add a source does (use() turns it on).
      await storage.setStreamBadgesUrl('https://x/GOLD-NONAMES.json');
      await badges.setOn(true);
      await pump();
      expect(find.text('Show stream badges'), findsOneWidget);
      expect(find.textContaining('GOLD-NONAMES.json'), findsOneWidget);
      expect(find.text('Change badge pack'), findsOneWidget);

      await tester.tap(find.text('Show stream badges'));
      await tester.pump();
      expect(storage.getStreamBadgesOn(), isFalse);
      expect(storage.getStreamBadgesUrl(), isNotEmpty);
      await tester.tap(find.text('Show stream badges'));
      await tester.pump();
      expect(storage.getStreamBadgesOn(), isTrue);

      await tester.tap(find.text('Remove badge pack'));
      // remove() also deletes the saved file (real I/O).
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(storage.getStreamBadgesUrl(), isEmpty);
      expect(find.text('Add a badge pack'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // the snack bar
    });
  });
}

// Badge order in _patterns (what matchStreamBadges returns).
int _order(String a, String b) =>
    _patterns.keys.toList().indexOf(a) - _patterns.keys.toList().indexOf(b);
