import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import '../storage_service.dart';
import 'ai_provider.dart';
import 'vesper_commands.dart';
import 'vesper_tools.dart';
import 'voice_input.dart';

/// What Vesper answered: the words for the screen, and whether it did
/// something on the TV (the panel then gets out of the way).
class VesperReply {
  const VesperReply(this.text, {this.acted = false, this.understood = true});
  final String text;
  final bool acted;
  final bool understood;
}

/// A line shown at the bottom of the TV for a few seconds ([VesperAi.bubble]).
class VesperBubble {
  VesperBubble(this.text, {this.from});
  final String text;

  /// Shown before the text ("Claude", "Phone"...), or null.
  final String? from;
  final DateTime at = DateTime.now();
}

/// Vesper AI: what the viewer says (remote microphone, typing, the phone)
/// goes to the built-in commands first ([parseVesperCommand]: free, works
/// offline), then to the viewer's own AI when Settings > Vesper AI has one.
/// AI apps linked over MCP call the same tools directly (`mcp_bridge.dart`).
class VesperAi {
  VesperAi._();
  static final instance = VesperAi._();

  VesperToolbox? _box;
  StorageService? _storage;

  /// The bottom-of-screen line (replies after the panel closed, AI apps).
  final bubble = ValueNotifier<VesperBubble?>(null);

  /// Opens the listening panel (set by the app root; see VesperPanel).
  void Function({bool listen, String? text})? openPanelHandler;

  VesperToolbox? get toolbox => _box;
  bool get ready => _box != null;

  void attach(VesperToolbox box) {
    _box = box;
    _storage = box.storage;
  }

  /// Opens the panel and starts listening ([listen]), or with [text] typed
  /// already (the phone).
  void openPanel({bool listen = true, String? text}) =>
      openPanelHandler?.call(listen: listen, text: text);

  /// [spoken]: what Read replies aloud says (default [text]; '' = nothing).
  void showBubble(String text, {String? from, String? spoken}) {
    bubble.value = VesperBubble(text, from: from);
    final say = spoken ?? text;
    if (say.isNotEmpty) unawaited(VoiceInput.instance.speakIfWanted(say));
  }

  // ------------------------------------------------------------ the AI

  AiProvider? _provider;
  String? _providerSignature;
  DateTime _lastAsked = DateTime.fromMillisecondsSinceEpoch(0);

  @visibleForTesting
  AiProvider? debugProvider;

  /// The viewer's own AI, or null (built-in commands only).
  AiProvider? get provider {
    if (debugProvider != null) return debugProvider;
    final s = _storage;
    if (s == null) return null;
    final signature = [
      s.getAiProvider(),
      s.getAiModel(),
      s.getAiApiKey(),
      s.getAiBaseUrl()
    ].join('|');
    if (signature != _providerSignature) {
      _providerSignature = signature;
      _provider = AiProvider.fromSettings(
          provider: s.getAiProvider(),
          model: s.getAiModel(),
          apiKey: s.getAiApiKey(),
          baseUrl: s.getAiBaseUrl());
    }
    return _provider;
  }

  bool get hasOwnAi => provider != null;

  /// Something said or typed by the viewer.
  Future<VesperReply> ask(String text) async {
    final box = _box;
    final spoken = text.trim();
    if (box == null || spoken.isEmpty) {
      return VesperReply(tr('I did not hear anything.'), understood: false);
    }
    final ai = provider;
    final command = parseVesperCommand(spoken);
    if (command?.tool == 'help') return VesperReply(helpText(hasOwnAi));
    if (command?.tool == 'play_feed') {
      return _playFeed(box, '${command!.args['name']}');
    }
    if (command != null) {
      final result = await box.call(command.tool, command.args);
      _rememberFeeds(command.tool, command.args, result);
      if (!result.containsKey('error') || ai == null) {
        debugPrint('VesperAi: command ${command.tool} '
            '${result.containsKey('error') ? 'failed' : 'ok'}');
        return describeResult(command, result);
      }
      // The built-in try failed (no such channel...): the AI may know better.
    }
    if (ai == null) {
      // Last try without an AI: the words may be a channel or title name.
      final play = await box.call('play', {'name': spoken});
      if (!play.containsKey('error')) {
        return describeResult(VesperCommand('play', {'name': spoken}), play);
      }
      return VesperReply(
          tr('I did not understand "{text}". Try "play TSN 1", "what\'s on" or "open the movies". Add your own AI in Settings > Vesper AI for anything else.',
              {'text': spoken}),
          understood: false);
    }
    return _askAi(ai, box, spoken);
  }

  /// The channels of the game the viewer last asked about ("which channels
  /// have the Habs game"): "play it on RDS" picks from them.
  ({String game, List<(String, String)> channels, DateTime at})? _feeds;

