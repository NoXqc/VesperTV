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
    if (command != null) {
      final result = await box.call(command.tool, command.args);
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
      'you did. If the playlists do not have something, say so.';

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
        return VesperReply(
            switch (command.args['action']) {
              'pause' => tr('Paused'),
              'resume' => tr('Playing'),
              'stop' => tr('Stopped'),
              'back_to_live' => tr('Back to live'),
              _ => tr('Done'),
            },
            acted: true);
      case 'open':
        return const VesperReply('', acted: true);
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

  static String _dayWord(Object? day) => switch (day) {
        'today' => tr('today'),
        'tomorrow' => tr('tomorrow'),
        'yesterday' => tr('yesterday'),
        _ => '${day ?? ''}',
      };

  static String _errorWords(VesperCommand c, Object? error) {
    final name = '${c.args['name'] ?? c.args['team'] ?? c.args['title'] ?? ''}';
    return switch (c.tool) {
      'play' =>
        tr('I could not find "{title}" in your playlists.', {'title': name}),
      'play_game' =>
        tr('No channel shows a {title} game today.', {'title': name}),
      'guide' => tr('I could not find the channel "{title}".', {'title': name}),
      'find_on_tv' => tr('That is not in the guide.'),
      'open' => tr('That section is hidden.'),
      'favorites' => tr('Nothing is playing.'),
      'player' when '$error'.contains('rewound') =>
        tr('This channel cannot be rewound.'),
      'player' when '$error'.contains('Windows') =>
        tr('Not available on Windows yet.'),
      'player' => tr('Nothing is playing.'),
      _ => tr('That did not work.'),
    };
  }
}
