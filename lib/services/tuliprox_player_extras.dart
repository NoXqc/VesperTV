part of 'tuliprox.dart';

// Tuliprox's Player API beyond Sources / stop / joinable (3.3.206+, merged
// into develop 2026-11-24; docs/src/player-api.md there): split a shared
// stream, members before playback, channels + EPG, bouquet, watch progress,
// the DVR (one-off requests, weekly rules, the recordings snapshot over the
// binary `/ws` socket, media), MCP player tools and the personal event
// WebSocket. Owner, 2026-11-24: "Add them all for future proofing".

/// A live channel of the playlist user's target (`GET /me/channels`).
class TuliproxServerChannel {
  const TuliproxServerChannel(
      {required this.virtualId,
      required this.name,
      this.group = '',
      this.epgChannelId = '',
      this.isGroup = false});
  final int virtualId;
  final String name;
  final String group;
  final String epgChannelId;

  /// A failover group (several sources behind one channel).
  final bool isGroup;
}

/// One programme of `GET /me/epg` (times unshifted, Unix seconds).
class TuliproxProgramme {
  const TuliproxProgramme(
      {required this.start,
      required this.stop,
      required this.title,
      this.description = '',
      this.categories = const [],
      this.isLive = false,
      this.isNew = false});
  final DateTime start;
  final DateTime stop;
  final String title;
  final String description;
  final List<String> categories;
  final bool isLive;
  final bool isNew;
}

/// A stored playback position (`/me/progress`): `kind` is `movie`,
/// `episode` or `recording`, [itemId] the Xtream stream id played.
class TuliproxProgress {
  const TuliproxProgress(
      {required this.kind,
      required this.itemId,
      required this.positionSecs,
      this.durationSecs,
      this.watched = false,
      this.seriesId,
      this.updatedAt = 0});
  final String kind;
  final int itemId;
  final int positionSecs;
  final int? durationSecs;
  final bool watched;
  final int? seriesId;

  /// Unix seconds.
  final int updatedAt;

  static TuliproxProgress? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = _int(j['item_id']);
    final pos = _int(j['position_secs']);
    if (id == null || pos == null) return null;
    return TuliproxProgress(
      kind: '${j['kind'] ?? ''}',
      itemId: id,
      positionSecs: pos,
      durationSecs: _int(j['duration_secs']),
      watched: j['watched'] == true,
      seriesId: _int(j['series_id']),
      updatedAt: _int(j['updated_at']) ?? 0,
    );
  }
}

/// The categories a playlist user may pick, and the ones picked
/// (`/api/v1/user/playlist/categories|bouquet`): per output (`xtream`,
/// `m3u`) and cluster (`live`, `vod`, `series`). A null cluster in a
/// bouquet = unrestricted.
typedef TuliproxBouquet = Map<String, Map<String, List<String>?>?>;

TuliproxBouquet _bouquetOf(Object? j) {
  final out = <String, Map<String, List<String>?>?>{};
  if (j is! Map) return out;
  for (final output in j.entries) {
    final clusters = output.value;
    if (clusters is! Map) {
      out['${output.key}'] = null;
      continue;
    }
    out['${output.key}'] = {
      for (final c in clusters.entries)
        '${c.key}':
            c.value is List ? [for (final v in c.value as List) '$v'] : null,
    };
  }
  return out;
}

/// A server recording (the snapshot's `tasks[]`).
class TuliproxRecording {
  const TuliproxRecording(
      {required this.id,
      required this.title,
      required this.status,
      this.kind = 'live',
      this.channelName = '',
      this.channelId = '',
      this.programStart,
      this.programEnd,
      this.completedAt,
      this.transferredBytes = 0,
      this.visibility = 'private',
      this.own = false,
      this.actions = const {},
      this.filename = ''});
  final String id;
  final String title;

  /// `scheduled`, `queued`, `waiting_for_capacity`, `retry_waiting`,
  /// `running`, `paused`, `cancelling`, `completed`, `failed`, `cancelled`.
  final String status;
  final String kind;
  final String channelName;
  final String channelId;
  final DateTime? programStart;
  final DateTime? programEnd;
  final DateTime? completedAt;
  final int transferredBytes;
  final String visibility;

  /// This user's own entry (`owner_id` is only sent for those).
  final bool own;

  /// What the server allows now (`allowed_actions`): `cancel`, `remove`,
  /// `edit`, … Render exactly these.
  final Set<String> actions;
  final String filename;

