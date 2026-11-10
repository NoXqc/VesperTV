import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/m3u_import.dart';
import 'package:nox_iptv/services/m3u_parser.dart';

/// The website's demo playlist (docs/demo/, tools/demo/build_demo.py) is
/// the screenshot and App Review source: it must keep landing in the right
/// tabs, with its guide ids and its shows' episodes.
void main() {
  final m3u = File('docs/demo/vesper-demo.m3u').readAsStringSync();
  final guide = File('docs/demo/guide.xml').readAsStringSync();
  final list = M3uList(M3uParser.parse(m3u, playlistId: 'demo'));

  test('six live channels in two groups, each with a guide', () {
    final live = list.byTab['tv']!;
    expect(live, hasLength(6));
    expect(list.groupsOf['tv']!.keys,
        unorderedEquals(['Vesper Demo', 'Vesper Demo Kids']));
    for (final channel in live) {
      expect(guide, contains('channel="${channel.rawId}"'),
          reason: '${channel.name} has no programmes');
      expect(channel.logoUrl, startsWith('https://vespertv.app/demo/logos/'));
    }
  });

  test('eight movies, two shows with their episodes in order', () {
    expect(list.byTab['vod']!, hasLength(8));
    final shows = <String, List<int>>{};
    for (final c in list.byTab['series']!) {
      final e = M3uImport.episodeOf(c.name);
      shows.putIfAbsent(e.show, () => []).add(e.episode);
    }
    expect(shows, {
      'Caminandes': [1, 2, 3],
      'Open Movie Collection': [1, 2, 3, 4, 5],
    });
  });

  group('Media Hub add-on (static files)', () {
    const root = 'docs/demo/addon';
    Map<String, dynamic> read(String path) =>
        jsonDecode(File('$root/$path').readAsStringSync())
            as Map<String, dynamic>;

    test('every catalog entry has a meta and a playable stream', () {
      final manifest = read('manifest.json');
      final catalogs = manifest['catalogs'] as List;
      expect(catalogs, hasLength(3));
      var titles = 0;
      for (final c in catalogs.cast<Map>()) {
        final type = c['type'] as String;
        final metas = read('catalog/$type/${c['id']}.json')['metas'] as List;
        expect(metas, isNotEmpty);
        for (final m in metas.cast<Map<String, dynamic>>()) {
          titles++;
          expect(ArchiveMeta.fromJson(m), isNotNull, reason: m['id']);
          final meta = ArchiveMeta.fromJson(
              read('meta/$type/${m['id']}.json')['meta']
                  as Map<String, dynamic>)!;
          expect(meta.backgroundUrl, isNotNull);
          final videos = type == 'series'
              ? [for (final v in meta.videos) v.id]
              : [meta.id];
          expect(videos, isNotEmpty);
          for (final id in videos) {
            final streams = read('stream/$type/$id.json')['streams'] as List;
            expect(Uri.parse((streams.first as Map)['url'] as String).host,
                'archive.org');
          }
        }
      }
      expect(titles, 10); // 8 films + 2 shows
    });
  });

  test('only Internet Archive and public test-stream links', () {
    const hosts = {
      'archive.org',
      'demo.unified-streaming.com',
      'test-streams.mux.dev',
    };
    for (final c in list.channels) {
      expect(hosts, contains(Uri.parse(c.url).host), reason: c.url);
    }
  });
}
