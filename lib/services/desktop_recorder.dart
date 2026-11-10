import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'desktop_stream_setup.dart' show kDesktopStreamUserAgent;

/// Windows' side of [RecordingService]'s recorder calls, for downloads only
/// (owner, 2026-11-10: Windows up to par with Android; recording stays
/// Android, owner 2026-11-05). Same method names, replies and `.status`
/// files as Android's RecorderService / Downloader.kt / NetworkFolder.kt,
/// so RecordingService, the Recordings tab and the download sheet stay
/// shared. Runs while VesperTV runs (minimized counts): a download due
/// while the app is closed starts at the next launch.
///
/// The network folder is the Windows share itself: `smb://host/share/…`
/// paths become `\\host\share\…`, which Windows opens with the signed-in
/// account, or with the folder's user / password through `net use`.
class DesktopRecorder {
  DesktopRecorder({String? videosDir}) : _videosDirOverride = videosDir;

  static final instance = DesktopRecorder();

  final String? _videosDirOverride;
  final Map<String, _Job> _jobs = {};
  Timer? _wake;
  Map<String, dynamic>? _network;
  String? _connected;

  // What the app plays (RecordingService 'policy'), per provider account.
  String _speed = 'watch';
  Map<String, int> _streams = const {};
  DateTime _streamsAt = DateTime(0);

  static const scheme = 'smb://';
  static const whilePlaying = 625000; // 5 Mbit/s
  static const _video = {'mkv', 'mp4', 'm4v', 'avi', 'ts', 'webm', 'mov'};
  static const detailsDir = '.vespertv';

  static bool isNetwork(String path) => path.startsWith(scheme);

  /// `smb://host/share/a/b.mkv` -> `\\host\share\a\b.mkv`; a local path as is.
  static String localPath(String path) => isNetwork(path)
      ? '\\\\${path.substring(scheme.length).replaceAll('/', '\\')}'
      : path;

  Future<Object?> invoke(String method, Map<String, Object?> args) async {
    switch (method) {
      case 'storage':
        return [await _storage()];
      case 'networkFolder':
        final config = args['config'];
        _network = config is String
            ? Map<String, dynamic>.from(jsonDecode(config) as Map)
            : null;
        _connected = null;
        return null;
      case 'testNetworkFolder':
        return _test(Map<String, dynamic>.from(
            jsonDecode(args['config'] as String) as Map));
      case 'schedule':
        _schedule(args['items'] as String? ?? '[]');
        return true;
      case 'active':
        return [
          for (final j in _jobs.values)
            if (j.active) {'id': j.id}
        ];
      case 'stop':
        _jobs[args['id']]?.stop('stopped');
        return null;
      case 'deleteFile':
        return _delete(args['path'] as String? ?? '');
      case 'playUrl':
        return localPath(args['path'] as String? ?? '');
      case 'networkList':
        return _list();
      case 'networkWriteText':
        return _writeText(
            args['path'] as String? ?? '', args['text'] as String? ?? '');
      case 'policy':
        _speed = args['speed'] as String? ?? 'watch';
        final streams = args['streams'];
        _streams = streams is Map
            ? {
                for (final e in streams.entries)
                  '${e.key}': (e.value as num?)?.toInt() ?? 0
              }
            : const {};
        _streamsAt = DateTime.now();
        return null;
      case 'yield':
        await _yield(args['account'] as String? ?? '');
        return null;
      // teePort, askNotifications: recording only.
      default:
        return null;
    }
  }

  // ------------------------------------------------------------- storage

  String get videosDir =>
      _videosDirOverride ??
      '${Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}'
          '\\Videos\\VesperTV';

  Future<Map<String, Object?>> _storage() async {
    final dir = Directory(videosDir);
    try {
      await dir.create(recursive: true);
    } catch (_) {}
    final (free, total) = diskSpace(dir.path);
    return {'path': dir.path, 'free': free, 'total': total, 'removable': false};
  }