  bool get completed => status == 'completed';
  bool get upcoming =>
      status == 'scheduled' ||
      status == 'queued' ||
      status == 'waiting_for_capacity' ||
      status == 'retry_waiting';
  bool get running => status == 'running' || status == 'paused';

  static DateTime? _time(Object? v) {
    final s = _int(v);
    return s == null || s <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(s * 1000);
  }

  static TuliproxRecording? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = '${j['id'] ?? ''}';
    if (id.isEmpty) return null;
    final allowed = j['allowed_actions'];
    final program = '${j['program_title'] ?? ''}';
    return TuliproxRecording(
      id: id,
      title: program.isNotEmpty ? program : '${j['title'] ?? ''}',
      status: '${j['status'] ?? ''}',
      kind: '${j['kind'] ?? 'live'}',
      channelName: '${j['channel_name'] ?? ''}',
      channelId: '${j['channel_id'] ?? ''}',
      programStart: _time(j['program_start']),
      programEnd: _time(j['program_end']),
      completedAt: _time(j['completed_at']),
      transferredBytes: _int(j['transferred_bytes']) ?? 0,
      visibility: '${j['visibility'] ?? 'private'}',
      own: j['owner_id'] != null,
      actions: {
        if (allowed is Map)
          for (final e in allowed.entries)
            if (e.value == true) '${e.key}'
      },
      filename: '${j['filename'] ?? ''}',
    );
  }
}

/// The DVR state of one playlist user (`RecordingSnapshotResponse`).
class TuliproxRecordingSnapshot {
  const TuliproxRecordingSnapshot(
      {required this.tasks,
      this.revision = 0,
      this.available = true,
      this.privateUsedBytes = 0,
      this.privateLimitBytes});
  final List<TuliproxRecording> tasks;
  final int revision;

  /// The DVR can accept work now.
  final bool available;
  final int privateUsedBytes;

  /// Null = unlimited.
  final int? privateLimitBytes;

  static TuliproxRecordingSnapshot fromJson(Map j) {
    final quota = j['quota'];
    return TuliproxRecordingSnapshot(
      revision: _int(j['revision']) ?? 0,
      available: j['available'] != false,
      privateUsedBytes:
          quota is Map ? _int(quota['private_used_bytes']) ?? 0 : 0,
      privateLimitBytes:
          quota is Map ? _int(quota['private_limit_bytes']) : null,
      tasks: [
        for (final t in (j['tasks'] as List? ?? const []))
          if (TuliproxRecording.fromJson(t) case final r?) r
      ],
    );
  }
}

/// A weekly server recording rule (`/api/v1/recording/rules`).
class TuliproxRecordingRule {
  const TuliproxRecordingRule(
      {required this.id,
      required this.virtualId,
      this.targetId = '',
      this.own = true,
      this.enabled = true,
      this.visibility = 'private',
      this.weekday = 1,
      this.localStartTime = '00:00',
      this.durationSecs = 0,
      this.timezone = 'UTC',
      this.channelId = ''});
  final String id;
  final String virtualId;
  final String targetId;
  final bool own;
  final bool enabled;
  final String visibility;

  /// ISO 8601: 1 = Monday .. 7 = Sunday.
  final int weekday;

  /// `HH:MM`, 24 h, in [timezone].
  final String localStartTime;
  final int durationSecs;
  final String timezone;
  final String channelId;

  static TuliproxRecordingRule? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = '${j['id'] ?? ''}';
    final source = j['source'];
    final body = j['body'];
    if (id.isEmpty || source is! Map) return null;
    return TuliproxRecordingRule(
      id: id,
      virtualId: '${source['virtual_id'] ?? ''}',
      targetId: '${source['target_id'] ?? ''}',
      own: j['own'] != false,
      enabled: j['enabled'] != false,
      visibility: '${j['visibility'] ?? 'private'}',
      weekday: body is Map ? _int(body['weekday']) ?? 1 : 1,
      localStartTime:
          body is Map ? '${body['local_start_time'] ?? '00:00'}' : '00:00',
      durationSecs: body is Map ? _int(body['duration_secs']) ?? 0 : 0,
      timezone: body is Map ? '${body['timezone'] ?? 'UTC'}' : 'UTC',
      channelId: '${j['channel_id'] ?? ''}',
    );
  }
}

