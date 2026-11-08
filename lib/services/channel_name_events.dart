import '../l10n/l10n.dart';
import '../models/epg_program.dart';

/// Guide listings read from a channel's own name, for event channels whose
/// provider guide has nothing (owner, 2026-11-07: a provider's USA | NBA and
/// NBA League Pass had no listings at all; the game and its start time were
/// only in the name, `NBA 01: Nuggets vs. Pacers @ 7 Nov 04:58 PM ET`).
///
/// Only names ending in `@ <date> <time> <zone>` are read. A name without a
/// date or a known zone is skipped: a wrong start time is worse than none.
class ChannelNameEvent {
  const ChannelNameEvent(this.title, this.start, {this.note});

  final String title;

  /// UTC.
  final DateTime start;

  /// Text after the time (`NFL Game Pass 02: … @ Nov 05 08:15 PM ET -
  /// Prime Feed` → `Prime Feed`), shown as the description.
  final String? note;

  /// Names give no end. Long enough for most games; a provider listing that
  /// overlaps the event wins anyway ([mergeChannelNameEvent]).
  static const length = Duration(hours: 3);

  DateTime get stop => start.add(length);

  @override
  bool operator ==(Object other) =>
      other is ChannelNameEvent &&
      other.title == title &&
      other.start == start &&
      other.note == note;

  @override
  int get hashCode => Object.hash(title, start, note);

  @override
  String toString() => 'ChannelNameEvent($title, $start, $note)';
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// `7 Nov 04:58 PM ET`, `Nov 07 1:00PM ET`, `6 Nov 04:25 PM Oslo`,
/// `7 Nov 01:30 PM GMT-5`, optionally followed by `- note`.
final _tail = RegExp(
    r'^\s*(?:(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3})[a-z]*\.?'
    r'|([a-z]{3})[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?)'
    // am/pm whole, so a 24 h time keeps a zone starting with a/p (PT).
    r',?\s+(\d{1,2}):(\d{2})\s*(?:([ap])\.?m\.?(?![a-z]))?\s*'
    r'([a-z]+(?:\s*[+-]\s*\d{1,2}(?::?\d{2})?)?)'
    r'\s*(?:[-|]\s*(.*))?$',
    caseSensitive: false);

/// `NBA 01: `, `NFHS Network 07: `, `Soccer03: `, `PDC 01 | `.
final _numberedPrefix = RegExp(r'^[^:|]{0,40}?\d{1,4}\s*[:|]\s*');
final _trailingJunk = RegExp(r'[\s\-|,:]+$');

/// The event in [name], or null when it doesn't end in a readable date,
/// time and zone. [now] picks the year (names don't have one): the one
/// that puts the date nearest to now.
ChannelNameEvent? parseChannelNameEvent(String name, {DateTime? now}) {
  final at = name.lastIndexOf('@');
  if (at <= 0) return null;
  final m = _tail.firstMatch(name.substring(at + 1));
  if (m == null) return null;

  final month = _months[(m[2] ?? m[3])!.toLowerCase()];
  final day = int.parse((m[1] ?? m[4])!);
  var hour = int.parse(m[5]!);
  final minute = int.parse(m[6]!);
  if (month == null || minute > 59) return null;
  final ampm = m[7]?.toLowerCase();
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    if (ampm == 'p' && hour < 12) hour += 12;
    if (ampm == 'a' && hour == 12) hour = 0;
  } else if (hour > 23) {
    return null;
  }
  final zone = _Zone.parse(m[8]!);
  if (zone == null) return null;

  final ref = (now ?? DateTime.now()).toUtc();
  DateTime? best;
  for (final year in [ref.year - 1, ref.year, ref.year + 1]) {
    if (DateTime.utc(year, month, day).month != month) continue; // 30 Feb
    final start = zone.toUtc(year, month, day, hour, minute);
    if (best == null ||
        start.difference(ref).abs() < best.difference(ref).abs()) {
      best = start;
    }
  }
  if (best == null) return null;

  final title = name
      .substring(0, at)
      .trim()
      .replaceFirst(_numberedPrefix, '')
      .replaceFirst(_trailingJunk, '')
      .trim();
  if (title.isEmpty) return null;
  final note = m[9]?.trim();
  return ChannelNameEvent(title, best,
      note: note == null || note.isEmpty ? null : note);
}

/// The provider's own placeholders: an event read from the name may cover
/// them, never a real listing. Variants matter: the same provider listed
/// "No Event Today" over that evening's League Pass games (2026-11-07).
final _filler =
    RegExp(r'^(?:no (?:events?|games?|programmes?|programs?|program data|'
        r'information|info|title)\b.*|signing off\b.*|sign off|off air\b.*|'
        r'stand ?by|to be announced|tba|tbd|n/a)$');