  void _rememberFeeds(
      String tool, Map<String, Object?> args, Map<String, Object?> result) {
    if (tool != 'play_game' || args['list'] != true) return;
    final games = result['games'];
    if (games is! List || games.isEmpty || games.first is! Map) return;
    final game = games.first as Map;
    final channels = <(String, String)>[
      for (final c in (game['channels'] as List? ?? const []))
        if (c is Map && c['ref'] is String && c['title'] is String)
          (c['ref'] as String, c['title'] as String)
    ];
    _feeds = (game: '${game['game']}', channels: channels, at: DateTime.now());
  }

  /// "play it on RDS": RDS among the game's channels just listed (for 20
  /// minutes), else the channel called that.
  Future<VesperReply> _playFeed(VesperToolbox box, String name) async {
    final feeds = _feeds;
    if (feeds != null &&
        DateTime.now().difference(feeds.at) < const Duration(minutes: 20)) {
      // The best-named one; among equally good names the first in the
      // list's order (the viewer's quality / country / language
      // preferences): "TSN 2" is the preferred copy, not the shortest.
      (String, String)? pick;
      int? best;
      for (final c in feeds.channels) {
        final r = spokenRank(name, c.$2);
        if (r != null && (best == null || r < best)) {
          best = r;
          pick = c;
        }
      }
      if (pick != null) {
        final r = await box.call('play', {'ref': pick.$1});
        return describeResult(VesperCommand('play', {'name': name}),
            r.containsKey('error') ? r : {...r, 'game': feeds.game});
      }
    }
    final r = await box.call('play', {'name': name});
    return describeResult(VesperCommand('play', {'name': name}), r);
  }

  Future<VesperReply> _askAi(
      AiProvider ai, VesperToolbox box, String spoken) async {
    if (DateTime.now().difference(_lastAsked) > const Duration(minutes: 10)) {
      ai.reset();
    }
    _lastAsked = DateTime.now();
    var acted = false;
    try {
      final now = DateTime.now();
      final words = await ai.send(
          '$spoken\n\n[Local time: ${_weekday(now)} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}]',
          system: systemPrompt(L10n.code),
          tools: box.tools.where((t) => t.name != 'show_message').toList(),
          runTool: (name, args) async {
        final result = await box.call(name, args);
        _rememberFeeds(name, args, result);
        if (!result.containsKey('error') &&
            const {'play', 'play_game', 'open', 'player'}.contains(name)) {
          acted = true;
        }
        debugPrint('VesperAi: AI tool $name '
            '${result.containsKey('error') ? 'failed' : 'ok'}');
        return result;
      });
      return VesperReply(words, acted: acted);
    } on AiProviderError catch (e) {
      return VesperReply(e.message, acted: acted, understood: false);
    }
  }

