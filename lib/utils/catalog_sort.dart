import '../models/channel.dart';
import '../models/xtream_series.dart';

/// The Movies / TV Shows sort picked in Expand catalog, saved per tab
/// (`vesper_catalog_sort_vod|series`). Since 1.0.36 the browse rows follow
/// it too (user request: "Date added/updated" in Expand, but the rows kept
/// the provider's order) — [PlaylistSession] asks the catalog database
/// for each category in this order ([orderBy]) before keeping its first
/// 300, so the newest titles really are the ones in the row.
///
/// [addedDate] and [tmdb] are deliberately separate: [addedDate] is the
/// provider's own "when this showed up in their catalog" timestamp
/// (`addedAt`, free, always there — same field What's New uses); [tmdb] is
/// the real release date, only known once `TmdbEnrichmentService` looked it
/// up with the user's key. Both are useful ("what's new in this category"
/// vs. "what actually just came out").
enum CatalogSort { none, aToZ, zToA, rating, addedDate, tmdb }

CatalogSort catalogSortFrom(String? name) =>
    CatalogSort.values.where((m) => m.name == name).firstOrNull ??
    CatalogSort.none;

extension CatalogSortQuery on CatalogSort {
  /// SQL `ORDER BY` for `vod_channels` / `series_items` (same columns);
  /// null = the provider's order. Missing dates/ratings go last.
  String? get orderBy => switch (this) {
        CatalogSort.none => null,
        CatalogSort.aToZ => 'name COLLATE NOCASE ASC',
        CatalogSort.zToA => 'name COLLATE NOCASE DESC',
        CatalogSort.rating =>
          "(rating IS NULL OR rating = '') ASC, CAST(rating AS REAL) DESC",
        CatalogSort.addedDate => 'added_at IS NULL ASC, added_at DESC',
        CatalogSort.tmdb => 'release_date IS NULL ASC, release_date DESC',
      };
}

/// A sorted copy (never sorts [items] in place: it's the shared list).
List<Channel> sortCatalogChannels(List<Channel> items, CatalogSort sort) =>
    _sorted(items, sort, (c) => c.name, (c) => c.rating, (c) => c.addedAt,
        (c) => c.releaseDate);

List<XtreamSeries> sortCatalogSeries(
        List<XtreamSeries> items, CatalogSort sort) =>
    _sorted(items, sort, (s) => s.name, (s) => s.rating, (s) => s.addedAt,
        (s) => s.releaseDate);

List<T> _sorted<T>(
  List<T> items,
  CatalogSort sort,
  String Function(T) name,
  String? Function(T) rating,
  DateTime? Function(T) added,
  DateTime? Function(T) released,
) {
  final sorted = List<T>.from(items);
  switch (sort) {
    case CatalogSort.none:
      break;
    case CatalogSort.aToZ:
      sorted.sort(
          (a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));
    case CatalogSort.zToA:
      sorted.sort(
          (a, b) => name(b).toLowerCase().compareTo(name(a).toLowerCase()));
    case CatalogSort.rating:
      sorted.sort((a, b) => (double.tryParse(rating(b) ?? '') ?? -1)
          .compareTo(double.tryParse(rating(a) ?? '') ?? -1));
    case CatalogSort.addedDate:
      sorted.sort((a, b) => _newestFirst(added(a), added(b)));
    case CatalogSort.tmdb:
      // No release date yet (lookup still running, or TMDB had nothing)
      // sorts to the end rather than being treated as "ancient".
      sorted.sort((a, b) => _newestFirst(released(a), released(b)));
  }
  return sorted;
}

/// Newest first; a null date always sorts last.
int _newestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