  /// Free and total bytes of the disk holding [path] (a UNC share too);
  /// (-1, -1) when unknown.
  static (int, int) diskSpace(String path) {
    if (!Platform.isWindows) return (-1, -1);
    try {
      final fn = DynamicLibrary.open('kernel32.dll').lookupFunction<
          Int32 Function(
              Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
          int Function(Pointer<Utf16>, Pointer<Uint64>, Pointer<Uint64>,
              Pointer<Uint64>)>('GetDiskFreeSpaceExW');
      final dir = path.endsWith('\\') ? path : '$path\\';
      final p = dir.toNativeUtf16(allocator: calloc);
      final free = calloc<Uint64>(), total = calloc<Uint64>();
      final all = calloc<Uint64>();
      try {
        return fn(p, free, total, all) == 0
            ? (-1, -1)
            : (free.value, total.value);
      } finally {
        calloc.free(p);
        calloc.free(free);
        calloc.free(total);
        calloc.free(all);
      }
    } catch (_) {
      return (-1, -1);
    }
  }

  // ------------------------------------------------------ network folder

  static String _uncBase(Map<String, dynamic> c) {
    final folder = '${c['folder'] ?? ''}'.replaceAll('/', '\\');
    return '\\\\${c['host']}\\${c['share']}${folder.isEmpty ? '' : '\\$folder'}';
  }

  /// Signs in to the share with the folder's user name (Windows keeps the
  /// session until it logs off); nothing to do without one. The error in
  /// plain words, or null.
  Future<String?> _connect(Map<String, dynamic> c, {bool force = false}) async {
    final user = '${c['user'] ?? ''}'.trim();
    if (user.isEmpty) return null;
    final share = '\\\\${c['host']}\\${c['share']}';
    final key = '$share|$user';
    if (!force && _connected == key) return null;
    final domain = '${c['domain'] ?? ''}'.trim();
    try {
      final r = await Process.run('net', [
        'use',
        share,
        '${c['password'] ?? ''}',
        '/user:${domain.isEmpty ? user : '$domain\\$user'}',
        '/persistent:no',
      ]).timeout(const Duration(seconds: 30));
      final out = '${r.stdout} ${r.stderr}';
      // 1219: already signed in to this computer (with this or another
      // user); Windows uses that session.
      if (r.exitCode == 0 || out.contains('1219')) {
        _connected = key;
        return null;
      }
      final code = RegExp(r'\b(\d{2,4})\b').firstMatch(out)?.group(1);
      debugPrint('DesktopRecorder: net use failed (${code ?? r.exitCode})');
      return describeCode(int.tryParse(code ?? '')) ?? 'Could not connect';
    } on TimeoutException {
      return "The computer didn't answer";
    } catch (e) {
      return '${e.runtimeType}';
    }
  }

  /// A short reason for the user (never the password).
  static String? describeCode(int? code) => switch (code) {
        5 => 'Wrong user name or password, or no access to this folder',
        86 || 1326 || 2202 => 'Wrong user name or password',
        53 || 1231 || 1232 =>
          "Can't reach the computer (is it on, and sharing turned on?)",
        67 => 'No shared folder with that name',
        3 => 'Folder not found',
        112 => 'Not enough storage space',
        64 || 121 => "The computer didn't answer",
        _ => null,
      };

  static String describe(Object e) {
    if (e is TimeoutException) return "The computer didn't answer";
    if (e is FileSystemException) {
      return describeCode(e.osError?.errorCode) ??
          (e.osError?.message.trim().isNotEmpty == true
              ? e.osError!.message.trim()
              : e.message);
    }
    return '${e.runtimeType}';
  }

  Future<Map<String, Object?>> _test(Map<String, dynamic> c) async {
    try {
      final error = await _connect(c, force: true);
      if (error != null) return {'ok': false, 'error': error};
      final dir = Directory(_uncBase(c));
      await dir.create(recursive: true).timeout(const Duration(seconds: 30));
      final probe = File('${dir.path}\\.vespertv-test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      final (free, total) = diskSpace('\\\\${c['host']}\\${c['share']}');
      return {
        'ok': true,
        if (free >= 0) 'free': free,
        if (total >= 0) 'total': total,
      };
    } catch (e) {
      debugPrint('DesktopRecorder: test failed: ${e.runtimeType}');
      return {'ok': false, 'error': describe(e)};
    }
  }

  Future<void> _connectSaved() async {
    final c = _network;
    if (c != null) await _connect(c);
  }

  Future<bool> _delete(String path) async {
    try {
      if (isNetwork(path)) await _connectSaved();
      final f = File(localPath(path));
      if (await f.exists()) await f.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _writeText(String path, String text) async {
    try {
      if (isNetwork(path)) await _connectSaved();
      final f = File(localPath(path));
      await f.parent.create(recursive: true);
      await f.writeAsString(text, flush: true);
      return true;
    } catch (e) {
      debugPrint('DesktopRecorder: write failed: ${e.runtimeType}');
      return false;
    }
  }

  /// `.vespertv/<name>.json` beside [path] (NetworkFolder.detailsUrl).
  static String detailsPath(String path) {
    final slash = path.lastIndexOf('/');
    return '${path.substring(0, slash)}/$detailsDir/'
        '${path.substring(slash + 1)}.json';
  }

  /// Every video in the network folder (3 folders deep) with the details
  /// file another device wrote: `{files: json}` or `{error: reason}`.
  Future<Map<String, Object?>> _list() async {
    final c = _network;
    if (c == null) return {'error': 'No network folder'};
    try {
      final error = await _connect(c);
      if (error != null) return {'error': error};
      final base = '$scheme${c['host']}/${c['share']}'
          '${'${c['folder'] ?? ''}'.isEmpty ? '' : '/${c['folder']}'}';
      final out = <Map<String, Object?>>[];
      Future<void> walk(String url, int depth) async {
        final dir = Directory(localPath(url));
        if (!await dir.exists()) return;
        final entries = await dir.list(followLinks: false).toList();
        final details = <String, String>{};
        final dd = Directory('${dir.path}\\$detailsDir');
        if (await dd.exists()) {
          await for (final f in dd.list(followLinks: false)) {
            if (f is! File || !f.path.endsWith('.json')) continue;
            try {
              if (await f.length() > 64 * 1024) continue;
              final name = f.uri.pathSegments.last;
              details[Uri.decodeComponent(name.substring(0, name.length - 5))] =
                  await f.readAsString();
            } catch (_) {}
          }
        }
        for (final e in entries) {
          final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final decoded = Uri.decodeComponent(name);
          if (decoded.startsWith('.')) continue;
          final child = '$url/$decoded';
          if (e is Directory) {
            if (depth < 3) await walk(child, depth + 1);
            continue;
          }
          if (e is! File) continue;
          final ext = decoded.contains('.')
              ? decoded.substring(decoded.lastIndexOf('.') + 1).toLowerCase()
              : '';
          if (!_video.contains(ext)) continue;
          final stat = await e.stat();
          out.add({
            'path': child,
            'name': decoded,
            'size': stat.size,
            'modified': stat.modified.millisecondsSinceEpoch,
            if (details[decoded] case final d?) 'details': d,
          });
        }
      }

      await walk(base, 0).timeout(const Duration(seconds: 60));
      return {'files': jsonEncode(out)};
    } catch (e) {
      debugPrint('DesktopRecorder: list failed: ${e.runtimeType}');
      return {'error': describe(e)};
    }
  }

  // ------------------------------------------------------------ downloads

  Map<String, int> get streams =>
      DateTime.now().difference(_streamsAt) > const Duration(minutes: 3)
          ? const {}
          : _streams;

  /// Bytes per second for [j]; null = no limit (DownloadPolicy.rate).
  int? _rateOf(_Job j) {
    if (j.fromNetwork) return null;
    int? r = switch (_speed) {
      'none' => null,
      '10' => 1250000,
      '25' => 3125000,
      '50' => 6250000,
      // Like watching: the file's own average bitrate with some headroom.
      _ => j.total > 0 && j.durationSec > 60
          ? math.max(500000, j.total ~/ j.durationSec * 5 ~/ 4)
          : 1500000,
    };
    if (streams.isNotEmpty) r = r == null ? whilePlaying : math.min(r, whilePlaying);
    return r;
  }

  /// Why [j] must wait, or null: the app plays from its account's last
  /// connection (DownloadPolicy.blocked; Windows has no recordings).
  String? _blocked(_Job j) {
    if (j.account.isEmpty) return null;
    final limit = j.maxConnections > 0 ? j.maxConnections : 1;
    return (streams[j.account] ?? 0) >= limit ? 'connection' : null;
  }

  void _schedule(String json) {
    final ids = <String>{};
    for (final m in (jsonDecode(json) as List).whereType<Map>()) {
      if (m['kind'] != 'download') continue;
      final id = '${m['id']}';
      ids.add(id);
      final job = _jobs[id];
      if (job == null || job.finished) {
        _jobs[id] = _Job(this, Map<String, dynamic>.from(m));
      } else {
        job.startAt = (m['startAt'] as num?)?.toInt() ?? job.startAt;
      }
    }
    for (final j in _jobs.values.toList()) {
      if (ids.contains(j.id)) continue;
      if (!j.finished) j.stop('stopped');
      if (!j.running) _jobs.remove(j.id);
    }
    pump();
  }

  /// Starts the earliest due download (one at a time) and wakes up for the
  /// next scheduled one.
  void pump() {
    _wake?.cancel();
    _wake = null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final waiting = _jobs.values.where((j) => !j.finished && !j.running);
    final busy = _jobs.values.any((j) => j.running);
    final due = waiting.where((j) => j.startAt <= now).toList()
      ..sort((a, b) => a.startAt != b.startAt
          ? a.startAt.compareTo(b.startAt)
          : a.id.compareTo(b.id));
    if (!busy && due.isNotEmpty) unawaited(due.first.run());
    for (final j in due.skip(busy ? 0 : 1)) {
      j.markQueued();
    }
    final later = waiting.where((j) => j.startAt > now).map((j) => j.startAt);
    if (later.isNotEmpty) {
      final next = later.reduce(math.min);
      _wake = Timer(Duration(milliseconds: next - now + 50), pump);
    }
  }

  Future<void> _yield(String account) async {
    final job = _jobs.values
        .where((j) => j.running && j.account == account)
        .firstOrNull;
    if (job == null) return;
    job.interrupt();
    final until = DateTime.now().add(const Duration(seconds: 4));
    while (job.running && job.state != 'paused' && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> writeDetails(String path, String details) async {
    if (!isNetwork(path)) return;
    await _writeText(detailsPath(path), details);
  }

  Future<void> connectFor(String path) async {
    if (isNetwork(path)) await _connectSaved();
  }
}

/// Waits: the connection is needed by the player.
class _Pause implements Exception {}

/// A problem retrying won't fix.
class _Fatal implements Exception {
  _Fatal(this.message);
  final String message;
}

/// One movie / episode download (Downloader.kt's `Download`): a plain HTTP
/// GET written to a local file or the network folder, resumed with Range
/// after a drop, a pause or a restart.
class _Job {
  _Job(this.owner, Map<String, dynamic> m)
      : id = '${m['id']}',
        url = '${m['url'] ?? ''}',
        path = '${m['path'] ?? ''}',
        statusPath = '${m['statusPath'] ?? '${m['path']}.status'}',
        account = '${m['account'] ?? ''}',
        maxConnections = (m['maxConnections'] as num?)?.toInt() ?? 1,
        durationSec = (m['durationSec'] as num?)?.toInt() ?? 0,
        startAt = (m['startAt'] as num?)?.toInt() ?? 0,
        minFreeBytes = (m['minFreeBytes'] as num?)?.toInt() ?? (1 << 30),
        maxBytes = (m['maxBytes'] as num?)?.toInt() ?? 0,
        headers = {
          if (m['headers'] case final Map h)
            for (final e in h.entries) '${e.key}': '${e.value}'
        },
        details = (m['details'] as String?)?.isNotEmpty == true
            ? m['details'] as String
            : null;

  final DesktopRecorder owner;
  final String id, url, path, statusPath, account;
  final int maxConnections, durationSec, minFreeBytes, maxBytes;
  int startAt;
  final Map<String, String> headers;
  final String? details;

  bool get fromNetwork => DesktopRecorder.isNetwork(url);

  int bytes = 0, total = 0;
  String state = 'queued', note = '', error = '';
  String? _stopReason;
  bool running = false;
  bool _queuedWritten = false;
  HttpClient? _client;

  /// Ends the running transfer (stop / yield): cancels the reads.
  void Function()? _abort;
  Completer<void>? _nap;
  final int _startedAt = DateTime.now().millisecondsSinceEpoch;
  int _lastStatusAt = 0;

  bool get finished => state == 'done' || state == 'stopped' || state == 'failed';

  /// Shown as running in the Recordings tab (Android: has a thread).
  bool get active =>
      !finished &&
      (running || startAt <= DateTime.now().millisecondsSinceEpoch);

  void stop(String reason) {
    _stopReason ??= reason;
    interrupt();
    if (!running) {
      state = reason;
      writeStatus();
    }
  }

  /// Closes the connection now (stop, or the player needs it).
  void interrupt() {
    _client?.close(force: true);
    _abort?.call();
    final nap = _nap;
    if (nap != null && !nap.isCompleted) nap.complete();
  }

  void markQueued() {
    if (_queuedWritten) return;
    _queuedWritten = true;
    state = 'queued';
    note = 'queue';
    writeStatus();
  }

  Future<void> _sleep(Duration d) async {
    final nap = _nap = Completer<void>();
    final timer = Timer(d, () {
      if (!nap.isCompleted) nap.complete();
    });
    await nap.future;
    timer.cancel();
  }

  Future<void> run() async {
    running = true;
    _readStatus();
    debugPrint('DesktopDownload: $id starts');
    var failures = 0;
    var bytesAtFailure = -1;
    var before = '';
    try {
      await owner.connectFor(path);
      await owner.connectFor(url);
      while (_stopReason == null) {
        final reason = owner._blocked(this);
        if (reason != null) {
          state = 'paused';
          note = reason;
          if (state != before) writeStatus();
          before = state;
          await _sleep(const Duration(seconds: 2));
          continue;
        }
        try {
          state = 'downloading';
          note = '';
          if (before != state) writeStatus();
          before = state;
          await _transfer();
          state = 'done';
          break;
        } on _Pause {
          // Back to the top: waits until the connection is free.
        } on _Fatal catch (e) {
          error = e.message;
          state = 'failed';
          break;
        } catch (e) {
          if (_stopReason != null) break;
          // The player took the connection back (yield): a pause.
          if (owner._blocked(this) != null) continue;
          error = DesktopRecorder.isNetwork(path) || fromNetwork
              ? DesktopRecorder.describe(e)
              : e is HttpException
                  ? e.message
                  : e is SocketException
                      ? e.message
                      : '${e.runtimeType}';
          // Only failures in a row count (a link that drops but keeps
          // delivering never gives up).
          if (bytes > bytesAtFailure) failures = 0;
          bytesAtFailure = bytes;
          failures++;
          debugPrint('DesktopDownload: $id ${e.runtimeType} (try $failures)');
          // A dropped link or a sleeping NAS: retry for ~20 min.
          if (failures > 40) {
            state = 'failed';
            break;
          }
          await _sleep(failures <= 3
              ? const Duration(seconds: 2)
              : const Duration(seconds: 30));
        }
      }
      if (_stopReason != null && state != 'done' && state != 'failed') {
        state = _stopReason!;
      }
      writeStatus();
      final details = this.details;
      if (state == 'done' && details != null) {
        await owner.writeDetails(path, details);
      }
      debugPrint('DesktopDownload: $id $state');
    } finally {
      running = false;
      owner.pump();
    }
  }

  void _readStatus() {
    try {
      final f = File(statusPath);
      if (!f.existsSync()) return;
      final m = jsonDecode(f.readAsStringSync()) as Map;
      total = (m['total'] as num?)?.toInt() ?? 0;
    } catch (_) {}
  }

  File get _target => File(DesktopRecorder.localPath(path));

  void _checkSpace(int left) {
    if (maxBytes > 0 && maxBytes < total) {
      throw _Fatal('Bigger than the space left for recordings');
    }
    final (free, _) = DesktopRecorder.diskSpace(_target.parent.path);
    if (free >= 0 && free - left < minFreeBytes) {
      throw _Fatal('Not enough storage space');
    }
  }

  Future<void> _transfer() async {
    final target = _target;
    await target.parent.create(recursive: true);
    bytes = await target.exists() ? await target.length() : 0;
    if (total > 0 && bytes >= total) return;
    if (fromNetwork) return _copyFromNetwork(target);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 30);
    _client = client;
    try {
      var uri = Uri.parse(url);
      HttpClientResponse? res;
      for (var i = 0; i < 8 && res == null; i++) {
        final req = await client.getUrl(uri);
        req.followRedirects = false;
        req.headers.set('User-Agent', kDesktopStreamUserAgent);
        req.headers.set('Accept', '*/*');
        headers.forEach(req.headers.set);
        if (bytes > 0) req.headers.set('Range', 'bytes=$bytes-');
        final r = await req.close().timeout(const Duration(seconds: 30));
        if (r.statusCode >= 300 && r.statusCode < 400) {
          final loc = r.headers.value('location');
          await r.drain<void>().catchError((_) {});
          if (loc == null) throw const HttpException('redirect without Location');
          uri = uri.resolve(loc);
          continue;
        }
        res = r;
      }
      if (res == null) throw const HttpException('too many redirects');
      final code = res.statusCode;
      var append = bytes > 0;
      if (code == 416) {
        // Asked past the end: complete already.
        if (bytes > 0 && (total == 0 || bytes >= total)) {
          await res.drain<void>().catchError((_) {});
          return;
        }
        append = false;
      } else if (code == 200) {
        append = false; // the server ignored Range: start over
      } else if (code != 206) {
        await res.drain<void>().catchError((_) {});
        if (const {401, 403, 458, 509}.contains(code)) {
          throw HttpException(
              'The provider refused the download (HTTP $code)');
        }
        if (code == 404 || code == 410) {
          throw _Fatal('The file is gone at the provider (HTTP $code)');
        }
        throw HttpException('HTTP $code');
      }
      if (!append) bytes = 0;
      final range = res.headers.value('content-range') ?? '';
      final length = res.contentLength;
      total = int.tryParse(RegExp(r'/(\d+)$').firstMatch(range)?.group(1) ?? '') ??
          (length > 0 ? bytes + length : total);
      final type = (res.headers.value('content-type') ?? '').toLowerCase();
      // A page or an error reply, not a video (a real file labelled
      // text/plain is big or unsized).
      final page = (type.startsWith('text/') || type.contains('json')) &&
          (total <= 0 || total < 5 * 1024 * 1024);
      if (page || type.contains('mpegurl')) {
        var text = '';
        try {
          final first = await res.first.timeout(const Duration(seconds: 10));
          text = utf8.decode(first.take(300).toList(), allowMalformed: true);
        } catch (_) {}
        final clean = text
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        throw _Fatal(type.contains('mpegurl')
            ? "This stream is a playlist (HLS), not a file. It can't be downloaded."
            : 'The link sent a page, not a video'
                '${clean.isEmpty ? '' : ': ${clean.substring(0, math.min(120, clean.length))}'}');
      }
      // A debrid "being downloaded" clip is ~0.1 MB; no film is under 5 MB.
      if (total > 0 && total < 5 * 1024 * 1024) {
        throw _Fatal('The source sent a short clip, not the file. Try again '
            'later or pick another stream.');
      }
      if (total > 0) _checkSpace(total - bytes);
      final out = await target.open(
          mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly);
      try {
        await _pumpBytes(res, out);
      } finally {
        await out.close();
      }
      if (total > 0 && bytes < total) {
        throw const HttpException('connection closed early');
      }
    } finally {
      client.close(force: true);
      _client = null;
    }
  }

  /// A file from the network folder to this computer, from where it stopped.
  Future<void> _copyFromNetwork(File target) async {
    final src = File(DesktopRecorder.localPath(url));
    if (!await src.exists()) {
      throw _Fatal('The file is no longer in the network folder');
    }
    final size = await src.length();
    if (bytes > size) bytes = 0; // another file under the same name
    total = size;
    if (bytes >= total) return;
    _checkSpace(total - bytes);
    final out = await target.open(
        mode: bytes > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly);
    try {
      await _pumpBytes(src.openRead(bytes), out);
    } finally {
      await out.close();
    }
    if (bytes < total) throw const FileSystemException('copy cut short');
  }

  Future<void> _pumpBytes(Stream<List<int>> input, RandomAccessFile out) async {
    var windowStart = DateTime.now().millisecondsSinceEpoch;
    var windowBytes = 0;
    var rate = owner._rateOf(this);
    final done = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = input.listen((chunk) async {
      sub.pause();
      try {
        if (_stopReason != null) throw StateError('stopped');
        if (owner._blocked(this) != null) throw _Pause();
        await out.writeFrom(chunk);
        bytes += chunk.length;
        // Speed limit: sleep off whatever ran ahead of the rate.
        final r = owner._rateOf(this);
        if (r != rate) {
          rate = r;
          windowStart = DateTime.now().millisecondsSinceEpoch;
          windowBytes = 0;
        }
        if (rate != null) {
          windowBytes += chunk.length;
          final due = windowBytes * 1000 ~/ rate!;
          final spent = DateTime.now().millisecondsSinceEpoch - windowStart;
          if (due > spent) {
            await Future<void>.delayed(
                Duration(milliseconds: math.min(due - spent, 2000)));
          }
          if (windowBytes > rate! * 20) {
            windowStart = DateTime.now().millisecondsSinceEpoch;
            windowBytes = 0;
          }
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastStatusAt > 3000) {
          _lastStatusAt = now;
          if (maxBytes > 0 && bytes >= maxBytes) {
            throw _Fatal('Bigger than the space left for recordings');
          }
          final (free, _) = DesktopRecorder.diskSpace(_target.parent.path);
          if (free >= 0 && free < minFreeBytes) {
            throw _Fatal('Not enough storage space');
          }
          writeStatus();
        }
        sub.resume();
      } catch (e, st) {
        await sub.cancel();
        if (!done.isCompleted) done.completeError(e, st);
      }
    }, onError: (Object e, StackTrace st) {
      if (!done.isCompleted) done.completeError(e, st);
    }, onDone: () {
      if (!done.isCompleted) done.complete();
    }, cancelOnError: true);
    _abort = () {
      unawaited(sub.cancel());
      if (!done.isCompleted) done.completeError(StateError('interrupted'));
    };
    try {
      await done.future;
    } finally {
      _abort = null;
    }
    if (_stopReason != null) throw StateError('stopped');
  }

  void writeStatus() {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final f = File(statusPath);
      f.parent.createSync(recursive: true);
      final tmp = File('$statusPath.tmp');
      tmp.writeAsStringSync(jsonEncode({
        'state': state,
        'bytes': bytes,
        'total': total,
        'note': note,
        'startedAt': _startedAt,
        'updatedAt': now,
        'error': error,
        if (finished) 'endedAt': now,
      }));
      if (f.existsSync()) f.deleteSync();
      tmp.renameSync(f.path);
    } catch (e) {
      debugPrint('DesktopDownload: $id status write failed: ${e.runtimeType}');
    }
  }
}
