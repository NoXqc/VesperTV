import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/sports.dart';
import '../utils/channel_name_matching.dart';
import 'epg_service.dart';
import 'storage_service.dart';

/// Why a channel was suggested for a game — shown next to it so the user
/// can judge a match at a glance.
enum MatchReason { pick, name, guide, network }

extension MatchReasonLabel on MatchReason {
  String get label => switch (this) {
        MatchReason.pick => 'Your pick',
        MatchReason.name => 'Found by its name',
        MatchReason.guide => 'Found in the guide',
        MatchReason.network => 'National broadcast',
      };
}

class ChannelMatch {
  const ChannelMatch(this.channel, this.reason, this.score, {this.detail});
  final Channel channel;
  final MatchReason reason;
  final int score;

  /// Guide programme title / network name that produced the match.
  final String? detail;
}

/// The user's own game -> channel choices, per viewer. A pick for one game
/// (`events`) wins over a pick for a team (`teams`, "always use TSN 1 for
/// the Canadiens"). Event-named channels are renumbered by providers every
/// day, so those are only ever remembered for the one game.
class SportsChannelPicks {
  SportsChannelPicks._(this._storage, this._events, this.teams);

  factory SportsChannelPicks.load(StorageService storage) {
    final events = <String, _EventPick>{};
    final teams = <String, String>{};
    final raw = storage.getSportsChannelPicks();
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final cutoff = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
        (m['events'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          final p =
              _EventPick((v as Map)['c'] as String, (v['t'] as num).toInt());
          if (p.savedAtMs > cutoff) events[k] = p;
        });
        (m['teams'] as Map<String, dynamic>? ?? {})
            .forEach((k, v) => teams[k] = v as String);
      } catch (_) {
        // Corrupt prefs read back as "no picks", like the other JSON prefs.
      }
    }
    return SportsChannelPicks._(storage, events, teams);
  }

  final StorageService _storage;
  final Map<String, _EventPick> _events;
  final Map<String, String> teams;

  static String eventKey(SportsGame g) => '${g.league.id}:${g.id}';
  static String teamKey(SportsGame g, SportsTeam t) => '${g.league.id}:${t.id}';

  /// Channel id the user chose for [g], game pick first, then either team.
  String? channelIdFor(SportsGame g) =>
      _events[eventKey(g)]?.channelId ??
      teams[teamKey(g, g.first)] ??
      teams[teamKey(g, g.second)];

  Future<void> pickForGame(SportsGame g, String channelId) {
    _events[eventKey(g)] =
        _EventPick(channelId, DateTime.now().millisecondsSinceEpoch);
    return _save();
  }

  Future<void> pickForTeam(SportsGame g, SportsTeam t, String channelId) {
    teams[teamKey(g, t)] = channelId;
    // A fresh team pick should win over an older pick for this game.
    _events.remove(eventKey(g));
    return _save();
  }

  Future<void> clearFor(SportsGame g) {
    _events.remove(eventKey(g));
    final c = teams[teamKey(g, g.first)];
    final d = teams[teamKey(g, g.second)];
    if (c != null) teams.remove(teamKey(g, g.first));
    if (d != null) teams.remove(teamKey(g, g.second));
    return _save();
  }

  Future<void> _save() => _storage.setSportsChannelPicks(jsonEncode({
        'events': _events
            .map((k, v) => MapEntry(k, {'c': v.channelId, 't': v.savedAtMs})),
        'teams': teams,
      }));
}

class _EventPick {
  const _EventPick(this.channelId, this.savedAtMs);
  final String channelId;
  final int savedAtMs;
}

