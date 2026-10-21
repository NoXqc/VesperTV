import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/sports.dart';
import 'greek_sports_names.dart';
import '../utils/channel_name_matching.dart';
import 'epg_service.dart';
import 'storage_service.dart';
import '../l10n/l10n.dart';

/// Why a channel was suggested for a game — shown next to it so the user
/// can judge a match at a glance.
enum MatchReason { pick, name, guide, network }

extension MatchReasonLabel on MatchReason {
  String get label => switch (this) {
        MatchReason.pick => tr('Your pick'),
        MatchReason.name => tr('Found by its name'),
        MatchReason.guide => tr('Found in the guide'),
        MatchReason.network => tr('National broadcast'),
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

  /// Event sports' "always for this series" pick (Sky Sports F1 for every
  /// F1 session). Stored with the team picks, under an empty team id.
  static String seriesKey(SportsGame g) => '${g.league.id}:*';

  /// Channel id the user chose for [g], game pick first, then either team
  /// (event sports: the series).
  String? channelIdFor(SportsGame g) =>
      _events[eventKey(g)]?.channelId ??
      (g.league.kind != SportsKind.team
          ? teams[seriesKey(g)]
          : teams[teamKey(g, g.first)] ?? teams[teamKey(g, g.second)]);

  Future<void> pickForSeries(SportsGame g, String channelId) {
    teams[seriesKey(g)] = channelId;
    _events.remove(eventKey(g));
    return _save();
  }

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

  /// The NFL RedZone pill's chosen channel (hold the pill). Stored with the
  /// team picks under a key no league/team id can produce; null = automatic.
  static const _redZoneKey = 'redzone';
  String? get redZoneChannelId => teams[_redZoneKey];

  Future<void> setRedZone(String? channelId) {
    if (channelId == null) {
      teams.remove(_redZoneKey);
    } else {
      teams[_redZoneKey] = channelId;
    }
    return _save();
  }

  Future<void> clearFor(SportsGame g) {
    _events.remove(eventKey(g));
    final c = teams[teamKey(g, g.first)];
    final d = teams[teamKey(g, g.second)];
    if (c != null) teams.remove(teamKey(g, g.first));
    if (d != null) teams.remove(teamKey(g, g.second));
    teams.remove(seriesKey(g));
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
  // Greek guides and channel names compare in Latin (greek_sports_names).
  if (hasGreek(s)) s = greekToLatin(s);
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
  // Balkan, Turkish and Central European guides (Sport Klub, Arena:
  // "Beşiktaş", "Žalgiris", "Crvena zvezda") — unfolded they split words.
  'č': 'c',
  'ć': 'c',
  'š': 's',
  'ž': 'z',
  'đ': 'd',
  'ş': 's',
  'ğ': 'g',
  'ı': 'i',
  'ł': 'l',
  'ą': 'a',
  'ę': 'e',
  'ń': 'n',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
  'ő': 'o',
  'ű': 'u',
  'ř': 'r',
  'ě': 'e',
  'ů': 'u',
  'ț': 't',
  'ș': 's',
  'ă': 'a',
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

/// Regional sports networks as ESPN writes them in `broadcasts` (an
/// abbreviation) -> phrases their channels go by in playlists (normalized,
/// lower case). The exact-name check in matchDay finds none of these:
/// "MNMT" is "US - Monumental Sports Network HD" (NBA user report,
/// 2026-10-21: most regional games had no channel). FanDuel's networks keep
/// their old Bally Sports names on many providers, so both are listed.
const Map<String, List<String>> _networkAliases = {
  'MNMT': ['monumental'],
  'MONUMENTAL': ['monumental'],
  'NBC SPORTS CA': ['nbc sports california', 'nbcs california'],
  'NBCS-CA': ['nbc sports california', 'nbcs california'],
  'NBC SPORTS BA': ['nbc sports bay area', 'nbcs bay area'],
  'NBCS-BA': ['nbc sports bay area', 'nbcs bay area'],
  'NBC SPORTS PH': ['nbc sports philadelphia', 'nbcs philadelphia'],
  'NBCS-PH': ['nbc sports philadelphia', 'nbcs philadelphia'],
  'NBC SPORTS BOS': ['nbc sports boston', 'nbcs boston'],
  'NBCS-BOS': ['nbc sports boston', 'nbcs boston'],
  'CHSN': ['chicago sports network', 'chsn'],
  'GCSEN': ['gulf coast sports', 'gcsen'],
  'YES': ['yes network'],
  'MSG': ['msg'],
  'MSGSN': ['msg sportsnet', 'msg 2', 'msg'],
  'SNY': ['sny'],
  'NESN': ['nesn'],
  'MASN': ['masn'],
  'MARQUEE': ['marquee'],
  'SPECTRUM SN': ['spectrum sportsnet'],
  'SPECTRUM SPORTSNET': ['spectrum sportsnet'],
  'SPECTRUM SPORTSNET LA': ['spectrum sportsnet la', 'sportsnet la'],
  'SNLA': ['spectrum sportsnet la', 'sportsnet la'],
  'ALT': ['altitude'],
  'ALTITUDE': ['altitude'],
  'ROOT SPORTS': ['root sports'],
  'ROOT': ['root sports'],
  'SCHN': ['space city'],
  'SPACE CITY HOME NETWORK': ['space city'],
  'FDSDET': [
    'fanduel sports network detroit',
    'fanduel sports detroit',
    'bally sports detroit'
  ],
  'FDSFL': [
    'fanduel sports network florida',
    'fanduel sports florida',
    'bally sports florida'
  ],
  'FDSSUN': [
    'fanduel sports network sun',
    'fanduel sports sun',
    'bally sports sun'
  ],
  'FDSSE': [
    'fanduel sports network southeast',
    'fanduel sports southeast',
    'bally sports southeast'
  ],
  'FDSSO': [
    'fanduel sports network south',
    'fanduel sports south',
    'bally sports south'
  ],
  'FDSIN': [
    'fanduel sports network indiana',
    'fanduel sports indiana',
    'bally sports indiana'
  ],
  'FDSOH': [
    'fanduel sports network ohio',
    'fanduel sports ohio',
    'bally sports ohio'
  ],
  'FDSWI': [
    'fanduel sports network wisconsin',
    'fanduel sports wisconsin',
    'bally sports wisconsin'
  ],
  'FDSN': [
    'fanduel sports network north',
    'fanduel sports north',
    'bally sports north'
  ],
  'FDSNO': [
    'fanduel sports network new orleans',
    'fanduel sports new orleans',
    'bally sports new orleans'
  ],
  'FDSSW': [
    'fanduel sports network southwest',
    'fanduel sports southwest',
    'bally sports southwest'
  ],
  'FDSMW': [
    'fanduel sports network midwest',
    'fanduel sports midwest',
    'bally sports midwest'
  ],
  'FDSOK': [
    'fanduel sports network oklahoma',
    'fanduel sports oklahoma',
    'bally sports oklahoma'
  ],
  'FDSSD': [
    'fanduel sports network san diego',
    'fanduel sports san diego',
    'bally sports san diego'
  ],
  'FDSWC': [
    'fanduel sports network socal',
    'fanduel sports socal',
    'bally sports socal'
  ],
  'FDSKC': [
    'fanduel sports network kansas city',
    'fanduel sports kansas city',
    'bally sports kansas city'
  ],
  'FDSCIN': [
    'fanduel sports network cincinnati',
    'fanduel sports cincinnati',
    'bally sports ohio'
  ],
};

/// A US/Canadian TV station's call sign ("KJZZ-TV", "KUNP 16", "WGN"):
/// its channel names carry it ("US - KJZZ 14 SALT LAKE CITY").
final RegExp _callSign =
    RegExp(r'^([KW][A-Z]{2,3})(?:-(?:TV|DT|CD|LD))?(?: \d+)?$');

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

/// App language -> the channel-name country tag that viewer watches. Only
/// Greek so far: French/Spanish/Italian viewers of this app mostly watch
/// North American feeds, which rank first by default.
const Map<String, String> _languageTags = {'el': 'gr'};

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

  static SportsChannelMatcher? _shared;

  /// One matcher for the whole app (Sports hub, live list, player side
  /// panel): its channel index and guide-scan cache then survive leaving
  /// Sports — a new one per visit re-indexed every channel and re-ran the
  /// guide scan each time the hub was reopened (owner, 2026-10-17).
  static SportsChannelMatcher shared(EpgService epg) {
    final m = _shared;
    if (m != null && identical(m._epg, epg)) return m;
    return _shared = SportsChannelMatcher(epg);
  }

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
      // A Greek club: how a transliterated Greek title spells it (short
      // ones like "aek" included — they're whole words).
      if (greekTeamFor(n) case final greek?) out.addAll(greek.phrases);
    }
    return out.toList();
  }

