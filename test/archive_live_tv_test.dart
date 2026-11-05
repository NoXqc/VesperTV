import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/archive_live_tv_screen.dart';

ArchiveCatalog _catalog(String type, {List<String> genres = const []}) =>
    ArchiveCatalog.fromJson({
      'type': type,
      'id': 'all',
      'name': 'All channels',
      if (genres.isNotEmpty) 'genres': genres,
    })!;

ArchiveSource _source(String type, {bool? liveTv}) => ArchiveSource(
      manifestUrl: 'https://addon.example/manifest.json',
      name: 'Add-on',
      catalogs: [_catalog(type)],
      liveTvChoice: liveTv,
    );

ArchiveMeta _meta(String id, List<String> genres) => ArchiveMeta.fromJson({
      'id': id,
      'type': 'tv',
      'name': id,
      'genres': genres,
    })!;

void main() {
  test('tv/channel add-ons are live TV by themselves, others by the switch',
      () {
    expect(_source('tv').isLiveTv, isTrue);
    expect(_source('channel').isLiveTv, isTrue);
    expect(_source('sport').isLiveTv, isFalse);
    expect(_source('movie').isLiveTv, isFalse);
    expect(_source('sport', liveTv: true).isLiveTv, isTrue);
    expect(_source('tv', liveTv: false).isLiveTv, isFalse);
  });

  test('the switch survives saving', () {
    final saved =
        ArchiveSource.fromJson(_source('sport', liveTv: true).toJson());
    expect(saved.liveTvChoice, isTrue);
    expect(saved.isLiveTv, isTrue);
    expect(ArchiveSource.fromJson(_source('tv').toJson()).liveTvChoice,
        isNull);
  });

  test('big catalogs with genre options split into genre rows, then all', () {
    final source = _source('tv');
    final catalog = _catalog('tv', genres: ['News', 'Sports', 'Kids']);
    final metas = [
      for (var i = 0; i < 40; i++)
        _meta('c$i', [if (i.isEven) 'News' else 'Sports']),
    ];
    final rows = liveTvRowsFor(source, catalog, metas);
    expect(rows.map((r) => r.title), [
      'All channels · News',
      'All channels · Sports',
      'All channels',
    ]);
    expect(rows.first.metas, hasLength(20));
    expect(rows.last.metas, hasLength(40));
    // A small list stays one row.
    expect(liveTvRowsFor(source, catalog, metas.take(10).toList()),
        hasLength(1));
  });

  test('live TV channel ids are live, Media Hub title ids are not', () {
    expect(Channel.isLiveId('hublive_abc_123'), isTrue);
    expect(Channel.isLiveId('arc_vod_abc'), isFalse);
  });
}
