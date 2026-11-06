import 'dart:async';
import 'dart:io' show Platform;

import '../../models/channel.dart';
import '../../models/epg_program.dart';
import '../../models/sports.dart';
import '../../models/xtream_series.dart';
import '../../utils/title_search.dart';
import '../app_preferences.dart';
import '../epg_service.dart';
import '../playback_service.dart';
import '../playlist_manager.dart';
import '../sports_channel_matcher.dart';
import '../sports_service.dart';
import '../storage_service.dart';

/// Who asked: the viewer on the TV (voice / typing / phone microphone, or
/// their own AI key acting for them) or an AI app linked over MCP from
/// somewhere else (its plays and changes are confirmed on the TV).
enum VesperCaller { viewer, remoteApp }

/// What the tools need from the app's screens (implemented in
/// vesper_host.dart, which knows the navigator and the two players).
abstract interface class VesperHost {
  /// Full screen, like picking the channel / movie in the guide or search.
  Future<void> playChannel(Channel channel);
  Future<void> openSeries(XtreamSeries series);

  /// 'tv', 'guide', 'movies', 'series', 'home', 'hub', 'sports', 'search',
  /// 'settings'. False when that section is hidden or unavailable.
  Future<bool> openSection(String section, {String? query});

  /// Asks on the TV (OK / Cancel); false on Cancel, Back or no answer.
  /// [question] is an English UI string for tr(), filled with [args].
  Future<bool> confirm(String question, Map<String, Object?> args);

  /// A short line on the TV (an AI app talking to the viewer).
  void showMessage(String text);
}