  /// The name groups a channel name or guide title must all contain (one
  /// phrase from each). Team sports: the two teams. Fights: the two
  /// fighters (tennis: players), by full or last name — event channels say
  /// "Allen vs Duncan".
  /// Golf/racing: the event alone ("singapore grand prix").
  static List<List<String>> _nameGroups(SportsGame g) {
    switch (g.league.kind) {
      case SportsKind.team:
        return [_teamPhrases(g.home), _teamPhrases(g.away)];
      case SportsKind.fight:
      case SportsKind.tennis:
        return [_fighterPhrases(g.home), _fighterPhrases(g.away)];
      case SportsKind.golf:
      case SportsKind.racing:
        final title = sportsNormalize(g.event?.title ?? g.home.name);
        final out = <String>{if (title.trim().length >= 6) title};
        // Sponsors pad the names ("Singapore Airlines Singapore Grand
        // Prix", "Butterfield Bermuda Championship"); guides use the core.
        final words = title.trim().split(' ');
        final gp = title.indexOf(' grand prix ');
        if (gp > 0) {
          final before = title.substring(0, gp).trim().split(' ').last;
          out.add(' $before grand prix ');
        } else if (g.league.kind == SportsKind.golf && words.length > 2) {
          out.add(' ${words.sublist(words.length - 2).join(' ')} ');
        }
        return [out.toList()];
    }
  }

