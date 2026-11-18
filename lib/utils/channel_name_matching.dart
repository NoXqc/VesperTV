/// Best-effort "is this the same real-world channel" comparison across
/// providers that each name it differently — confirmed against three real
/// providers' own catalogs (see the session this was built in): one uses
/// `NAME | REGION`, one `REGION: NAME`, one `REGION - NAME`, and all three
/// tack on their own mix of quality/format suffixes (`HD`, `HEVC`, `4K`,
/// `RAW`...). Used to power "Auto-Pair Channels" in both the EPG Channel
/// Matching screen and the cross-playlist Channel Linking screen.
///
/// Deliberately conservative: [tokensMatch] requires an *exact* token-set
/// match after normalizing, never a fuzzy/scored similarity. A channel
/// like `CSN BOSTON` and `CSN CALIFORNIA`, or `ESPN` and `ESPN+`, differ
/// by a real identity token (not a stripped quality one), so they never
/// match here — auto-pairing can't afford a confident-looking wrong
/// guess the way a manual search-and-pick screen can, since nobody's
/// eyes are on it to catch the mistake.
library;

/// Pure quality/format markers — safe to discard when comparing names,
/// since they never distinguish one real channel from another the way a
/// region, city, or service-tier word does.
const Set<String> _qualityTokens = {
  'HD',
  'HEVC',
  'UHD',
  'FHD',
  'SD',
  'HDR',
  'H265',
  'H264',
  'RAW',
};

/// Splits off a leading region/category tag before the first `|`, `:`, or
/// ` - ` — whichever a given name actually uses (see this file's own doc
/// comment for the three real conventions this was built against).
/// Leaves the name untouched if none of them appear at all.
String _stripLeadingTag(String name) {
  var bestIndex = -1;
  var bestSepLength = 0;
  for (final sep in const ['|', ':', ' - ']) {
    final idx = name.indexOf(sep);
    if (idx > 0 && (bestIndex == -1 || idx < bestIndex)) {
      bestIndex = idx;
      bestSepLength = sep.length;
    }
  }
  if (bestIndex == -1) return name;
  return name.substring(bestIndex + bestSepLength);
}

/// The token set a channel name reduces to for matching — upper-cased,
/// punctuation-normalized words with the leading region/category tag and
/// any pure quality tokens removed. `+` is kept as part of a word (not
/// treated as punctuation to strip) specifically so `ESPN+` stays
/// distinct from `ESPN` rather than both collapsing to the same token.
Set<String> normalizedChannelTokens(String name) {
  final withoutTag = _stripLeadingTag(name);
  final cleaned = withoutTag.toUpperCase().replaceAll(_punctuation, ' ');
  return cleaned
      .split(_spaces)
      .where((t) => t.isNotEmpty && !_qualityTokens.contains(t))
      .toSet();
}

/// True only on an exact token-set match (both directions, so neither
/// name is missing something the other has) — see this file's own doc
/// comment for why this is exact rather than fuzzy.
bool channelNamesMatch(String a, String b) =>
    canonicalChannelKey(a).isNotEmpty &&
    canonicalChannelKey(a) == canonicalChannelKey(b);

/// [normalizedChannelTokens] collapsed into one comparable/hashable
/// `String` (sorted, so token order in the original name never matters)
/// — lets a bulk "auto-pair everything" operation bucket hundreds or
/// thousands of channels by this key once, up front, rather than
/// recomputing and comparing token sets pairwise for every candidate
/// (quadratic — noticeable on a real catalog this size, not just in
/// theory). Empty for a name that reduces to nothing (rare, but a title
/// that's *only* quality tokens isn't unheard of) — callers treat that as
/// "never matches anything", same as [channelNamesMatch] does.
String canonicalChannelKey(String name) {
  final tokens = normalizedChannelTokens(name).toList()..sort();
  return tokens.join('\u0000');
}

final _lettersThenDigits = RegExp(r'^([A-Z]+)(\d+)$');
// Compiled once: [channelCopyKey] runs on every channel of every playlist.
final _punctuation = RegExp(r'[^\w+]');
final _spaces = RegExp(r'\s+');

