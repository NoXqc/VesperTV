import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../../l10n/l10n.dart';
import '../../models/archive_models.dart';
import '../../models/channel.dart';
import '../../models/epg_program.dart';
import '../../models/sports.dart';
import '../../models/viewer_profile.dart';
import '../../models/xtream_series.dart';
import '../../utils/title_search.dart';
import '../addon_service.dart';
import '../app_preferences.dart';
import '../archive_playback_preferences.dart';
import '../archive_playback_sources.dart';
import '../archive_service.dart';
import '../archive_stream_size.dart';
import '../audio_track_preferences.dart';
import '../channel_copy_fallback.dart';
import '../epg_service.dart';
import '../playback_service.dart';
import '../playlist_edits.dart';
import '../playlist_edits_diff.dart';
import '../playlist_manager.dart';
import '../playlist_session.dart';
import '../real_4k_channels.dart';
import '../sports_channel_countries.dart';
import '../sports_channel_matcher.dart';
import '../sports_service.dart';
import '../storage_service.dart';
import '../stream_languages.dart';
import '../subtitle_tracks.dart';
import '../vod_buffering.dart';
import 'watch_list.dart';
import '../../utils/constants.dart';
import '../../utils/desktop_platform.dart';
import '../../utils/video_hdr_report.dart';
import '../../widgets/data_pool_card.dart';

part 'game_channel_tool.dart';
part 'media_hub_tool.dart';
part 'my_groups_tool.dart';
part 'player_tracks.dart';
part 'playlist_editor_tool.dart';
part 'profiles_tool.dart';
part 'settings_tool.dart';
part 'vesper_help.dart';

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

/// Viewer profiles and the parental PIN for the profiles / parental tools
/// (the app's is in vesper_host.dart). The PIN is only ever typed on the
/// TV's own pad: nothing here takes or returns its digits.
abstract interface class VesperProfileControl {
  List<ViewerProfile> get profiles;
  ViewerProfile get active;
  bool get pinSet;

  /// The PIN pad on the TV: true only on the right PIN (false on Back, a
  /// lockout, or nobody answering in time).
  Future<bool> askPin();

  /// "Enter a new PIN, then again" on the TV: true once saved.
  Future<bool> newPin();

  /// [unlocked]: the PIN was already entered for this request.
  Future<bool> switchTo(String id, {bool unlocked = false});
  Future<ViewerProfile> create(String name,
      {required bool kid, required int colour});
  Future<void> rename(String id, String name);
  Future<bool> delete(String id);
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
    this.findHubTitle,
    this.clearHubHistory,
    this.profiles,
    this.hub,
  });

  /// Media Hub for the media_hub tool (null = no Media Hub).
  final VesperHub? hub;

  /// Viewer profiles + parental PIN (null = not available here).
  final VesperProfileControl? profiles;

  /// Media Hub search by title for the watch list (null = no Media Hub).
  final Future<HubTitle?> Function(String name)? findHubTitle;

  /// Empties Media Hub's Recently watched; returns how many titles it held
  /// (null = no Media Hub).
  final Future<int> Function()? clearHubHistory;

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
      HubTitle h => 'h:${h.key}',
      HubStream s => s.key,
      SportsGame g => 'g:${SportsChannelPicks.eventKey(g)}',
      _ => '$item',
    };
    final existing = _refOf[key];
    if (existing != null) {
      // A game is fetched again with a newer score: same ref, latest copy.
      if (item is SportsGame) _refs[existing] = item;
      return existing;
    }
    final prefix = switch (item) {
      Channel c => c.isLive ? 'l' : 'm',
      HubTitle _ => 'h',
      HubStream _ => 'o',
      SportsGame _ => 'g',
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
      if (c.isLive) ..._quality(c),
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

  /// Shown in Live TV for this viewer (hidden channels / groups, editor and
  /// Combine playlists all count).
  bool isVisibleLive(Channel c) =>
      playlist.visibleChannels(category: 'tv').any((x) => x.id == c.id);

  /// The live group best named by [query] ("PPV", "pay per view", "live
  /// events"), or null.
  String? findLiveGroup(String query) {
    final titles = {
      for (final g in playlist.tvGroups)
        if (!g.isHidden &&
            !playlist.hiddenGroupsFor(g.playlistId).contains(g.title))
          g.title
    }.toList();
    for (final q in [query, ...?_groupSynonyms[TitleSearch.fold(query)]]) {
      final best = rankByName(titles, q, (t) => t, limit: 1).firstOrNull;
      if (best != null) return best;
    }
    return null;
  }
}

