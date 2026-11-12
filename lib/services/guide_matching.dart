import 'dart:isolate';
import 'dart:math' as math;

import '../utils/title_search.dart';

/// Fuzzy "which guide channel is this live channel" suggestions, for the
/// `epg_matching` AI tool (owner, 2026-11-12: an AI should be able to link
/// channels the exact Auto-Pair leaves out because of prefixes or spelling).
///
/// Unlike `canonicalChannelKey` (exact token sets, safe to apply blindly),
/// this scores near matches: region tags and quality words are ignored,
/// `TSN1` == `TSN 1`, `BBC One` == `BBC 1`, `SkySports` == `Sky Sports`, a
/// one-letter typo still matches. Numbers must agree (TSN 1 is never TSN 2)
/// and a different region costs points. Only [GuideSuggestion]s that
/// [isSure] are meant to be linked without a look; the AI reviews the rest.
/// See dev-notes/vesper-ai.md (EPG matching tool).

/// A guide channel: an XMLTV `<channel id>` with its display name.
class GuideEntry {
  GuideEntry(
    this.id,
    this.name, {
    this.source = '',
    this.url = '',
    this.live = false,
    List<String>? aliases,
  }) : aliases = aliases ?? [];

  final String id;
  final String name;

  /// Which guide it's from, as the viewer knows it ("Extra guide 1").
  final String source;

  /// The guide's address (never shown: it can carry a login).
  final String url;

  /// The guide has a programme on it right now.
  final bool live;

  /// Other names for the same id (another playlist's channels that use it).
  final List<String> aliases;
}

class GuideSuggestion {
  const GuideSuggestion(this.entry, this.score);
  final GuideEntry entry;

  /// 0..1; 1 = the same name once tags, quality and spacing are ignored.
  final double score;
}

/// Sure enough to link without review: a strong best match that nothing
/// else comes close to (or only another id for the very same name, when
/// just one of them has a programme on now).
bool isSure(List<GuideSuggestion> s) {
  if (s.isEmpty || s.first.score < 0.9) return false;
  if (s.length == 1 || s.first.score - s[1].score >= 0.1) return true;
  final best = s.first;
  final close = [
    for (final x in s)
      if (best.score - x.score < 0.1) x,
  ];
  final sameName = close.every(
    (x) => _key(x.entry.name) == _key(best.entry.name),
  );
  return sameName &&
      best.entry.live &&
      close.where((x) => x.entry.live).length == 1;
}

String _key(String name) => GuideName.parse(name).tokens.join(' ');

/// A channel or guide name taken apart for matching.
class GuideName {
  GuideName(this.tokens, this.region);

  final List<String> tokens;

  /// Two-letter country from a tag (`US:`, `[UK]`, `.ca` on an id), if any.
  final String? region;

  static const _quality = {
    'hd',
    'fhd',
    'uhd',
    'sd',
    'hdr',
    'hevc',
    'h265',
    'h264',
    'raw',
    '4k',
    '8k',
    '2160p',
    '1080p',
    '1080i',
    '720p',
    '50fps',
    '60fps',
    'hq',
    'lq',
    'fullhd',
    'backup',
    'vip',
  };

  static const _numbers = {'one': '1', 'two': '2', 'three': '3', 'four': '4'};