/// Lower-case, accent-free, punctuation as spaces, single-spaced and padded
/// with a space each side — so `' red wings '` matches a whole phrase and
/// never the inside of another word.
String sportsNormalize(String s) {
  final buffer = StringBuffer(' ');
  var lastSpace = true;
  // Code-unit checks, not a RegExp per character: this runs over every
  // channel name (tens of thousands) when the tab opens.
  for (final rune in s.toLowerCase().runes) {
    final isAscii = (rune >= 0x61 && rune <= 0x7a) ||
        (rune >= 0x30 && rune <= 0x39) ||
        rune == 0x2b;
    String? ch = isAscii ? String.fromCharCode(rune) : null;
    if (ch == null && rune > 0x7f) ch = _foldAccents[String.fromCharCode(rune)];
    if (ch != null) {
      buffer.write(ch);
      lastSpace = false;
    } else if (!lastSpace) {
      buffer.write(' ');
      lastSpace = true;
    }
  }
  if (!lastSpace) buffer.write(' ');
  return buffer.toString();
}

const Map<String, String> _foldAccents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ß': 'ss',
};

/// Streaming-only services ESPN lists that have no linear channel to find.
const Set<String> _streamingOnly = {
  'ESPN+',
  'PEACOCK',
  'PRIME VIDEO',
  'APPLE TV',
  'APPLE TV+',
  'PARAMOUNT+',
  'NETFLIX',
  'DAZN',
  'NFL+',
  'NBA LEAGUE PASS',
  'NHL.TV',
  'MLB.TV',
  'MAX',
  'YOUTUBE',
  'FUBO',
  'ESPN UNLMTD',
};

const Set<String> _englishTags = {'us', 'usa', 'ca', 'uk', 'en', 'english'};

