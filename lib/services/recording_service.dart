import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/channel.dart';
import '../models/playlist_profile.dart';
import '../models/sports.dart';
import 'playback_service.dart';
import 'sports_channel_matcher.dart';
import 'sports_service.dart';

/// Sports Trak recording (Android). The list of recordings, the one
/// auto-recorded team and the settings live in `recordings.json` in app
/// support storage — device-only on purpose (files are on this device, so
/// Transfer / Backup never carry it). The recording itself is native
/// (`RecorderService.kt`): it writes `<file>.ts` + `<file>.ts.status`, and
/// [RecorderScheduler] starts timed ones with an exact alarm even when the
/// app is closed. Dart re-sends the whole upcoming schedule on every change
/// ([_push]).
class RecordingService extends ChangeNotifier {
  RecordingService._();
  static final instance = RecordingService._();

  static const _channel = MethodChannel('vespertv/recorder');

  static bool get supported => Platform.isAndroid;

  final List<RecordingEntry> _items = [];
  AutoTeam? _autoTeam;
  RecordingSettings settings = const RecordingSettings();
  File? _file;
  bool _ready = false;
  Timer? _poll;

  /// Newest first.
  List<RecordingEntry> get items =>
      List.unmodifiable(_items..sort((a, b) => b.startAt.compareTo(a.startAt)));
  AutoTeam? get autoTeam => _autoTeam;

