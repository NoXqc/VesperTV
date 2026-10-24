/// A published episode schedule, separate from playback availability or progress.
class EpisodeAiring {
  const EpisodeAiring(this.date,
      {required this.dateOnly, this.season, this.episode});

  final DateTime date;
  final bool dateOnly;
  final int? season;
  final int? episode;

  static EpisodeAiring? parse(String? raw, {int? season, int? episode}) {
    if (raw == null) return null;
    final value = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|T)').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final calendar = DateTime.utc(year, month, day);
    if (year < 1900 ||
        calendar.year != year ||
        calendar.month != month ||
        calendar.day != day) {
      return null;
    }
    if (value.length > 10) {
      final time = RegExp(r'T(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(value);
      if (time == null ||
          int.parse(time[1]!) > 23 ||
          int.parse(time[2]!) > 59 ||
          int.parse(time[3] ?? '0') > 59) {
        return null;
      }
    }
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return EpisodeAiring(date,
        dateOnly: value.length == 10, season: season, episode: episode);
  }

  bool upcoming(DateTime now) => dateOnly
      ? !date.isBefore(DateTime(now.year, now.month, now.day))
      : !date.isBefore(now);

  /// A future release, rather than today's date-only schedule whose exact
  /// availability is unknown. Used for the episode card's Coming soon tag.
  bool unreleased(DateTime now) => dateOnly
      ? date.isAfter(DateTime(now.year, now.month, now.day))
      : date.isAfter(now);

  DateTime get displayDate => dateOnly ? date : date.toLocal();

  String? get code => season != null &&
          season! >= 0 &&
          episode != null &&
          episode! > 0
      ? 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}'
      : null;

  static EpisodeAiring? next(Iterable<EpisodeAiring> entries, DateTime now) {
    final future = entries.where((e) => e.upcoming(now)).toList()
      ..sort((a, b) {
        final order = a.date.compareTo(b.date);
        if (order != 0) return order;
        final season = (a.season ?? 0).compareTo(b.season ?? 0);
        return season != 0
            ? season
            : (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
    return future.firstOrNull;
  }
}
