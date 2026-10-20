/// Greek channel names and guide titles ("Ολυμπιακός - ΠΑΟΚ") for the
/// Sports Trak channel matcher (user request, 2026-10-20: no app matched
/// Greek channels). Two pieces:
///
/// * [greekToLatin] turns Greek script into the Latin spelling the score
///   feeds use, so a normalized title compares with a team name.
/// * [greekTeamNames]: per club, the extra Latin spellings a transliterated
///   title produces (Ολυμπιακός → "olympiakos", the feeds say
///   "Olympiacos") and the Greek stems the guide query looks for (SQL
///   `LIKE` only folds ASCII case, so lower and upper case are both listed;
///   stems end before accents and case endings).
library;

/// True when [s] has any Greek letter.
bool hasGreek(String s) {
  for (final r in s.runes) {
    if ((r >= 0x370 && r <= 0x3ff) || (r >= 0x1f00 && r <= 0x1fff)) {
      return true;
    }
  }
  return false;
}

/// Simplified ELOT 743, lower case: digraphs first (ου → ou, ει/οι → i,
/// αυ/ευ → av/ev), then letter by letter; anything not Greek is kept.
String greekToLatin(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  var i = 0;
  while (i < lower.length) {
    final two =
        i + 1 < lower.length ? _plain(lower[i]) + _plain(lower[i + 1]) : '';
    final digraph = _digraphs[two];
    if (digraph != null) {
      out.write(digraph);
      i += 2;
      continue;
    }
    out.write(_letters[lower[i]] ?? lower[i]);
    i++;
  }
  return out.toString();
}

/// A letter without its accent, for the digraph lookup (ού, εί, αύ).
String _plain(String ch) => _unaccented[ch] ?? ch;

const _unaccented = {
  'ά': 'α',
  'έ': 'ε',
  'ή': 'η',
  'ί': 'ι',
  'ό': 'ο',
  'ύ': 'υ',
  'ώ': 'ω',
  'ϊ': 'ι',
  'ΐ': 'ι',
  'ϋ': 'υ',
  'ΰ': 'υ',
};

const _digraphs = {
  'ου': 'ou',
  'ει': 'i',
  'οι': 'i',
  'αυ': 'av',
  'ευ': 'ev',
};

const _letters = {
  'α': 'a',
  'ά': 'a',
  'β': 'v',
  'γ': 'g',
  'δ': 'd',
  'ε': 'e',
  'έ': 'e',
  'ζ': 'z',
  'η': 'i',
  'ή': 'i',
  'θ': 'th',
  'ι': 'i',
  'ί': 'i',
  'ϊ': 'i',
  'ΐ': 'i',
  'κ': 'k',
  'λ': 'l',
  'μ': 'm',
  'ν': 'n',
  'ξ': 'x',
  'ο': 'o',
  'ό': 'o',
  'π': 'p',
  'ρ': 'r',
  'σ': 's',
  'ς': 's',
  'τ': 't',
  'υ': 'y',
  'ύ': 'y',
  'ϋ': 'y',
  'ΰ': 'y',
  'φ': 'f',
  'χ': 'ch',
  'ψ': 'ps',
  'ω': 'o',
  'ώ': 'o',
};

class GreekTeamName {
  const GreekTeamName(
      {required this.keys, this.phrases = const [], required this.stems});

  /// Normalized words of the feed's team name that identify the club
  /// (' olympiacos ', ' aek '); any one is enough.
  final List<String> keys;

  /// Extra normalized phrases a transliterated Greek title uses for it.
  final List<String> phrases;

  /// Raw Greek substrings for the guide query.
  final List<String> stems;
}

