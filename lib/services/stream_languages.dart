// The audio languages a Media Hub stream's label names ("Movie.2012.2160p.
// MULTi.TrueHD", "🇷🇺 / 🇺🇦", "English | Russian"), and how well a stream
// fits the viewer's language. Owner, 2026-11-09: the AI and Auto-play picked
// a Russian dub of an English film; a stream naming only other languages now
// goes after the rest (ArchivePlaybackPreferences.ranked).

/// What a label says about its audio: the languages it names (ISO 639-1)
/// and whether it says several ("MULTi", "Dual audio").
class StreamLanguages {
  const StreamLanguages(this.codes, {this.multi = false});
  final Set<String> codes;
  final bool multi;
}

/// Words that name a language in release names and add-on labels. Only
/// 3-letter codes release names really use: two-letter ones ("it", "de",
/// "es") are ordinary words, and some 3-letter ones are too ("dan", "rum",
/// "vie" in "La Vie en Rose").
const _languageWords = <String, List<String>>{
  'en': ['english', 'eng'],
  'fr': [
    'french', 'français', 'francais', 'truefrench', 'fre', 'fra', 'vff', //
    'vfq', 'vfi', 'vf2', 'vf',
  ],
  'es': ['spanish', 'español', 'espanol', 'castellano', 'latino', 'spa'],
  'de': ['german', 'deutsch', 'ger', 'deu'],
  'it': ['italian', 'italiano', 'ita'],
  'pt': ['portuguese', 'português', 'portugues', 'dublado', 'por'],
  'ru': ['russian', 'русский', 'rus'],
  'uk': ['ukrainian', 'українська', 'ukr'],
  'pl': ['polish', 'polski', 'pol'],
  'nl': ['dutch', 'nederlands', 'dut', 'nld'],
  'ja': ['japanese', 'jpn'],
  'ko': ['korean', 'kor'],
  'zh': ['chinese', 'mandarin', 'cantonese'],
  'hi': ['hindi', 'hin'],
  'tr': ['turkish', 'türkçe', 'turkce', 'tur'],
  'ar': ['arabic', 'ara'],
  'el': ['greek', 'ελληνικά', 'gre', 'ell'],
  'sv': ['swedish', 'svenska', 'swe'],
  'da': ['danish', 'dansk'],
  'no': ['norwegian', 'norsk'],
  'fi': ['finnish', 'suomi'],
  'cs': ['czech', 'čeština', 'cze', 'ces'],
  'hu': ['hungarian', 'magyar', 'hun'],
  'ro': ['romanian', 'română', 'romana'],
  'ta': ['tamil', 'tam'],
  'te': ['telugu', 'tel'],
  'fa': ['persian', 'farsi'],
  'he': ['hebrew', 'heb'],
  'th': ['thai'],
  'vi': ['vietnamese'],
};

/// Flags add-ons put on a stream (Torrentio: "🇷🇺 / 🇺🇦"), by country.
const _flagLanguages = <String, String>{
  'GB': 'en', 'US': 'en', 'FR': 'fr', 'ES': 'es', 'MX': 'es', 'DE': 'de', //
  'IT': 'it', 'PT': 'pt', 'BR': 'pt', 'RU': 'ru', 'UA': 'uk', 'PL': 'pl',
  'NL': 'nl', 'JP': 'ja', 'KR': 'ko', 'CN': 'zh', 'TW': 'zh', 'HK': 'zh',
  'IN': 'hi', 'TR': 'tr', 'SA': 'ar', 'GR': 'el', 'SE': 'sv', 'DK': 'da',
  'NO': 'no', 'FI': 'fi', 'CZ': 'cs', 'HU': 'hu', 'RO': 'ro', 'IL': 'he',
  'TH': 'th', 'VN': 'vi', 'IR': 'fa',
};

final _wordPatterns = {
  for (final e in _languageWords.entries)
    e.key: RegExp('(?<![\\p{L}\\p{N}])(${e.value.join('|')})(?![\\p{L}\\p{N}])',
        caseSensitive: false, unicode: true),
};

/// Subtitle tags name a language that isn't the audio: VOSTFR, SUBFRENCH,
/// "Eng Subs", ESub, "Multi Subs".
final _subtitleTags = RegExp(
    r'(?<![\p{L}\p{N}])(vost\w*|subfrench|subita|e-?subs?|'
    r'[\p{L}]{2,12}[ ._-]?subs?|[\p{L}]{2,12}[ ._-]?subtitles?)'
    r'(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true);

final _multi = RegExp(r'(?<![\p{L}\p{N}])(multi|dual)(?![\p{L}\p{N}])',
    caseSensitive: false, unicode: true);

StreamLanguages streamLanguagesOf(String label) {
  final text = label.replaceAll(_subtitleTags, ' ');
  final codes = <String>{
    for (final e in _wordPatterns.entries)
      if (e.value.hasMatch(text)) e.key,
  };
  final runes = text.runes.toList();
  for (var i = 0; i + 1 < runes.length; i++) {
    final a = runes[i], b = runes[i + 1];
    if (_isIndicator(a) && _isIndicator(b)) {
      final country =
          String.fromCharCodes([a - 0x1F1E6 + 0x41, b - 0x1F1E6 + 0x41]);
      final code = _flagLanguages[country];
      if (code != null) codes.add(code);
      i++;
    }
  }
  return StreamLanguages(codes, multi: _multi.hasMatch(text));
}

bool _isIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

/// How well a stream labelled [label] fits [lang]: 3 = only [lang] (for
/// English, also a label naming no language: untagged releases are
/// English), 2 = [lang] among others or multi-audio, 1 = nothing known, 0 =
/// only other languages (a dub). A multi-audio file's default track can
/// still be another language; Settings > Playback > Audio picks the track.
int streamLanguageFit(String label, String lang) {
  final base = lang.toLowerCase().split(RegExp('[-_]')).first;
  final found = streamLanguagesOf(label);
  if (found.codes.contains(base)) {
    return found.codes.length == 1 && !found.multi ? 3 : 2;
  }
  if (found.codes.isEmpty) {
    return found.multi
        ? 2
        : base == 'en'
            ? 3
            : 1;
  }
  // Flags list the dubs; the English original usually isn't flagged.
  return base == 'en' && found.multi ? 1 : 0;
}

/// [language]'s words, for telling whether a track's name already says its
/// language ("English (Original)" vs "English").
bool namesLanguage(String text, String? language) {
  final base = language?.toLowerCase().split(RegExp('[-_]')).first ?? '';
  final pattern = _wordPatterns[_threeLetter[base] ?? base];
  return pattern != null && pattern.hasMatch(text);
}

const _threeLetter = {
  'eng': 'en', 'fre': 'fr', 'fra': 'fr', 'spa': 'es', 'ger': 'de', //
  'deu': 'de', 'ita': 'it', 'por': 'pt', 'rus': 'ru', 'ukr': 'uk',
  'pol': 'pl', 'dut': 'nl', 'nld': 'nl', 'jpn': 'ja', 'kor': 'ko',
  'chi': 'zh', 'zho': 'zh', 'hin': 'hi', 'tur': 'tr', 'ara': 'ar',
  'gre': 'el', 'ell': 'el', 'swe': 'sv', 'dan': 'da', 'nor': 'no',
  'fin': 'fi', 'cze': 'cs', 'ces': 'cs', 'hun': 'hu', 'rum': 'ro',
  'ron': 'ro', 'tam': 'ta', 'tel': 'te', 'per': 'fa', 'fas': 'fa',
  'heb': 'he', 'tha': 'th', 'vie': 'vi',
};
