import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/playlist_profile.dart';
import '../models/sports.dart';
import 'network_files.dart';
import 'playback_service.dart';
import 'sports_channel_matcher.dart';
import 'sports_service.dart';
import 'programme_reminders.dart' show programmeKey;

/// Sports Trak recording (Android). The list of recordings, the one
/// auto-recorded team and the settings live in `recordings.json` in app
/// support storage — device-only on purpose (files are on this device, so
/// Transfer / Backup never carry it). The recording itself is native
/// (`RecorderService.kt`): it writes `<file>.ts` + `<file>.ts.status`, and
/// [RecorderScheduler] starts timed ones with an exact alarm even when the
/// app is closed. Dart re-sends the whole upcoming schedule on every change
/// ([_push]).
class RecordingService extends ChangeNotifier {
  RecordingService._(
      {bool? platformSupported,
      Future<Directory> Function()? supportDirectory,
      DateTime Function()? now})
      : _platformSupported = platformSupported,
        _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _now = now ?? DateTime.now;
  static final instance = RecordingService._();

  @visibleForTesting
  RecordingService.forTesting(Directory directory, {DateTime Function()? now})
      : this._(
            platformSupported: true,
            supportDirectory: () async => directory,
            now: now);
  final bool? _platformSupported;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _now;
  bool get available => _platformSupported ?? supported;

  static const _channel = MethodChannel('vespertv/recorder');

  static bool get supported => Platform.isAndroid;

  /// Paths in the network folder start with this (NetworkFolder.kt).
  static const networkScheme = 'smb://';

  final List<RecordingEntry> _items = [];
  AutoTeam? _autoTeam;
  RecordingSettings settings = const RecordingSettings();
  bool exactSchedule = true;
  File? _file;
  bool _ready = false;
  Timer? _poll;
  Timer? _programmeTimer;
  bool _disposed = false;
  final Set<String> _preparedProgrammes = {};
  Future<void> Function(RecordingEntry)? _prepareProgramme;
  set prepareProgramme(Future<void> Function(RecordingEntry)? callback) {
    _prepareProgramme = callback;
    _armProgrammeStart();
  }

  Future<void> _saveWrites = Future.value();

  /// Newest first.
  List<RecordingEntry> get items =>
      List.unmodifiable(_items..sort((a, b) => b.startAt.compareTo(a.startAt)));
  AutoTeam? get autoTeam => _autoTeam;

