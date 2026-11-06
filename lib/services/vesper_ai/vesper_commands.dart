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
  var s = ' ${TitleSearch.fold(spoken)} ';
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

  final seek = _seek(s);
  if (seek != null) return seek;

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

  // "search for dune", "cherche dune" (the search page, with the words).
  for (final verb in _searchVerbs) {
    final rest = _after(s, verb);
    if (rest != null && rest.isNotEmpty) {
      return VesperCommand('open', {'section': 'search', 'query': rest});
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

  // "put on the habs game", "le match du canadien".
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
    for (final w in e.value) {
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