/// Resolution/format words that only say which copy of a channel this is.
const Set<String> _copyTokens = {
  ..._qualityTokens,
  '4K',
  '8K',
  '2160P',
  '1080P',
  '720P',
  '50FPS',
  '60FPS',
};

/// Region tags that name the same country (`channelCopyKey`). Quebec is in
/// Canada: one provider lists `QC: TVA MONTREAL`, another `CA| TVA MONTREAL
/// HD` (owner, 2026-11-18: Sources didn't offer his Trex copy).
const Map<String, String> _sameRegion = {
  'QC': 'CA',
  'QUEBEC': 'CA',
  'CAFR': 'CA',
  'FRCA': 'CA',
  'CAEN': 'CA',
  'USA': 'US',
  'GB': 'UK',
};

/// Accented capitals as their plain letter (`MONTRÉAL` = `MONTREAL`): the
/// punctuation pass below would otherwise split the word in two.
const Map<int, String> _plainLetter = {
  0xC0: 'A', 0xC1: 'A', 0xC2: 'A', 0xC3: 'A', 0xC4: 'A', 0xC5: 'A', //
  0xC7: 'C',
  0xC8: 'E', 0xC9: 'E', 0xCA: 'E', 0xCB: 'E', //
  0xCC: 'I', 0xCD: 'I', 0xCE: 'I', 0xCF: 'I', //
  0xD1: 'N',
  0xD2: 'O', 0xD3: 'O', 0xD4: 'O', 0xD5: 'O', 0xD6: 'O', 0xD8: 'O', //
  0xD9: 'U', 0xDA: 'U', 0xDB: 'U', 0xDC: 'U', //
  0xDD: 'Y',
};

String _plainUpper(String text) {
  final upper = text.toUpperCase();
  if (upper.codeUnits.every((c) => c < 128)) return upper;
  final out = StringBuffer();
  for (final c in upper.codeUnits) {
    final plain = _plainLetter[c];
    plain == null ? out.writeCharCode(c) : out.write(plain);
  }
  return out.toString();
}

/// Same real channel, different quality copy (`CA: TSN 1 4K` / `CA: TSN 1
/// FHD` / `CA: TSN 1 HD`): the leading region tag is kept, unlike
/// [canonicalChannelKey] — `US: ESPN` and `CA: ESPN` air different things —
/// but tags of one country are one tag ([_sameRegion]: `QC` = `CA`), and
/// accents don't count. Anything else that differs (East/West, 1/2,
/// ESPN/ESPN+) keeps them apart.
String channelCopyKey(String name) {
  final rest = _stripLeadingTag(name);
  final rawTag = _plainUpper(name.substring(0, name.length - rest.length))
      .replaceAll(_punctuation, '');
  final tag = _sameRegion[rawTag] ?? rawTag;
  final tokens = _plainUpper(rest)
      .replaceAll(_punctuation, ' ')
      .split(_spaces)
      .where((t) => t.isNotEmpty && !_copyTokens.contains(t))
      // `TSN2` == `TSN 2` (Trex lists both spellings, playlist editor
      // test 2026-11-02): letters followed by a number become two words.
      // Quality tags were removed first, so `4K` is never split.
      .expand((t) => switch (_lettersThenDigits.firstMatch(t)) {
            final m? => [m[1]!, m[2]!],
            null => [t],
          })
      .toList()
    ..sort();
  return tokens.isEmpty ? '' : '$tag|${tokens.join(' ')}';
}

/// Cheap pre-check before [channelCopyKey] (big playlists): [name] can only
/// have a key holding [probe] if it contains it, upper-cased, or has
/// accented letters (`MONTRÉAL` holds `MONTREAL` once folded).
bool channelCopyMayMatch(String name, String probe) {
  if (probe.isEmpty) return true;
  final upper = name.toUpperCase();
  return upper.contains(probe) || upper.codeUnits.any((c) => c >= 128);
}

/// The longest word of a [channelCopyKey] key (`TSN` in `CA|1 TSN`), '' when
/// none: every name with that key holds it, upper-cased, so a cheap
/// `contains` skips most channels before their own [channelCopyKey].
String channelCopyProbe(String key) {
  final words = key.substring(key.indexOf('|') + 1).split(' ');
  return words.fold('', (a, b) => b.length > a.length ? b : a);
}