  Future<void> init() async {
    if (_ready || !available) return;
    _ready = true;
    try {
      final dir = await _supportDirectory();
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
    // The native side keeps its own copy for alarms with the app closed.
    await _sendNetworkFolder();
    await _sendPolicy(force: true);
    await refreshStatus();
    // Downloads cut short (process killed, box restarted) carry on.
    if (_items.any((r) => r.isDownload && r.state == RecState.interrupted)) {
      await _push();
    }
    _armProgrammeStart();
    // While anything is recording, keep sizes/states fresh for the tab.
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      // What's playing, again every minute while a download runs: the
      // recorder forgets it after 3 min (an app that died mid-play).
      if (++ticks % 12 == 0 &&
          _items.any((r) =>
              r.isDownload &&
              (r.state == RecState.recording || r.state == RecState.queued))) {
        unawaited(_sendPolicy(force: true));
      }
      if (_items.any((r) =>
          r.state == RecState.recording ||
          r.state == RecState.queued ||
          (r.state == RecState.scheduled && !r.startAt.isAfter(_now())))) {
        unawaited(refreshStatus());
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _programmeTimer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// Give an open player's same-channel connection to the recorder just
  /// before the native alarm. Android still owns the alarm when the app is closed.
  void _armProgrammeStart() {
    _programmeTimer?.cancel();
    final prepare = _prepareProgramme;
    if (_disposed || prepare == null) return;
    final upcoming = _items
        .where((r) =>
            r.programmeKey.isNotEmpty &&
            r.state == RecState.scheduled &&
            !_preparedProgrammes.contains(r.id) &&
            r.startAt.isAfter(_now().subtract(const Duration(seconds: 2))))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (upcoming.isEmpty) return;
    final entry = upcoming.first;
    final delay =
        entry.startAt.subtract(const Duration(seconds: 2)).difference(_now());
    _programmeTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      if (_disposed ||
          !_items.contains(entry) ||
          entry.state != RecState.scheduled) {
        return;
      }
      _preparedProgrammes.add(entry.id);
      try {
        await prepare(entry);
      } catch (e) {
        debugPrint(
            'RecordingService: programme handoff failed: ${e.runtimeType}');
      } finally {
        _armProgrammeStart();
      }
    });
  }

  Future<void> _save() async {
    if (_file == null) return;
    try {
      await _saveChecked();
    } catch (e) {
      debugPrint('RecordingService: save failed: ${e.runtimeType}');
    }
  }

  Future<void> _saveChecked() {
    final f = _file;
    if (f == null) throw StateError('Recording storage unavailable');
    final data = jsonEncode({
      'items': [for (final r in _items) r.toJson()],
      if (_autoTeam != null) 'autoTeam': _autoTeam!.toJson(),
      'settings': settings.toJson(),
    });
    _saveWrites = _saveWrites.catchError((Object _) {}).then((_) async {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(data);
      await tmp.rename(f.path);
    });
    return _saveWrites;
  }

  // ------------------------------------------------------------ storage

  /// Where recordings can go: app storage first, then USB / SD volumes,
  /// then the network folder when one is set up (its space isn't asked
  /// here: a round trip to the NAS).
  Future<List<RecordingVolume>> volumes() async {
    final network = settings.network;
    final vols = <RecordingVolume>[];
    try {
      final list = await _channel.invokeListMethod<Map>('storage') ?? const [];
      vols.addAll([
        for (final m in list)
          RecordingVolume(
            path: m['path'] as String,
            free: (m['free'] as num).toInt(),
            total: (m['total'] as num).toInt(),
            removable: m['removable'] == true,
          ),
      ]);
    } catch (e) {
      debugPrint('RecordingService: storage failed: $e');
    }
    if (vols.isNotEmpty) _devicePath = vols.first.path;
    if (network != null) {
      vols.add(RecordingVolume(
          path: network.base,
          free: -1,
          total: -1,
          removable: false,
          network: true));
    }
    return vols;
  }

  /// App storage's Recordings folder: where a network recording goes when
  /// the network folder can't be reached as it starts.
  String? _devicePath;

  /// The chosen folder when it's on this device (USB / SD too), else app
  /// storage: where a copy from the network folder goes.
  Future<RecordingVolume?> _deviceVolume() async {
    final vols = (await volumes()).where((v) => !v.network);
    return vols.where((v) => v.path == settings.folder).firstOrNull ??
        vols.firstOrNull;
  }

  /// The chosen folder when it's still mounted, else app storage.
  Future<RecordingVolume?> currentVolume() async {
    final vols = await volumes();
    return vols.where((v) => v.path == settings.folder).firstOrNull ??
        vols.where((v) => !v.network).firstOrNull;
  }

  /// Space used on this device (the cap in Settings); the network folder
  /// has its own disk.
  int get usedBytes => _items.fold(0, (s, r) => r.onNetwork ? s : s + r.bytes);

  Future<void> updateSettings(RecordingSettings s) async {
    final before = settings;
    settings = s;
    await _save();
    if (before.network?.toJson().toString() != s.network?.toJson().toString()) {
      await _sendNetworkFolder();
    }
    if (before.downloadSpeed != s.downloadSpeed) await _sendPolicy(force: true);
    await _push();
    notifyListeners();
  }

  // ------------------------------------------------------ network folder

  Future<void> _sendNetworkFolder() async {
    if (!available) return;
    try {
      await _channel.invokeMethod('networkFolder', {
        'config': settings.network == null
            ? null
            : jsonEncode(settings.network!.toJson()),
      });
    } catch (e) {
      debugPrint('RecordingService: network folder send failed: '
          '${e.runtimeType}');
    }
  }

  /// Connects with [config], writes and removes a small test file. Returns
  /// (free bytes, null) or (null, the reason in plain words).
  Future<({int? free, int? total, String? error})> testNetworkFolder(
      NetworkFolderConfig config) async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>(
          'testNetworkFolder', {'config': jsonEncode(config.toJson())});
      if (r?['ok'] == true) {
        return (
          free: (r!['free'] as num?)?.toInt(),
          total: (r['total'] as num?)?.toInt(),
          error: null
        );
      }
      return (free: null, total: null, error: '${r?['error'] ?? 'failed'}');
    } catch (e) {
      return (free: null, total: null, error: '${e.runtimeType}');
    }
  }

  /// The `.status` file the recorder writes: beside a file on the device,
  /// in app storage for one in the network folder (Dart can't read a
  /// network share).
  String statusPathOf(RecordingEntry r) {
    if (!r.onNetwork) return '${r.path}.status';
    final dir = _file?.parent.path ?? '';
    return '$dir/recording_status/${r.id}.status';
  }

  /// What the player opens for a recording / download: the recorder's tap
  /// while it records, the local server for a network file, else null
  /// (the channel's own URL).
  Future<String?> playbackUrl(Channel channel) async {
    if (Channel.isRecordingId(channel.rawId)) {
      if (!channel.url.startsWith(networkScheme)) return null;
      try {
        return await _channel
            .invokeMethod<String>('playUrl', {'path': channel.url});
      } catch (_) {
        return null;
      }
    }
    final rec = recordingOf(channel);
    return rec == null ? null : teeUrl(rec);
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

  static String _fileName(String title, DateTime start, String id,
      {String ext = 'ts'}) {
    final safe = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final d = '${start.year}-${_two(start.month)}-${_two(start.day)}';
    return '${d}_${safe.isEmpty ? 'Recording' : safe}_$id.$ext';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  RecordingEntry? entryForProgramme(
          Channel channel, EpgProgram programme) =>
      _items
          .where((r) =>
              r.programmeKey == programmeKey(channel, programme) &&
              (r.state == RecState.scheduled ||
                  r.state == RecState.recording ||
                  r.state == RecState.waiting))
          .firstOrNull;

  /// Exact XMLTV start/stop, not the Sports overtime margins. Uses the same
  /// native persisted alarm/boot scheduler and device storage limits.
  Future<RecordingEntry> recordProgramme(Channel channel, EpgProgram programme,
      {int maxConnections = 1}) async {
    if (!available) throw UnsupportedError('Recording requires Android');
    await init();
    final existing = entryForProgramme(channel, programme);
    if (existing != null) return existing;
    if (!channel.isLive ||
        channel.transientPlayback ||
        !programme.start.isAfter(_now()) ||
        !programme.stop.isAfter(programme.start) ||
        !['http', 'https'].contains(Uri.tryParse(channel.url)?.scheme)) {
      throw StateError('Invalid upcoming programme');
    }
    final vol = await currentVolume();
    final duplicate = entryForProgramme(channel, programme);
    if (duplicate != null) return duplicate;
    if (programmeConflict(channel, programme, maxConnections) != null) {
      throw StateError('Recording connection conflict');
    }
    if (vol == null ||
        (vol.free >= 0 && vol.free < settings.minFreeBytes + (256 << 20)) ||
        (!vol.network && usedBytes >= settings.capGb * 1024 * 1024 * 1024) ||
        _file == null) {
      throw StateError('Recording storage unavailable');
    }
    final id =
        '${_now().microsecondsSinceEpoch.toRadixString(36)}_${_items.length}';
    final entry = RecordingEntry(
        id: id,
        title: programme.title,
        league: channel.name,
        gameKey: '',
        leagueId: '',
        gameStart: programme.start.toLocal(),
        startAt: programme.start.toLocal(),
        endAt: programme.stop.toLocal(),
        channelId: channel.id,
        channelName: channel.name,
        playlistId: channel.playlistId,
        url: channel.url,
        path:
            '${vol.path}/${_fileName(programme.title, programme.start.toLocal(), id)}',
        program: programme.title,
        channelLogo: channel.logoUrl,
        programmeKey: programmeKey(channel, programme));
    _items.add(entry);
    try {
      // Unlike older immediate-record paths, don't claim success if persistence
      // or native scheduling fails. Restore the old native schedule on failure.
      await _saveChecked();
      await _push(strict: true);
    } catch (_) {
      _items.remove(entry);
      await _save();
      await _push();
      rethrow;
    }
    notifyListeners();
    return entry;
  }

  /// Maximum overlapping recordings, scoped to one provider account.
  RecordingEntry? programmeConflict(
      Channel channel, EpgProgram programme, int maxConnections) {
    final overlaps = _items
        .where((r) =>
            r.playlistId == channel.playlistId &&
            (r.state == RecState.scheduled ||
                r.state == RecState.recording ||
                r.state == RecState.waiting) &&
            r.startAt.isBefore(programme.stop) &&
            r.endAt.isAfter(programme.start))
        .toList();
    final points = [
      programme.start,
      ...overlaps.map((r) => r.startAt).where((t) => t.isAfter(programme.start))
    ];
    for (final at in points) {
      final active =
          overlaps.where((r) => !r.startAt.isAfter(at) && r.endAt.isAfter(at));
      if (active.length >= (maxConnections < 1 ? 1 : maxConnections)) {
        return active.first;
      }
    }
    return null;
  }

  Future<void> cancelProgramme(RecordingEntry entry) async {
    if (entry.programmeKey.isEmpty) {
      throw StateError('Not a programme recording');
    }
    await refreshStatus();
    if (entry.state == RecState.recording) {
      await stop(entry);
      return;
    }
    _items.remove(entry);
    try {
      await _saveChecked();
      await _push(strict: true);
    } catch (_) {
      _items.add(entry);
      await _save();
      await _push();
      rethrow;
    }
    // It may have started while its menu was open. Stop that exact ID too.
    await _channel.invokeMethod<void>('stop', {'id': entry.id});
    notifyListeners();
  }

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
    final vol = await currentVolume();
    if (vol?.network == true) return true; // checked as it writes
    if (usedBytes >= settings.capGb * 1024 * 1024 * 1024) return false;
    return vol == null || vol.free >= settings.minFreeBytes + (256 << 20);
  }

  /// Cancels a scheduled one, stops a running one (keeps what it has).
  Future<void> stop(RecordingEntry r) async {
    if (r.state == RecState.recording ||
        r.state == RecState.queued ||
        (r.isDownload && r.state == RecState.interrupted)) {
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
    if (r.state == RecState.recording || r.state == RecState.queued) {
      await stop(r);
    }
    if (r.onNetwork) {
      for (final p in [r.path, networkDetailsPath(r.path)]) {
        try {
          await _channel.invokeMethod<bool>('deleteFile', {'path': p});
        } catch (_) {}
      }
    }
    for (final p in [if (!r.onNetwork) r.path, statusPathOf(r)]) {
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
  Future<bool> _push({bool strict = false}) async {
    if (!available) return true;
    final now = _now();
    final cap = settings.capGb * 1024 * 1024 * 1024;
    final room = cap - usedBytes;
    if (_devicePath == null && _items.any((r) => r.onNetwork)) {
      await volumes();
    }
    final device = _devicePath;
    final due = [
      for (final r in _items)
        if (r.isDownload
            // A download stays with the native scheduler until it's done,
            // so a reboot or a killed app picks it up again.
            ? const {
                  RecState.scheduled,
                  RecState.queued,
                  RecState.recording,
                  RecState.interrupted
                }.contains(r.state) &&
                r.url.isNotEmpty
            : r.state == RecState.scheduled &&
                r.endAt.isAfter(now) &&
                r.url.isNotEmpty)
          {
            'id': r.id,
            'url': r.url,
            'path': r.path,
            'statusPath': statusPathOf(r),
            'title': r.isDownload && r.league.isNotEmpty
                ? '${r.league} · ${r.title}'
                : r.title,
            'startAt': r.startAt.millisecondsSinceEpoch,
            // A download has no end: it runs until the file is complete.
            'endAt': r.isDownload ? 0 : r.endAt.millisecondsSinceEpoch,
            'account': r.playlistId,
            'minFreeBytes': settings.minFreeBytes,
            // The whole cap is shared: a new recording gets what's left
            // (its own bytes so far are already counted in usedBytes).
            // The network folder has its own disk.
            if (!r.onNetwork)
              'maxBytes': room + r.bytes > 0 ? room + r.bytes : 1,
            if (r.onNetwork && !r.isDownload && device != null)
              'fallbackPath': '$device/${r.path.split('/').last}',
            if (r.isDownload) ...{
              'kind': 'download',
              'headers': r.headers,
              'maxConnections': r.maxConnections,
              'durationSec': r.durationSec,
            },
            if (r.onNetwork) 'details': jsonEncode(detailsOf(r)),
          },
    ];
    debugPrint('RecordingService: ${due.length} recording(s) sent to the '
        'scheduler');
    try {
      exactSchedule = await _channel
              .invokeMethod<bool>('schedule', {'items': jsonEncode(due)}) ??
          true;
      _armProgrammeStart();
      return exactSchedule;
    } catch (e) {
      debugPrint('RecordingService: schedule failed: $e');
      if (strict) rethrow;
      return true;
    }
  }

  /// Reads each recording's `.status` and the native running list.
  Future<void> refreshStatus() async {
    if (!available) return;
    Set<String> running = const {};
    try {
      final list = await _channel.invokeListMethod<Map>('active') ?? const [];
      running = {for (final m in list) m['id'] as String};
    } catch (_) {}
    var changed = false;
    final now = _now();
    for (final r in _items) {
      if (r.state == RecState.cancelled) continue;
      final before = (r.state, r.bytes, r.note, r.path);
      try {
        final f = File(statusPathOf(r));
        final m = await f.exists()
            ? jsonDecode(await f.readAsString()) as Map<String, dynamic>
            : null;
        // A download resumed (or re-scheduled) by hand: the file still
        // holds its last run until the recorder starts again.
        final stale = m != null &&
            r.state == RecState.scheduled &&
            ((m['updatedAt'] as num?)?.toInt() ?? 0) <
                r.startAt.millisecondsSinceEpoch;
        if (m != null && !stale) {
          r.bytes = (m['bytes'] as num?)?.toInt() ?? r.bytes;
          r.totalBytes = (m['total'] as num?)?.toInt() ?? r.totalBytes;
          r.note = m['note'] as String? ?? '';
          r.error = m['error'] as String? ?? '';
          if (m['path'] case final String p when p.isNotEmpty) r.path = p;
          final s = RecState.fromNative(m['state'] as String? ?? '');
          // "recording" in the file but not running = the process died.
          r.state = (s == RecState.recording || s == RecState.queued) &&
                  !running.contains(r.id)
              ? RecState.interrupted
              : s;
        } else if (stale) {
          // Waiting for the recorder to pick it up again.
        } else if (running.contains(r.id)) {
          r.state = RecState.recording;
        } else if (r.state == RecState.scheduled && r.endAt.isBefore(now)) {
          // Never started (box off the whole time, no channel, no alarm).
          r.state = RecState.missed;
        }
      } catch (_) {}
      if (before != (r.state, r.bytes, r.note, r.path)) changed = true;
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
    unawaited(_saveMissingDetails());
  }

  // ------------------------------------- the network folder, other devices

  /// What another device browsing the network folder shows for [r]: the
  /// file's `.vespertv/<name>.json` ([networkDetailsPath]).
  static Map<String, dynamic> detailsOf(RecordingEntry r) => {
        'v': 1,
        'kind': r.isDownload
            ? 'download'
            : r.isChannel
                ? 'channel'
                : 'game',
        'title': r.isChannel && r.program.isNotEmpty ? r.program : r.title,
        if (r.league.isNotEmpty) 'group': r.league,
        if (r.isChannel && r.channelName.isNotEmpty) 'group': r.channelName,
        if (r.poster != null) 'poster': r.poster,
        if (!r.isDownload && (r.logo ?? r.channelLogo) != null)
          'logo': r.logo ?? r.channelLogo,
        if (r.durationSec > 0) 'durationSec': r.durationSec,
        'date': r.gameStart.millisecondsSinceEpoch,
      };

  bool _savingDetails = false;

  /// Finished files in the network folder without their details file yet
  /// (saved before details existed, or the native write failed): written
  /// now, once each.
  Future<void> _saveMissingDetails() async {
    if (_savingDetails || !available) return;
    _savingDetails = true;
    var changed = false;
    try {
      for (final r in [..._items]) {
        final finished = r.isDownload
            ? r.complete
            : (r.state == RecState.done || r.state == RecState.stopped) &&
                r.bytes > 0;
        if (!r.onNetwork || r.detailsSaved || !finished) continue;
        final ok = await _channel.invokeMethod<bool>('networkWriteText', {
              'path': networkDetailsPath(r.path),
              'text': jsonEncode(detailsOf(r)),
            }) ??
            false;
        // The share is away: try again next time.
        if (!ok) break;
        r.detailsSaved = true;
        changed = true;
      }
    } catch (e) {
      debugPrint('RecordingService: details not saved: ${e.runtimeType}');
    } finally {
      _savingDetails = false;
    }
    if (changed) await _save();
  }

  /// The network folder's videos ([NetworkFile]), or why it can't be read.
  Future<({List<NetworkFile> files, String? error})> networkFiles() async {
    if (!available || settings.network == null) {
      return (files: const <NetworkFile>[], error: null);
    }
    try {
      final r = await _channel
          .invokeMapMethod<String, dynamic>('networkList')
          .timeout(const Duration(seconds: 60));
      if (r?['error'] case final String e) {
        return (files: const <NetworkFile>[], error: e);
      }
      final list = jsonDecode('${r?['files'] ?? '[]'}') as List;
      return (
        files: [
          for (final m in list)
            if (m is Map) NetworkFile.fromJson(m),
        ].whereType<NetworkFile>().toList(),
        error: null
      );
    } catch (e) {
      return (files: const <NetworkFile>[], error: '${e.runtimeType}');
    }
  }

  /// The share's videos worth offering here: see [networkFilesToShow].
  List<NetworkFile> networkFilesToOffer(List<NetworkFile> all) =>
      networkFilesToShow(all, ownPaths: {
        for (final r in _items)
          if (r.onNetwork && r.state != RecState.cancelled) r.path
      }, copiedFrom: {
        for (final r in _items)
          if (r.isDownload &&
              r.url.startsWith(networkScheme) &&
              r.state != RecState.cancelled)
            r.url
      });

  /// Copies [file] from the network folder to this device (never back to
  /// the share, whatever Save to says): a download like any other, run
  /// now, one at a time, resumed if the share drops.
  Future<RecordingEntry?> copyToDevice(NetworkFile file) async {
    final added = await download([
      DownloadItem(
        sourceId: 'net:${file.path}',
        title: file.title,
        group: file.group,
        url: file.path,
        poster: file.poster,
        durationSec: file.durationSec,
        totalBytes: file.size,
        fileExtension: file.extension,
      ),
    ], toDevice: true);
    return added.firstOrNull;
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
    // A download gives its connection back to the player by itself.
    final mine = _items.where((r) =>
        !r.isDownload &&
        r.state == RecState.recording &&
        r.playlistId == channel.playlistId);
    if (mine.any((r) => r.channelId == channel.id)) return null;
    final others = mine.toList();
    return others.length >= limit ? others.firstOrNull : null;
  }

  /// The running recording of [channel], if any — play [teeUrl] instead
  /// of the provider so both share one connection.
  RecordingEntry? recordingOf(Channel channel) => _items
      .where((r) =>
          !r.isDownload &&
          r.state == RecState.recording &&
          r.channelId == channel.id)
      .firstOrNull;

  Future<String?> teeUrl(RecordingEntry r) async {
    try {
      final port = await _channel.invokeMethod<int>('teePort');
      return port == null ? null : 'http://127.0.0.1:$port/rec/${r.id}.ts';
    } catch (_) {
      return null;
    }
  }

  /// A recording as something the player opens (seekable local file, or
  /// the network folder through [playbackUrl]).
  Channel channelFor(RecordingEntry r) => Channel(
        id: '${Channel.recordingPrefix}${r.id}',
        rawId: '${Channel.recordingPrefix}${r.id}',
        playlistId: '',
        name: r.isDownload && r.league.isNotEmpty
            ? '${r.league} · ${r.title}'
            : r.title,
        group: r.league,
        url: r.path,
        logoUrl: r.isDownload ? r.poster : r.logo,
      );

  // ----------------------------------------------------------- downloads

  /// The download of the title with channel id [sourceId], if any (not a
  /// removed one).
  RecordingEntry? downloadFor(String sourceId) => _items
      .where((r) =>
          r.isDownload &&
          r.channelId == sourceId &&
          r.state != RecState.cancelled)
      .firstOrNull;

  /// The next time of day the download sheet suggests ([at] minutes after
  /// midnight): today when it's still ahead, else tomorrow.
  static DateTime nextStart(int at, DateTime now) {
    final today = DateTime(now.year, now.month, now.day, at ~/ 60, at % 60);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// Queues [items] (one at a time, in this order) to start at [at], or
  /// now. Titles already downloaded or queued are left as they are.
  Future<List<RecordingEntry>> download(List<DownloadItem> items,
      {DateTime? at, bool toDevice = false}) async {
    if (!available) throw UnsupportedError('Downloads require Android');
    await init();
    final vol = toDevice ? await _deviceVolume() : await currentVolume();
    final start = at ?? _now();
    final added = <RecordingEntry>[];
    var n = 0;
    for (final item in items) {
      final existing = downloadFor(item.sourceId);
      if (existing != null) {
        added.add(existing);
        continue;
      }
      // Keeps the queue in the order given (the native side runs the
      // earliest start first).
      final when = start.add(Duration(milliseconds: n++));
      final id =
          'dl${_now().microsecondsSinceEpoch.toRadixString(36)}_${_items.length}';
      final name =
          item.group.isEmpty ? item.title : '${item.group} ${item.title}';
      final entry = RecordingEntry(
        id: id,
        title: item.title,
        league: item.group,
        gameKey: '',
        leagueId: '',
        gameStart: when,
        startAt: when,
        // Not started within two weeks (box off): shown as missed.
        endAt: when.add(const Duration(days: 14)),
        channelId: item.sourceId,
        channelName: '',
        playlistId: item.playlistId,
        url: item.url,
        path:
            '${vol?.path ?? ''}/${_fileName(name, when, id, ext: item.extension)}',
        kind: 'download',
        poster: item.poster,
        durationSec: item.durationSec,
        totalBytes: item.totalBytes,
        headers: item.headers,
        maxConnections: item.maxConnections,
      );
      _items.add(entry);
      added.add(entry);
    }
    await _save();
    await _push();
    notifyListeners();
    return added;
  }

  /// Starts a stopped / failed / scheduled download again now (or at
  /// [at]), from where it stopped.
  Future<void> resumeDownload(RecordingEntry r, {DateTime? at}) async {
    if (!r.isDownload) return;
    r
      ..state = RecState.scheduled
      ..note = ''
      ..error = ''
      ..startAt = at ?? _now()
      ..endAt = (at ?? _now()).add(const Duration(days: 14));
    await _save();
    await _push();
    notifyListeners();
  }

  // ------------------------------------------- what the app is playing

  String? _mainAccount;
  bool _mainPlaying = false;
  List<String> _multiview = const [];
  String _sentPolicy = '';

  /// Tells the downloads what the player plays (main.dart, on every
  /// change): its account's connection, and that the network is busy.
  /// [account] is the IPTV playlist id ('' for Media Hub); [playing] false
  /// for nothing or a file on this device.
  void playerChanged({required bool playing, String? account}) {
    _mainPlaying = playing;
    _mainAccount = playing ? account : null;
    unawaited(_sendPolicy());
  }

  /// Multiview's tiles, one entry per tile (their playlist ids).
  void multiviewChanged(List<String> accounts) {
    _multiview = accounts;
    unawaited(_sendPolicy());
  }

  Map<String, int> get _streams {
    final m = <String, int>{};
    if (_mainPlaying) {
      m.update(_mainAccount ?? '', (v) => v + 1, ifAbsent: () => 1);
    }
    for (final a in _multiview) {
      m.update(a, (v) => v + 1, ifAbsent: () => 1);
    }
    return m;
  }

  Future<void> _sendPolicy({bool force = false}) async {
    if (!available) return;
    final streams = _streams;
    final key = '${settings.downloadSpeed}|$streams';
    if (!force && key == _sentPolicy) return;
    _sentPolicy = key;
    try {
      await _channel.invokeMethod(
          'policy', {'speed': settings.downloadSpeed, 'streams': streams});
    } catch (_) {}
  }

  /// Before the player opens [channel]: a download using that account's
  /// last free connection lets go of it first (the provider would kick
  /// one of the two). Quick when nothing is downloading from it.
  Future<void> yieldConnection(Channel channel) async {
    if (!available || channel.playlistId.isEmpty) return;
    final download = _items
        .where((r) =>
            r.isDownload &&
            r.state == RecState.recording &&
            r.playlistId == channel.playlistId)
        .firstOrNull;
    if (download == null) return;
    final limit = download.maxConnections > 0 ? download.maxConnections : 1;
    final used = 1 +
        _multiview.where((a) => a == channel.playlistId).length +
        _items
            .where((r) =>
                !r.isDownload &&
                r.state == RecState.recording &&
                r.playlistId == channel.playlistId)
            .length;
    if (used < limit) return; // room for the player too
    _mainPlaying = true;
    _mainAccount = channel.playlistId;
    await _sendPolicy();
    try {
      await _channel.invokeMethod('yield',
          {'account': channel.playlistId}).timeout(const Duration(seconds: 6));
    } catch (_) {}
    // The provider needs a moment to free the connection.
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

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

  /// Recording now; for a download, downloading now.
  recording,

  /// A download waiting its turn, or for a free provider connection
  /// ([RecordingEntry.note] says which).
  queued,
  done,
  stopped,
  failed,
  interrupted,
  missed,

  /// Auto-team game the user removed (kept so it isn't added back).
  cancelled;

  static RecState fromNative(String s) => switch (s) {
        'recording' || 'downloading' => recording,
        'queued' || 'paused' => queued,
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
    this.programmeKey = '',
    this.kind = '',
    this.poster,
    this.durationSec = 0,
    this.totalBytes = 0,
    this.headers = const {},
    this.maxConnections = 0,
    this.note = '',
    this.detailsSaved = false,
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

  /// The provider's live URL — only the native recorder uses it. For a
  /// download, the file's link (an add-on's own link, not where it
  /// redirects: a debrid link expires, the add-on's gives a fresh one).
  String url;

  /// Where the file is: a device path, or `smb://…` in the network folder
  /// (the recorder may move a recording to the device when the network
  /// folder can't be reached, see RecorderService.kt `openTarget`).
  String path;
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
  final String programmeKey;

  /// '' = a recording, 'download' = a movie / episode download.
  final String kind;

  /// Download: the poster, the length (for the Like watching speed), the
  /// file's size once the server said it, its request headers and the
  /// provider account's connection limit (0 = not an IPTV account).
  final String? poster;
  final int durationSec;
  int totalBytes;
  final Map<String, String> headers;
  final int maxConnections;

  /// Why a queued download waits: 'queue' (another one first) or
  /// 'connection' (the account's connection is in use).
  String note;

  /// A file in the network folder: its details file for other devices is
  /// written ([RecordingService.detailsOf]).
  bool detailsSaved;

  bool get isDownload => kind == 'download';

  /// A plain channel recording (no game behind it).
  bool get isChannel => gameKey.isEmpty && !isDownload;

  bool get onNetwork => path.startsWith(RecordingService.networkScheme);

  bool get playable => bytes > 0 && state != RecState.cancelled;

  /// Downloaded completely (a download can stop part way).
  bool get complete =>
      state == RecState.done && (totalBytes == 0 || bytes >= totalBytes);

  double? get progress =>
      totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : null;

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
        if (programmeKey.isNotEmpty) 'programmeKey': programmeKey,
        if (kind.isNotEmpty) 'kind': kind,
        if (poster != null) 'poster': poster,
        if (durationSec > 0) 'durationSec': durationSec,
        if (totalBytes > 0) 'totalBytes': totalBytes,
        if (headers.isNotEmpty) 'headers': headers,
        if (maxConnections > 0) 'maxConnections': maxConnections,
        if (note.isNotEmpty) 'note': note,
        if (detailsSaved) 'detailsSaved': true,
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
      programmeKey: m['programmeKey'] as String? ?? '',
      kind: m['kind'] as String? ?? '',
      poster: m['poster'] as String?,
      durationSec: (m['durationSec'] as num?)?.toInt() ?? 0,
      totalBytes: (m['totalBytes'] as num?)?.toInt() ?? 0,
      headers: {
        if (m['headers'] case final Map h)
          for (final e in h.entries) '${e.key}': '${e.value}',
      },
      maxConnections: (m['maxConnections'] as num?)?.toInt() ?? 0,
      note: m['note'] as String? ?? '',
      detailsSaved: m['detailsSaved'] == true,
    );
  }
}

/// One movie or episode to download (`RecordingService.download`).
class DownloadItem {
  const DownloadItem({
    required this.sourceId,
    required this.title,
    required this.url,
    this.group = '',
    this.headers = const {},
    this.playlistId = '',
    this.maxConnections = 0,
    this.poster,
    this.durationSec = 0,
    this.totalBytes = 0,
    this.fileExtension,
  });

  /// The title's channel id (IPTV `playlist::xt_vod_…`, Media Hub
  /// `arc_vod_…`): its page finds the download by it.
  final String sourceId;
  final String title;

  /// Show name for an episode, '' for a movie.
  final String group;
  final String url;
  final Map<String, String> headers;

  /// The IPTV playlist (its account's connections); '' for Media Hub.
  final String playlistId;
  final int maxConnections;
  final String? poster;
  final int durationSec;
  final int totalBytes;

  /// Known from a file name (a copy from the network folder).
  final String? fileExtension;

  /// The file's extension from its link (`.mkv`, `.mp4`…), else `ts`.
  String get extension {
    if (fileExtension case final String e when e.isNotEmpty) return e;
    final path = Uri.tryParse(url)?.path ?? '';
    final m = RegExp(r'\.([A-Za-z0-9]{2,4})$').firstMatch(path);
    final ext = m?.group(1)?.toLowerCase();
    return const {'mkv', 'mp4', 'm4v', 'avi', 'ts', 'webm', 'mov'}.contains(ext)
        ? ext!
        : 'mkv';
  }
}

/// Settings > Recordings > Network folder: a Windows / NAS shared folder.
/// The password stays on this device (recordings.json and the native
/// prefs, never Transfer / Backup / cloud sync).
class NetworkFolderConfig {
  const NetworkFolderConfig({
    required this.host,
    required this.share,
    this.folder = 'VesperTV',
    this.user = '',
    this.password = '',
    this.domain = '',
  });

  final String host;
  final String share;
  final String folder;
  final String user;
  final String password;
  final String domain;

  /// `smb://host/share/folder`: what recording paths start with.
  String get base => '${RecordingService.networkScheme}$host/$share'
      '${folder.isEmpty ? '' : '/$folder'}';

  /// `\\host\share\folder`, as Windows shows it.
  String get display =>
      '\\\\$host\\$share${folder.isEmpty ? '' : '\\${folder.replaceAll('/', '\\')}'}';

  /// Reads `\\host\share\folder`, `smb://host/share/folder` or `host`
  /// typed into the address field; null without a host.
  static ({String host, String share, String folder})? parseAddress(
      String text) {
    var t = text.trim().replaceAll('\\', '/');
    t = t.replaceFirst(RegExp(r'^smb:', caseSensitive: false), '');
    final parts = t.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return (
      host: parts.first.trim(),
      share: parts.length > 1 ? parts[1].trim() : '',
      folder: parts.length > 2 ? parts.skip(2).join('/').trim() : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'share': share,
        'folder': folder,
        'user': user,
        'password': password,
        if (domain.isNotEmpty) 'domain': domain,
      };

  factory NetworkFolderConfig.fromJson(Map<String, dynamic> m) =>
      NetworkFolderConfig(
        host: m['host'] as String? ?? '',
        share: m['share'] as String? ?? '',
        folder: m['folder'] as String? ?? '',
        user: m['user'] as String? ?? '',
        password: m['password'] as String? ?? '',
        domain: m['domain'] as String? ?? '',
      );
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
    this.downloadSpeed = 'watch',
    this.downloadAt = 120,
    this.network,
  });

  final int minutesBefore;
  final int minutesAfter;
  final int capGb;

  /// The chosen volume's Recordings folder; null = app storage. The
  /// network folder's [NetworkFolderConfig.base] when that's the choice.
  final String? folder;

  /// Download speed limit: 'watch' (about the file's own bitrate), '10',
  /// '25', '50' (Mbit/s) or 'none'.
  final String downloadSpeed;

  /// The download sheet's suggested start, minutes after midnight (2:00).
  final int downloadAt;

  final NetworkFolderConfig? network;

  static const downloadSpeeds = ['watch', '10', '25', '50', 'none'];

  /// Recording stops when the volume has less than this left.
  int get minFreeBytes => 1024 * 1024 * 1024;

  RecordingSettings copyWith({
    int? minutesBefore,
    int? minutesAfter,
    int? capGb,
    String? folder,
    String? downloadSpeed,
    int? downloadAt,
    NetworkFolderConfig? network,
    bool clearNetwork = false,
    bool clearFolder = false,
  }) =>
      RecordingSettings(
        minutesBefore: minutesBefore ?? this.minutesBefore,
        minutesAfter: minutesAfter ?? this.minutesAfter,
        capGb: capGb ?? this.capGb,
        folder: clearFolder ? null : folder ?? this.folder,
        downloadSpeed: downloadSpeed ?? this.downloadSpeed,
        downloadAt: downloadAt ?? this.downloadAt,
        network: clearNetwork ? null : network ?? this.network,
      );

  Map<String, dynamic> toJson() => {
        'minutesBefore': minutesBefore,
        'minutesAfter': minutesAfter,
        'capGb': capGb,
        if (folder != null) 'folder': folder,
        'downloadSpeed': downloadSpeed,
        'downloadAt': downloadAt,
        if (network != null) 'network': network!.toJson(),
      };

  factory RecordingSettings.fromJson(Map<String, dynamic> m) =>
      RecordingSettings(
        minutesBefore: (m['minutesBefore'] as num?)?.toInt() ?? 5,
        minutesAfter: (m['minutesAfter'] as num?)?.toInt() ?? 30,
        capGb: (m['capGb'] as num?)?.toInt() ?? 20,
        folder: m['folder'] as String?,
        downloadSpeed: downloadSpeeds.contains(m['downloadSpeed'])
            ? m['downloadSpeed'] as String
            : 'watch',
        downloadAt: (m['downloadAt'] as num?)?.toInt() ?? 120,
        network: m['network'] is Map
            ? NetworkFolderConfig.fromJson(
                Map<String, dynamic>.from(m['network'] as Map))
            : null,
      );
}

class RecordingVolume {
  const RecordingVolume(
      {required this.path,
      required this.free,
      required this.total,
      required this.removable,
      this.network = false});
  final String path;

  /// Bytes; -1 when not known (the network folder isn't asked every time).
  final int free;
  final int total;
  final bool removable;
  final bool network;
}
