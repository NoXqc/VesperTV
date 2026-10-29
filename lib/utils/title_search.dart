/// Shared title matching for local catalogs and Media Hub search.
/// Keep Unicode letters; punctuation and word spacing are interchangeable.
class TitleSearch {
  TitleSearch(String query)
      : folded = fold(query),
        compact = key(query),
        terms =
            fold(query).split(' ').where((s) => s.isNotEmpty).toSet().toList();

  final String folded;
  final String compact;
  final List<String> terms;
  bool get isEmpty => compact.isEmpty;

  static final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static const _accents = {
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđ',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
    'α': 'ά',
    'ε': 'έ',
    'η': 'ή',
    'ι': 'ίϊΐ',
    'ο': 'ό',
    'υ': 'ύϋΰ',
    'ω': 'ώ',
    'σ': 'ς',
  };
  static final _replacements = <String, String>{
    for (final entry in _accents.entries)
      for (final ch in entry.value.split('')) ch: entry.key,
    'œ': 'oe',
    'æ': 'ae',
    'ß': 'ss',
  };

  /// Folded titles, remembered: Search folds every channel/title name on
  /// each rebuild, and the same names come back on every keystroke.
  static final Map<String, String> _folded = {};
  static final Map<String, String> _joined = {};
  static const _cacheMax = 60000;

  static String fold(String text) {
    final hit = _folded[text];
    if (hit != null) return hit;
    final out = _fold(text);
    if (_folded.length >= _cacheMax) _folded.clear();
    return _folded[text] = out;
  }

  static String _fold(String text) {
    final lower = text.toLowerCase();
    final units = lower.codeUnits;
    if (units.every((c) => c < 128)) {
      // ASCII: letters/digits kept, every other run becomes one space.
      final out = StringBuffer();
      var gap = false;
      for (final c in units) {
        if ((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39)) {
          if (gap && out.isNotEmpty) out.write(' ');
          gap = false;
          out.writeCharCode(c);
        } else {
          gap = true;
        }
      }
      return out.toString();
    }
    final out = StringBuffer();
    for (final c in units) {
      if (c >= 0x300 && c <= 0x36f) continue;
      final ch = String.fromCharCode(c);
      out.write(_replacements[ch] ?? ch);
    }
    return out.toString().replaceAll(_separators, ' ').trim();
  }

  /// Uncached: the catalog database keys every synced title through here.
  static String key(String text) => _fold(text).replaceAll(' ', '');

  static String _joinedFold(String text) {
    final hit = _joined[text];
    if (hit != null) return hit;
    if (_joined.length >= _cacheMax) _joined.clear();
    return _joined[text] = fold(text).replaceAll(' ', '');
  }

  /// Lower ranks win; all query words may match in a different order.
  int? rank(String title) {
    if (isEmpty) return null;
    final name = fold(title);
    final joined = _joinedFold(title);
    if (joined.startsWith(compact)) return 0;
    if (' $name'.contains(' $folded')) return 1;
    if (joined.contains(compact)) return 2;
    if (terms.every(joined.contains)) return 3;
    return null;
  }

  bool matches(String title) => rank(title) != null;

  /// At most three requests. Full variants preserve provider alias matches;
  /// the short prefix only discovers joined compounds and is filtered locally.
  List<({String text, bool broad})> remoteQueries(String original) {
    if (isEmpty) return const [];
    final queries = <({String text, bool broad})>[];
    final seen = <String>{};
    void add(String text, {bool broad = false}) {
      if (seen.add(text.toLowerCase())) queries.add((text: text, broad: broad));
    }

    add(original.trim());
    add(folded);
    if (terms.length > 1) {
      add(compact);
    } else if (compact.runes.length >= 6) {
      add(String.fromCharCodes(compact.runes.take(4)), broad: true);
    }
    return queries.take(3).toList();
  }
}