/// The clubs of the Super League, Super League 2 and the Basket League
/// most often on Greek channels (football and basketball share names).
const List<GreekTeamName> greekTeamNames = [
  GreekTeamName(
      keys: [' olympiacos ', ' olympiakos '],
      phrases: [' olympiakos ', ' olympiacos '],
      stems: ['Ολυμπιακ', 'ΟΛΥΜΠΙΑΚ']),
  GreekTeamName(
      keys: [' panathinaikos '],
      phrases: [' panathinaikos ', ' pao '],
      stems: ['Παναθηνα', 'ΠΑΝΑΘΗΝΑ', 'ΠΑΟ']),
  GreekTeamName(keys: [' paok '], phrases: [' paok '], stems: ['ΠΑΟΚ']),
  GreekTeamName(keys: [' aek '], phrases: [' aek '], stems: ['ΑΕΚ']),
  GreekTeamName(
      keys: [' aris '], phrases: [' aris '], stems: ['Άρη', 'Αρη', 'ΑΡΗ']),
  GreekTeamName(keys: [' ofi '], phrases: [' ofi '], stems: ['ΟΦΗ']),
  GreekTeamName(
      keys: [' asteras '],
      phrases: [' asteras '],
      stems: ['Αστέρα', 'Αστερα', 'ΑΣΤΕΡΑ']),
  GreekTeamName(
      keys: [' atromitos '],
      phrases: [' atromitos '],
      stems: ['Ατρόμητ', 'Ατρομητ', 'ΑΤΡΟΜΗΤ']),
  GreekTeamName(
      keys: [' levadiakos ', ' levadeiakos '],
      phrases: [' levadiakos '],
      stems: ['Λεβαδειακ', 'ΛΕΒΑΔΕΙΑΚ']),
  GreekTeamName(
      keys: [' volos '], phrases: [' volos '], stems: ['Βόλο', 'Βολο', 'ΒΟΛΟ']),
  GreekTeamName(
      keys: [' kifisia ', ' kifissia ', ' kifisias '],
      phrases: [' kifisia ', ' kifisias '],
      stems: ['Κηφισι', 'ΚΗΦΙΣΙ']),
  GreekTeamName(
      keys: [' panserraikos '],
      phrases: [' panserraikos '],
      stems: ['Πανσερρα', 'ΠΑΝΣΕΡΡΑ']),
  GreekTeamName(
      keys: [' panetolikos ', ' panaitolikos '],
      phrases: [' panaitolikos ', ' panetolikos '],
      stems: ['Παναιτωλικ', 'ΠΑΝΑΙΤΩΛΙΚ']),
  GreekTeamName(
      keys: [' ael ', ' larisa ', ' larissa '],
      phrases: [' ael ', ' larisa '],
      stems: ['ΑΕΛ', 'Λάρισ', 'Λαρισ', 'ΛΑΡΙΣ']),
  GreekTeamName(
      keys: [' iraklis '], phrases: [' iraklis '], stems: ['Ηρακλ', 'ΗΡΑΚΛ']),
  GreekTeamName(
      keys: [' peristeri '],
      phrases: [' peristeri '],
      stems: ['Περιστέρ', 'Περιστερ', 'ΠΕΡΙΣΤΕΡ']),
  GreekTeamName(
      keys: [' promitheas ', ' promethean '],
      phrases: [' promitheas '],
      stems: ['Προμηθ', 'ΠΡΟΜΗΘ']),
  GreekTeamName(
      keys: [' panionios '],
      phrases: [' panionios '],
      stems: ['Πανιών', 'Πανιων', 'ΠΑΝΙΩΝ']),
  GreekTeamName(
      keys: [' kolossos '],
      phrases: [' kolossos '],
      stems: ['Κολοσσ', 'ΚΟΛΟΣΣ']),
  GreekTeamName(
      keys: [' mykonos '],
      phrases: [' mykonos '],
      stems: ['Μύκον', 'Μυκον', 'ΜΥΚΟΝ']),
  GreekTeamName(
      keys: [' karditsa '],
      phrases: [' karditsa '],
      stems: ['Καρδίτσ', 'Καρδιτσ', 'ΚΑΡΔΙΤΣ']),
  GreekTeamName(
      keys: [' maroussi ', ' marousi '],
      phrases: [' marousi '],
      stems: ['Μαρούσ', 'Μαρουσ', 'ΜΑΡΟΥΣ']),
  GreekTeamName(
      keys: [' lavrio ', ' lavrion '],
      phrases: [' lavrio '],
      stems: ['Λαύρι', 'Λαυρι', 'ΛΑΥΡΙ']),
];

/// The [greekTeamNames] entry for a team's normalized name, if any.
GreekTeamName? greekTeamFor(String normalizedName) {
  for (final t in greekTeamNames) {
    if (t.keys.any(normalizedName.contains)) return t;
  }
  return null;
}