/// The DVR refused a command: [code] is the server's `{"error": code}`
/// (`recording_quota_exceeded`, `recording_duplicate`, …).
class TuliproxRecordingError extends TuliproxException {
  TuliproxRecordingError(this.code, {super.status}) : super(code);
  final String code;
}

/// What a DVR refusal means for the viewer.
String tuliproxRecordingErrorText(Object error) {
  final code = error is TuliproxRecordingError ? error.code : '';
  return switch (code) {
    'recording_quota_exceeded' =>
      tr('Your recording space on the server is full.'),
    'recording_concurrency_exceeded' => tr(
        'The server is already recording as many shows as you are allowed at that time.'),
    'recording_duplicate' => tr('The server is already recording this show.'),
    'recording_disk_full' => tr("The server's disk is full."),
    'recording_disabled' => tr('Recording is switched off on this server.'),
    'recording_forbidden' ||
    'recording_shared_not_administrator' =>
      tr('This account may not record on the server.'),
    'recording_invalid_interval' =>
      tr('This show has already ended or has no times in the guide.'),
    'recording_rule_limit_exceeded' => tr(
        'You have as many weekly recordings on the server as you are allowed.'),
    'recording_needs_target' => tr(
        'This Tuliprox version can only record weekly. A one-time recording needs a newer Tuliprox.'),
    _ => tr("The server didn't take the recording."),
  };
}

/// [base] (`https://host/ui`) as a WebSocket address + [path].
String _wsUrl(String base, String path) =>
    '${base.replaceFirst(RegExp(r'^http'), 'ws')}$path';

/// A WebSocket frame as text (the server sends binary or text frames).
String? _frameText(Object? frame) => switch (frame) {
      String s => s,
      List<int> b => utf8.decode(b, allowMalformed: true),
      _ => null,
    };

extension TuliproxPlayerApi on TuliproxApi {
  Future<http.Response> _send(String method, TuliproxLogin l, String path,
      {Object? body, Map<String, String>? extra}) {
    final req = http.Request(method, Uri.parse('${l.base}$path'))
      ..headers.addAll({...TuliproxApi._headers(bearer: l.token), ...?extra});
    if (body != null) req.body = jsonEncode(body);
    return _client
        .send(req)
        .then(http.Response.fromStream)
        .timeout(TuliproxApi._timeout);
  }