/// A failure the model / viewer should read: said back as is.
class VesperToolError implements Exception {
  VesperToolError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One thing Vesper can do. [schema] is a JSON Schema object (the same one
/// goes to Claude / OpenAI / Gemini and to MCP clients).
class VesperTool {
  const VesperTool({
    required this.name,
    required this.description,
    required this.schema,
    required this.run,
  });

  final String name;
  final String description;
  final Map<String, Object?> schema;
  final Future<Map<String, Object?>> Function(
      VesperToolbox box, Map<String, Object?> args, VesperCaller caller) run;
}

/// The tools plus what they act on. One per app ([VesperAi.instance] builds
/// it once the services exist).
class VesperToolbox {
  VesperToolbox({
    required this.playlist,
    required this.playback,
    required this.epg,
    required this.storage,
    required this.prefs,
    required this.host,
  });

  final PlaylistManager playlist;
  final PlaybackService playback;
  final EpgService epg;
  final StorageService storage;
  final AppPreferences prefs;
  final VesperHost host;

  /// Things search returned, by the short ref handed out ("l12", "m3",
  /// "s7"): the model plays a ref instead of retyping a long title. Kept for
  /// the app's lifetime, capped.
  final Map<String, Object> _refs = {};
  final Map<String, String> _refOf = {};
  int _nextRef = 1;

  String refFor(Object item) {
    final key = switch (item) {
      Channel c => '${c.isLive ? 'l' : 'm'}:${c.id}',
      XtreamSeries s => 's:${s.playlistId}:${s.id}',
      _ => '$item',
    };
    final existing = _refOf[key];
    if (existing != null) return existing;
    final prefix = switch (item) {
      Channel c => c.isLive ? 'l' : 'm',
      _ => 's',
    };
    final ref = '$prefix${_nextRef++}';
    _refs[ref] = item;
    _refOf[key] = ref;
    if (_refs.length > 2000) {
      final oldest = _refs.keys.first;
      _refs.remove(oldest);
      _refOf.removeWhere((_, v) => v == oldest);
    }
    return ref;
  }

  Object? lookup(String ref) => _refs[ref.trim().toLowerCase()];

  List<VesperTool> get tools => vesperTools;

  VesperTool? tool(String name) {
    for (final t in vesperTools) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Runs [name] with [args]. Never throws: errors come back as
  /// `{"error": "..."}` so a model can read them and try again.
  Future<Map<String, Object?>> call(String name, Map<String, Object?> args,
      {VesperCaller caller = VesperCaller.viewer}) async {
    final t = tool(name);
    if (t == null) return {'error': 'Unknown tool $name.'};
    try {
      return await t.run(this, args, caller);
    } on VesperToolError catch (e) {
      return {'error': e.message};
    } catch (e) {
      return {'error': 'That did not work ($e).'};
    }
  }

  // ------------------------------------------------------------ helpers

  String _playlistName(String id) {
    for (final p in playlist.profiles) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  bool get _manyPlaylists =>
      playlist.profiles.where((p) => p.enabled).length > 1;

  Map<String, Object?> describeChannel(Channel c, {bool withNow = true}) {
    final now = c.isLive && withNow ? epg.getCurrentProgram(c.epgId) : null;
    return {
      'ref': refFor(c),
      'title': c.name,
      'kind': c.isLive ? 'live' : 'movie',
      if (c.group.isNotEmpty) 'group': c.group,
      if (_manyPlaylists) 'playlist': _playlistName(c.playlistId),
      if (now != null) 'on_now': now.title,
      if (c.hasCatchup) 'catch_up_days': c.catchupDays,
    };
  }

  Map<String, Object?> describeSeries(XtreamSeries s) => {
        'ref': refFor(s),
        'title': s.name,
        'kind': 'series',
        if (_manyPlaylists) 'playlist': _playlistName(s.playlistId),
      };

  /// Live channels whose name matches [query], best first: exact name,
  /// then names starting with it, then the rest.
  Future<List<Channel>> findLive(String query, {int limit = 20}) async {
    await playlist.ensureLiveChannelsLoaded();
    return rankByName(
        playlist.visibleChannels(category: 'tv'), query, (c) => c.name,
        limit: limit);
  }

  Future<List<Channel>> findMovies(String query, {int limit = 20}) async {
    if (prefs.hideMoviesShows) return const [];
    final ids = playlist.profiles
        .where((p) => p.enabled && p.isXtream)
        .map((p) => p.id)
        .toList();
    final seen = <String>{};
    final out = <Channel>[];
    if (ids.isNotEmpty) {
      for (final c
          in await playlist.searchVisibleVod(query, ids, limit: limit * 2)) {
        if (seen.add(c.id)) out.add(c);
      }
    }
    for (final c in rankByName(
        playlist.visibleChannels(category: 'vod'), query, (c) => c.name,
        limit: limit * 2)) {
      if (seen.add(c.id)) out.add(c);
    }
    return rankByName(out, query, (c) => c.name, limit: limit);
  }

  /// Xtream shows; M3U shows are channels ([findM3uShows]).
  Future<List<XtreamSeries>> findSeries(String query, {int limit = 20}) async {
    if (prefs.hideMoviesShows) return const [];
    final ids = playlist.profiles
        .where((p) => p.enabled && p.isXtream)
        .map((p) => p.id)
        .toList();
    if (ids.isEmpty) return const [];
    final found =
        await playlist.searchVisibleSeries(query, ids, limit: limit * 2);
    return rankByName(found, query, (s) => s.name, limit: limit);
  }

  List<Channel> findM3uShows(String query, {int limit = 20}) => prefs
          .hideMoviesShows
      ? const []
      : rankByName(
          playlist.visibleChannels(category: 'series'), query, (c) => c.name,
          limit: limit);

  /// The live channel for a ref, an exact/near name, or null.
  Future<Channel?> resolveLive({String? ref, String? name}) async {
    if (ref != null && ref.isNotEmpty) {
      final item = lookup(ref);
      if (item is Channel && item.isLive) return item;
    }
    if (name != null && name.trim().isNotEmpty) {
      final found = await findLive(name, limit: 1);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }

  /// The guide's programmes of [channel] between [from] and [to]. The
  /// guide loads rows on demand, so a channel not yet loaded is waited for
  /// briefly.
  Future<List<EpgProgram>> programmes(
      Channel channel, DateTime from, DateTime to) async {
    final id = channel.epgId;
    var list = epg.programsBetween(id, from, to);
    for (var i = 0; list.isEmpty && epg.hasPrograms(id) && i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      list = epg.programsBetween(id, from, to);
    }
    return list;
  }

  bool get restrictedViewer => playlist.activeViewerRestricted;
}

/// [items] whose [name] matches every word of [query] (accent / case /
/// separator folded, see [TitleSearch]), best first: exact, then the
/// query at the start of the name, then shorter names.
List<T> rankByName<T>(Iterable<T> items, String query, String Function(T) name,
    {int limit = 20}) {
  final search = TitleSearch(query);
  if (search.isEmpty) return const [];
  final scored = <(int, int, T)>[];
  for (final item in items) {
    final n = name(item);
    if (!search.matches(n)) continue;
    final folded = TitleSearch.fold(n);
    final score = folded == search.folded
        ? 0
        : folded.startsWith(search.folded)
            ? 1
            : folded.contains(search.folded)
                ? 2
                : 3;
    scored.add((score, n.length, item));
  }
  scored.sort((a, b) {
    final s = a.$1.compareTo(b.$1);
    return s != 0 ? s : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored.take(limit)) s.$3];
}

String _str(Map<String, Object?> args, String key) {
  final v = args[key];
  return v is String ? v.trim() : (v == null ? '' : '$v'.trim());
}

int _int(Map<String, Object?> args, String key, int fallback,
    {int min = 1, int max = 50}) {
  final v = args[key];
  final n = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  return (n ?? fallback).clamp(min, max);
}

String _clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _day(DateTime t) {
  final l = t.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(l.year, l.month, l.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff == -1) return 'yesterday';
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

Map<String, Object?> _programme(EpgProgram p) => {
      'title': p.title,
      'day': _day(p.start),
      'start': _clock(p.start),
      'end': _clock(p.stop),
      if (p.description != null && p.description!.isNotEmpty)
        'about': p.description!.length > 200
            ? '${p.description!.substring(0, 200)}…'
            : p.description,
    };

Future<void> _confirmRemote(VesperToolbox box, VesperCaller caller,
    String question, Map<String, Object?> args) async {
  if (caller != VesperCaller.remoteApp) return;
  if (!box.storage.getAiConfirmRemotePlay()) return;
  if (!await box.host.confirm(question, args)) {
    throw VesperToolError('The viewer said no on the TV.');
  }
}

Future<Map<String, Object?>> _play(
    VesperToolbox box, Object item, VesperCaller caller) async {
  switch (item) {
    case Channel c:
      await _confirmRemote(
          box, caller, 'An AI app wants to play {title}.', {'title': c.name});
      await box.host.playChannel(c);
      return {'playing': c.name, 'kind': c.isLive ? 'live' : 'movie'};
    case XtreamSeries s:
      await _confirmRemote(
          box, caller, 'An AI app wants to open {title}.', {'title': s.name});
      await box.host.openSeries(s);
      return {
        'opened': s.name,
        'kind': 'series',
        'note': 'The show page is open on the TV; the viewer picks the episode.'
      };
  }
  throw VesperToolError('Nothing to play.');
}

// ------------------------------------------------------------------- tools

/// Every tool, in the order models see them.
final List<VesperTool> vesperTools = [
  VesperTool(
    name: 'search',
    description:
        'Search the viewer\'s own playlists for live TV channels, movies and '
        'TV shows by name. Returns refs to use with play, guide or '
        'favorites. Search with short distinctive words (a channel name '
        'like "TSN 1", a title like "Dune").',
    schema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Words of the name.'},
        'kind': {
          'type': 'string',
          'enum': ['all', 'live', 'movie', 'series'],
          'description': 'What to search (default all).',
        },
        'limit': {'type': 'integer', 'description': 'Per kind, 1-30.'},
      },
      'required': ['query'],
    },
    run: (box, args, caller) async {
      final query = _str(args, 'query');
      if (query.isEmpty) throw VesperToolError('Say what to search for.');
      final kind = _str(args, 'kind').isEmpty ? 'all' : _str(args, 'kind');
      final limit = _int(args, 'limit', 8, max: 30);
      final out = <String, Object?>{};
      if (kind == 'all' || kind == 'live') {
        out['live'] = [
          for (final c in await box.findLive(query, limit: limit))
            box.describeChannel(c)
        ];
      }
      if (kind == 'all' || kind == 'movie') {
        out['movies'] = [
          for (final c in await box.findMovies(query, limit: limit))
            box.describeChannel(c)
        ];
      }
      if (kind == 'all' || kind == 'series') {
        out['series'] = [
          for (final s in await box.findSeries(query, limit: limit))
            box.describeSeries(s),
          for (final c in box.findM3uShows(query, limit: limit))
            {...box.describeChannel(c), 'kind': 'series'},
        ];
      }
      return out;
    },
  ),
  VesperTool(
    name: 'play',
    description:
        'Play something full screen on the TV: a ref from search / guide / '
        'favorites / recent, or a name (the best match is played). A TV '
        'show opens its page so the viewer picks the episode.',
    schema: {
      'type': 'object',
      'properties': {
        'ref': {'type': 'string', 'description': 'A ref like "l12".'},
        'name': {
          'type': 'string',
          'description': 'Channel or title name when there is no ref.'
        },
        'kind': {
          'type': 'string',
          'enum': ['live', 'movie', 'series'],
          'description': 'With name: what it is (default live first).',
        },
      },
    },
    run: (box, args, caller) async {
      final ref = _str(args, 'ref');
      if (ref.isNotEmpty) {
        final item = box.lookup(ref);
        if (item == null) {
          throw VesperToolError('Unknown ref $ref. Search again.');
        }
        return _play(box, item, caller);
      }
      final name = _str(args, 'name');
      if (name.isEmpty) throw VesperToolError('Give a ref or a name.');
      final kind = _str(args, 'kind');
      Object? item;
      if (kind.isEmpty || kind == 'live') {
        item = (await box.findLive(name, limit: 1)).firstOrNull;
      }
      if (item == null && (kind.isEmpty || kind == 'movie')) {
        item = (await box.findMovies(name, limit: 1)).firstOrNull;
      }
      if (item == null && (kind.isEmpty || kind == 'series')) {
        item = (await box.findSeries(name, limit: 1)).firstOrNull ??
            box.findM3uShows(name, limit: 1).firstOrNull;
      }
      if (item == null) {
        throw VesperToolError('Nothing called "$name" in the playlists.');
      }
      return _play(box, item, caller);
    },
  ),
  VesperTool(
    name: 'now_playing',
    description: 'What the TV is playing right now: the channel or title, the '
        'programme on now and next, and whether it is paused.',
    schema: {'type': 'object', 'properties': {}},
    run: (box, args, caller) async {
      if (Platform.isWindows) {
        throw VesperToolError('Not available on Windows yet.');
      }
      final c = box.playback.liveChannel;
      if (c == null) return {'playing': null};
      final controller = box.playback.controller;
      final out = <String, Object?>{
        ...box.describeChannel(c, withNow: false),
        'paused': controller != null && !controller.value.isPlaying,
        if (box.playback.catchup != null) 'catch_up': true,
      };
      if (c.isLive) {
        final now = box.epg.getCurrentProgram(c.epgId);
        final next = box.epg.getNextProgram(c.epgId);
        if (now != null) out['on_now'] = _programme(now);
        if (next != null) out['next'] = _programme(next);
      } else if (controller != null && controller.value.isInitialized) {
        out['position_min'] = controller.value.position.inMinutes;
        out['length_min'] = controller.value.duration.inMinutes;
      }
      return out;
    },
  ),
  VesperTool(
    name: 'player',
    description:
        'Control the player: pause, resume, stop, go back or forward a '
        'number of seconds, back to live, next / previous channel.',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'pause',
            'resume',
            'stop',
            'seek',
            'back_to_live',
            'channel_up',
            'channel_down',
          ],
        },
        'seconds': {
          'type': 'integer',
          'description': 'For seek: negative goes back, positive forward.',
        },
      },
      'required': ['action'],
    },
    run: (box, args, caller) async {
      if (Platform.isWindows) {
        throw VesperToolError('Not available on Windows yet.');
      }
      final playback = box.playback;
      final c = playback.controller;
      final action = _str(args, 'action');
      if (c == null && action != 'stop') {
        throw VesperToolError('Nothing is playing.');
      }
      switch (action) {
        case 'pause':
          if (c!.value.isPlaying) await playback.togglePlayPause();
          return {'done': 'paused'};
        case 'resume':
          if (!c!.value.isPlaying) await playback.togglePlayPause();
          return {'done': 'playing'};
        case 'stop':
          await playback.stop();
          return {'done': 'stopped'};
        case 'back_to_live':
          if (playback.catchup == null) return {'done': 'already live'};
          await playback.backToLive();
          return {'done': 'live'};
        case 'seek':
          final seconds = _int(args, 'seconds', -30, min: -7200, max: 7200);
          final ch = playback.currentChannel;
          if (ch != null && ch.isLive) {
            if (seconds < 0 && ch.hasCatchup) {
              await playback.playCatchup(
                  ch, DateTime.now().add(Duration(seconds: seconds)),
                  toProgrammeEnd: false);
              return {'done': 'catch-up from ${-seconds} s ago'};
            }
            throw VesperToolError('This live channel cannot be rewound.');
          }
          final target = c!.value.position + Duration(seconds: seconds);
          final clamped = target < Duration.zero
              ? Duration.zero
              : (c.value.duration > Duration.zero && target > c.value.duration
                  ? c.value.duration
                  : target);
          await c.seekTo(clamped);
          return {'done': 'at ${clamped.inMinutes} min'};
        case 'channel_up':
        case 'channel_down':
          final ch = playback.liveChannel;
          if (ch == null || !ch.isLive) {
            throw VesperToolError('No live channel is playing.');
          }
          final list = (playback.zapList?.any((x) => x.id == ch.id) ?? false)
              ? playback.zapList!
              : box.playlist
                  .visibleChannels(category: 'tv')
                  .where((x) => x.group == ch.group)
                  .toList();
          final i = list.indexWhere((x) => x.id == ch.id);
          if (i < 0 || list.length < 2) {
            throw VesperToolError('No other channel in this list.');
          }
          final step = action == 'channel_up' ? 1 : -1;
          final next = list[(i + step) % list.length];
          await box.host.playChannel(next);
          return {'playing': next.name};
      }
      throw VesperToolError('Unknown player action $action.');
    },
  ),
  VesperTool(
    name: 'guide',
    description:
        'The TV guide of one live channel (ref or name): what is on now and '
        'the next hours.',
    schema: {
      'type': 'object',
      'properties': {
        'ref': {'type': 'string'},
        'name': {'type': 'string', 'description': 'Channel name.'},
        'hours': {'type': 'integer', 'description': 'How far ahead, 1-24.'},
      },
    },
    run: (box, args, caller) async {
      final channel = await box.resolveLive(
          ref: _str(args, 'ref'), name: _str(args, 'name'));
      if (channel == null) throw VesperToolError('No such live channel.');
      final hours = _int(args, 'hours', 4, max: 24);
      final now = DateTime.now();
      final list =
          await box.programmes(channel, now, now.add(Duration(hours: hours)));
      return {
        'channel': box.describeChannel(channel, withNow: false),
        'programmes': [for (final p in list.take(30)) _programme(p)],
        if (list.isEmpty) 'note': 'No guide data for this channel.',
      };
    },
  ),
  VesperTool(
    name: 'find_on_tv',
    description:
        'Find when a programme (show, match, film) is on the live channels '
        'in the guide, from now up to a few days ahead.',
    schema: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Words of the programme title.'
        },
        'hours': {'type': 'integer', 'description': 'How far ahead, 1-168.'},
      },
      'required': ['title'],
    },
    run: (box, args, caller) async {
      final title = _str(args, 'title');
      if (title.isEmpty) throw VesperToolError('Say which programme.');
      await box.playlist.ensureLiveChannelsLoaded();
      final now = DateTime.now();
      final hours = _int(args, 'hours', 48, max: 168);
      final terms = TitleSearch(title).terms;
      final found = await box.epg.findProgrammesByTitle(
          now.subtract(const Duration(hours: 3)),
          now.add(Duration(hours: hours)),
          terms);
      final byEpg = <String, Channel>{};
      for (final c in box.playlist.visibleChannels(category: 'tv')) {
        byEpg.putIfAbsent(normalizeEpgId(c.epgId), () => c);
      }
      final out = <Map<String, Object?>>[];
      for (final p in found) {
        if (!p.stop.isAfter(now)) continue;
        final c = byEpg[normalizeEpgId(p.channelId)];
        if (c == null) continue;
        out.add({..._programme(p), 'channel': box.describeChannel(c)});
        if (out.length >= 20) break;
      }
      return {
        'airings': out,
        if (out.isEmpty) 'note': 'Not in the guide for that time.',
      };
    },
  ),
  VesperTool(
    name: 'open',
    description: 'Open a part of the app on the TV: tv (live channels), guide, '
        'movies, series, home, hub (Media Hub), sports (Sports Trak), '
        'search (with a query) or settings.',
    schema: {
      'type': 'object',
      'properties': {
        'section': {
          'type': 'string',
          'enum': [
            'tv',
            'guide',
            'movies',
            'series',
            'home',
            'hub',
            'sports',
            'search',
            'settings',
          ],
        },
        'query': {'type': 'string', 'description': 'For search.'},
      },
      'required': ['section'],
    },
    run: (box, args, caller) async {
      final section = _str(args, 'section');
      final ok = await box.host.openSection(section,
          query: _str(args, 'query').isEmpty ? null : _str(args, 'query'));
      if (!ok) throw VesperToolError('$section is hidden or unavailable.');
      return {'opened': section};
    },
  ),
  VesperTool(
    name: 'favorites',
    description:
        'List the viewer\'s favourite live channels, or add / remove a '
        'channel or movie (ref, or "current" for what is playing).',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['list', 'add', 'remove'],
        },
        'ref': {'type': 'string'},
      },
      'required': ['action'],
    },
    run: (box, args, caller) async {
      final action = _str(args, 'action');
      if (action == 'list') {
        await box.playlist.ensureLiveChannelsLoaded();
        return {
          'favorites': [
            for (final c in box.playlist.orderedFavoriteLiveChannels().take(60))
              box.describeChannel(c)
          ]
        };
      }
      final ref = _str(args, 'ref');
      final Object? item = ref == 'current' || ref.isEmpty
          ? box.playback.liveChannel
          : box.lookup(ref);
      if (item is XtreamSeries) {
        final on = box.playlist.isSeriesFavorited(item.id);
        if (on != (action == 'add')) {
          await box.playlist.toggleSeriesFavorite(item);
        }
        return {'done': action, 'title': item.name};
      }
      if (item is! Channel) throw VesperToolError('Which one? Search first.');
      final on = box.playlist.isChannelFavorited(item.id);
      if (on != (action == 'add')) await box.playlist.toggleFavorite(item);
      return {'done': action, 'title': item.name};
    },
  ),
  VesperTool(
    name: 'recent',
    description: 'Channels and titles the viewer played most recently.',
    schema: {'type': 'object', 'properties': {}},
    run: (box, args, caller) async => {
      'recent': [
        for (final c in box.playback.recentlyPlayed.take(20))
          box.describeChannel(c)
      ]
    },
  ),
  VesperTool(
    name: 'groups',
    description:
        'The groups (categories) of a tab: list them, or hide / show the '
        'groups whose name contains some words (e.g. hide every group with '
        '"Turkish"). Hidden groups come back in Settings > Playlists.',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['list', 'hide', 'show'],
        },
        'tab': {
          'type': 'string',
          'enum': ['tv', 'movies', 'series'],
        },
        'contains': {
          'type': 'string',
          'description': 'For hide / show: words the group names contain.',
        },
      },
      'required': ['action', 'tab'],
    },
    run: (box, args, caller) async {
      final action = _str(args, 'action');
      final tab = _str(args, 'tab');
      final groups = switch (tab) {
        'movies' => box.playlist.vodGroups,
        'series' => box.playlist.seriesGroups,
        _ => box.playlist.tvGroups,
      };
      if (action == 'list') {
        return {
          'groups': [
            for (final g in groups.take(300))
              {
                'name': g.title,
                if (box._manyPlaylists)
                  'playlist': box._playlistName(g.playlistId),
              }
          ],
          if (groups.length > 300) 'note': '${groups.length} groups in all.',
        };
      }
      if (box.restrictedViewer) {
        throw VesperToolError('This profile cannot change groups.');
      }
      final words = _str(args, 'contains');
      if (words.isEmpty) throw VesperToolError('Say which groups.');
      final search = TitleSearch(words);
      final hide = action == 'hide';
      final hidden = <String, Set<String>>{};
      if (hide) {
        for (final g in groups.where((g) => search.matches(g.title))) {
          (hidden[g.playlistId] ??= {}).add(g.title);
        }
      } else {
        for (final p in box.playlist.profiles) {
          for (final title in box.playlist.hiddenGroupsFor(p.id)) {
            if (search.matches(title)) (hidden[p.id] ??= {}).add(title);
          }
        }
      }
      final count = hidden.values.fold<int>(0, (n, s) => n + s.length);
      if (count == 0) throw VesperToolError('No group matches "$words".');
      await _confirmRemote(
          box,
          caller,
          hide
              ? 'An AI app wants to hide {count} groups ({words}).'
              : 'An AI app wants to show {count} groups ({words}).',
          {'count': count, 'words': words});
      for (final e in hidden.entries) {
        await box.playlist.setGroupsHidden(e.key, e.value, hide);
      }
      return {
        'done': action,
        'groups': [for (final s in hidden.values) ...s],
      };
    },
  ),
  VesperTool(
    name: 'sports_today',
    description:
        'Today\'s games in the viewer\'s Sports Trak leagues (optionally one '
        'team): status, start time, score, and a channel ref when a live '
        'channel carries the game.',
    schema: {
      'type': 'object',
      'properties': {
        'team': {'type': 'string', 'description': 'Team name or city.'},
      },
    },
    run: (box, args, caller) async {
      final team = _str(args, 'team');
      final games = await _todaysGames(box, team);
      final hideScores = box.prefs.sportsHideScores;
      final matched = await _gameChannels(box, games);
      return {
        'games': [
          for (final g in games.take(25))
            {
              'game': g.title,
              'league': g.league.name,
              'state': g.state.name,
              'start': '${_day(g.start)} ${_clock(g.start)}',
              if (g.statusText.isNotEmpty) 'status': g.statusText,
              if (!hideScores && g.state != GameState.pre)
                'score':
                    '${g.away.shortName} ${g.away.score ?? '-'}, ${g.home.shortName} ${g.home.score ?? '-'}',
              if (matched[g] case final c?) 'channel': box.describeChannel(c),
            }
        ],
        if (games.isEmpty) 'note': 'No games today in the viewer\'s leagues.',
        if (hideScores) 'note_scores': 'The viewer hides scores.',
      };
    },
  ),
  VesperTool(
    name: 'play_game',
    description:
        'Play the live (or next) game of a team today on the channel that '
        'carries it.',
    schema: {
      'type': 'object',
      'properties': {
        'team': {'type': 'string'},
      },
      'required': ['team'],
    },
    run: (box, args, caller) async {
      final team = _str(args, 'team');
      if (team.isEmpty) throw VesperToolError('Which team?');
      final games = await _todaysGames(box, team);
      if (games.isEmpty) throw VesperToolError('No $team game today.');
      games.sort((a, b) => _stateRank(a).compareTo(_stateRank(b)));
      final matched = await _gameChannels(box, games);
      for (final g in games) {
        final c = matched[g];
        if (c == null) continue;
        final result = await _play(box, c, caller);
        return {...result, 'game': g.title};
      }
      throw VesperToolError(
          'No channel in the playlists carries ${games.first.title}.');
    },
  ),
  VesperTool(
    name: 'show_message',
    description:
        'Show a short message on the TV screen for the viewer (one or two '
        'sentences).',
    schema: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
      },
      'required': ['text'],
    },
    run: (box, args, caller) async {
      final text = _str(args, 'text');
      if (text.isEmpty) throw VesperToolError('No text.');
      box.host.showMessage(text.length > 300 ? text.substring(0, 300) : text);
      return {'shown': true};
    },
  ),
];