  static const _nameSuffixes = {'jr', 'sr', 'ii', 'iii', 'iv'};

  static List<String> _fighterPhrases(SportsTeam t) {
    final full = sportsNormalize(t.name);
    final words =
        full.trim().split(' ').where((w) => !_nameSuffixes.contains(w));
    final last = words.isEmpty ? null : words.last;
    return {
      if (full.trim().length >= 4) full,
      if (last != null && last.length >= 4) ' $last ',
    }.toList();
  }

  /// When a guide programme for [g] may start: around a game's start; a
  /// fight card's main event comes hours after the prelims; a golf round
  /// runs all day, so its day (today's, while it's on).
  static (DateTime, DateTime) _guideWindow(SportsGame g) {
    if (g.end != null) {
      final now = DateTime.now().toUtc();
      final from = now.isAfter(g.start) &&
              now.isBefore(g.end!.add(const Duration(days: 1)))
          ? now.subtract(const Duration(hours: 2))
          : g.start;
      return (from, from.add(const Duration(hours: 24)));
    }
    // Tennis times are "not before": a match often starts hours late.
    final after = switch (g.league.kind) {
      SportsKind.fight => const Duration(hours: 5),
      SportsKind.tennis => const Duration(hours: 4),
      _ => const Duration(minutes: 30),
    };
    return (g.start.subtract(const Duration(minutes: 60)), g.start.add(after));
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
  ///
  /// A league's own country ([SportsLeague.homeTags]: "gr" for the Greek
  /// leagues) ranks its channels first instead (+20, above English), and so
  /// does the viewer's own when the app is in Greek ([_languageTags]: a Greek
  /// viewer's EuroLeague game listed the Croatian feeds above Nova, owner,
  /// 2026-10-20).
  int _regionBias(int index, [SportsLeague? league]) {
    final tokens = _names[index].trim().split(' ');
    final home = league?.homeTags ?? const <String>[];
    final own = _languageTags[L10n.code];
    var bias = 0;
    for (final t in tokens) {
      if (home.contains(t) || t == own) return 20;
    }
    for (final t in tokens) {
      if (_englishTags.contains(t)) bias = math.max(bias, 10);
      if (_foreignTags.contains(t)) return -30;
    }
    return bias;
  }

  /// The guide title scan, by its window + terms. It's one SQL `LIKE` per
  /// term over the whole guide — on a busy Saturday (dozens of college
  /// games, hundreds of terms) the Formuler took long enough that the Sports
  /// hub stayed on "Looking…", and every 30 s score refresh ran it again.
  /// The guide barely changes, so a hit is reused for 15 minutes, and a
  /// scan already running is shared instead of started twice.
  final Map<String, (Future<List<EpgProgram>>, DateTime)> _guideCache = {};

  Future<List<EpgProgram>> _guideHits(
      DateTime from, DateTime to, Set<String> terms) {
    // A guide refresh changes lastUpdated: rescan at once, not after 15 min.
    final key = '${_epg.lastUpdated?.millisecondsSinceEpoch}|'
        '${from.millisecondsSinceEpoch}|${to.millisecondsSinceEpoch}|'
        '${(terms.toList()..sort()).join('\u0001')}';
    final now = DateTime.now();
    _guideCache.removeWhere(
        (_, v) => now.difference(v.$2) > const Duration(minutes: 15));
    final hit = _guideCache[key];
    if (hit != null) return hit.$1;
    final future = _epg.findProgrammesByTitle(from, to, terms.toList());
    _guideCache[key] = (future, now);
    return future;
  }

  /// Suggestions for every game in [games], keyed by
  /// [SportsChannelPicks.eventKey], best first, at most [limit] each.
  Future<Map<String, List<ChannelMatch>>> matchDay(
      List<SportsGame> games, SportsChannelPicks picks,
      {int limit = 8}) async {
    final out = <String, List<ChannelMatch>>{};
    if (games.isEmpty) return out;

    // One guide query for the whole day. A title must name every group
    // (both teams), and the loop below checks that — so SQL only needs one
    // group per game to find every candidate. Terms containing a shorter
    // term are dropped too ("georgia bulldogs" ⊃ "georgia"). Each term is a
    // LIKE over every guide row of the day: fewer terms, faster hub.
    final raw = <String>{};
    for (final g in games) {
      final groups = _nameGroups(g);
      if (groups.isNotEmpty) {
        for (final p in groups.first) {
          if (p.trim().isNotEmpty) raw.add(p.trim());
        }
      }
      for (final p in g.league.seriesPhrases) {
        if (p.trim().isNotEmpty) raw.add(p.trim());
      }
      // Greek clubs: the guide may write them in Greek. Both teams, since
      // a Latin term can't find a Greek title for the other one.
      for (final t in [g.home, g.away]) {
        final greek = greekTeamFor(sportsNormalize(t.name)) ??
            greekTeamFor(sportsNormalize(t.shortName));
        if (greek != null) raw.addAll(greek.stems);
      }
    }
    final byLength = raw.toList()..sort((a, b) => a.length.compareTo(b.length));
    final terms = <String>{};
    for (final t in byLength) {
      if (!terms.any(t.contains)) terms.add(t);
    }
    var earliest = _guideWindow(games.first).$1;
    var latest = _guideWindow(games.first).$2;
    for (final g in games) {
      final (from, to) = _guideWindow(g);
      if (from.isBefore(earliest)) earliest = from;
      if (to.isAfter(latest)) latest = to;
    }
    final List<EpgProgram> programmes =
        _byEpgId.isEmpty ? const [] : await _guideHits(earliest, latest, terms);

    // Team leagues with series phrases (EuroLeague): a title naming the
    // series but not this game's teams still counts — Greek guides write
    // foreign clubs in Greek ("Euroleague: Χάποελ Τελ Αβίβ - Βίρτους
    // Μπολόνια", user report 2026-10-20) — unless it names another game.
    final groupsByGame = {for (final g in games) g: _nameGroups(g)};
    bool namesOtherGame(SportsGame g, String title) =>
        groupsByGame.entries.any((o) =>
            o.key != g &&
            o.key.league.id == g.league.id &&
            o.value.every((group) => group.any(title.contains)));

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

      // 2. Event channels naming both teams (event sports: the event).
      final groups = groupsByGame[g]!;
      Set<int>? named;
      for (final group in groups) {
        final hits = _channelsNaming(group);
        named = named == null ? hits : named.intersection(hits);
        if (named.isEmpty) break;
      }
      for (final i in named ?? const <int>{}) {
        final d = _dateInName(_names[i]);
        if (d != null && !_dateFits(d, g.start)) continue;
        add(i, MatchReason.name,
            (d != null ? 120 : 100) + _regionBias(i, g.league));
      }

      // 2b. A team's own channel: one team's full name plus the league
      // ("US - NBA TEAMS - ATLANTA HAWKS FHD"). Providers carry every
      // team's local broadcast that way, without a guide (NBA user report,
      // 2026-10-21: Hawks-Magic and Jazz-Grizzlies had nothing else). The
      // full name only — "heat" or "magic" alone would hit other channels.
      if (g.league.kind == SportsKind.team) {
        final league = sportsNormalize(g.league.shortName).trim();
        if (league.length >= 2) {
          for (final t in [g.home, g.away]) {
            final full = sportsNormalize(t.name).trim();
            if (full.split(' ').length < 2) continue;
            for (final i in _channelsNaming([full])) {
              if (!_names[i].trim().split(' ').contains(league)) continue;
              final bias = _regionBias(i, g.league);
              if (bias < 0) continue;
              add(i, MatchReason.name, 65 + bias, t.shortName);
            }
          }
        }
      }

      // 3. Guide programmes naming both teams near the start time — or,
      // for event sports, the event or its series ("Formula 1: Qualifying",
      // "PGA Tour Golf").
      final (from, to) = _guideWindow(g);
      final series = [
        for (final p in g.league.seriesPhrases) sportsNormalize(p)
      ];
      for (final p in programmes) {
        final start = p.start.toUtc();
        if (start.isBefore(from) || !start.isBefore(to)) continue;
        final title = sportsNormalize(p.title);
        final byName = groups.every((group) => group.any(title.contains));
        if (!byName && !series.any(title.contains)) continue;
        if (!byName &&
            g.league.kind == SportsKind.team &&
            namesOtherGame(g, title)) {
          continue;
        }
        final diff = g.end != null
            ? 0 // golf: all day, nothing to be early or late for
            : start.difference(g.start).inMinutes;
        for (final i in _byEpgId[p.channelId] ?? const <int>[]) {
          add(
              i,
              MatchReason.guide,
              (byName ? 80 : 70) -
                  math.min(diff.abs(), 60) ~/ 6 +
                  _regionBias(i, g.league),
              p.title);
        }
      }

      // 3b. Event sports: channels named after the series ("Sky Sports F1",
      // "NASCAR"), a few at most — they carry it, if not always live. Not
      // team leagues: "EuroLeague 03 | ..." channels are one game each.
      if (series.isNotEmpty && g.league.kind != SportsKind.team) {
        var taken = 0;
        for (final i in _channelsNaming(series)) {
          if (taken >= 3) break;
          if (_regionBias(i, g.league) < 0) continue;
          add(i, MatchReason.name, 60 + _regionBias(i, g.league));
          taken++;
        }
      }

      // 4. National networks, exact channel name only — or, for regional
      // networks and local stations, the names they go by
      // ([_networkAliases], [_callSign]).
      for (final network in g.broadcasts) {
        final upper = network.toUpperCase().trim();
        if (_streamingOnly.contains(upper)) continue;
        final key = canonicalChannelKey(network);
        var hits = _byCanonical[key] ?? const <int>[];
        if (hits.isEmpty) {
          final call = _callSign.firstMatch(upper)?.group(1);
          final phrases = _networkAliases[upper] ??
              (call != null ? [call.toLowerCase()] : const <String>[]);
          if (phrases.isNotEmpty) {
            hits = (_channelsNaming(phrases).toList()
                  ..sort(
                      (a, b) => _names[a].length.compareTo(_names[b].length)))
                .toList();
          }
        }
        var taken = 0;
        for (final i in hits) {
          if (taken >= 3) break;
          // Same name, different country's channel ("RU: TNT" is not TNT).
          final bias = _regionBias(i, g.league);
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