  /// A DVR / rule answer: 2xx is fine, anything else a
  /// [TuliproxRecordingError] with the server's code.
  dynamic _dvr(http.Response r) {
    if (r.statusCode == 401) throw TuliproxLoginException(status: 401);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        return null;
      }
    }
    var code = 'HTTP ${r.statusCode}';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['error'] is String) code = j['error'] as String;
    } catch (_) {
      final text = utf8.decode(r.bodyBytes, allowMalformed: true).trim();
      if (text.isNotEmpty && text.length < 80) code = text;
    }
    throw TuliproxRecordingError(code, status: r.statusCode);
  }

  // --- 4.13 Split ---

  /// Splits [l]'s own shared stream [uid] off onto its own provider
  /// connection: the server-relative address to open instead
  /// (`/live/u/p/vid.ts?dedicated=1`, contains the playlist password:
  /// never log it). Refusals: [TuliproxSwitchRefused] with the code
  /// (`stream_not_shared`, `split_unsupported_protocol`, `switch_cooldown`).
  Future<String> split(TuliproxLogin l, int uid) async {
    final r = await _send('POST', l, '/api/v1/me/streams/$uid/split');
    if (r.statusCode == 401) throw TuliproxLoginException(status: 401);
    final text = utf8.decode(r.bodyBytes, allowMalformed: true).trim();
    if (r.statusCode < 200 || r.statusCode >= 300) {
      var code = text;
      try {
        final j = jsonDecode(text);
        if (j is Map && j['error'] is String) code = j['error'] as String;
      } catch (_) {}
      throw TuliproxSwitchRefused(code, status: r.statusCode);
    }
    final j = jsonDecode(text);
    final url = j is Map ? j['url'] : null;
    if (url is! String || url.isEmpty) {
      throw TuliproxSwitchRefused('no url', status: r.statusCode);
    }
    return url;
  }

  // --- 4.2 Members before playback ---

  /// The sources of failover channel [vid] before anything plays (no
  /// current one); null when it isn't a group (404).
  Future<TuliproxGroup?> channelMembers(TuliproxLogin l, int vid) async {
    try {
      final j = await _get(l, '/api/v1/me/channels/$vid/failover-members');
      return j is Map<String, dynamic>
          ? TuliproxGroup.fromJson(0, j, player: l)
          : null;
    } on TuliproxException catch (e) {
      if (e.status == 400 || e.status == 404) return null;
      rethrow;
    }
  }

  // --- 4.4 Channels and EPG ---

  Future<List<TuliproxServerChannel>> searchChannels(TuliproxLogin l,
      {String? query, String? group, int limit = 50}) async {
    final q = Uri(queryParameters: {
      if (query != null && query.isNotEmpty) 'query': query,
      if (group != null && group.isNotEmpty) 'group': group,
      'limit': '$limit',
    }).query;
    final j = await _get(l, '/api/v1/me/channels?$q');
    return [
      for (final c in (j is List ? j : const []))
        if (c is Map && _int(c['virtual_id']) != null)
          TuliproxServerChannel(
            virtualId: _int(c['virtual_id'])!,
            name: '${c['name'] ?? ''}',
            group: '${c['group'] ?? ''}',
            epgChannelId: '${c['epg_channel_id'] ?? ''}',
            isGroup: c['is_group'] == true,
          ),
    ];
  }

  /// Channel [vid]'s programmes from [from] (default now) to [to] (default
  /// 24 h later; the server allows 48 h at most).
  Future<List<TuliproxProgramme>> epg(TuliproxLogin l, int vid,
      {DateTime? from, DateTime? to}) async {
    final q = Uri(queryParameters: {
      'vid': '$vid',
      if (from != null) 'from': '${from.millisecondsSinceEpoch ~/ 1000}',
      if (to != null) 'to': '${to.millisecondsSinceEpoch ~/ 1000}',
    }).query;
    final j = await _get(l, '/api/v1/me/epg?$q');
    DateTime at(Object? v) =>
        DateTime.fromMillisecondsSinceEpoch((_int(v) ?? 0) * 1000);
    return [
      for (final p in (j is List ? j : const []))
        if (p is Map)
          TuliproxProgramme(
            start: at(p['start_ts']),
            stop: at(p['stop_ts']),
            title: '${p['title'] ?? ''}',
            description: '${p['desc'] ?? ''}',
            categories: [
              for (final c in (p['categories'] as List? ?? const [])) '$c'
            ],
            isLive: p['is_live'] == true,
            isNew: p['is_new'] == true,
          ),
    ];
  }

  // --- 4.5 Bouquet (needs Web UI access for the user) ---

  Future<TuliproxBouquet> categories(TuliproxLogin l) async =>
      _bouquetOf(await _get(l, '/api/v1/user/playlist/categories'));

  Future<TuliproxBouquet> bouquet(TuliproxLogin l) async =>
      _bouquetOf(await _get(l, '/api/v1/user/playlist/bouquet'));

  Future<void> setBouquet(TuliproxLogin l, TuliproxBouquet bouquet) async =>
      _decode(
          await _send('POST', l, '/api/v1/user/playlist/bouquet',
              body: bouquet),
          empty: true);

  // --- 4.11 Watch progress ---

  /// [kind] / [itemId]'s stored position; null when none (404).
  Future<TuliproxProgress?> progress(
      TuliproxLogin l, String kind, int itemId) async {
    try {
      return TuliproxProgress.fromJson(
          await _get(l, '/api/v1/me/progress/$kind/$itemId'));
    } on TuliproxException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Stored positions, newest first ([limit] 1..200).
  Future<List<TuliproxProgress>> progressList(TuliproxLogin l,
      {String? kind, bool? watched, int limit = 200}) async {
    final q = Uri(queryParameters: {
      if (kind != null) 'kind': kind,
      if (watched != null) 'watched': '$watched',
      'limit': '$limit',
    }).query;
    final j = await _get(l, '/api/v1/me/progress?$q');
    return [
      for (final p in (j is List ? j : const []))
        if (TuliproxProgress.fromJson(p) case final v?) v
    ];
  }

  Future<void> saveProgress(TuliproxLogin l, String kind, int itemId,
          {required int positionSecs,
          int? durationSecs,
          int? seriesId,
          bool? watched}) async =>
      _decode(
          await _send('PUT', l, '/api/v1/me/progress/$kind/$itemId', body: {
            'position_secs': positionSecs,
            if (durationSecs != null && durationSecs > 0)
              'duration_secs': durationSecs,
            if (seriesId != null && seriesId > 0) 'series_id': seriesId,
            if (watched != null) 'watched': watched,
          }),
          empty: true);

  Future<void> deleteProgress(TuliproxLogin l,
          [String? kind, int? itemId]) async =>
      _decode(
          await _send(
              'DELETE',
              l,
              kind == null || itemId == null
                  ? '/api/v1/me/progress'
                  : '/api/v1/me/progress/$kind/$itemId'),
          empty: true);

  // --- 4.6 / 4.10 DVR ---

  /// Whether [l] may use the server's DVR: true (204), false when it may
  /// not or it is off (403 / 501).
  Future<bool> recordingAvailable(TuliproxLogin l) async {
    final r = await _send('GET', l, '/api/v1/recording/availability');
    if (r.statusCode == 401) throw TuliproxLoginException(status: 401);
    return r.statusCode >= 200 && r.statusCode < 300;
  }

  /// Records live channel [vid] of target [targetId] from [start] to [end]
  /// ([preRoll] / [postRoll] padding). An empty [targetId] = the caller's
  /// own (Tuliprox after 3.3.207; 3.3.207 answers `recording_invalid_source`). 204 = accepted; the id comes with
  /// the next snapshot. [idempotencyKey]: the same request twice records once.
  Future<void> createRecording(TuliproxLogin l,
      {required String targetId,
      required int vid,
      required String title,
      required DateTime start,
      required DateTime end,
      Duration preRoll = Duration.zero,
      Duration postRoll = Duration.zero,
      String? channelId,
      String? channelName,
      String visibility = 'private',
      String? idempotencyKey}) async {
    _dvr(await _send('POST', l, '/api/v1/recording/requests', body: {
      'source': {
        'target_id': targetId,
        'virtual_id': '$vid',
        'cluster': 'Live',
        'input_name': '',
      },
      'program_title': title,
      'program_start': start.millisecondsSinceEpoch ~/ 1000,
      'program_end': end.millisecondsSinceEpoch ~/ 1000,
      'pre_roll_secs': preRoll.inSeconds,
      'post_roll_secs': postRoll.inSeconds,
      'visibility': visibility,
      if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId,
      if (channelName != null && channelName.isNotEmpty)
        'channel_name': channelName,
    }, extra: {
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    }));
  }

  Future<void> editRecording(TuliproxLogin l, String id,
          {DateTime? start,
          DateTime? end,
          Duration? preRoll,
          Duration? postRoll,
          String? title}) async =>
      _dvr(await _send(
          'PATCH', l, '/api/v1/recording/requests/${Uri.encodeComponent(id)}',
          body: {
            if (start != null)
              'program_start': start.millisecondsSinceEpoch ~/ 1000,
            if (end != null) 'program_end': end.millisecondsSinceEpoch ~/ 1000,
            if (preRoll != null) 'pre_roll_secs': preRoll.inSeconds,
            if (postRoll != null) 'post_roll_secs': postRoll.inSeconds,
            if (title != null) 'program_title': title,
          }));

  Future<void> cancelRecording(TuliproxLogin l, String id) async =>
      _dvr(await _send('POST', l,
          '/api/v1/recording/requests/${Uri.encodeComponent(id)}/cancel'));

  Future<void> deleteRecording(TuliproxLogin l, String id) async =>
      _dvr(await _send('DELETE', l,
          '/api/v1/recording/requests/${Uri.encodeComponent(id)}'));

  /// `no_known_conflict`, `possible_capacity_wait` or `likely_missed_window`.
  /// An empty [targetName] = the caller's own (Tuliprox after 3.3.207).
  Future<String> recordingConflicts(TuliproxLogin l,
      {String targetName = '',
      required int vid,
      required DateTime start,
      required DateTime end,
      Duration preRoll = Duration.zero,
      Duration postRoll = Duration.zero}) async {
    final j = _dvr(
        await _send('POST', l, '/api/v1/recording/conflicts/preview', body: {
      'source': {
        'target_name': targetName,
        'virtual_id': '$vid',
        'input_name': '',
      },
      'candidate': {
        'padded_start': start.subtract(preRoll).millisecondsSinceEpoch ~/ 1000,
        'padded_end': end.add(postRoll).millisecondsSinceEpoch ~/ 1000,
        'pre_roll_secs': preRoll.inSeconds,
        'post_roll_secs': postRoll.inSeconds,
        'priority': 0,
      },
    }));
    return j is Map
        ? '${j['severity'] ?? 'no_known_conflict'}'
        : 'no_known_conflict';
  }

  Future<List<TuliproxRecordingRule>> recordingRules(TuliproxLogin l) async {
    final j = _dvr(await _send('GET', l, '/api/v1/recording/rules'));
    return [
      for (final r in (j is List ? j : const []))
        if (TuliproxRecordingRule.fromJson(r) case final v?) v
    ];
  }

  /// Records channel [vid] every week at [weekday] (1 = Monday) [start]
  /// (`HH:MM`) in [timezone] (IANA) for [duration]. The target defaults
  /// to the caller's.
  Future<TuliproxRecordingRule?> createRecordingRule(TuliproxLogin l,
      {required int vid,
      required int weekday,
      required String start,
      required Duration duration,
      required String timezone,
      Duration preRoll = Duration.zero,
      Duration postRoll = Duration.zero,
      String? channelId,
      String visibility = 'private'}) async {
    final j = _dvr(await _send('POST', l, '/api/v1/recording/rules', body: {
      'virtual_id': '$vid',
      if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId,
      'body': {
        'kind': 'weekly_timeslot',
        'weekday': weekday,
        'local_start_time': start,
        'duration_secs': duration.inSeconds,
        'timezone': timezone,
      },
      'pre_roll_secs': preRoll.inSeconds.clamp(0, 900),
      'post_roll_secs': postRoll.inSeconds.clamp(0, 1800),
      'visibility': visibility,
    }));
    return TuliproxRecordingRule.fromJson(j);
  }

  /// [cancelFuture]: also cancels the upcoming recordings it scheduled.
  Future<void> deleteRecordingRule(TuliproxLogin l, String id,
          {bool cancelFuture = false}) async =>
      _dvr(await _send('DELETE', l,
          '/api/v1/recording/rules/${Uri.encodeComponent(id)}?future=${cancelFuture ? 'cancel' : 'retain'}'));

  /// Where recording [id] plays (HTTP Range; needs [recordingHeaders]).
  String recordingPlaybackUrl(TuliproxLogin l, String id) =>
      '${l.base}/api/v1/library/recording/playback/${Uri.encodeComponent(id)}';

  String recordingDownloadUrl(TuliproxLogin l, String id) =>
      '${l.base}/api/v1/library/recording/download/${Uri.encodeComponent(id)}';

  Map<String, String> recordingHeaders(TuliproxLogin l) =>
      {'Authorization': 'Bearer ${l.token}'};

  /// [l]'s recordings: the snapshot over the binary `/ws` socket (version
  /// byte 4, `{"Auth": token}`, `"RecordingSnapshotRequest"`).
  Future<TuliproxRecordingSnapshot> recordingSnapshot(TuliproxLogin l,
      {Duration timeout = const Duration(seconds: 12)}) async {
    final ws = await WebSocket.connect(_wsUrl(l.base, '/ws'),
        headers: {'User-Agent': 'VesperTV'}).timeout(timeout);
    final frames = StreamIterator<dynamic>(ws);
    Future<String?> next() async => await frames.moveNext().timeout(timeout)
        ? _frameText(frames.current)
        : null;
    try {
      ws.add(Uint8List.fromList(const [4]));
      final echo = await frames.moveNext().timeout(timeout);
      if (!echo) throw TuliproxException('no answer');
      ws.add(utf8.encode(jsonEncode({'Auth': l.token})));
      final auth = await next();
      if (auth == null || auth.contains('Unauthorized')) {
        throw TuliproxLoginException(status: 401);
      }
      _wsError(auth);
      ws.add(utf8.encode(jsonEncode('RecordingSnapshotRequest')));
      for (var i = 0; i < 20; i++) {
        final text = await next();
        if (text == null) break;
        _wsError(text);
        try {
          final j = jsonDecode(text);
          final snap = j is Map ? j['RecordingSnapshotResponse'] : null;
          if (snap is Map) return TuliproxRecordingSnapshot.fromJson(snap);
        } catch (_) {
          // Not JSON (or another message): keep reading.
        }
      }
      throw TuliproxException('no recordings snapshot');
    } finally {
      await frames.cancel();
      await ws.close();
    }
  }

  void _wsError(String text) {
    if (!text.contains('RecordingWsError')) return;
    try {
      final j = jsonDecode(text);
      final e = j is Map ? j['RecordingWsError'] : null;
      if (e is Map) {
        throw TuliproxRecordingError('${e['code'] ?? 'recording_error'}');
      }
    } on TuliproxRecordingError {
      rethrow;
    } catch (_) {}
    throw TuliproxRecordingError('recording_error');
  }

  // --- 4.9 MCP player tools ---

  /// Calls player tool [name] (`POST {base}/mcp`, JSON-RPC `tools/call`):
  /// its text result. Null when the server has no MCP endpoint (404/405);
  /// a tool error throws [TuliproxRecordingError] with its text.
  Future<String?> mcpTool(
      TuliproxLogin l, String name, Map<String, Object?> arguments) async {
    final r = await _send('POST', l, '/mcp', body: {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {'name': name, 'arguments': arguments},
    });
    if (r.statusCode == 404 || r.statusCode == 405) return null;
    final j = _decode(r);
    if (j is! Map) throw TuliproxException('not Tuliprox');
    if (j['error'] is Map) {
      // Unknown / hidden tool (player tools off): like no endpoint.
      return null;
    }
    final result = j['result'];
    final text = [
      if (result is Map)
        for (final c in (result['content'] as List? ?? const []))
          if (c is Map && c['type'] == 'text') '${c['text'] ?? ''}'
    ].join('\n');
    if (result is Map && result['isError'] == true) {
      final code = RegExp(r'recording_[a-z_]+').firstMatch(text)?.group(0);
      throw TuliproxRecordingError(code ?? text);
    }
    return text;
  }
}