  // A short one-word tag before ":", "|" or " - ", or in brackets ("US:",
  // "|UK|", "[CA]", "AM |"): "ESPN 2 - Live" keeps its name.
  static final _tag = RegExp(
    r'^\s*(?:[\[(|]\s*([^\s\])|:]{1,6})\s*[\])|]|([^\s:|\-\[\]()]{1,6})\s*(?::|\||\s-\s))\s*',
  );
  static final _tailTag = RegExp(r'\s*[\[(]\s*([A-Za-z]{2,3})\s*[\])]\s*$');
  static final _lettersDigits = RegExp(r'^([a-z]+)(\d+)$|^(\d+)([a-z]+)$');
  static final _camel = RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])');

  static String? _region(String tag) {
    final t = tag.trim().toLowerCase();
    if (RegExp(r'^[a-z]{2}$').hasMatch(t)) return t == 'uk' ? 'gb' : t;
    return switch (t) {
      'usa' => 'us',
      'can' => 'ca',
      'gbr' => 'gb',
      _ => null,
    };
  }

  /// A channel's display name.
  factory GuideName.parse(String name) {
    var rest = name;
    String? region;
    // Up to two leading tags: "AM | US: ESPN".
    for (var i = 0; i < 2; i++) {
      final m = _tag.firstMatch(rest);
      if (m == null || m.end >= rest.length) break;
      // The tag next to the name wins ("AM | US:" is US).
      region = _region(m[1] ?? m[2] ?? '') ?? region;
      rest = rest.substring(m.end);
    }
    final tail = _tailTag.firstMatch(rest);
    if (tail != null) {
      region ??= _region(tail[1]!);
      rest = rest.substring(0, tail.start);
    }
    return GuideName(_tokens(rest), region);
  }

  /// An XMLTV id (`ESPN.us`, `BBCOne.uk`, `tsn1-ca`): the part before the
  /// first dot, camel case split; a two-letter last part is the region.
  factory GuideName.fromId(String id) {
    final parts = id.split('.');
    final region = parts.length > 1 ? _region(parts.last) : null;
    final base = parts.first.replaceAll(_camel, ' ');
    return GuideName(_tokens(base), region);
  }

  static List<String> _tokens(String text) {
    final folded = TitleSearch.fold(
      text.replaceAll('+', ' plus ').replaceAll('&', ' and '),
    );
    final out = <String>[];
    for (final w in folded.split(' ')) {
      if (w.isEmpty || _quality.contains(w)) continue;
      final m = _lettersDigits.firstMatch(w);
      if (m != null) {
        out.add(m[1] ?? m[3]!);
        out.add(m[2] ?? m[4]!);
      } else {
        out.add(_numbers[w] ?? w);
      }
    }
    return out;
  }

  bool get isEmpty => tokens.isEmpty;
  String get joined => tokens.join();
  Set<String> get digits => {
        for (final t in tokens)
          if (_isNumber(t)) t,
      };

  static bool _isNumber(String t) => int.tryParse(t) != null;
}

/// Suggests guide channels for channel names; build once per guide set.
class GuideMatcher {
  GuideMatcher(List<GuideEntry> entries) : _entries = entries {
    for (var i = 0; i < entries.length; i++) {
      final id = GuideName.fromId(entries[i].id);
      final display = GuideName.parse(entries[i].name);
      // `CNN.ca` named "CNN": the id's country goes with every name.
      final region = id.region ?? display.region;
      final names = [
        display,
        id,
        for (final a in entries[i].aliases) GuideName.parse(a),
      ]
          .where((n) => !n.isEmpty)
          .map((n) => GuideName(n.tokens, n.region ?? region))
          .toList();
      _names.add(names);
      for (final n in names) {
        (_byJoined[n.joined] ??= []).add(i);
        for (final t in n.tokens.toSet()) {
          (_byToken[t] ??= []).add(i);
          if (t.length >= 5) (_byPrefix[t.substring(0, 4)] ??= []).add(i);
        }
      }
    }
  }

  final List<GuideEntry> _entries;
  final List<List<GuideName>> _names = [];
  final Map<String, List<int>> _byJoined = {};
  final Map<String, List<int>> _byToken = {};
  final Map<String, List<int>> _byPrefix = {};

  /// A token in this many entries says little about which one it is.
  int _df(String t) => _byToken[t]?.length ?? 0;

  double _weight(String t) =>
      GuideName._isNumber(t) ? 2.0 : 1 / math.log(2.7 + _df(t) / 20);