/// Country/language tags providers put in channel names. Two-letter tags
/// only count as whole words (names are normalized and split on spaces).
const Set<String> _foreignTags = {
  'es',
  'se',
  'fi',
  'de',
  'fr',
  'nl',
  'it',
  'pt',
  'pl',
  'ru',
  'ar',
  'tr',
  'br',
  'mx',
  'dk',
  'no',
  'gr',
  'ro',
  'hu',
  'cz',
  'al',
  'rs',
  'hr',
  'bg',
  'espanol',
  'beisbol',
  'latino',
  'latam',
  'arabic',
  'francais',
};

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'sept': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Finds IPTV channels for games, best signal first (measured on a real
/// provider, see dev-notes/sports-tab.md "Channel-matching test"):
/// 1. the user's own pick,
/// 2. **event channels named after the game** ("NHL | 01 - 7pm Kraken @ Red
///    Wings") — the strongest automatic signal,
/// 3. a guide programme around the start time naming both teams,
/// 4. the national network the provider lists (ESPN, TNT, ...), exact
///    channel-name match only — fuzzy network matching ("Fox" -> 500+
///    channels) was useless in testing.
///
/// Build once per channel list ([prepare]), then [matchDay] per day shown.
class SportsChannelMatcher {
  SportsChannelMatcher(this._epg);

  final EpgService _epg;

  List<Channel> _channels = const [];
  List<String> _names = const [];
  final Map<String, List<int>> _tokenIndex = {};
  final Map<String, List<int>> _byCanonical = {};
  final Map<String, List<int>> _byEpgId = {};
  final Map<String, int> _byId = {};
  String? _preparedFor;

  Channel? channelById(String id) {
    final i = _byId[id];
    return i == null ? null : _channels[i];
  }

  List<Channel> get channels => _channels;

  /// Indexes [channels] (tens of thousands on big providers). Yields to the
  /// event loop every few thousand rows so a weak box keeps drawing.
  Future<void> prepare(List<Channel> channels) async {
    // visibleChannels() builds a new list per call, so compare a cheap
    // signature rather than identity.
    final signature = channels.isEmpty
        ? ''
        : '${channels.length}|${channels.first.id}|${channels.last.id}';
    if (_preparedFor == signature) return;
    _preparedFor = signature;
    _channels = channels;
    _tokenIndex.clear();
    _byCanonical.clear();
    _byEpgId.clear();
    _byId.clear();
    final names = List<String>.filled(channels.length, '');
    for (var i = 0; i < channels.length; i++) {
      if (i % 3000 == 2999) await Future<void>.delayed(Duration.zero);
      final c = channels[i];
      final norm = sportsNormalize(c.name);
      names[i] = norm;
      _byId[c.id] = i;
      for (final t in norm.trim().split(' ')) {
        if (t.length < 3) continue;
        final list = _tokenIndex[t] ??= <int>[];
        if (list.isEmpty || list.last != i) list.add(i);
      }
      final canon = canonicalChannelKey(c.name);
      if (canon.isNotEmpty) (_byCanonical[canon] ??= <int>[]).add(i);
      (_byEpgId[normalizeEpgId(c.epgId)] ??= <int>[]).add(i);
    }
    _names = names;
  }

  /// Name phrases a channel or programme title may use for [t] — nickname
  /// and full name. City names alone are skipped (two New York teams).
  static List<String> _teamPhrases(SportsTeam t) {
    final out = <String>{};
    for (final s in [t.shortName, t.name]) {
      final n = sportsNormalize(s);
      if (n.trim().length >= 4) out.add(n);
    }
    return out.toList();
  }

  /// Channel indexes whose name contains one of [phrases] as whole words.
  Set<int> _channelsNaming(List<String> phrases) {
    final hits = <int>{};
    for (final phrase in phrases) {
      final words = phrase.trim().split(' ').where((w) => w.length >= 3);
      if (words.isEmpty) continue;
      // Walk the rarest word's postings, verify the full phrase.
      List<int>? best;
      for (final w in words) {
        final list = _tokenIndex[w];
        if (list == null) {
          best = null;
          break;
        }
        if (best == null || list.length < best.length) best = list;
      }
      if (best == null) continue;
      for (final i in best) {
        if (_names[i].contains(phrase)) hits.add(i);
      }
    }
    return hits;
  }

  /// A date written in an event channel's name ("Oct 13", "13 Oct",
  /// "2026-10-13"), or null. Lets yesterday's leftover event channels — and the
  /// next meeting of the same two teams — be told apart from today's.
  static ({int month, int day})? _dateInName(String norm) {
    final m1 = RegExp(
            r' (jan|feb|mar|apr|may|jun|jul|aug|sept?|oct|nov|dec)[a-z]* (\d{1,2}) ')
        .firstMatch(norm);
    if (m1 != null) {
      return (month: _months[m1.group(1)]!, day: int.parse(m1.group(2)!));
    }
    final m2 = RegExp(
            r' (\d{1,2}) (jan|feb|mar|apr|may|jun|jul|aug|sept?|oct|nov|dec)[a-z]* ')
        .firstMatch(norm);
    if (m2 != null) {
      return (month: _months[m2.group(2)]!, day: int.parse(m2.group(1)!));
    }
    // ISO "2026-10-13" (normalized to " 2026 10 13 ").
    final m3 = RegExp(r' 20\d\d (\d{1,2}) (\d{1,2}) ').firstMatch(norm);
    if (m3 != null) {
      final month = int.parse(m3.group(1)!);
      final day = int.parse(m3.group(2)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return (month: month, day: day);
      }
    }
    return null;
  }

  static bool _dateFits(({int month, int day}) d, DateTime startUtc) {
    // The name's date may be the provider's local date, Eastern time, or
    // Europe's next day for an evening game — any of start-1d..start+1d.
    for (final offset in const [-1, 0, 1]) {
      final day = startUtc.add(Duration(days: offset));
      if (day.month == d.month && day.day == d.day) return true;
    }
    return false;
  }

  /// Providers carry the same game in many languages; the app's audience
  /// watches North American / English feeds, so those rank first and
  /// obviously foreign ones (country tags in the name) sink. Only reorders —
  /// nothing is dropped except for network matches.
  int _regionBias(int index) {
    final tokens = _names[index].trim().split(' ');
    var bias = 0;
    for (final t in tokens) {
      if (_englishTags.contains(t)) bias = math.max(bias, 10);
      if (_foreignTags.contains(t)) return -30;
    }
    return bias;
  }

  /// Suggestions for every game in [games], keyed by
  /// [SportsChannelPicks.eventKey], best first, at most [limit] each.
  Future<Map<String, List<ChannelMatch>>> matchDay(
      List<SportsGame> games, SportsChannelPicks picks,
      {int limit = 8}) async {
    final out = <String, List<ChannelMatch>>{};
    if (games.isEmpty) return out;

    // One guide query for the whole day: every team phrase at once.
    final terms = <String>{};
    for (final g in games) {
      for (final t in [g.home, g.away]) {
        for (final p in _teamPhrases(t)) {
          terms.add(p.trim());
        }
      }
    }
    var earliest = games.first.start;
    var latest = games.first.start;
    for (final g in games) {
      if (g.start.isBefore(earliest)) earliest = g.start;
      if (g.start.isAfter(latest)) latest = g.start;
    }
    final List<EpgProgram> programmes = _byEpgId.isEmpty
        ? const []
        : await _epg.findProgrammesByTitle(
            earliest.subtract(const Duration(minutes: 60)),
            latest.add(const Duration(minutes: 30)),
            terms.toList());

    for (final g in games) {
      final found = <String, ChannelMatch>{};
      void add(int index, MatchReason reason, int score, [String? detail]) {
        final c = _channels[index];
        final existing = found[c.id];
        if (existing == null || existing.score < score) {
          found[c.id] = ChannelMatch(c, reason, score, detail: detail);
        }
      }

      final picked = picks.channelIdFor(g);
      if (picked != null) {
        final i = _byId[picked];
        if (i != null) add(i, MatchReason.pick, 1000);
      }

      // 2. Event channels naming both teams.
      final a = _channelsNaming(_teamPhrases(g.home));
      if (a.isNotEmpty) {
        final b = _channelsNaming(_teamPhrases(g.away));
        for (final i in a.intersection(b)) {
          final d = _dateInName(_names[i]);
          if (d != null && !_dateFits(d, g.start)) continue;
          add(i, MatchReason.name, (d != null ? 120 : 100) + _regionBias(i));
        }
      }

      // 3. Guide programmes naming both teams near the start time.
      final home = _teamPhrases(g.home);
      final away = _teamPhrases(g.away);
      for (final p in programmes) {
        final diff = p.start.toUtc().difference(g.start).inMinutes;
        if (diff < -60 || diff > 30) continue;
        final title = sportsNormalize(p.title);
        if (!home.any(title.contains) || !away.any(title.contains)) continue;
        for (final i in _byEpgId[p.channelId] ?? const <int>[]) {
          add(i, MatchReason.guide,
              80 - math.min(diff.abs(), 60) ~/ 6 + _regionBias(i), p.title);
        }
      }

      // 4. National networks, exact channel name only.
      for (final network in g.broadcasts) {
        if (_streamingOnly.contains(network.toUpperCase())) continue;
        final key = canonicalChannelKey(network);
        final hits = _byCanonical[key] ?? const <int>[];
        var taken = 0;
        for (final i in hits) {
          if (taken >= 3) break;
          // Same name, different country's channel ("RU: TNT" is not TNT).
          final bias = _regionBias(i);
          if (bias < 0) continue;
          add(i, MatchReason.network, 50 + bias, network);
          taken++;
        }
      }

      final list = found.values.toList()
        ..sort((x, y) {
          final s = y.score.compareTo(x.score);
          return s != 0
              ? s
              : x.channel.name.length.compareTo(y.channel.name.length);
        });
      out[SportsChannelPicks.eventKey(g)] =
          list.length > limit ? list.sublist(0, limit) : list;
    }
    return out;
  }

  /// Channels whose name contains every word of [query] — the manual
  /// "Pick channel" search. Empty query = nothing.
  List<Channel> search(String query, {int limit = 200}) {
    final words = sportsNormalize(query)
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final out = <Channel>[];
    for (var i = 0; i < _names.length && out.length < limit; i++) {
      final n = _names[i];
      if (words.every((w) => n.contains(w))) out.add(_channels[i]);
    }
    return out;
  }
}
