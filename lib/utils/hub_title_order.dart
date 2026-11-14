import '../l10n/l10n.dart';
import '../models/archive_models.dart';

/// Media Hub titles: the Coming soon / New poster tags and the expanded
/// grid's sort and filters (owner, 2026-11-13: "Nuvio and Stremio are very
/// good at showing newer titles, even some in theaters, with a Coming soon
/// tag"). Everything here reads what the add-on sent with each title:
/// `released` (a full date: Cinemeta's catalogs carry it, upcoming films
/// included), `releaseInfo` (the year), `imdbRating`, `genres` and
/// `popularity`. Nothing is fetched.

/// A poster's release tag.
enum HubReleaseTag {
  /// Out after today.
  comingSoon,

  /// Out in the last [hubNewDays] days.
  isNew;

  String get label => switch (this) {
        HubReleaseTag.comingSoon => tr('Coming soon'),
        HubReleaseTag.isNew => tr('NEW'),
      };
}

/// How long a title counts as new after its release day.
const int hubNewDays = 30;

/// [meta]'s tag on [today] (a calendar day): Coming soon after today, NEW
/// up to [hubNewDays] days after. A bare year only says Coming soon (a
/// later year); it can't tell how new a title of this year is.
HubReleaseTag? hubReleaseTag(ArchiveMeta meta, DateTime today) {
  final day = meta.releaseDate;
  if (day == null) return null;
  final d = DateTime(today.year, today.month, today.day);
  if (!meta.hasReleaseDay) {
    return day.year > d.year ? HubReleaseTag.comingSoon : null;
  }
  if (day.isAfter(d)) return HubReleaseTag.comingSoon;
  if (d.difference(day).inDays <= hubNewDays) return HubReleaseTag.isNew;
  return null;
}

/// The poster tag text for [meta] today, or null.
String? hubReleaseLabel(ArchiveMeta meta) =>
    hubReleaseTag(meta, DateTime.now())?.label;

/// The expanded grid's orders.
enum HubSort {
  /// As the add-on sent them (its own ranking: Latest, Top 10…).
  source,

  /// Release date, newest first (upcoming titles lead).
  newest,

  /// Release date, oldest first.
  oldest,

  /// The add-on's popularity score (only offered when titles carry one).
  popular,

  /// Rating, highest first.
  rating,

  /// Name A to Z.
  aToZ;

  String get label => switch (this) {
        HubSort.source => tr('Default'),
        HubSort.newest => tr('Newest'),
        HubSort.oldest => tr('Oldest'),
        HubSort.popular => tr('Most popular'),
        HubSort.rating => tr('Rating (high to low)'),
        HubSort.aToZ => tr('A to Z'),
      };
}

double? _rating(ArchiveMeta m) => double.tryParse(m.rating ?? '');

/// The order of [items] for [sort], as indexes (titles missing the value
/// go last, in their sent order). Stable.
List<int> hubSortOrder(List<ArchiveMeta> items, HubSort sort) {
  final idx = [for (var i = 0; i < items.length; i++) i];
  if (sort == HubSort.source) return idx;
  int byValue(int a, int b, Comparable<Object?>? Function(ArchiveMeta) of,
      bool descending) {
    final x = of(items[a]), y = of(items[b]);
    if (x == null && y == null) return a.compareTo(b);
    if (x == null) return 1;
    if (y == null) return -1;
    final c = descending ? y.compareTo(x) : x.compareTo(y);
    return c != 0 ? c : a.compareTo(b);
  }

  int Function(int, int) compare = switch (sort) {
    HubSort.source => (a, b) => a.compareTo(b),
    HubSort.newest => (a, b) => byValue(a, b, (m) => m.releaseDate, true),
    HubSort.oldest => (a, b) => byValue(a, b, (m) => m.releaseDate, false),
    HubSort.popular => (a, b) => byValue(a, b, (m) => m.popularity, true),
    HubSort.rating => (a, b) => byValue(a, b, _rating, true),
    HubSort.aToZ => (a, b) {
        final c =
            items[a].name.toLowerCase().compareTo(items[b].name.toLowerCase());
        return c != 0 ? c : a.compareTo(b);
      },
  };
  idx.sort(compare);
  return idx;
}

/// Whether any of [items] carries a popularity score (the Most popular
/// sort is offered only then).
bool hubHasPopularity(List<ArchiveMeta> items) =>
    items.any((m) => m.popularity != null);

/// The decade of [meta]'s release (2020 for 2024), or null.
int? hubDecade(ArchiveMeta meta) {
  final y = meta.releaseDate?.year ??
      int.tryParse(
          RegExp(r'\d{4}').firstMatch(meta.year ?? '')?.group(0) ?? '');
  return y == null ? null : y - y % 10;
}

/// The decades [items] cover, newest first.
List<int> hubDecades(List<ArchiveMeta> items) =>
    ({for (final m in items) hubDecade(m)}..remove(null)).cast<int>().toList()
      ..sort((a, b) => b.compareTo(a));

/// The genres [items] carry, the most common first (then by name).
List<String> hubGenres(List<ArchiveMeta> items) {
  final count = <String, int>{};
  for (final m in items) {
    for (final g in m.genres.toSet()) {
      count[g] = (count[g] ?? 0) + 1;
    }
  }
  return count.keys.toList()
    ..sort((a, b) {
      final c = count[b]!.compareTo(count[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
}

/// "2020s" in the viewer's language.
String hubDecadeLabel(int decade) => tr('{n}s', {'n': decade});

/// A genre's display name: genres are the source's ids, translated under
/// `genre.` keys ("History" alone is watch history); one the dictionaries
/// don't know is shown as sent.
String hubGenreName(String genre) {
  final key = 'genre.$genre';
  final s = tr(key);
  return s == key ? genre : s;
}

/// [hubReleaseTag] for today, for a poster.
extension HubReleaseTagOf on ArchiveMeta {
  HubReleaseTag? get releaseTag => hubReleaseTag(this, DateTime.now());
}