/// The personal event stream (`GET {base}/api/v1/me/events`, a JSON
/// WebSocket): `stream_ended`, `failover_member_switched`,
/// `recording_finished`, `connection_denied`, `resync_required`. Opened
/// while a channel of that server plays; reconnects with a growing pause,
/// stops for good on a policy close (1008: feature off, signed out).
class TuliproxEventSocket {
  TuliproxEventSocket(this.login, this.onEvent);

  final TuliproxLogin login;
  final void Function(Map<String, dynamic> event) onEvent;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _failures = 0;
  bool _closed = false;
  bool _everConnected = false;

  /// Connected and authorised (the server's `connected` frame came).
  bool connected = false;

  Future<void> open() async {
    if (_closed || _ws != null) return;
    try {
      final ws = await WebSocket.connect(
          _wsUrl(login.base, '/api/v1/me/events'),
          headers: {
            'Authorization': 'Bearer ${login.token}',
            'User-Agent': 'VesperTV',
          }).timeout(const Duration(seconds: 12));
      if (_closed) {
        await ws.close();
        return;
      }
      _ws = ws;
      ws.pingInterval = const Duration(seconds: 30);
      _sub = ws.listen(_frame, onDone: _done, onError: (_) => _done());
    } catch (e) {
      debugPrint('Tuliprox: event stream not opened (${e.runtimeType})');
      _again();
    }
  }