int _stateRank(SportsGame g) => switch (g.state) {
      GameState.live => 0,
      GameState.pre => 1,
      GameState.post => 2,
    };

Future<List<SportsGame>> _todaysGames(VesperToolbox box, String team) async {
  final leagues = savedSportsLeagues(box.storage);
  if (leagues.isEmpty) return const [];
  final games =
      await SportsService.instance.gamesForDay(leagues, DateTime.now());
  if (team.isEmpty) return games;
  final search = TitleSearch(team);
  bool hit(SportsTeam t) =>
      search.matches(t.name) ||
      search.matches(t.shortName) ||
      TitleSearch.fold(t.abbreviation) == search.folded;
  return games.where((g) => hit(g.home) || hit(g.away)).toList();
}

/// The best live channel per game (Sports Trak's own matching and saved
/// picks).
Future<Map<SportsGame, Channel>> _gameChannels(
    VesperToolbox box, List<SportsGame> games) async {
  if (games.isEmpty) return const {};
  await box.playlist.ensureLiveChannelsLoaded();
  final live = box.playlist.visibleChannels(category: 'tv');
  final matcher = SportsChannelMatcher.shared(box.epg);
  await matcher.prepare(live, hidden: box.playlist.hiddenLiveChannels());
  final picks = SportsChannelPicks.load(box.storage);
  final found = await matcher.matchDay(games.take(25).toList(), picks);
  final out = <SportsGame, Channel>{};
  for (final g in games.take(25)) {
    final key = SportsChannelPicks.eventKey(g);
    final best = picks
        .orderMatches(found[key] ?? const [],
            countries: picks.countryPreferences)
        .firstOrNull
        ?.channel;
    if (best != null) out[g] = best;
  }
  return out;
}
