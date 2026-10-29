/// Custom Media Hub posters (Settings > Media Hub > Custom posters): a URL
/// pattern from a poster service the user picked (RPDB, Top Posters…, with
/// their own key inside), filled in per title. Like Nuvio's "Custom Poster
/// Source". Read through `ArchiveMeta.posterUrl`, so every Media Hub poster
/// follows it and clearing it brings the source's own posters back (the
/// stored metas keep the original).
class ArchivePosters {
  ArchivePosters._();

  /// The saved pattern, set at startup and on save; empty = off.
  static String pattern = '';

  static const placeholders = ['{imdb_id}', '{tmdb_id}', '{type}'];

  /// [pattern] filled in for one title, or null (keep the source's poster)
  /// when it is off, has no placeholder, or the title lacks a value one of
  /// its placeholders needs.
  static String? apply(
      {required String? imdb, required String? tmdb, required String type}) {
    final p = pattern.trim();
    if (p.isEmpty || !placeholders.any(p.contains)) return null;
    if (p.contains('{imdb_id}') && imdb == null) return null;
    if (p.contains('{tmdb_id}') && tmdb == null) return null;
    final url = p
        .replaceAll('{imdb_id}', imdb ?? '')
        .replaceAll('{tmdb_id}', tmdb ?? '')
        .replaceAll('{type}', type);
    final uri = Uri.tryParse(url);
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? url
        : null;
  }
}