  void _frame(dynamic frame) {
    final text = _frameText(frame);
    if (text == null) return;
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic>) return;
      if (j['type'] == 'connected') {
        connected = true;
        _everConnected = true;
        _failures = 0;
        debugPrint('Tuliprox: event stream connected');
      }
      onEvent(j);
    } catch (_) {
      // Not JSON: ignored.
    }
  }

  void _done() {
    final code = _ws?.closeCode;
    _sub?.cancel();
    _sub = null;
    _ws = null;
    connected = false;
    if (_closed) return;
    if (code == 1008) {
      debugPrint('Tuliprox: event stream closed by the server (policy)');
      _closed = true;
      return;
    }
    _again();
  }

  /// Gave up: closed by the server (policy) or never reached (a reverse
  /// proxy without WebSocket upgrades for this path).
  bool get finished => _closed;

  void _again() {
    if (_closed) return;
    _failures++;
    // Never connected after 4 tries: the address doesn't take WebSockets
    // (nginx without Upgrade headers for /me/events). Not again this run.
    if (_failures >= 4 && !_everConnected) {
      debugPrint('Tuliprox: event stream unreachable, given up');
      _closed = true;
      return;
    }
    final wait = Duration(seconds: min(60, 2 << min(_failures, 5)));
    _retry?.cancel();
    _retry = Timer(wait, open);
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _sub?.cancel();
    _sub = null;
    final ws = _ws;
    _ws = null;
    connected = false;
    await ws?.close();
  }
}