/// Group names people say differently from how providers write them.
const _groupSynonyms = {
  'pay per view': ['ppv'],
  'pay per views': ['ppv'],
  'ppv': ['pay per view'],
  'live events': ['events', 'ppv'],
  'events': ['live events', 'ppv'],
  'paiement a la carte': ['ppv'],
  'pago por evento': ['ppv'],
};

/// [items] whose [name] matches [query] as a viewer says it, best first:
/// spoken numbers are digits ("TSN one" = "TSN 1", "Sportsnet 1" =
/// "Sportsnet One"), spelled letters join ("T S N" = "TSN"), and whole
/// words beat pieces of words ("TSN" never prefers "Sportsnet", which
/// holds "tsn"). Within a tier, shorter names first. Matches on a piece
/// of a word only are dropped when anything matches better.
List<T> rankByName<T>(Iterable<T> items, String query, String Function(T) name,
    {int limit = 20}) {
  final q = spokenTokens(query);
  if (q.isEmpty) return const [];
  // A cheap pass first (cached folds): the longest real word must be in
  // the name somewhere. ~350k channels for a big multi-playlist setup.
  final words = q.where((t) => !_isNumber(t)).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final gate = words.isEmpty ? null : TitleSearch(words.first);
  final loose = TitleSearch(query);
  final spoken = TitleSearch(q.join(' '));
  final scored = <(int, int, T)>[];
  for (final item in items) {
    final n = name(item);
    if (gate != null && !gate.matches(n)) continue;
    final score = _spokenScore(q, spokenTokens(n.replaceFirst(_tag, ''))) ??
        (loose.matches(n) || spoken.matches(n) ? 5 : null);
    if (score == null) continue;
    scored.add((score, n.length, item));
  }
  if (scored.any((s) => s.$1 < 5)) scored.removeWhere((s) => s.$1 == 5);
  scored.sort((a, b) {
    final s = a.$1.compareTo(b.$1);
    return s != 0 ? s : a.$2.compareTo(b.$2);
  });
  return [for (final s in scored.take(limit)) s.$3];
}

/// How well [name] matches [query] as [rankByName] scores it (0 best, 5 a
/// piece of a word only), null = no match.
int? spokenRank(String query, String name) {
  final q = spokenTokens(query);
  if (q.isEmpty) return null;
  return _spokenScore(q, spokenTokens(name.replaceFirst(_tag, ''))) ??
      (TitleSearch(query).matches(name) ||
              TitleSearch(q.join(' ')).matches(name)
          ? 5
          : null);
}

/// 0 same words, 1 starts with the query's words, 2 has them in a row,
/// 3 has every word, 4 every word starts a word ("1" in "10"); null =
/// not a whole-word match.
int? _spokenScore(List<String> q, List<String> n) {
  if (n.length < q.length) {
    return q.every((t) => n.any((w) => w.startsWith(t))) ? 4 : null;
  }
  bool runAt(int i) {
    for (var j = 0; j < q.length; j++) {
      if (n[i + j] != q[j]) return false;
    }
    return true;
  }

  if (runAt(0)) return n.length == q.length ? 0 : 1;
  for (var i = 1; i + q.length <= n.length; i++) {
    if (runAt(i)) return 2;
  }
  if (q.every(n.contains)) return 3;
  if (q.every((t) => n.any((w) => w.startsWith(t)))) return 4;
  return null;
}

bool _isNumber(String t) => int.tryParse(t) != null;

/// A leading provider tag ("CA: ", "US| ", "[UK] "): "CA: TSN 1" is
/// exactly "TSN 1" for ranking.
final _tag = RegExp(r'^\s*(?:[\[(][A-Za-z]{2,4}[\])]|[A-Za-z]{2,4}\s*[:|])\s*');

/// Spoken numbers (EN / FR / ES / IT / DE) as digits.
const _numberWords = {
  'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', //
  'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
  'ten': '10', 'eleven': '11', 'twelve': '12',
  'un': '1', 'une': '1', 'deux': '2', 'trois': '3', 'quatre': '4',
  'cinq': '5', 'sept': '7', 'huit': '8', 'neuf': '9', 'dix': '10',
  'uno': '1', 'dos': '2', 'tres': '3', 'cuatro': '4', 'cinco': '5',
  'seis': '6', 'siete': '7', 'ocho': '8', 'nueve': '9', 'diez': '10',
  'due': '2', 'tre': '3', 'quattro': '4', 'cinque': '5', 'sei': '6',
  'sette': '7', 'otto': '8', 'nove': '9', 'dieci': '10',
  'eins': '1', 'zwei': '2', 'drei': '3', 'vier': '4', 'funf': '5',
  'sechs': '6', 'sieben': '7', 'acht': '8', 'neun': '9', 'zehn': '10',
};

