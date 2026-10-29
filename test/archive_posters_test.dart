import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_posters.dart';

void main() {
  tearDown(() => ArchivePosters.pattern = '');

  const movie = ArchiveMeta(
      id: 'tt0111161',
      type: ArchiveType.movie,
      name: 'A title',
      posterUrl: 'https://source.example/p.jpg');

  test('off: the source poster', () {
    expect(movie.posterUrl, 'https://source.example/p.jpg');
  });

  test('pattern fills the IMDb id and type', () {
    ArchivePosters.pattern = 'https://posters.example/KEY/{type}/{imdb_id}.jpg';
    expect(movie.posterUrl, 'https://posters.example/KEY/movie/tt0111161.jpg');
  });

  test('a missing id keeps the source poster', () {
    ArchivePosters.pattern = 'https://posters.example/{tmdb_id}.jpg';
    expect(movie.posterUrl, 'https://source.example/p.jpg');
    const tmdb = ArchiveMeta(
        id: 'tmdb:603',
        type: ArchiveType.movie,
        name: 'B',
        posterUrl: 'https://source.example/b.jpg');
    expect(tmdb.posterUrl, 'https://posters.example/603.jpg');
  });

  test('no placeholder or not a web address: ignored', () {
    ArchivePosters.pattern = 'https://posters.example/fixed.jpg';
    expect(movie.posterUrl, 'https://source.example/p.jpg');
    ArchivePosters.pattern = 'not a url {imdb_id}';
    expect(movie.posterUrl, 'https://source.example/p.jpg');
  });

  test('saved metas keep the source poster, so turning it off restores it', () {
    ArchivePosters.pattern = 'https://posters.example/{imdb_id}.jpg';
    final saved = movie.toJson();
    expect(saved['poster'], 'https://source.example/p.jpg');
    ArchivePosters.pattern = '';
    expect(ArchiveMeta.fromJson(saved)?.posterUrl,
        'https://source.example/p.jpg');
  });
}