  /// The best [max] guide channels for [channelName], best first; nothing
  /// below 0.5.
  List<GuideSuggestion> suggest(String channelName, {int max = 3}) {
    final name = GuideName.parse(channelName);
    if (name.isEmpty) return const [];
    final pool = <int, int>{};
    void add(Iterable<int>? ids) {
      for (final i in ids ?? const <int>[]) {
        pool[i] = (pool[i] ?? 0) + 1;
      }
    }

    add(_byJoined[name.joined]);
    for (final t in name.tokens.toSet()) {
      if (_df(t) <= 3000) add(_byToken[t]);
    }
    if (pool.length < 5) {
      for (final t in name.tokens) {
        if (t.length >= 5) add(_byPrefix[t.substring(0, 4)]);
      }
    }
    var ids = pool.keys.toList();
    if (ids.length > 1500) {
      ids.sort((a, b) => pool[b]!.compareTo(pool[a]!));
      ids = ids.take(1500).toList();
    }
    final scored = <GuideSuggestion>[];
    for (final i in ids) {
      var best = 0.0;
      for (final n in _names[i]) {
        best = math.max(best, score(name, n));
      }
      if (best >= 0.5) scored.add(GuideSuggestion(_entries[i], best));
    }
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      if (a.entry.live != b.entry.live) return a.entry.live ? -1 : 1;
      return a.entry.name.length.compareTo(b.entry.name.length);
    });
    return scored.take(max).toList();
  }

  /// How alike two names are, 0..1.
  double score(GuideName a, GuideName b) {
    if (a.isEmpty || b.isEmpty) return 0;
    double s;
    if (a.joined == b.joined) {
      s = 1;
    } else {
      s = math.max(
        _tokenScore(a.tokens, b.tokens),
        _similarity(a.joined, b.joined) * 0.95,
      );
    }
    final da = a.digits, db = b.digits;
    if (da.length != db.length || !da.containsAll(db)) s *= 0.4;
    if (a.region != null && b.region != null) {
      s = a.region == b.region ? math.min(1, s + 0.05) : s * 0.75;
    }
    return s;
  }

  /// Weighted Dice over tokens; a token one or two letters off still counts
  /// (most of it).
  double _tokenScore(List<String> a, List<String> b) {
    var wa = 0.0, wb = 0.0, hit = 0.0;
    for (final t in b) {
      wb += _weight(t);
    }
    final left = [...b];
    for (final t in a) {
      final w = _weight(t);
      wa += w;
      var best = -1;
      var near = 0.0;
      for (var j = 0; j < left.length; j++) {
        final u = left[j];
        if (u == t) {
          best = j;
          near = 1;
          break;
        }
        if (GuideName._isNumber(t) || GuideName._isNumber(u)) continue;
        final len = math.max(t.length, u.length);
        if (len < 5) continue;
        final d = _distance(t, u, len >= 9 ? 2 : 1);
        if (d <= (len >= 9 ? 2 : 1) && near < 0.85) {
          best = j;
          near = 0.85;
        }
      }
      if (best >= 0) {
        hit += w * near * 2;
        left.removeAt(best);
      }
    }
    return wa + wb == 0 ? 0 : hit / (wa + wb);
  }

  double _similarity(String a, String b) {
    final len = math.max(a.length, b.length);
    if (len == 0 || len > 40) return 0;
    return 1 - _distance(a, b, len) / len;
  }

  /// Levenshtein distance, giving up past [cap].
  static int _distance(String a, String b, int cap) {
    if ((a.length - b.length).abs() > cap) return cap + 1;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      var rowMin = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = math.min(
          math.min(cur[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
        rowMin = math.min(rowMin, cur[j]);
      }
      if (rowMin > cap) return cap + 1;
      prev = cur;
    }
    return prev[b.length];
  }
}

/// [GuideMatcher.suggest] for many names, off the UI thread (a TV box with
/// a 40,000-channel guide and thousands of channels would stutter).
Future<List<List<GuideSuggestion>>> suggestGuides(
  List<GuideEntry> entries,
  List<String> names, {
  int max = 3,
}) =>
    Isolate.run(() {
      final matcher = GuideMatcher(entries);
      return [for (final n in names) matcher.suggest(n, max: max)];
    });
