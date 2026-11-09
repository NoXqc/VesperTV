import '../../utils/title_search.dart';

/// A sentence understood without any AI: which tool to run with what.
class VesperCommand {
  const VesperCommand(this.tool, [this.args = const {}]);
  final String tool;
  final Map<String, Object?> args;

  @override
  String toString() => '$tool $args';
}

/// The built-in commands: everyday remote things said in English, French,
/// Spanish, Italian, German or Greek ("play TSN 1", "mets RDS", "pause",
/// "go back 30 seconds", "what's on", "open the movies", "put on the Habs
/// game"). Free and offline; anything else goes to the viewer's own AI
/// when one is set (Settings > Vesper AI). Null = not a built-in command.
///
/// Matching is done on [TitleSearch.fold]ed text (lowercase, no accents,
/// punctuation as spaces), so the patterns below are written that way.
VesperCommand? parseVesperCommand(String spoken) {
  final folded = TitleSearch.fold(spoken).trim();
  // Before the fillers: "what can you do" holds one ("can you").
  if (_help.contains(folded)) return const VesperCommand('help');
  var s = ' $folded ';
  // Politeness and the assistant's name never change the command.
  for (final filler in _fillers) {
    s = s.replaceAll(' $filler ', ' ');
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return null;

  if (_isOneOf(s, _pause)) {
    return const VesperCommand('player', {'action': 'pause'});
  }
  if (_isOneOf(s, _resume)) {
    return const VesperCommand('player', {'action': 'resume'});
  }
  if (_isOneOf(s, _stop)) {
    return const VesperCommand('player', {'action': 'stop'});
  }
  if (_isOneOf(s, _nextEpisode)) {
    return const VesperCommand('player', {'action': 'next_episode'});
  }
  if (_isOneOf(s, _previousEpisode)) {
    return const VesperCommand('player', {'action': 'previous_episode'});
  }
  if (_isOneOf(s, _channelUp)) {
    return const VesperCommand('player', {'action': 'channel_up'});
  }
  if (_isOneOf(s, _channelDown)) {
    return const VesperCommand('player', {'action': 'channel_down'});
  }
  if (_isOneOf(s, _live)) {
    return const VesperCommand('player', {'action': 'back_to_live'});
  }
  if (_isOneOf(s, _whatsOn)) return const VesperCommand('now_playing');
  if (_isOneOf(s, _recent)) return const VesperCommand('recent');
  if (_isOneOf(s, _favouriteAdd)) {
    return const VesperCommand(
        'favorites', {'action': 'add', 'ref': 'current'});
  }
  if (_isOneOf(s, _favouriteRemove)) {
    return const VesperCommand(
        'favorites', {'action': 'remove', 'ref': 'current'});
  }
  if (_isOneOf(s, _favouriteList)) {
    return const VesperCommand('favorites', {'action': 'list'});
  }
  if (_isOneOf(s, _sportsToday)) return const VesperCommand('sports_today');
  if (_isOneOf(s, _help)) return const VesperCommand('help');
  if (_isOneOf(s, _watchListShow)) {
    return const VesperCommand('watchlist', {'action': 'list'});
  }
  if (_isOneOf(s, _watchListAdd)) {
    return const VesperCommand(
        'watchlist', {'action': 'add', 'ref': 'current'});
  }
  for (final verb in _watchListAddVerbs) {
    final m = RegExp('^$verb (.+?) (?:to|on|a|dans|en|alla|zur|auf) '
            r'(?:my |ma |mi |la mia |meine )?(?:watch ?list|liste|lista|merkliste)$')
        .firstMatch(s);
    final name = _strip(m?.group(1) ?? '');
    if (name.isNotEmpty && name != 'this' && name != 'ca') {
      return VesperCommand('watchlist', {'action': 'add', 'name': name});
    }
  }

  final seek = _seek(s);
  if (seek != null) return seek;

  // "which channels have the Habs game", "quelle chaine passe le match du
  // Canadien": the bubble lists that game's channels ("play it on RDS"
  // then picks one, see VesperAi).
  for (final p in _feedQuestions) {
    final team = _gameTeam(p.firstMatch(s)?.group(1) ?? '');
    if (team.isNotEmpty) {
      return VesperCommand('play_game', {'team': team, 'list': true});
    }
  }

  // "find the English feed of the Habs game", "le match du Canadien en
  // anglais": the game, on a channel in that language.
  final (language, withoutLanguage) = _language(s);
  if (language != null) {
    for (final p in _gamePatterns) {
      final team =
          _strip(p.firstMatch(withoutLanguage)?.group(1)?.trim() ?? '');
      if (team.isNotEmpty) {
        return VesperCommand('play_game', {'team': team, 'language': language});
      }
    }
  }

  // "continue watching Spider-Man in Media Hub", "reprends Severance": Media
  // Hub's Continue watching, from where it stopped (owner, 2026-11-09).
  final going = _continueTitle(s);
  if (going != null) {
    return VesperCommand('media_hub', {'action': 'continue', 'query': going});
  }
  // "play Carrie in Media Hub": that title, not a channel named so.
  final hubbed = _hubSuffix.firstMatch(s)?.group(1);
  if (hubbed != null) {
    for (final verb in _playVerbs) {
      final title = _strip(_after(hubbed, verb) ?? '');
      if (title.isNotEmpty) {
        return VesperCommand('media_hub', {'action': 'play', 'query': title});
      }
    }
  }

  // "open Carrie in Media Hub", "find dune in movies": the search page
  // (it has a Media Hub section) with just the title.
  final scoped = _scopedTitle(s);
  if (scoped != null) {
    return VesperCommand('open', {'section': scoped.$1, 'query': scoped.$2});
  }

  // "open the movies", "ouvre le guide", "go to sports"...
  for (final verb in _openVerbs) {
    final rest = _after(s, verb);
    if (rest == null) continue;
    final section = _section(rest);
    if (section != null) return VesperCommand('open', {'section': section});
  }
  final bare = _section(s);
  if (bare != null && s.split(' ').length <= 3) {
    return VesperCommand('open', {'section': bare});
  }

  // "play it on RDS", "mets-le sur RDS": a channel of the game just listed
  // (VesperAi remembers it), else that channel.
  for (final p in _playItOn) {
    final name = _strip(p.firstMatch(s)?.group(1)?.trim() ?? '');
    if (name.isNotEmpty) return VesperCommand('play_feed', {'name': name});
  }

  // "show me all TSN", "every CBS channel", "toutes les chaines TSN": the
  // search page lists every match to pick from (play picks just one).
  final many = _listAll(s);
  if (many != null) {
    final section = _section(many);
    if (section != null) return VesperCommand('open', {'section': section});
    return VesperCommand('open', {'section': 'search', 'query': many});
  }

  // "open PPV", "go to the Live Events category": that live group (the
  // tool falls back to the search page when no group has that name).
  for (final verb in _openVerbs) {
    final rest = _after(s, verb);
    if (rest == null || rest.isEmpty) continue;
    final group = _groupName(verb, rest);
    if (group != null) {
      return VesperCommand('open', {'section': 'group', 'query': group});
    }
  }

  // "search for dune", "cherche dune" (the search page, with the words).
  for (final verb in _searchVerbs) {
    final rest = _after(s, verb);
    if (rest != null && rest.isNotEmpty) {
      // "search project x movie": every search word must be in a title, so
      // "movie" hid the IPTV "EN - Project X - 2012" (owner, 2026-11-07).
      // The kind word is dropped; a bare "search movie" stays as it is.
      final (_, title) = _kindOf(rest);
      return VesperCommand(
          'open', {'section': 'search', 'query': title.isEmpty ? rest : title});
    }
  }

  // "when is the simpsons on", "quand joue le canadien".
  for (final p in _whenOn) {
    final title = _strip(p.firstMatch(s)?.group(1)?.trim() ?? '');
    if (title.isNotEmpty) {
      return VesperCommand('find_on_tv', {'title': title});
    }
  }

  // "what's on tsn 1" = that channel's guide.
  for (final p in _whatsOnChannel) {
    final rest = _after(s, p);
    if (rest != null && rest.isNotEmpty) {
      return VesperCommand('guide', {'name': _strip(rest)});
    }
  }

  // "put on the habs game", "le match du canadien". Never a question:
  // "what are the habs feeds for tonight's game" is no team name.
  if (RegExp(r'^(?:what|which|where|who|when|how|is|are|do|does|quel|quelle|'
          r'quels|quelles|ou|est ce|que|cual|cuales|quale|quali|welche|wo) ')
      .hasMatch(s)) {
    return null;
  }
  for (final p in _gamePatterns) {
    final team = _strip(p.firstMatch(s)?.group(1)?.trim() ?? '');
    if (team.isNotEmpty) {
      return VesperCommand('play_game', {'team': team});
    }
  }

  // "play tsn 1", "mets rds", "watch dune".
  for (final verb in _playVerbs) {
    final rest = _after(s, verb);
    if (rest == null || rest.isEmpty) continue;
    final (kind, name) = _kindOf(_strip(rest));
    if (name.isEmpty) continue;
    return VesperCommand(
        'play', {'name': name, if (kind != null) 'kind': kind});
  }
  return null;
}

bool _isOneOf(String s, List<String> phrases) => phrases.contains(s);

/// What follows [verb] at the start of [s], or null.
String? _after(String s, String verb) {
  if (s == verb) return '';
  if (s.startsWith('$verb ')) return s.substring(verb.length + 1).trim();
  return null;
}

/// Drops a leading article / "channel" word: "the simpsons" -> "simpsons".
String _strip(String s) {
  var out = ' $s ';
  for (final a in _articles) {
    if (out.startsWith(' $a ')) out = out.substring(a.length + 1);
  }
  return out.trim();
}

(String?, String) _kindOf(String rest) {
  for (final e in _kindWords.entries) {
    // Longest first: "project x the movie" drops "the movie", not "movie".
    for (final w in [...e.value]..sort((a, b) => b.length - a.length)) {
      if (rest.startsWith('$w ')) {
        return (e.key, _strip(rest.substring(w.length)));
      }
      if (rest.endsWith(' $w')) {
        return (e.key, _strip(rest.substring(0, rest.length - w.length)));
      }
    }
  }
  return (null, rest);
}

String? _section(String rest) {
  final r = _strip(rest);
  for (final e in _sections.entries) {
    if (e.value.contains(r)) return e.key;
  }
  return null;
}

/// The words after "all": null when [s] doesn't ask for every match.
String? _listAll(String s) {
  // "the all star game" is a game, not a list.
  if (RegExp(r' (?:game|games|match)$').hasMatch(s)) return null;
  for (final p in _listAllPatterns) {
    final m = p.firstMatch(s);
    if (m == null) continue;
    var words = _strip(m.group(1)!.trim());
    // "CBS west and east": both feeds = every CBS.
    final parts = words.split(' ');
    if (parts.contains('east') && parts.contains('west')) {
      words = parts
          .where((w) =>
              !const {'east', 'west', 'and', 'et', 'y', 'e', 'und'}.contains(w))
          .join(' ');
    }
    if (words.isNotEmpty) return words;
  }
  return null;
}

final _listAllPatterns = [
  RegExp(r'^(?:show me|show|list|see|give me|find|search for|search|get)? ?'
      r'(?:me )?(?:all|every|each)(?: of)? (?:the |my )?(.+?)'
      r'(?: channels?| feeds?| options| versions| stations?)?$'),
  RegExp(r'^(?:show me|show|list|find|search for|search)(?: me)? (?:the |my )?'
      r'(.+?) (?:channels|feeds|options|versions|stations)$'),
  RegExp(r'^(?:which|what) (.+?) channels?'
      r'(?: are there| do i have| do we have| are on)?$'),
  RegExp(r'^(?:montre moi|montre|affiche|trouve|cherche|liste)? ?(?:moi )?'
      r'(?:toutes|tous) (?:les )?(?:chaines |canaux )?(.+?)(?: chaines)?$'),
  RegExp(r'^(?:muestrame|muestra|busca|lista)? ?(?:me )?(?:todos|todas) '
      r'(?:los |las )?(?:canales )?(.+)$'),
  RegExp(r'^(?:mostrami|mostra|cerca|elenca)? ?(?:mi )?(?:tutti|tutte) '
      r'(?:i |le )?(?:canali )?(.+)$'),
  RegExp(r'^(?:zeig mir|zeig|zeige|suche|such|liste)? ?(?:mir )?alle '
      r'(?:sender |kanale )?(.+)$'),
];

/// A team out of a feed question: "the habs", "tonight s habs" -> "habs".
String _gameTeam(String raw) {
  var t = ' ${raw.trim()} ';
  for (final w in const [
    'tonight s',
    'tonights',
    'tonight',
    'today s',
    'todays',
    'today',
    'ce soir',
    'aujourd hui',
    'stasera',
    'oggi',
    'esta noche',
    'hoy',
    'heute abend',
    'heute',
  ]) {
    t = t.replaceAll(' $w ', ' ');
  }
  return _strip(t.trim());
}

const _channelWords = r'(?:channels?|feeds?|stations?|networks?)';
const _gameWords = r'(?:game|match|matchup)';

/// Questions asking which channels carry a game (group 1 = the team).
final _feedQuestions = [
  // "which channels have the habs game", "what channel is the habs game on"
  RegExp('^(?:what|which) $_channelWords '
      r'(?:is|are|has|have|carry|carries|show|shows|air|airs|got)? ?'
      r'(?:showing |airing |carrying |playing )?(?:the )?(.+?) '
      '$_gameWords(?: on| tonight| today)*\$'),
  // "what are the montreal canadiens feeds for tonight's game"
  RegExp(r'^(?:what|which) (?:are|is) (?:the )?(.+?) '
      '$_channelWords (?:for|of) (?:the |tonight s |tonights |today s )?'
      '$_gameWords(?: tonight| today)?\$'),
  // "where can i watch the habs game", "where is the habs game on"
  RegExp(r'^where (?:can i watch|can i see|is|s) (?:the )?(.+?) '
      '$_gameWords(?: on| tonight| today)*\$'),
  // No "game" word, a team playing (owner's phone, 2026-11-07): "what
  // channel are the montreal canadiens playing tonight", "what channel do
  // the habs play on", "on which channel are the habs playing today".
  // Only with play/playing: "what channel is jeopardy on" is no team.
  RegExp('^(?:on )?(?:what|which) $_channelWords '
      r'(?:are|is|do|does|will) (?:the )?(.+?) (?:playing|play|plays|be playing)'
      r'(?: on)?(?: tonight| today)*$'),
  // "sur quelle chaine jouent les canadiens ce soir", "a quel poste joue
  // le canadien" (folded: no accents; "ce soir" is dropped by _gameTeam).
  RegExp(r'^(?:sur |a )?(?:quel|quelle|quels|quelles) (?:chaine|chaines|'
      r'poste|postes|canal|canaux) (?:jouent|joue) (?:les |le |la |l )?(.+)$'),
  RegExp(r'^(?:sur )?(?:quel|quelle|quels|quelles) (?:chaine|chaines|poste|'
      r'postes|canal|canaux) (?:a|ont|passe|passent|diffuse|diffusent|montre|'
      r'montrent|est|joue|presente)? ?(?:le |ce )?match (?:des |du |de la |'
      r'de l |de |d )?(.+)$'),
  RegExp(r'^(?:que|cual|cuales|en que) canal(?:es)? (?:tiene|tienen|da|dan|'
      r'pasa|pasan|transmite|transmiten|echa|echan)? ?(?:el )?partido (?:del |'
      r'de los |de la |de )?(.+)$'),
  RegExp(r'^(?:quale|quali|che|su che) canal[ei] (?:ha|hanno|da|danno|'
      r'trasmette|trasmettono|fa|fanno)? ?(?:la )?partita (?:del |della |dei |'
      r'di )?(.+)$'),
  RegExp(r'^(?:welche|welcher|auf welchem) sender (?:zeigt|zeigen|hat|haben|'
      r'ubertragt|ubertragen|bringt)? ?(?:das )?spiel (?:von |der |des )?(.+)$'),
];

/// "play it on rds": group 1 = the channel.
final _playItOn = [
  RegExp(r'^(?:play|put|watch|show|turn|switch|change) (?:it|that|this|'
      r'that one|the game|the match|this game|that game) (?:on|to|over to) '
      r'(.+)$'),
  RegExp(r'^(?:mets|met|mettre|joue|regarde|passe|change) (?:le|la|ca|ce '
      r'match|le match) (?:sur|a) (.+)$'),
  RegExp(r'^(?:ponlo|ponla|pon el partido|ver el partido) (?:en) (.+)$'),
  RegExp(r'^(?:mettilo|mettila|metti la partita|guarda la partita) '
      r'(?:su|sul|sulla) (.+)$'),
  RegExp(r'^(?:zeig es|spiel es|zeig das spiel|schalte das spiel) auf (.+)$'),
];

/// "open carrie in media hub" -> (hub, carrie): the Media Hub searches it
/// itself; any other place ("in movies") is the search page. Null without
/// a place.
(String, String)? _scopedTitle(String s) {
  final m = _scopeSuffix.firstMatch(s);
  if (m == null) return null;
  final head = m.group(1)!;
  final section = const {'media hub', 'mediahub', 'hub'}.contains(m.group(2))
      ? 'hub'
      : 'search';
  for (final verb in [..._searchVerbs, ..._openVerbs]) {
    final rest = _after(head, verb);
    if (rest == null) continue;
    final title = _strip(rest);
    // "open the guide in the hub" etc. stay what they were.
    if (title.isEmpty || _section(title) != null) return null;
    return (section, title);
  }
  return null;
}

/// The title after a "continue watching" verb, "in Media Hub" or not; null
/// when [s] isn't one ("continue" alone resumes the player, "resume
/// playback" too).
String? _continueTitle(String s) {
  final head = _hubSuffix.firstMatch(s)?.group(1) ?? s;
  // Longest first: "continuer de regarder dune" isn't "continuer" + the rest.
  for (final verb in [..._continueVerbs]..sort((a, b) => b.length - a.length)) {
    final title = _strip(_after(head, verb) ?? '');
    if (title.isEmpty) continue;
    if (_notATitle.contains(title) || _section(title) != null) return null;
    return title;
  }
  return null;
}

final _hubSuffix = RegExp(
    r'^(.+?) (?:in|on|from|dans|sur|en|nel|nella|in der|im|auf|apo) '
    r'(?:the |le |la |l |el |il |der |dem |my )?(?:media hub|mediahub|hub)$');

const _continueVerbs = [
  'continue watching',
  'keep watching',
  'resume watching',
  'finish watching',
  'continue',
  'resume',
  'continue de regarder',
  'continuer de regarder',
  'continuer a regarder',
  'reprends',
  'reprendre',
  'continuer',
  'sigue viendo',
  'seguir viendo',
  'continuar viendo',
  'reanudar',
  'continuar',
  'continua a guardare',
  'continua guardare',
  'riprendi',
  'riprendere',
  'schau weiter',
  'weiter schauen',
  'weiterschauen',
  'synecheia',
];

/// What follows those verbs when they mean the player, not a title.
const _notATitle = {
  'playback',
  'playing',
  'watching',
  'video',
  'the video',
  'it',
  'this',
  'that',
  'la lecture',
  'lecture',
  'la video',
  'ca',
  'la reproduccion',
  'la riproduzione',
  'die wiedergabe',
};

final _scopeSuffix = RegExp(
    r'^(.+?) (?:in|on|from|dans|sur|en|nel|nella|in der|im) '
    r'(?:the |le |la |les |l |el |il |der |die |den )?(?:my )?'
    r'(media hub|mediahub|hub|movies|movie|films|film|tv shows|shows|series|'
    r'live tv|peliculas|pelicula|serie|serien)$');

/// Group words: "the PPV category" names a group.
const _groupWords = [
  'category',
  'categories',
  'group',
  'section',
  'folder',
  'categorie',
  'groupe',
  'categoria',
  'grupo',
  'gruppo',
  'kategorie',
  'gruppe',
];

/// Verbs that open a group by name even without a group word ("open PPV");
/// "go to" / "switch to" stay channel / section verbs.
const _openGroupVerbs = {
  'open',
  'ouvre',
  'ouvrir',
  'abre',
  'apri',
  'offne',
  'oeffne',
  'anoixe',
};

String? _groupName(String verb, String rest) {
  var words = ' $rest ';
  var named = false;
  for (final w in _groupWords) {
    if (words.contains(' $w ')) {
      named = true;
      words = words.replaceAll(' $w ', ' ');
    }
  }
  // "the category of PPV", "la categorie des sports".
  words = words.replaceAll(RegExp(r' (?:of|for|des|du|de|del|di|von) '), ' ');
  // "open channel 5" is a channel ([_strip] drops the word "channel").
  if (!named &&
      RegExp(r'^(?:the |la |el |il )?'
              r'(?:channel|chaine|canal|canale|sender|kanali) ')
          .hasMatch(words.trim())) {
    return null;
  }
  final name = _strip(words.trim());
  if (name.isEmpty || int.tryParse(name) != null) return null;
  if (named || _openGroupVerbs.contains(verb)) return name;
  return null;
}

const _languageNames = {
  'en': ['english', 'anglais', 'ingles', 'inglese', 'englisch'],
  'fr': ['french', 'francais', 'frances', 'francese', 'franzosisch'],
  'es': ['spanish', 'espagnol', 'espanol', 'spagnolo', 'spanisch'],
};

/// A feed language in [s] ("the english feed of", "in french", "en
/// anglais") and [s] without it.
(String?, String) _language(String s) {
  for (final e in _languageNames.entries) {
    for (final w in e.value) {
      final feed = RegExp('(?:^| )(?:the |le |la |el |il |die |das )?$w '
              '(?:feed|broadcast|version|stream|commentary|audio|call)'
              '(?: (?:of|for|du|de|des|del|di|von))?(?= |\$)')
          .firstMatch(s);
      if (feed != null) {
        final rest = '${s.substring(0, feed.start)} ${s.substring(feed.end)}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return (e.key, rest);
      }
      for (final p in const ['in', 'en', 'auf']) {
        if (s.endsWith(' $p $w')) {
          return (e.key, s.substring(0, s.length - p.length - w.length - 2));
        }
      }
    }
  }
  return (null, s);
}

final _number = RegExp(r'(\d+)');
const _words = {
  'one': 1,
  'un': 1,
  'une': 1,
  'uno': 1,
  'eins': 1,
  'two': 2,
  'deux': 2,
  'dos': 2,
  'due': 2,
  'zwei': 2,
  'three': 3,
  'trois': 3,
  'tres': 3,
  'tre': 3,
  'drei': 3,
  'five': 5,
  'cinq': 5,
  'cinco': 5,
  'cinque': 5,
  'funf': 5,
  'ten': 10,
  'dix': 10,
  'diez': 10,
  'dieci': 10,
  'zehn': 10,
  'fifteen': 15,
  'quinze': 15,
  'quince': 15,
  'quindici': 15,
  'twenty': 20,
  'vingt': 20,
  'veinte': 20,
  'venti': 20,
  'thirty': 30,
  'trente': 30,
  'treinta': 30,
  'trenta': 30,
  'dreissig': 30,
  'a': 1,
  'an': 1,
};

/// "go back 30 seconds", "recule de 2 minutes", "skip 10 minutes".
VesperCommand? _seek(String s) {
  // Typed "2min" / "30sec": the unit is a word of its own below.
  s = s.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');
  int? sign;
  for (final w in _back) {
    if (s.startsWith('$w ') || s == w) sign = -1;
  }
  for (final w in _forward) {
    if (s.startsWith('$w ') || s == w) sign = 1;
  }
  if (sign == null) return null;
  int? amount;
  final digits = _number.firstMatch(s);
  if (digits != null) {
    amount = int.parse(digits.group(1)!);
  } else {
    for (final w in s.split(' ')) {
      if (_words[w] case final n?) amount = n;
    }
  }
  amount ??= 30;
  final minutes = _minuteWords.any((m) => s.contains(' $m'));
  final seconds = amount * (minutes ? 60 : 1) * sign;
  return VesperCommand('player', {'action': 'seek', 'seconds': seconds});
}

// ------------------------------------------------------------- phrases

const _fillers = [
  'hey vesper',
  'ok vesper',
  'vesper',
  'please',
  'can you',
  'could you',
  'would you',
  'i want to',
  'i wanna',
  'i would like to',
  'let s',
  'lets',
  's il te plait',
  's il vous plait',
  'svp',
  'peux tu',
  'pourrais tu',
  'je veux',
  'je voudrais',
  'por favor',
  'puedes',
  'quiero',
  'per favore',
  'puoi',
  'voglio',
  'bitte',
  'kannst du',
  'ich will',
  'ich mochte',
  'parakalo',
  'thelo',
];

const _articles = [
  'the',
  'a',
  'an',
  'le',
  'la',
  'les',
  'l',
  'du',
  'de',
  'des',
  'el',
  'los',
  'las',
  'il',
  'lo',
  'gli',
  'der',
  'die',
  'das',
  'den',
  'o',
  'i',
  'to',
  'channel',
  'chaine',
  'canal',
  'canale',
  'sender',
  'kanali',
];

const _pause = [
  'pause',
  'pause it',
  'pause this',
  'pause the video',
  'hold on',
  'mets pause',
  'mettre pause',
  'mets sur pause',
  'pausa',
  'metti in pausa',
  'pausieren',
  'anhalten',
  'pafsi',
];
const _resume = [
  'resume',
  'continue',
  'play',
  'unpause',
  'keep playing',
  'reprends',
  'reprendre',
  'continuer',
  'lecture',
  'continua',
  'reanudar',
  'sigue',
  'riprendi',
  'weiter',
  'fortsetzen',
  'abspielen',
  'synecheia',
];
const _stop = [
  'stop',
  'stop it',
  'stop playing',
  'stop the video',
  'arrete',
  'arreter',
  'arrete ca',
  'detener',
  'para',
  'parar',
  'ferma',
  'fermati',
  'stopp',
  'beenden',
  'stamata',
];
const _nextEpisode = [
  'next episode',
  'play the next episode',
  'play next episode',
  'skip to the next episode',
  'episode suivant',
  'l episode suivant',
  'prochain episode',
  'siguiente episodio',
  'proximo episodio',
  'episodio siguiente',
  'prossimo episodio',
  'episodio successivo',
  'nachste folge',
  'nachste episode',
  'epomeno epeisodio',
];
const _previousEpisode = [
  'previous episode',
  'play the previous episode',
  'episode precedent',
  'l episode precedent',
  'episodio anterior',
  'episodio precedente',
  'vorherige folge',
  'vorherige episode',
  'proigoumeno epeisodio',
];
const _channelUp = [
  'next channel',
  'channel up',
  'next',
  'chaine suivante',
  'poste suivant',
  'suivant',
  'canal siguiente',
  'siguiente canal',
  'canale successivo',
  'prossimo canale',
  'nachster sender',
  'nachster kanal',
  'epomeno kanali',
];
const _channelDown = [
  'previous channel',
  'channel down',
  'previous',
  'last channel',
  'chaine precedente',
  'poste precedent',
  'precedent',
  'canal anterior',
  'canale precedente',
  'vorheriger sender',
  'vorheriger kanal',
  'proigoumeno kanali',
];
const _live = [
  'back to live',
  'go live',
  'live',
  'retour au direct',
  'en direct',
  'direct',
  'en vivo',
  'en directo',
  'in diretta',
  'diretta',
  'live tv',
  'zuruck zu live',
  'zurueck zu live',
  'zontana',
];
const _whatsOn = [
  'what s on',
  'whats on',
  'what is on',
  'what s playing',
  'what is playing',
  'what am i watching',
  'what is this',
  'what s this',
  'what show is this',
  'qu est ce qui joue',
  'qu est ce que c est',
  'c est quoi',
  'c est quoi ca',
  'qu est ce que je regarde',
  'que es esto',
  'que estoy viendo',
  'cos e questo',
  'che cosa sto guardando',
  'was lauft',
  'was ist das',
  'ti einai afto',
];
const _recent = [
  'recent',
  'recent channels',
  'what did i watch',
  'history',
  'chaines recentes',
  'historique',
  'recientes',
  'recenti',
  'verlauf',
];
const _favouriteAdd = [
  'add to favorites',
  'add to favourites',
  'add this to favorites',
  'add this to favourites',
  'favorite this',
  'favourite this',
  'add to my favorites',
  'add to my favourites',
  'ajoute aux favoris',
  'ajouter aux favoris',
  'mets dans les favoris',
  'anadir a favoritos',
  'aggiungi ai preferiti',
  'zu favoriten hinzufugen',
  'favorit',
];
const _favouriteRemove = [
  'remove from favorites',
  'remove from favourites',
  'unfavorite',
  'unfavourite',
  'enleve des favoris',
  'retire des favoris',
  'quitar de favoritos',
  'rimuovi dai preferiti',
  'aus favoriten entfernen',
];
const _favouriteList = [
  'my favorites',
  'my favourites',
  'favorites',
  'favourites',
  'show my favorites',
  'show my favourites',
  'mes favoris',
  'favoris',
  'mis favoritos',
  'i miei preferiti',
  'meine favoriten',
];
const _sportsToday = [
  'games today',
  'today s games',
  'todays games',
  'what games are on',
  'scores',
  'sports today',
  'matchs aujourd hui',
  'les matchs',
  'les matchs d aujourd hui',
  'partidos de hoy',
  'partite di oggi',
  'spiele heute',
];

const _help = [
  'help',
  'what can you do',
  'what can i say',
  'what can i ask',
  'how does this work',
  'aide',
  'que peux tu faire',
  'qu est ce que tu peux faire',
  'ayuda',
  'que puedes hacer',
  'aiuto',
  'cosa puoi fare',
  'hilfe',
  'was kannst du',
];
const _watchListShow = [
  'my watch list',
  'my watchlist',
  'watch list',
  'watchlist',
  'show my watch list',
  'ma liste',
  'ma liste a regarder',
  'mi lista',
  'la mia lista',
  'meine merkliste',
  'merkliste',
];
const _watchListAdd = [
  'add this to my watch list',
  'add this to my watchlist',
  'add to my watch list',
  'add to watch list',
  'add to my watchlist',
  'save this for later',
  'ajoute ca a ma liste',
  'ajoute a ma liste',
  'anadir a mi lista',
  'aggiungi alla mia lista',
  'zur merkliste hinzufugen',
];
const _watchListAddVerbs = [
  'add',
  'put',
  'ajoute',
  'mets',
  'anade',
  'aggiungi',
  'fuge'
];

const _back = [
  'go back',
  'back',
  'rewind',
  'reculer',
  'recule',
  'retour en arriere',
  'retrocede',
  'retroceder',
  'atras',
  'indietro',
  'torna indietro',
  'zuruck',
  'zurueck',
  'zuruckspulen',
  'piso',
];
const _forward = [
  'skip',
  'skip ahead',
  'forward',
  'go forward',
  'fast forward',
  'avance',
  'avancer',
  'adelanta',
  'adelantar',
  'avanti',
  'vai avanti',
  'vorspulen',
  'vor',
  'mprosta',
];
const _minuteWords = [
  'minute',
  'minutes',
  'min',
  'minuto',
  'minutos',
  'minuti',
  'minuten',
  'lepta'
];

const _openVerbs = [
  'open',
  'go to',
  'show',
  'show me',
  'take me to',
  'switch to',
  'ouvre',
  'ouvrir',
  'va a',
  'va aux',
  'va au',
  'va dans',
  'montre',
  'montre moi',
  'affiche',
  'abre',
  'ir a',
  'muestra',
  'apri',
  'vai a',
  'vai al',
  'mostra',
  'offne',
  'oeffne',
  'zeige',
  'geh zu',
  'anoixe',
];
const _searchVerbs = [
  'search for',
  'search',
  'find',
  'look for',
  'look up',
  'cherche',
  'chercher',
  'recherche',
  'trouve',
  'busca',
  'buscar',
  'cerca',
  'trova',
  'suche',
  'suche nach',
  'finde',
  'psakse',
];
const _playVerbs = [
  'put on',
  'play',
  'watch',
  'turn on',
  'switch to',
  'change to',
  'go to channel',
  'tune to',
  'start',
  'mets',
  'mettre',
  'met',
  'joue',
  'jouer',
  'regarder',
  'regarde',
  'lance',
  'ouvre la chaine',
  'pon',
  'poner',
  'ver',
  'reproduce',
  'metti',
  'guarda',
  'riproduci',
  'spiel',
  'spiele',
  'zeig',
  'schalte auf',
  'valto',
  'paixe',
];

/// "when is X on", "quand joue X".
final _whenOn = [
  RegExp(r'^when (?:is|does) (.+?) (?:on|play|playing|start|airing)$'),
  RegExp(r'^what time is (.+?) on$'),
  RegExp(r'^when can i watch (.+)$'),
  RegExp(r'^quand (?:joue|jouent|passe|passent|commence) (.+)$'),
  RegExp(r'^a quelle heure (?:joue|jouent|passe|passent|commence) (.+)$'),
  RegExp(r'^cuando (?:juega|juegan|dan|empieza|ponen) (.+)$'),
  RegExp(r'^quando (?:gioca|giocano|danno|inizia|fanno) (.+)$'),
  RegExp(r'^wann (?:spielt|spielen|lauft|kommt|beginnt) (.+)$'),
];

const _whatsOnChannel = [
  'what s on',
  'whats on',
  'what is on',
  'qu est ce qui joue sur',
  'qu est ce qui passe sur',
  'que dan en',
  'cosa c e su',
  'was lauft auf',
];

/// "put on the habs game", "le match du canadien", "el partido del madrid".
final _gamePatterns = [
  RegExp(r'^(?:put on|play|watch|show|turn on|find)? ?(?:the )?(.+?) game$'),
  RegExp(r'^(?:put on|play|watch|show|turn on|find)? ?(?:the )?(.+?) match$'),
  RegExp(
      r'^(?:mets |regarder |regarde |trouve )?(?:le )?match (?:des |du |de la |de l |de |d )?(.+)$'),
  RegExp(
      r'^(?:pon |ver |busca )?(?:el )?partido (?:del |de los |de la |de )?(.+)$'),
  RegExp(
      r'^(?:metti |guarda |trova )?(?:la )?partita (?:del |della |dei |di )?(.+)$'),
  RegExp(r'^(?:zeig |spiel )?(?:das )?spiel (?:von |der |des )?(.+)$'),
];

const _kindWords = {
  'movie': [
    'movie',
    'the movie',
    'film',
    'le film',
    'la pelicula',
    'pelicula',
    'il film'
  ],
  'series': [
    'show',
    'the show',
    'series',
    'the series',
    'serie',
    'la serie',
    'l emission',
    'emission'
  ],
};

const _sections = {
  'guide': [
    'guide',
    'tv guide',
    'epg',
    'program guide',
    'programme guide',
    'guide tele',
    'guia',
    'guida',
    'programmfuhrer',
    'odigos'
  ],
  'tv': [
    'tv',
    'live tv',
    'live',
    'channels',
    'television',
    'tele',
    'la tele',
    'chaines',
    'en direct',
    'canales',
    'canali',
    'fernsehen',
    'sender',
    'kanalia'
  ],
  'movies': [
    'movies',
    'films',
    'movie',
    'film',
    'peliculas',
    'film',
    'filme',
    'tainies'
  ],
  'series': [
    'tv shows',
    'shows',
    'series',
    'tv series',
    'emissions',
    'les series',
    'serie tv',
    'serien',
    'seires'
  ],
  'home': [
    'home',
    'accueil',
    'the home page',
    'inicio',
    'home page',
    'startseite',
    'archiki'
  ],
  'hub': ['media hub', 'hub', 'mediahub'],
  'sports': [
    'sports',
    'sport',
    'sports trak',
    'sports track',
    'deportes',
    'sportivi',
    'spiele'
  ],
  'settings': [
    'settings',
    'parametres',
    'reglages',
    'configuracion',
    'ajustes',
    'impostazioni',
    'einstellungen',
    'rythmiseis'
  ],
  'search': [
    'search',
    'recherche',
    'busqueda',
    'ricerca',
    'suche',
    'anazitisi'
  ],
};