bool isFillerProgrammeTitle(String title) {
  final t = title.trim().toLowerCase();
  return _filler.hasMatch(t) || t == tr('No Title').toLowerCase();
}

/// [programs] (one channel, sorted, not overlapping) with [event] added,
/// unless a real listing overlaps it: the provider's word wins. Fillers it
/// overlaps are cut around it.
List<EpgProgram> mergeChannelNameEvent(
    List<EpgProgram> programs, ChannelNameEvent event, String channelId) {
  final start = event.start.toLocal();
  final stop = event.stop.toLocal();
  final out = <EpgProgram>[];
  for (final p in programs) {
    if (!p.start.isBefore(stop) || !p.stop.isAfter(start)) {
      out.add(p);
      continue;
    }
    if (!isFillerProgrammeTitle(p.title)) return programs;
    if (p.start.isBefore(start)) out.add(_retimed(p, p.start, start));
    if (p.stop.isAfter(stop)) out.add(_retimed(p, stop, p.stop));
  }
  out
    ..add(EpgProgram(
        channelId: channelId,
        title: event.title,
        description: event.note,
        start: start,
        stop: stop))
    ..sort((a, b) => a.start.compareTo(b.start));
  return out;
}

EpgProgram _retimed(EpgProgram p, DateTime start, DateTime stop) => EpgProgram(
    channelId: p.channelId,
    title: p.title,
    description: p.description,
    start: start,
    stop: stop);

/// A zone as written in channel names, with its daylight-saving rule.
class _Zone {
  const _Zone(this.baseMinutes, this.rule);

  final int baseMinutes;
  final _Dst rule;

  static const _us = {
    'et': -5, 'est': -5, 'edt': -5, 'eastern': -5, //
    'ct': -6, 'cst': -6, 'cdt': -6, 'central': -6,
    'mt': -7, 'mst': -7, 'mdt': -7, 'mountain': -7,
    'pt': -8, 'pst': -8, 'pdt': -8, 'pacific': -8,
  };
  static const _uk = {
    'london', 'uk', 'bst', 'dublin', 'lisbon', 'wet', 'west', //
  };
  static const _cet = {
    'cet', 'cest', 'oslo', 'stockholm', 'amsterdam', 'berlin', 'paris', //
    'madrid', 'rome', 'copenhagen', 'brussels', 'vienna', 'zurich',
    'warsaw', 'prague', 'budapest', 'belgrade', 'zagreb',
  };
  static const _eet = {
    'eet', 'eest', 'helsinki', 'athens', 'bucharest', 'sofia', 'kyiv', //
  };
  static final _fixed =
      RegExp(r'^(gmt|utc)(?:\s*([+-])\s*(\d{1,2})(?::?(\d{2}))?)?$');

  static _Zone? parse(String raw) {
    final z = raw.trim().toLowerCase();
    final us = _us[z];
    if (us != null) return _Zone(us * 60, _Dst.us);
    if (_uk.contains(z)) return const _Zone(0, _Dst.eu);
    if (_cet.contains(z)) return const _Zone(60, _Dst.eu);
    if (_eet.contains(z)) return const _Zone(120, _Dst.eu);
    final f = _fixed.firstMatch(z);
    if (f == null) return null;
    if (f[2] == null) return const _Zone(0, _Dst.none);
    final minutes = int.parse(f[3]!) * 60 + int.parse(f[4] ?? '0');
    if (minutes > 14 * 60) return null;
    return _Zone(f[2] == '-' ? -minutes : minutes, _Dst.none);
  }

  DateTime toUtc(int year, int month, int day, int hour, int minute) {
    final wall = DateTime.utc(year, month, day, hour, minute);
    final standard = wall.subtract(Duration(minutes: baseMinutes));
    final summer = switch (rule) {
      // Second Sunday in March to first Sunday in November, 2:00 local.
      _Dst.us =>
        !wall.isBefore(DateTime.utc(year, 3, _sunday(year, 3, 2), 2)) &&
            wall.isBefore(DateTime.utc(year, 11, _sunday(year, 11, 1), 2)),
      // Last Sunday in March to last Sunday in October, 1:00 UTC.
      _Dst.eu =>
        !standard.isBefore(DateTime.utc(year, 3, _lastSunday(year, 3), 1)) &&
            standard.isBefore(DateTime.utc(year, 10, _lastSunday(year, 10), 1)),
      _Dst.none => false,
    };
    return summer ? standard.subtract(const Duration(hours: 1)) : standard;
  }

  static int _sunday(int year, int month, int nth) {
    final first = DateTime.utc(year, month).weekday; // Mon 1 … Sun 7
    return 1 + (7 - first) % 7 + 7 * (nth - 1);
  }

  static int _lastSunday(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    return last.day - last.weekday % 7;
  }
}

enum _Dst { us, eu, none }