  Future<void> init() async {
    if (_ready || !supported) return;
    _ready = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/recordings.json');
      if (await _file!.exists()) {
        final m =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _items.addAll([
          for (final r in (m['items'] as List? ?? const []))
            RecordingEntry.fromJson(Map<String, dynamic>.from(r as Map)),
        ]);
        if (m['autoTeam'] case final Map a) {
          _autoTeam = AutoTeam.fromJson(Map<String, dynamic>.from(a));
        }
        if (m['settings'] case final Map s) {
          settings = RecordingSettings.fromJson(Map<String, dynamic>.from(s));
        }
      }
    } catch (e) {
      debugPrint('RecordingService: load failed: $e');
    }
    await refreshStatus();
    // While anything is recording, keep sizes/states fresh for the tab.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_items.any((r) => r.state == RecState.recording)) {
        unawaited(refreshStatus());
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'items': [for (final r in _items) r.toJson()],
        if (_autoTeam != null) 'autoTeam': _autoTeam!.toJson(),
        'settings': settings.toJson(),
      }));
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('RecordingService: save failed: $e');
    }
  }

  // ------------------------------------------------------------ storage

  /// Where recordings can go: app storage first, then USB / SD volumes.
  Future<List<RecordingVolume>> volumes() async {
    try {
      final list = await _channel.invokeListMethod<Map>('storage') ?? const [];
      return [
        for (final m in list)
          RecordingVolume(
            path: m['path'] as String,
            free: (m['free'] as num).toInt(),
            total: (m['total'] as num).toInt(),
            removable: m['removable'] == true,
          ),
      ];
    } catch (e) {
      debugPrint('RecordingService: storage failed: $e');
      return const [];
    }
  }

  /// The chosen folder when it's still mounted, else app storage.
  Future<RecordingVolume?> currentVolume() async {
    final vols = await volumes();
    return vols.where((v) => v.path == settings.folder).firstOrNull ??
        vols.firstOrNull;
  }

  int get usedBytes => _items.fold(0, (s, r) => s + r.bytes);

  Future<void> updateSettings(RecordingSettings s) async {
    settings = s;
    await _save();
    await _push();
    notifyListeners();
  }

  // ----------------------------------------------------------- schedule

  static String _key(SportsGame g) => SportsChannelPicks.eventKey(g);

  RecordingEntry? entryFor(SportsGame g) {
    final key = _key(g);
    return _items
        .where((r) => r.gameKey == key && r.state != RecState.cancelled)
        .firstOrNull;
  }

  bool isAutoTeam(SportsGame g, SportsTeam t) =>
      _autoTeam != null &&
      _autoTeam!.teamId == t.id &&
      sportsLeagueById(_autoTeam!.leagueId)?.isCfl == g.league.isCfl &&
      _sport(sportsLeagueById(_autoTeam!.leagueId)) == _sport(g.league);

  static String _sport(SportsLeague? l) => l?.espnPath.split('/').first ?? '';

  static String _gameTitle(SportsGame g) =>
      '${g.first.shortName} ${g.joiner} ${g.second.shortName}';

  /// Records [game] from [channel] (start - margin to end + margin).
  /// Returns the entry; starts at once when the game is already on.
  Future<RecordingEntry> recordGame(SportsGame game, Channel channel,
      {bool auto = false}) async {
    await init();
    final existing = entryFor(game);
    if (existing != null) return existing;
    final vol = await currentVolume();
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final start = game.start.toLocal();
    final title = game.isEventOnly ? game.title : _gameTitle(game);
    final entry = RecordingEntry(
      id: id,
      title: title,
      league: game.league.name,
      gameKey: _key(game),
      leagueId: game.league.id,
      gameStart: start,
      startAt: start.subtract(Duration(minutes: settings.minutesBefore)),
      endAt: _endFor(game),
      channelId: channel.id,
      channelName: channel.name,
      playlistId: channel.playlistId,
      url: channel.url,
      path: '${vol?.path ?? ''}/${_fileName(title, start, id)}',
      auto: auto,
      logo: game.first.logoUrl,
      logo2: game.isEventOnly ? null : game.second.logoUrl,
      team1: game.isEventOnly ? game.title : game.first.shortName,
      team2: game.isEventOnly ? '' : game.second.shortName,
      abbr1: game.first.abbreviation,
      abbr2: game.isEventOnly ? '' : game.second.abbreviation,
      color1: game.first.color,
      color2: game.isEventOnly ? null : game.second.color,
      channelLogo: channel.logoUrl,
    );
    _items.add(entry);
    await _save();
    await _push();
    notifyListeners();
    return entry;
  }

  DateTime _endFor(SportsGame g) {
    final end =
        g.end?.toLocal() ?? g.start.toLocal().add(_typicalLength(g.league));
    return end.add(Duration(minutes: settings.minutesAfter));
  }

  /// A game's usual length when the feed gives no end time.
  static Duration _typicalLength(SportsLeague l) {
    final sport = _sport(l);
    return switch (sport) {
      'soccer' => const Duration(minutes: 115),
      'football' => const Duration(hours: 3, minutes: 15),
      'baseball' => const Duration(hours: 3),
      'basketball' => const Duration(hours: 2, minutes: 30),
      'hockey' => const Duration(hours: 2, minutes: 40),
      'tennis' => const Duration(hours: 3),
      'mma' || 'boxing' || 'wrestling' => const Duration(hours: 4),
      'golf' => const Duration(hours: 5),
      'racing' => const Duration(hours: 2, minutes: 30),
      _ => const Duration(hours: 3),
    };
  }

  static String _fileName(String title, DateTime start, String id) {
    final safe = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final d = '${start.year}-${_two(start.month)}-${_two(start.day)}';
    return '${d}_${safe.isEmpty ? 'Recording' : safe}_$id.ts';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Records [channel] now until [until] (the guide program's end; 2 h
  /// without a guide), or until stopped when [untilStopped] (4 h at most,
  /// a forgotten one shouldn't fill the disk). [program] = what's on, for
  /// the card.
  Future<RecordingEntry> recordChannel(Channel channel,
      {String program = '', DateTime? until, bool untilStopped = false}) async {
    await init();
    final running = recordingOf(channel);
    if (running != null) return running;
    final vol = await currentVolume();
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final now = DateTime.now();
    final end = untilStopped
        ? now.add(const Duration(hours: 4))
        : (until != null && until.isAfter(now))
            ? until.add(const Duration(minutes: 5))
            : now.add(const Duration(hours: 2));
    final title = program.isEmpty ? channel.name : program;
    final entry = RecordingEntry(
      id: id,
      title: title,
      league: channel.name,
      gameKey: '',
      leagueId: '',
      gameStart: now,
      startAt: now,
      endAt: end,
      channelId: channel.id,
      channelName: channel.name,
      playlistId: channel.playlistId,
      url: channel.url,
      path: '${vol?.path ?? ''}/${_fileName(title, now, id)}',
      program: program,
      channelLogo: channel.logoUrl,
    );
    _items.add(entry);
    await _save();
    await _push();
    notifyListeners();
    return entry;
  }

  /// Starts a recording of [channel] with [start]. When [channel] is
  /// what's playing, the player lets go of the provider connection first
  /// (one-connection accounts would kick one of the two), then rejoins
  /// through the recorder's local tap once bytes arrive.
  Future<RecordingEntry> handOver(Channel channel, PlaybackService playback,
      Future<RecordingEntry> Function() start) async {
    final playing = playback.currentChannel?.id == channel.id;
    if (playing) await playback.stop();
    final entry = await start();
    if (playing) {
      await waitStarted(entry);
      await refreshStatus();
      await playback.play(channel);
    }
    return entry;
  }

  /// Waits (max [timeout]) until the recorder has received data for [r].
  Future<bool> waitStarted(RecordingEntry r,
      {Duration timeout = const Duration(seconds: 12)}) async {
    final until = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(until)) {
      try {
        final list = await _channel.invokeListMethod<Map>('active') ?? const [];
        final mine = list.where((m) => m['id'] == r.id).firstOrNull;
        if (mine != null && ((mine['bytes'] as num?) ?? 0) > 0) return true;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  /// Room for one more: under the cap, and the volume has a bit more than
  /// the 1 GB that recording always leaves free (small Fire Sticks have
  /// under 2 GB free; the recording then stops at that 1 GB).
  Future<bool> hasRoom() async {
    await init();
    if (usedBytes >= settings.capGb * 1024 * 1024 * 1024) return false;
    final vol = await currentVolume();
    return vol == null || vol.free >= settings.minFreeBytes + (256 << 20);
  }

  /// Cancels a scheduled one, stops a running one (keeps what it has).
  Future<void> stop(RecordingEntry r) async {
    if (r.state == RecState.recording) {
      try {
        await _channel.invokeMethod('stop', {'id': r.id});
      } catch (_) {}
      r.state = RecState.stopped;
    } else if (r.state == RecState.scheduled || r.state == RecState.waiting) {
      // An auto-team game stays cancelled (not re-added on refresh).
      if (r.auto) {
        r.state = RecState.cancelled;
      } else {
        _items.remove(r);
      }
    }
    await _save();
    await _push();
    notifyListeners();
  }

  /// Deletes the file and the entry.
  Future<void> delete(RecordingEntry r) async {
    if (r.state == RecState.recording) await stop(r);
    for (final p in [r.path, '${r.path}.status']) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (r.auto) {
      // Keep a tombstone so the team refresh doesn't add it back.
      r.state = RecState.cancelled;
      r.bytes = 0;
    } else {
      _items.remove(r);
    }
    await _save();
    await _push();
    notifyListeners();
  }

  /// Sends every upcoming recording to the native scheduler (which starts
  /// those already due). Returns false when Android only allowed inexact
  /// alarms.
  Future<bool> _push() async {
    if (!supported) return true;
    final now = DateTime.now();
    final cap = settings.capGb * 1024 * 1024 * 1024;
    final room = cap - usedBytes;
    final due = [
      for (final r in _items)
        if (r.state == RecState.scheduled &&
            r.endAt.isAfter(now) &&
            r.url.isNotEmpty)
          {
            'id': r.id,
            'url': r.url,
            'path': r.path,
            'title': r.title,
            'startAt': r.startAt.millisecondsSinceEpoch,
            'endAt': r.endAt.millisecondsSinceEpoch,
            'minFreeBytes': settings.minFreeBytes,
            // The whole cap is shared: a new recording gets what's left.
            'maxBytes': room > 0 ? room : 1,
          },
    ];
    debugPrint('RecordingService: ${due.length} recording(s) sent to the '
        'scheduler');
    try {
      return await _channel
              .invokeMethod<bool>('schedule', {'items': jsonEncode(due)}) ??
          true;
    } catch (e) {
      debugPrint('RecordingService: schedule failed: $e');
      return true;
    }
  }

  /// Reads each recording's `.status` and the native running list.
  Future<void> refreshStatus() async {
    if (!supported) return;
    Set<String> running = const {};
    try {
      final list = await _channel.invokeListMethod<Map>('active') ?? const [];
      running = {for (final m in list) m['id'] as String};
    } catch (_) {}
    var changed = false;
    final now = DateTime.now();
    for (final r in _items) {
      if (r.state == RecState.cancelled) continue;
      final before = (r.state, r.bytes);
      try {
        final f = File('${r.path}.status');
        if (await f.exists()) {
          final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          r.bytes = (m['bytes'] as num?)?.toInt() ?? r.bytes;
          r.error = m['error'] as String? ?? '';
          final s = RecState.fromNative(m['state'] as String? ?? '');
          // "recording" in the file but not running = the process died.
          r.state = s == RecState.recording && !running.contains(r.id)
              ? RecState.interrupted
              : s;
        } else if (running.contains(r.id)) {
          r.state = RecState.recording;
        } else if (r.state == RecState.scheduled && r.endAt.isBefore(now)) {
          // Never started (box off the whole time, no channel, no alarm).
          r.state = RecState.missed;
        }
      } catch (_) {}
      if (before != (r.state, r.bytes)) changed = true;
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  // --------------------------------------------------- connection check

  /// A running recording that would lose its connection if [channel] were
  /// opened: same playlist, another channel, and an account limited to one
  /// stream (unknown = one, the common case behind the owner's Tuliprox).
  RecordingEntry? conflictFor(Channel channel, List<PlaylistProfile> profiles) {
    if (!supported) return null;
    final profile =
        profiles.where((p) => p.id == channel.playlistId).firstOrNull;
    final limit = profile?.maxConnections ?? 1;
    final mine = _items.where((r) =>
        r.state == RecState.recording && r.playlistId == channel.playlistId);
    if (mine.any((r) => r.channelId == channel.id)) return null;
    final others = mine.toList();
    return others.length >= limit ? others.firstOrNull : null;
  }

  /// The running recording of [channel], if any — play [teeUrl] instead
  /// of the provider so both share one connection.
  RecordingEntry? recordingOf(Channel channel) => _items
      .where((r) => r.state == RecState.recording && r.channelId == channel.id)
      .firstOrNull;

  Future<String?> teeUrl(RecordingEntry r) async {
    try {
      final port = await _channel.invokeMethod<int>('teePort');
      return port == null ? null : 'http://127.0.0.1:$port/rec/${r.id}.ts';
    } catch (_) {
      return null;
    }
  }

  /// A recording as something the player opens (seekable local file).
  Channel channelFor(RecordingEntry r) => Channel(
        id: '${Channel.recordingPrefix}${r.id}',
        rawId: '${Channel.recordingPrefix}${r.id}',
        playlistId: '',
        name: r.title,
        group: r.league,
        url: r.path,
        logoUrl: r.logo,
      );

  // ---------------------------------------------------------- auto team

  Future<void> setAutoTeam(SportsLeague league, SportsTeam team) async {
    await init();
    _autoTeam = AutoTeam(
        leagueId: league.id, teamId: team.id, teamName: team.shortName);
    await _save();
    notifyListeners();
  }

  Future<void> clearAutoTeam() async {
    _autoTeam = null;
    // Upcoming auto games go; finished recordings stay.
    _items.removeWhere((r) =>
        r.auto &&
        (r.state == RecState.scheduled ||
            r.state == RecState.waiting ||
            r.state == RecState.cancelled));
    await _save();
    await _push();
    notifyListeners();
  }

  bool _refreshing = false;

  /// Adds the auto team's next games (14 days, its league + the viewer's
  /// other leagues of the same sport: cups) and gives each one the channel
  /// Sports Trak would pick. Games with no channel yet wait; they get one
  /// on a later refresh once the guide lists them. Run at startup and
  /// from Sports Trak.
  Future<void> refreshAutoTeam({
    required List<SportsLeague> viewerLeagues,
    required SportsChannelMatcher matcher,
    required SportsChannelPicks picks,
    required List<Channel> channels,
    List<Channel> hiddenChannels = const [],
  }) async {
    final team = _autoTeam;
    if (team == null || _refreshing || !supported) return;
    _refreshing = true;
    try {
      await init();
      final home = sportsLeagueById(team.leagueId);
      if (home == null) return;
      final leagues = <SportsLeague>{
        home,
        for (final l in viewerLeagues)
          if (_sport(l) == _sport(home) &&
              l.isCfl == home.isCfl &&
              l.sportsDbId == null &&
              home.sportsDbId == null)
            l,
      };
      final games = <String, SportsGame>{};
      for (final l in leagues) {
        final s = await SportsService.instance.teamSchedule(l, team.teamId);
        for (final g in s?.upcoming() ?? const <SportsGame>[]) {
          games[_key(g)] = g;
        }
      }
      if (games.isEmpty) return;
      // The same hidden list as every other caller: the shared matcher
      // re-indexes whenever the lists it's given differ.
      await matcher.prepare(channels, hidden: hiddenChannels);
      final matches = await matcher.matchDay(games.values.toList(), picks);
      var changed = false;
      for (final g in games.values) {
        final best = matches[_key(g)]?.firstOrNull?.channel;
        final existing = _items.where((r) => r.gameKey == _key(g)).firstOrNull;
        if (existing == null) {
          if (best != null) {
            await recordGame(g, best, auto: true);
          } else {
            final start = g.start.toLocal();
            final title = _gameTitle(g);
            final vol = await currentVolume();
            final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
            _items.add(RecordingEntry(
              id: id,
              title: title,
              league: g.league.name,
              gameKey: _key(g),
              leagueId: g.league.id,
              gameStart: start,
              startAt:
                  start.subtract(Duration(minutes: settings.minutesBefore)),
              endAt: _endFor(g),
              channelId: '',
              channelName: '',
              playlistId: '',
              url: '',
              path: '${vol?.path ?? ''}/${_fileName(title, start, id)}',
              auto: true,
              state: RecState.waiting,
              logo: g.first.logoUrl,
              logo2: g.second.logoUrl,
              team1: g.first.shortName,
              team2: g.second.shortName,
              abbr1: g.first.abbreviation,
              abbr2: g.second.abbreviation,
              color1: g.first.color,
              color2: g.second.color,
            ));
            changed = true;
          }
        } else if (existing.state == RecState.waiting && best != null) {
          existing
            ..channelId = best.id
            ..channelName = best.name
            ..playlistId = best.playlistId
            ..url = best.url
            ..state = RecState.scheduled;
          changed = true;
        } else if ((existing.state == RecState.scheduled ||
                existing.state == RecState.waiting) &&
            existing.gameStart != g.start.toLocal()) {
          // Rescheduled game.
          existing
            ..gameStart = g.start.toLocal()
            ..startAt = g.start
                .toLocal()
                .subtract(Duration(minutes: settings.minutesBefore))
            ..endAt = _endFor(g);
          changed = true;
        }
      }
      if (changed) {
        await _save();
        await _push();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('RecordingService: auto team refresh failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  /// Ask once for the notification permission (Android 13+), so the
  /// "Recording…" notification can show.
  Future<void> askNotifications() async {
    try {
      await _channel.invokeMethod('askNotifications');
    } catch (_) {}
  }
}

enum RecState {
  /// Auto-team game whose channel isn't known yet.
  waiting,
  scheduled,
  recording,
  done,
  stopped,
  failed,
  interrupted,
  missed,

  /// Auto-team game the user removed (kept so it isn't added back).
  cancelled;

  static RecState fromNative(String s) => switch (s) {
        'recording' => recording,
        'done' => done,
        'stopped' => stopped,
        'interrupted' => interrupted,
        _ => failed,
      };

  static RecState parse(String? s) =>
      RecState.values.where((v) => v.name == s).firstOrNull ?? scheduled;

  bool get finished =>
      this == done || this == stopped || this == failed || this == interrupted;
}

class RecordingEntry {
  RecordingEntry({
    required this.id,
    required this.title,
    required this.league,
    required this.gameKey,
    required this.leagueId,
    required this.gameStart,
    required this.startAt,
    required this.endAt,
    required this.channelId,
    required this.channelName,
    required this.playlistId,
    required this.url,
    required this.path,
    this.auto = false,
    this.state = RecState.scheduled,
    this.bytes = 0,
    this.error = '',
    this.logo,
    this.logo2,
    this.team1 = '',
    this.team2 = '',
    this.abbr1 = '',
    this.abbr2 = '',
    this.color1,
    this.color2,
    this.program = '',
    this.channelLogo,
  });

  final String id;
  final String title;
  final String league;
  final String gameKey;
  final String leagueId;
  DateTime gameStart;
  DateTime startAt;
  DateTime endAt;
  String channelId;
  String channelName;
  String playlistId;

  /// The provider's live URL — only the native recorder uses it.
  String url;
  final String path;
  final bool auto;
  RecState state;
  int bytes;
  String error;
  final String? logo;
  final String? logo2;

  /// Game card: both sides as Sports Trak shows them (no score is kept).
  final String team1;
  final String team2;
  final String abbr1;
  final String abbr2;
  final String? color1;
  final String? color2;

  /// Channel recording: the guide programme on air when it started.
  final String program;
  final String? channelLogo;

  /// A plain channel recording (no game behind it).
  bool get isChannel => gameKey.isEmpty;

  bool get playable => bytes > 0 && state != RecState.cancelled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'league': league,
        'gameKey': gameKey,
        'leagueId': leagueId,
        'gameStart': gameStart.millisecondsSinceEpoch,
        'startAt': startAt.millisecondsSinceEpoch,
        'endAt': endAt.millisecondsSinceEpoch,
        'channelId': channelId,
        'channelName': channelName,
        'playlistId': playlistId,
        'url': url,
        'path': path,
        'auto': auto,
        'state': state.name,
        'bytes': bytes,
        'error': error,
        if (logo != null) 'logo': logo,
        if (logo2 != null) 'logo2': logo2,
        'team1': team1,
        'team2': team2,
        'abbr1': abbr1,
        'abbr2': abbr2,
        if (color1 != null) 'color1': color1,
        if (color2 != null) 'color2': color2,
        'program': program,
        if (channelLogo != null) 'channelLogo': channelLogo,
      };

  factory RecordingEntry.fromJson(Map<String, dynamic> m) {
    DateTime t(String k) =>
        DateTime.fromMillisecondsSinceEpoch((m[k] as num?)?.toInt() ?? 0);
    return RecordingEntry(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      league: m['league'] as String? ?? '',
      gameKey: m['gameKey'] as String? ?? '',
      leagueId: m['leagueId'] as String? ?? '',
      gameStart: t('gameStart'),
      startAt: t('startAt'),
      endAt: t('endAt'),
      channelId: m['channelId'] as String? ?? '',
      channelName: m['channelName'] as String? ?? '',
      playlistId: m['playlistId'] as String? ?? '',
      url: m['url'] as String? ?? '',
      path: m['path'] as String? ?? '',
      auto: m['auto'] == true,
      state: RecState.parse(m['state'] as String?),
      bytes: (m['bytes'] as num?)?.toInt() ?? 0,
      error: m['error'] as String? ?? '',
      logo: m['logo'] as String?,
      logo2: m['logo2'] as String?,
      team1: m['team1'] as String? ?? '',
      team2: m['team2'] as String? ?? '',
      abbr1: m['abbr1'] as String? ?? '',
      abbr2: m['abbr2'] as String? ?? '',
      color1: m['color1'] as String?,
      color2: m['color2'] as String?,
      program: m['program'] as String? ?? '',
      channelLogo: m['channelLogo'] as String?,
    );
  }
}

class AutoTeam {
  const AutoTeam(
      {required this.leagueId, required this.teamId, required this.teamName});
  final String leagueId;
  final String teamId;
  final String teamName;

  Map<String, dynamic> toJson() =>
      {'leagueId': leagueId, 'teamId': teamId, 'teamName': teamName};

  factory AutoTeam.fromJson(Map<String, dynamic> m) => AutoTeam(
        leagueId: m['leagueId'] as String? ?? '',
        teamId: m['teamId'] as String? ?? '',
        teamName: m['teamName'] as String? ?? '',
      );
}

class RecordingSettings {
  const RecordingSettings({
    this.minutesBefore = 5,
    this.minutesAfter = 30,
    this.capGb = 20,
    this.folder,
  });

  final int minutesBefore;
  final int minutesAfter;
  final int capGb;

  /// The chosen volume's Recordings folder; null = app storage.
  final String? folder;

  /// Recording stops when the volume has less than this left.
  int get minFreeBytes => 1024 * 1024 * 1024;

  RecordingSettings copyWith(
          {int? minutesBefore,
          int? minutesAfter,
          int? capGb,
          String? folder}) =>
      RecordingSettings(
        minutesBefore: minutesBefore ?? this.minutesBefore,
        minutesAfter: minutesAfter ?? this.minutesAfter,
        capGb: capGb ?? this.capGb,
        folder: folder ?? this.folder,
      );

  Map<String, dynamic> toJson() => {
        'minutesBefore': minutesBefore,
        'minutesAfter': minutesAfter,
        'capGb': capGb,
        if (folder != null) 'folder': folder,
      };

  factory RecordingSettings.fromJson(Map<String, dynamic> m) =>
      RecordingSettings(
        minutesBefore: (m['minutesBefore'] as num?)?.toInt() ?? 5,
        minutesAfter: (m['minutesAfter'] as num?)?.toInt() ?? 30,
        capGb: (m['capGb'] as num?)?.toInt() ?? 20,
        folder: m['folder'] as String?,
      );
}

class RecordingVolume {
  const RecordingVolume(
      {required this.path,
      required this.free,
      required this.total,
      required this.removable});
  final String path;
  final int free;
  final int total;
  final bool removable;
}