  static String _weekday(DateTime t) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];

  /// The instructions every provider gets (the same for each request, so
  /// it caches).
  static String systemPrompt(String language) =>
      'You are Vesper, the assistant inside VesperTV, a TV app that plays '
      'the viewer\'s own IPTV playlists (live channels with a TV guide, '
      'movies, TV shows), a Media Hub and Sports Trak (live scores). The '
      'viewer talks to you with the remote\'s microphone, their phone or by '
      'typing, while sitting in front of the TV.\n'
      'Your reply is shown on the TV for a few seconds and may be read '
      'aloud: answer in one or two short sentences, plain text, no '
      'markdown, no lists unless asked. Reply in the language with code '
      '"$language" unless the viewer speaks another one.\n'
      'Use the tools to see and change what is on the TV. Only name '
      'channels, titles, times and scores that a tool gave you; search '
      'before you play when unsure, and pick the most fitting result '
      'yourself rather than asking which one. When the viewer asks to '
      'watch something, play it. After an action, say in a few words what '
      'you did. If the playlists do not have something, say so. Media Hub '
      '(media_hub) holds the movies and shows of the viewer\'s add-ons and '
      'media servers: look there when asked to, or when the playlists do '
      'not have a title; play with best true. When a Media Hub title '
      'buffers or fails, media_hub switch next. When the '
      'viewer asks for all / every / which channels of a name (all TSN, '
      'CBS east and west), open the search page with that name so they '
      'can pick. A category name (PPV, Pay Per View, Live Events) opens '
      'that live group (open section group). For a game in a language '
      '("the English feed"), use play_game with language. When asked which '
      'channels carry a game, call play_game with list true and name the '
      'channels in one line (the order already follows the '
      'viewer quality, country and language preferences); when they then pick one '
      '("play it on RDS"), play the ref of that channel. Spoken numbers '
      'are fine in searches ("TSN one" finds TSN 1). Before editing a '
      'playlist, read vesper_help topic "playlist_editor"; before filling '
      'in missing TV guide data, topic "epg_matching".';

  /// The words for a built-in command's result.
  @visibleForTesting
  static VesperReply describeResult(
      VesperCommand command, Map<String, Object?> r) {
    final error = r['error'];
    if (error != null) {
      return VesperReply(_errorWords(command, error), understood: false);
    }
    String? s(String key) => r[key] is String ? r[key] as String : null;
    switch (command.tool) {
      case 'play_game' when r['games'] is List:
        return VesperReply(_feedsText(r['games'] as List));
      case 'play':
      case 'play_game':
        final title = s('playing') ?? s('opened') ?? '';
        if (s('opened') != null) {
          return VesperReply(tr('Opened {title}', {'title': title}),
              acted: true);
        }
        final game = s('game');
        return VesperReply(
            game == null
                ? tr('Playing {title}', {'title': title})
                : tr('Playing {game} on {title}',
                    {'game': game, 'title': title}),
            acted: true);
      case 'player':
        final playing = s('playing');
        if (playing != null) {
          return VesperReply(tr('Playing {title}', {'title': playing}),
              acted: true);
        }
        final action = command.args['action'];
        if (action == 'audio_tracks' || action == 'subtitles') {
          return VesperReply(_trackList(action == 'subtitles', r));
        }
        final done = s('done') ?? '';
        return VesperReply(
            switch (action) {
              'pause' => tr('Paused'),
              'resume' => tr('Playing'),
              'stop' => tr('Stopped'),
              'back_to_live' => tr('Back to live'),
              'audio_track' when done.startsWith('audio: ') =>
                '${tr('Audio')}: ${done.substring(7)}',
              'subtitle' when done == 'subtitles off' =>
                '${tr('Subtitles')}: ${tr('Off')}',
              'subtitle' when done.startsWith('subtitles: ') =>
                '${tr('Subtitles')}: ${done.substring(11)}',
              _ => tr('Done'),
            },
            acted: true);
      case 'open':
        return const VesperReply('', acted: true);
      case 'media_hub' when s('playing') != null:
        return VesperReply(tr('Playing {title}', {'title': s('playing')}),
            acted: true);
      case 'media_hub' when s('opened') != null:
        return VesperReply(tr('Opened {title}', {'title': s('opened')}),
            acted: true);
      case 'now_playing':
        final title = s('title');
        if (title == null) return VesperReply(tr('Nothing is playing.'));
        final now = r['on_now'];
        final next = r['next'];
        final parts = [
          title,
          if (now is Map) tr('now: {title}', {'title': now['title']}),
          if (next is Map)
            tr('next: {title} at {time}',
                {'title': next['title'], 'time': next['start']}),
        ];
        return VesperReply(parts.join(' · '));
      case 'guide':
        final list = (r['programmes'] as List?) ?? const [];
        final channel = r['channel'];
        final name = channel is Map ? '${channel['title']}' : '';
        if (list.isEmpty) {
          return VesperReply(tr('No guide for {title}.', {'title': name}));
        }
        return VesperReply('$name: ${[
          for (final p in list.take(4))
            if (p is Map) '${p['start']} ${p['title']}'
        ].join(' · ')}');
      case 'find_on_tv':
        final list = (r['airings'] as List?) ?? const [];
        if (list.isEmpty) {
          return VesperReply(tr('That is not in the guide.'));
        }
        return VesperReply([
          for (final p in list.take(3))
            if (p is Map)
              '${p['title']} — ${(p['channel'] as Map?)?['title'] ?? ''}, '
                  '${_dayWord(p['day'])} ${p['start']}'
        ].join(' · '));
      case 'favorites':
        if (command.args['action'] == 'list') {
          final list = (r['favorites'] as List?) ?? const [];
          if (list.isEmpty) return VesperReply(tr('No favourites yet.'));
          return VesperReply([
            for (final c in list.take(8))
              if (c is Map) '${c['title']}'
          ].join(' · '));
        }
        return VesperReply(
            command.args['action'] == 'add'
                ? tr('Added {title} to Favourites', {'title': s('title')})
                : tr('Removed {title} from Favourites', {'title': s('title')}),
            acted: true);
      case 'recent':
        final list = (r['recent'] as List?) ?? const [];
        if (list.isEmpty) return VesperReply(tr('Nothing watched yet.'));
        return VesperReply([
          for (final c in list.take(8))
            if (c is Map) '${c['title']}'
        ].join(' · '));
      case 'watchlist':
        if (command.args['action'] == 'list') {
          final list = (r['watchlist'] as List?) ?? const [];
          if (list.isEmpty) return VesperReply(tr('Your watch list is empty.'));
          return VesperReply([
            for (final c in list.take(8))
              if (c is Map) '${c['title']}'
          ].join(' · '));
        }
        return VesperReply(r['added'] == true
            ? tr('Added {title} to your watch list', {'title': s('title')})
            : tr('{title} is already on your watch list',
                {'title': s('title')}));
      case 'sports_today':
        final list = (r['games'] as List?) ?? const [];
        if (list.isEmpty) return VesperReply(tr('No games today.'));
        return VesperReply([
          for (final g in list.take(5))
            if (g is Map)
              '${g['game']}${g['score'] != null ? ' (${g['score']})' : ''}'
        ].join(' · '));
    }
    return VesperReply(tr('Done'));
  }

  /// "help" / "what can you do".
  static String helpText(bool withAi) => withAi
      ? tr(
          'Ask me anything about what\'s on: "play TSN 1", "what\'s on tonight", "put on the Habs game", "make me a movie night list for Friday", "hide every Turkish group", "go back 30 seconds".')
      : tr(
          'Try: "play TSN 1", "what\'s on", "pause", "go back 30 seconds", "open the movies", "put on the Habs game", "add this to my watch list". Add your own AI in Settings > Vesper AI for anything else.');

  static String _dayWord(Object? day) => switch (day) {
        'today' => tr('today'),
        'tomorrow' => tr('tomorrow'),
        'yesterday' => tr('yesterday'),
        _ => '${day ?? ''}',
      };

  /// "Canadiens at Maple Leafs: TSN 2 · Sportsnet One · RDS (FR)": the
  /// first game's channels, each name once, the language when it isn't the
  /// app's own.
  static String _feedsText(List games) {
    if (games.isEmpty || games.first is! Map) return tr('Nothing found.');
    final game = games.first as Map;
    final names = <String>[];
    for (final c in (game['channels'] as List? ?? const [])) {
      if (c is! Map || c['title'] is! String) continue;
      final lang = c['language'];
      final label = lang is String && lang != L10n.code
          ? '${c['title']} (${lang.toUpperCase()})'
          : c['title'] as String;
      if (!names.contains(label)) names.add(label);
      if (names.length == 6) break;
    }
    if (names.isEmpty) {
      return tr('No channel in your playlists carries {game}.',
          {'game': game['game']});
    }
    return '${game['game']}: ${names.join(' · ')}';
  }

  /// "which subtitles / audio tracks": the names, the playing one first
  /// marked, in one line.
  static String _trackList(bool subtitles, Map<String, Object?> r) {
    final tracks = [
      for (final t in (r['tracks'] as List?) ?? const [])
        if (t is Map && t['name'] is String)
          (t['playing'] == true || t['showing'] == true)
              ? '▶ ${t['name']}'
              : '${t['name']}',
    ];
    if (subtitles) {
      final online = r['showing_online'];
      final names = [
        if (online is String) '▶ $online',
        ...tracks,
        if (r['off'] == true) '▶ ${tr('Off')}',
      ];
      return tracks.isEmpty && online == null
          ? tr('No subtitles in this file.')
          : '${tr('Subtitles')}: ${names.join(' · ')}';
    }
    return tracks.isEmpty
        ? tr('This stream has no audio tracks to choose from.')
        : '${tr('Audio tracks')}: ${tracks.join(' · ')}';
  }

  static String _errorWords(VesperCommand c, Object? error) {
    final name =
        '${c.args['name'] ?? c.args['team'] ?? c.args['title'] ?? c.args['query'] ?? ''}';
    return switch (c.tool) {
      'media_hub' when '$error'.contains('hidden') =>
        tr('That section is hidden.'),
      'media_hub' =>
        tr('I could not find "{title}" in Media Hub.', {'title': name}),
      'play' =>
        tr('I could not find "{title}" in your playlists.', {'title': name}),
      'play_game' =>
        tr('No channel shows a {title} game today.', {'title': name}),
      'guide' => tr('I could not find the channel "{title}".', {'title': name}),
      'find_on_tv' => tr('That is not in the guide.'),
      'open' => tr('That section is hidden.'),
      'favorites' => tr('Nothing is playing.'),
      'watchlist' when name.isNotEmpty =>
        tr('I could not find "{title}" in your playlists.', {'title': name}),
      'watchlist' => tr('Nothing is playing.'),
      'player' when '$error'.contains('rewound') =>
        tr('This channel cannot be rewound.'),
      'player' when '$error'.contains('Windows') =>
        tr('Not available on Windows yet.'),
      'player' when '$error'.contains('next episode') => tr('No next episode.'),
      'player' when '$error'.contains('previous episode') =>
        tr('No previous episode.'),
      'player' when '$error'.contains('no audio tracks') =>
        tr('This stream has no audio tracks to choose from.'),
      'player' when '$error'.contains('audio in this stream') =>
        tr('That language is not in this stream.'),
      'player' when '$error'.contains('no closed captions') =>
        tr('This channel has no closed captions.'),
      'player' when '$error'.contains('subtitle') =>
        tr('No subtitles in that language.'),
      'player' => tr('Nothing is playing.'),
      _ => tr('That did not work.'),
    };
  }
}