final Map<String, List<String>> _spokenCache = {};
final _letterDigit = RegExp(r'(?<=[a-z])(?=\d)|(?<=\d)(?=[a-z])');

/// [text]'s words as [rankByName] compares them: folded, "tsn1" split into
/// "tsn 1", number words as digits, runs of single letters joined.
List<String> spokenTokens(String text) {
  final hit = _spokenCache[text];
  if (hit != null) return hit;
  final words = TitleSearch.fold(text)
      .replaceAll(_letterDigit, ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => _numberWords[w] ?? w)
      .toList();
  final out = <String>[];
  var letters = '';
  for (final w in words) {
    if (w.length == 1 && !_isNumber(w)) {
      letters += w;
      continue;
    }
    if (letters.isNotEmpty) out.add(letters);
    letters = '';
    out.add(w);
  }
  if (letters.isNotEmpty) out.add(letters);
  if (_spokenCache.length >= 20000) _spokenCache.clear();
  return _spokenCache[text] = out;
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
      // A ref from an earlier search outlives a Hide channel / hidden group
      // (user report: hidden channels still played).
      if (c.isLive && !box.isVisibleLive(c)) {
        throw VesperToolError('${c.name} is hidden on this TV. Search again '
            'for another channel.');
      }
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
        'programme on now and next, whether it is paused and any error on '
        'screen. quality true also measures how it plays (picture, HDR, '
        'audio, downloaded bitrate, buffer, buffering, dropped frames; '
        'takes 2 s). A Media Hub title also gives its stream (media_hub '
        'sources lists the others).',
    schema: {
      'type': 'object',
      'properties': {
        'quality': {
          'type': 'boolean',
          'description': 'Measure picture, sound and bitrate too.',
        },
      },
    },
    run: (box, args, caller) async {
      if (usesMediaKit) {
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
      final playing = box.playback.currentChannel;
      final hubStream =
          playing == null ? null : box.playback.hubSources?.current(playing.id);
      if (playing != null && hubStream != null) {
        out['stream'] = _describeStream(
            box, HubStream(hubStream, channelId: playing.id),
            playing: true);
      }
      if (args['quality'] == true) {
        final quality = await _playingQuality(box);
        if (quality.isNotEmpty) out['quality'] = quality;
      }
      if (box.playback.error case final error?) out['error_on_tv'] = error;
      return out;
    },
  ),
  VesperTool(
    name: 'player',
    description:
        'Control the player: pause, resume, stop, go back or forward a '
        'number of seconds (fast forward 2 minutes = seek 120, rewind 30 '
        'seconds = seek -30), back to live, next / previous channel, next / '
        'previous episode of the show playing. audio_tracks / subtitles '
        'list what the playing file has; audio_track picks one by language '
        '(code or name) or track number; subtitle picks a language, a '
        'track number or "off" (not in the file: the first match from the '
        'viewer\'s subtitle add-ons). Both are remembered for the rest of '
        'the show, like a pick in the player. Prefer audio_track over '
        'switching the Media Hub stream when the file has the language.',
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
            'next_episode',
            'previous_episode',
            'audio_tracks',
            'audio_track',
            'subtitles',
            'subtitle',
          ],
        },
        'language': {
          'type': 'string',
          'description': 'For audio_track / subtitle: a language code or '
              'name ("en", "French"); subtitle also "off" or "cc" (live '
              'closed captions).',
        },
        'track': {
          'type': 'integer',
          'description': 'For audio_track / subtitle: the track number from '
              'audio_tracks / subtitles.',
        },
        'forced': {
          'type': 'boolean',
          'description': 'For subtitle: the forced track (foreign lines '
              'only) instead of full subtitles.',
        },
        'seconds': {
          'type': 'integer',
          'description': 'For seek: negative goes back, positive forward.',
        },
      },
      'required': ['action'],
    },
    run: (box, args, caller) async {
      if (usesMediaKit) {
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
        case 'audio_tracks':
          return _audioTracks(box, c!);
        case 'audio_track':
          return _setAudioTrack(box, c!, args);
        case 'subtitles':
          return _subtitles(box, c!);
        case 'subtitle':
          return _setSubtitles(box, c!, args);
        case 'next_episode':
        case 'previous_episode':
          // The player's own Next / Previous episode buttons (IPTV and
          // Media Hub shows): the queue the show's page set.
          final episode = action == 'next_episode'
              ? playback.nextUpChannel
              : playback.previousUpChannel;
          if (episode == null) {
            throw VesperToolError(action == 'next_episode'
                ? 'No next episode: this is the last one, or not a show.'
                : 'No previous episode: this is the first one, or not a show.');
          }
          await playback.play(episode);
          return {'playing': episode.name};
        case 'channel_up':
        case 'channel_down':
          final ch = playback.liveChannel;
          // "Next" during a show means its next episode.
          final episode = action == 'channel_up'
              ? playback.nextUpChannel
              : playback.previousUpChannel;
          if ((ch == null || !ch.isLive) && episode != null) {
            await playback.play(episode);
            return {'playing': episode.name};
          }
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
  _mediaHubTool,
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
        'movies, series, home, hub (Media Hub; with a query it searches the '
        'Media Hub for that title), sports (Sports Trak), '
        'search (with a query; lists every match in the playlists and the '
        'Media Hub for the viewer to pick), '
        'group (a live TV category by name, e.g. "PPV" or "Live Events", '
        'in query) or settings.',
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
            'group',
            'settings',
          ],
        },
        'query': {
          'type': 'string',
          'description':
              'For search, group and hub. For search: only the title words '
                  '(every word must be in a title): "project x", never "project x movie".',
        },
      },
      'required': ['section'],
    },
    run: (box, args, caller) async {
      final section = _str(args, 'section');
      if (section == 'group') {
        final words = _str(args, 'query');
        if (words.isEmpty) throw VesperToolError('Which group?');
        await box.playlist.ensureLiveChannelsLoaded();
        final title = box.findLiveGroup(words);
        if (title != null &&
            await box.host.openSection('group', query: title)) {
          return {'opened': 'group', 'group': title};
        }
        // No such group: the search page with those words instead.
        if (await box.host.openSection('search', query: words)) {
          return {
            'opened': 'search',
            'note': 'No live group is called "$words"; the search page '
                'shows the channels with those words.',
          };
        }
        throw VesperToolError('No live group is called "$words".');
      }
      final ok = await box.host.openSection(section,
          query: _str(args, 'query').isEmpty ? null : _str(args, 'query'));
      if (!ok) throw VesperToolError('$section is hidden or unavailable.');
      return {'opened': section};
    },
  ),
  VesperTool(
    name: 'favorites',
    description:
        'The viewer\'s favourite live channels, in the order the TV shows '
        'them. list: all of them. add / remove: a channel or movie (ref, or '
        '"current" for what is playing). move: one favourite channel (ref) '
        'to top, bottom, up / down (steps) or a position. order: refs in '
        'the order wanted (e.g. CP24, then the Canadian channels, then US, '
        'then 24/7): they go first in that order, the others keep their '
        'order after them; list all of them to set the whole order.',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['list', 'add', 'remove', 'move', 'order'],
        },
        'ref': {'type': 'string'},
        'to': {
          'type': 'string',
          'description': 'For move: top, bottom, up, down or a position '
              'number (1 = first).',
        },
        'steps': {
          'type': 'integer',
          'description': 'For move up / down: how many places (default 1).',
        },
        'refs': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'For order: favourite channel refs from list, in '
              'the new order.',
        },
      },
      'required': ['action'],
    },
    run: (box, args, caller) async {
      final action = _str(args, 'action');
      final mix = box.prefs.mixFavoritePlaylists;
      if (action == 'list') {
        await box.playlist.ensureLiveChannelsLoaded();
        final all = box.playlist.orderedFavoriteLiveChannels(mixPlaylists: mix);
        // All of them, so an order can cover every one; what's on now only
        // for the first ones (it's long).
        return {
          'favorites': [
            for (final (i, c) in all.take(500).indexed)
              box.describeChannel(c, withNow: i < 40)
          ],
          if (all.length > 500)
            'note': '${all.length} favourites; the first 500 are listed.',
        };
      }
      if (action == 'order') {
        final refs = args['refs'];
        if (refs is! List || refs.isEmpty) {
          throw VesperToolError('Give refs: favourite channel refs from list, '
              'in the order wanted.');
        }
        await box.playlist.ensureLiveChannelsLoaded();
        final ids = <String>[];
        final unknown = <String>[];
        for (final r in refs) {
          final c = box.lookup('$r');
          if (c is Channel) {
            ids.add(c.id);
          } else {
            unknown.add('$r');
          }
        }
        final before = box.playlist
            .orderedFavoriteLiveChannels(mixPlaylists: mix)
            .map((c) => c.id)
            .toSet();
        final now = await box.playlist
            .orderFavoriteLiveChannels(ids, mixPlaylists: mix);
        return {
          'order': [
            for (final (i, c) in now.take(500).indexed) '${i + 1}. ${c.name}'
          ],
          if (unknown.isNotEmpty) 'unknown_refs': unknown,
          if (ids.any((id) => !before.contains(id)))
            'note': 'Some refs are not favourites and were skipped.',
        };
      }
      final ref = _str(args, 'ref');
      final Object? item = ref == 'current' || ref.isEmpty
          ? box.playback.liveChannel
          : box.lookup(ref);
      if (action == 'move') {
        if (item is! Channel) {
          throw VesperToolError('Give a favourite channel ref from list.');
        }
        await box.playlist.ensureLiveChannelsLoaded();
        final shown =
            box.playlist.orderedFavoriteLiveChannels(mixPlaylists: mix);
        final from = shown.indexWhere((c) => c.id == item.id);
        if (from < 0) {
          throw VesperToolError('${item.name} is not in the favourites.');
        }
        final to = _str(args, 'to').toLowerCase();
        final steps = _int(args, 'steps', 1, min: 1, max: 10000);
        final index = switch (to) {
          'top' || 'first' => 0,
          'bottom' || 'last' => shown.length - 1,
          'up' || 'higher' => from - steps,
          'down' || 'lower' => from + steps,
          _ => (int.tryParse(to) ??
                  (throw VesperToolError(
                      'to: top, bottom, up, down or a position number.'))) -
              1,
        };
        final placed = await box.playlist
            .placeFavoriteLiveChannel(item, index, mixPlaylists: mix);
        return {
          'moved': item.name,
          'position': (placed ?? from) + 1,
          'of': shown.length,
        };
      }
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
    name: 'watchlist',
    description:
        'The viewer\'s watch list (a row on the Home page, in Movies / TV '
        'Shows and a page in Media Hub): list it, add or remove titles (a ref '
        'from search or from this list, a name, or "current" for what is '
        'playing), or clear it. Titles come from the IPTV playlists or from '
        'Media Hub (source: "media_hub"); by name, the playlists are tried '
        'first, then Media Hub. Use it for lists like "a movie night list for '
        'Friday": search, then add each pick with a short note.',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['list', 'add', 'remove', 'clear'],
        },
        'ref': {'type': 'string'},
        'name': {
          'type': 'string',
          'description': 'Title name when there is no ref.'
        },
        'source': {
          'type': 'string',
          'enum': ['iptv', 'media_hub'],
          'description': 'For a name: only look there.'
        },
        'note': {
          'type': 'string',
          'description': 'For add: why it is on the list (a few words).'
        },
      },
      'required': ['action'],
    },
    run: (box, args, caller) async {
      final action = _str(args, 'action');
      final list = WatchList.instance;
      if (action == 'list') {
        return {
          'watchlist': [
            for (final i in list.load(box.storage))
              {
                'ref': box.refFor((i.channel ?? i.series ?? i.hub)!),
                'title': i.title,
                'kind': i.kind,
                if (i.hub != null) 'source': 'Media Hub',
                if (i.note != null) 'note': i.note,
              }
          ]
        };
      }
      if (action == 'clear') {
        await _confirmRemote(
            box, caller, 'An AI app wants to clear your watch list.', const {});
        return {'cleared': await list.clear(box.storage)};
      }
      final ref = _str(args, 'ref');
      final name = _str(args, 'name');
      final source = _str(args, 'source');
      final note = _str(args, 'note');
      // Removing by name: what is on the list wins over a fresh search.
      if (action == 'remove' && ref.isEmpty && name.isNotEmpty) {
        final want = name.toLowerCase();
        final saved = list.load(box.storage);
        final hit =
            saved.where((i) => i.title.toLowerCase() == want).firstOrNull ??
                saved
                    .where((i) => i.title.toLowerCase().contains(want))
                    .firstOrNull;
        if (hit != null) {
          await list.remove(box.storage, hit.id);
          return {'removed': true, 'title': hit.title};
        }
      }
      Object? item = ref == 'current'
          ? box.playback.liveChannel
          : (ref.isNotEmpty ? box.lookup(ref) : null);
      if (item == null && name.isNotEmpty && source != 'media_hub') {
        item = (await box.findMovies(name, limit: 1)).firstOrNull ??
            (await box.findSeries(name, limit: 1)).firstOrNull ??
            box.findM3uShows(name, limit: 1).firstOrNull ??
            (source == 'iptv'
                ? (await box.findLive(name, limit: 1)).firstOrNull
                : null);
      }
      if (item == null &&
          name.isNotEmpty &&
          source != 'iptv' &&
          box.findHubTitle != null) {
        item = await box.findHubTitle!(name);
      }
      if (item == null && name.isNotEmpty && source.isEmpty) {
        item = (await box.findLive(name, limit: 1)).firstOrNull;
      }
      final entry = switch (item) {
        Channel c => WatchListItem(channel: c, note: note),
        XtreamSeries s => WatchListItem(series: s, note: note),
        HubTitle h => WatchListItem(hub: h, note: note),
        _ => null,
      };
      if (entry == null) throw VesperToolError('Which title? Search first.');
      if (action == 'remove') {
        final removed = await list.remove(box.storage, entry.id);
        return {'removed': removed, 'title': entry.title};
      }
      final added = await list.add(box.storage, entry);
      return {
        'added': added,
        'title': entry.title,
        if (entry.hub != null) 'source': 'Media Hub',
        if (!added) 'note': 'Already on the watch list.',
      };
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
        'The groups (categories) of a tab: list them, list the live channels '
        'of one group with their guide now / next (action channels, e.g. '
        'every "NBA League Pass" channel), or hide / show the groups whose '
        'name contains some words (e.g. hide every group with "Turkish"). '
        'Hidden groups come back in Settings > Playlists. For single '
        'channels, rules or renames use playlist_editor; for the viewer\'s '
        'own groups (new groups of picked channels) use my_groups.',
    schema: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': ['list', 'channels', 'hide', 'show'],
        },
        'tab': {
          'type': 'string',
          'enum': ['tv', 'movies', 'series'],
        },
        'contains': {
          'type': 'string',
          'description': 'For hide / show: words the group names contain.',
        },
        'group': {
          'type': 'string',
          'description': 'For channels: the group\'s name (tab tv).',
        },
      },
      'required': ['action', 'tab'],
    },
    run: (box, args, caller) async {
      final action = _str(args, 'action');
      final tab = _str(args, 'tab');
      if (action == 'channels') return _groupChannels(box, _str(args, 'group'));
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
  _myGroupsTool,
  _playlistEditorTool,
  _settingsTool,
  _profilesTool,
  _parentalTool,
  VesperTool(
    name: 'sports_today',
    description:
        'The games of a day (default today) in the viewer\'s Sports Trak '
        'leagues, optionally one league ("NBA") or team: a game ref, status, '
        'start time, score, the TV networks the league lists, and the '
        'channel Sports Trak matched (matched_by says how sure). To fix or '
        'fill a game\'s channel use game_channel; read vesper_help topic '
        '"sports" first.',
    schema: {
      'type': 'object',
      'properties': {
        'team': {'type': 'string', 'description': 'Team name or city.'},
        'league': {
          'type': 'string',
          'description': 'League name or short name ("NBA", "Premier '
              'League").',
        },
        'day': {
          'type': 'string',
          'description': '"today" (default), "tomorrow", "yesterday" or '
              'YYYY-MM-DD.',
        },
      },
    },
    run: (box, args, caller) async {
      final team = _str(args, 'team');
      final day = _sportsDay(_str(args, 'day'));
      final games =
          await _todaysGames(box, team, league: _str(args, 'league'), day: day);
      final hideScores = box.prefs.sportsHideScores;
      final matched = await _gameMatchList(box, games);
      return {
        'games': [
          for (final g in games.take(25))
            {
              'ref': box.refFor(g),
              'game': g.title,
              'league': g.league.name,
              'state': g.state.name,
              'start': '${_day(g.start)} ${_clock(g.start)}',
              if (g.statusText.isNotEmpty) 'status': g.statusText,
              if (!hideScores && g.state != GameState.pre)
                'score':
                    '${g.away.shortName} ${g.away.score ?? '-'}, ${g.home.shortName} ${g.home.score ?? '-'}',
              if (g.broadcasts.isNotEmpty) 'networks': g.broadcasts,
              if (matched[g]?.firstOrNull case final m?)
                'channel': _gameChannel(box, g, m),
            }
        ],
        if (games.length > 25)
          'note_more': '${games.length} games in all; '
              'ask for one league or team.',
        if (games.isEmpty)
          'note': 'No games that day in the viewer\'s leagues.',
        if (hideScores) 'note_scores': 'The viewer hides scores.',
      };
    },
  ),
  _gameChannelTool,
  VesperTool(
    name: 'play_game',
    description:
        'Play the live (or next) game of a team today on the channel that '
        'carries it. language picks the feed ("en" for the English '
        'broadcast, "fr" French, "es" Spanish...); list: true returns every '
        'channel carrying it (with its language) instead of playing.',
    schema: {
      'type': 'object',
      'properties': {
        'team': {'type': 'string'},
        'language': {
          'type': 'string',
          'description': 'Feed language code: en, fr, es, it, de, pt, el.',
        },
        'list': {'type': 'boolean'},
      },
      'required': ['team'],
    },
    run: (box, args, caller) async {
      final team = _str(args, 'team');
      if (team.isEmpty) throw VesperToolError('Which team?');
      final asked = _str(args, 'language').toLowerCase();
      // Not said: the viewer's preferred audio language (Settings >
      // Playback > Audio), after a channel they saved for the game.
      final language =
          asked.isNotEmpty ? asked : box.storage.getPreferredAudioLanguage();
      final games = await _todaysGames(box, team);
      if (games.isEmpty) throw VesperToolError('No $team game today.');
      games.sort((a, b) => _stateRank(a).compareTo(_stateRank(b)));
      final matched = {
        for (final e in (await _gameMatchList(box, games)).entries)
          e.key: _inLanguage(e.value, language, keepPick: asked.isEmpty),
      };
      if (args['list'] == true) {
        return {
          'games': [
            for (final g in games.take(3))
              {
                'ref': box.refFor(g),
                'game': g.title,
                'state': g.state.name,
                'start': '${_day(g.start)} ${_clock(g.start)}',
                'channels': [
                  for (final m
                      in (matched[g] ?? const <ChannelMatch>[]).take(15))
                    {
                      ..._gameChannel(box, g, m),
                      if (vesperChannelLanguage(m.channel) case final l?)
                        'language': l,
                    }
                ],
              }
          ],
        };
      }
      for (final g in games) {
        final options = matched[g] ?? const <ChannelMatch>[];
        if (options.isEmpty) continue;
        final best = options.first.channel;
        final result = await _play(box, best, caller);
        return {
          ...result,
          'game': g.title,
          if (asked.isNotEmpty && vesperChannelLanguage(best) != asked)
            'note': 'No channel in that language carries it; playing the '
                'best match instead.',
        };
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
  _vesperHelpTool,
];

int _stateRank(SportsGame g) => switch (g.state) {
      GameState.live => 0,
      GameState.pre => 1,
      GameState.post => 2,
    };

Future<List<SportsGame>> _todaysGames(VesperToolbox box, String team,
    {String league = '', DateTime? day}) async {
  var leagues = savedSportsLeagues(box.storage);
  if (leagues.isEmpty) return const [];
  if (league.isNotEmpty) {
    final want = TitleSearch.fold(league);
    final exact = [
      for (final l in leagues)
        if (TitleSearch.fold(l.shortName) == want ||
            TitleSearch.fold(l.name) == want ||
            TitleSearch.fold(l.id) == want)
          l
    ];
    final search = TitleSearch(league);
    leagues = exact.isNotEmpty
        ? exact
        : [
            for (final l in leagues)
              if (search.matches(l.name) || search.matches(l.shortName)) l
          ];
    if (leagues.isEmpty) {
      throw VesperToolError('$league is not in the viewer\'s Sports Trak '
          'leagues (${savedSportsLeagues(box.storage).map((l) => l.shortName).join(', ')}). '
          'The viewer adds leagues in Sports Trak > Edit leagues.');
    }
  }
  final games =
      await SportsService.instance.gamesForDay(leagues, day ?? DateTime.now());
  if (team.isEmpty) return games;
  final search = TitleSearch(team);
  bool hit(SportsTeam t) =>
      search.matches(t.name) ||
      search.matches(t.shortName) ||
      TitleSearch.fold(t.abbreviation) == search.folded;
  return games.where((g) => hit(g.home) || hit(g.away)).toList();
}

/// "today" / "tomorrow" / "yesterday" / YYYY-MM-DD as a local day (empty
/// or unreadable = today).
DateTime _sportsDay(String said) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (said.toLowerCase()) {
    'tomorrow' => today.add(const Duration(days: 1)),
    'yesterday' => today.subtract(const Duration(days: 1)),
    _ => DateTime.tryParse(said) ?? today,
  };
}

/// How sure Sports Trak's match is, in words a model reads: only "pick",
/// "guide" and "channel_name" name the game itself; the guesses only name
/// the team's or the broadcaster's channel.
String _matchedBy(ChannelMatch m) => switch (m.reason) {
      MatchReason.pick => 'viewer_pick',
      MatchReason.guide => m.gameEvidence ? 'guide' : 'guide_series_guess',
      MatchReason.name => m.gameEvidence ? 'channel_name' : 'name_guess',
      MatchReason.teamChannel => 'team_channel_guess',
      MatchReason.network => 'network_guess',
    };

/// [matches] with the ones in [language] first, otherwise in the same
/// order; with [keepPick] a channel the viewer saved for the game stays
/// first whatever its language.
List<ChannelMatch> _inLanguage(List<ChannelMatch> matches, String language,
    {required bool keepPick}) {
  if (language.isEmpty) return matches;
  int tier(ChannelMatch m) => keepPick && m.reason == MatchReason.pick
      ? 0
      : vesperChannelLanguage(m.channel) == language
          ? 1
          : 2;
  final indexed = [...matches.indexed]..sort((a, b) {
      final t = tier(a.$2).compareTo(tier(b.$2));
      return t != 0 ? t : a.$1.compareTo(b.$1);
    });
  return [for (final (_, m) in indexed) m];
}

/// A channel carrying [g], for the sports tools. Not describeChannel: its
/// kind "live" (a live TV channel) read as the game being live, and its
/// on_now is the wrong moment for a game that starts later (an AI app
/// saw another game's title there). Here: the guide's programme at the
/// game's start (or now, once it started), how the match was made and the
/// picture quality.
Map<String, Object?> _gameChannel(
    VesperToolbox box, SportsGame g, ChannelMatch m) {
  final c = m.channel;
  final upcoming = g.state == GameState.pre;
  final at = upcoming ? g.start : DateTime.now();
  final around =
      box.epg.programsBetween(c.epgId, at, at.add(const Duration(minutes: 1)));
  final p = around
          .where((p) => !p.start.isAfter(at) && p.stop.isAfter(at))
          .firstOrNull ??
      around.firstOrNull;
  return {
    'ref': box.refFor(c),
    'title': c.name,
    if (c.group.isNotEmpty) 'group': c.group,
    if (box._manyPlaylists) 'playlist': box._playlistName(c.playlistId),
    ..._quality(c),
    'matched_by': _matchedBy(m),
    if (m.detail case final d? when d.isNotEmpty) 'evidence': d,
    if (p != null) (upcoming ? 'on_at_game_time' : 'on_now'): p.title,
  };
}

/// The picture quality a live channel's name (else its group) says: 8K,
/// 4K, FHD, HD or SD; nothing when neither says. quality_measured: the TV
/// saw it decode at 2160p (Real 4K tag).
Map<String, Object?> _quality(Channel c) {
  var rank = ChannelCopyFallback.qualityRank(c.name);
  if (rank == 2 && c.group.isNotEmpty) {
    rank = ChannelCopyFallback.qualityRank(c.group);
  }
  final label = switch (rank) {
    6 => '8K',
    5 => '4K',
    4 => 'FHD',
    3 => 'HD',
    1 => 'SD',
    _ => null,
  };
  final measured = Real4kChannels.contains(c.id);
  return {
    if (measured) 'quality': '4K' else if (label != null) 'quality': label,
    if (measured) 'quality_measured': true,
  };
}

/// Every channel carrying each game, best first: the Sports Trak order
/// (saved pick, game evidence, preferred playlist, preferred countries,
/// highest quality; distinct channels before their copies).
Future<Map<SportsGame, List<ChannelMatch>>> _gameMatchList(
    VesperToolbox box, List<SportsGame> games) async {
  if (games.isEmpty) return const {};
  await box.playlist.ensureLiveChannelsLoaded();
  final live = box.playlist.visibleChannels(category: 'tv');
  final matcher = SportsChannelMatcher.shared(box.epg);
  await matcher.prepare(live, hidden: box.playlist.hiddenLiveChannels());
  final picks = SportsChannelPicks.load(box.storage);
  final found = await matcher.matchDay(games.take(25).toList(), picks);
  final out = <SportsGame, List<ChannelMatch>>{};
  for (final g in games.take(25)) {
    final key = SportsChannelPicks.eventKey(g);
    out[g] = picks.orderMatches(found[key] ?? const [],
        countries: picks.countryPreferences);
  }
  return out;
}

/// A live channel's language as its name / group / network says it
/// ("FR| RDS" = fr, "US| ESPN" = en), null when it doesn't say. Canada
/// counts as English unless the channel is French (RDS, TVA, "CA FR").
String? vesperChannelLanguage(Channel c) {
  final words = ' ${TitleSearch.fold('${c.name} ${c.group}')} ';
  bool has(String pattern) => RegExp(' (?:$pattern) ').hasMatch(words);
  if (has('fr|french|francais|vf|vff|cafr|qc|quebec|rds|rds2|tva|tva sports'
      '|ca fr')) {
    return 'fr';
  }
  if (has('es|spanish|espanol|deportes|tudn|univision|telemundo|latino'
      '|latam|mx')) {
    return 'es';
  }
  final country = SportsChannelCountries.infer(c);
  return switch (country) {
    'US' || 'UK' || 'CA' || 'IE' || 'AU' || 'NZ' => 'en',
    'FR' => 'fr',
    'ES' || 'MX' || 'AR' => 'es',
    'IT' => 'it',
    'DE' || 'AT' => 'de',
    'PT' || 'BR' => 'pt',
    'GR' || 'CY' => 'el',
    'NL' => 'nl',
    _ => has('en|eng|english') ? 'en' : null,
  };
}
