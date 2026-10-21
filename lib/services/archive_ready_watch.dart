import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'debrid_api.dart';
import 'storage_service.dart';

/// Media Hub titles whose source answered Play with a short "being
/// downloaded to your account" clip instead of the file (user report,
/// 2026-10-21: debrid-backed add-ons do that for a title they don't hold
/// yet, and nothing told the user when it was there). Such a stream is
/// checked every minute in the background, and the title's poster gets a
/// gold "Ready" tag once it's there. With the user's own debrid key
/// (Settings > Media Hub > Debrid accounts) the account itself confirms
/// it — the torrent hash in the stream URL is "downloaded"; otherwise the
/// same URL is asked again until a much bigger file answers instead of
/// the clip.
class ArchiveReadyWatch {
  ArchiveReadyWatch._();

  static final instance = ArchiveReadyWatch._();

  /// Shorter than this = a placeholder clip, not the title.
  static const placeholderMax = Duration(seconds: 90);
  static const _interval = Duration(minutes: 1);
  static const _giveUpAfter = Duration(hours: 24);

  /// The real file must be this much bigger than the clip (and at least
  /// [_minReadyBytes]) — a placeholder re-encoded or served from another
  /// host must not count as ready.
  static const _growth = 4;
  static const _minReadyBytes = 50 * 1024 * 1024;

  /// Meta ids (`ArchiveMeta.id`, the show's for an episode) with the tag.
  /// Widgets listen to repaint it.
  final ValueNotifier<Set<String>> ready = ValueNotifier(const {});

  /// Meta ids still being checked — the poster's outlined "Fetching…"
  /// tag, so the user can see it was noticed.
  final ValueNotifier<Set<String>> fetching = ValueNotifier(const {});

  /// Either tag changed: what the posters listen to. Its value is [ready].
  late final ValueListenable<Set<String>> tags = _Tags(ready, fetching);

  StorageService? _storage;
  DebridApi? _debrid;
  final _client = http.Client();
  Timer? _timer;
  bool _checking = false;

  /// Channel id → the title it plays, for the stream playing now.
  final Map<String, ({String metaId, String url})> _playing = {};

  /// Placeholders being re-asked, by meta id.
  final Map<String, _Pending> _pending = {};

  void init(StorageService storage) {
    _storage = storage;
    _debrid = DebridApi(storage);
    try {
      final j = jsonDecode(storage.getArchiveReadyWatch() ?? '{}') as Map;
      ready.value = {...(j['ready'] as List? ?? const []).cast<String>()};
      for (final p in (j['pending'] as List? ?? const [])) {
        final e = _Pending.fromJson(Map<String, dynamic>.from(p as Map));
        _pending[e.metaId] = e;
      }
    } catch (e) {
      debugPrint('ArchiveReadyWatch: bad saved state: $e');
    }
    fetching.value = {..._pending.keys};
    _schedule();
  }

  bool isReady(String metaId) => ready.value.contains(metaId);

  /// A Media Hub title is about to play [url] as [channelId]. Playing it
  /// again is what the tag asked for, so it's dropped.
  void register(String channelId,
      {required String metaId, required String url}) {
    _playing[channelId] = (metaId: metaId, url: url);
    final hadTag = ready.value.contains(metaId);
    if (_pending.remove(metaId) != null || hadTag) {
      if (hadTag) ready.value = {...ready.value}..remove(metaId);
      _save();
    }
  }

  /// [channelId] is a Media Hub title whose stream is [duration] long:
  /// too short to be the title.
  bool isClip(String channelId, Duration duration) =>
      _playing.containsKey(channelId) &&
      duration > Duration.zero &&
      duration < placeholderMax;

  /// Playback of [channelId] stopped; its whole length was [duration].
  /// True when it was a placeholder clip: the caller then keeps no resume
  /// point and reports nothing to Trakt/Simkl.
  bool ended(String channelId, Duration duration) {
    if (!isClip(channelId, duration)) {
      _playing.remove(channelId);
      return false;
    }
    final item = _playing.remove(channelId)!;
    _pending[item.metaId] =
        _Pending(metaId: item.metaId, url: item.url, since: DateTime.now());
    _save();
    _schedule();
    // The clip's own size, measured right away (the source is still busy).
    unawaited(_check());
    return true;
  }

  void _schedule() {
    if (_pending.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_interval, (_) => _check());
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      var changed = false;
      void markReady(_Pending p) {
        _pending.remove(p.metaId);
        ready.value = {...ready.value, p.metaId};
        changed = true;
      }

      // One account listing per round, only when a pending title has a hash.
      final debrid = _debrid;
      final torrents = debrid != null &&
              debrid.configured &&
              _pending.values.any((p) => DebridApi.infoHashIn(p.url) != null)
          ? await debrid.torrents()
          : const <String, bool>{};
      for (final p in [..._pending.values]) {
        if (DateTime.now().difference(p.since) > _giveUpAfter) {
          _pending.remove(p.metaId);
          changed = true;
          continue;
        }
        // The account knows this torrent: its word is final.
        final hash = DebridApi.infoHashIn(p.url);
        final done = hash == null ? null : torrents[hash];
        if (done != null) {
          if (done) markReady(p);
          continue;
        }
        final size = await _size(p.url);
        if (size == null) continue;
        final clip = p.clipBytes;
        if (clip == null) {
          p.clipBytes = size;
          changed = true;
        } else if (size >= _minReadyBytes && size >= clip * _growth) {
          markReady(p);
        }
      }
      if (changed) _save();
      _schedule();
    } finally {
      _checking = false;
    }
  }

  /// The full size of what [url] serves now (redirects followed), from a
  /// one-byte range request; null when it didn't say or failed.
  Future<int?> _size(String url) async {
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['Range'] = 'bytes=0-0';
      final r = await _client.send(req).timeout(const Duration(seconds: 20));
      // Only the headers are wanted; drop the body unread.
      unawaited(r.stream.listen(null).cancel());
      if (r.statusCode >= 400) return null;
      final range = r.headers['content-range'];
      final total = range == null
          ? null
          : int.tryParse(range.substring(range.lastIndexOf('/') + 1));
      return total ?? (r.statusCode == 200 ? r.contentLength : null);
    } catch (e) {
      debugPrint('ArchiveReadyWatch: check failed: $e');
      return null;
    }
  }

  void _save() {
    fetching.value = {..._pending.keys};
    _storage?.setArchiveReadyWatch(jsonEncode({
      'ready': ready.value.toList(),
      'pending': [for (final p in _pending.values) p.toJson()],
    }));
  }
}

class _Pending {
  _Pending({required this.metaId, required this.url, required this.since});

  final String metaId;
  final String url;
  final DateTime since;

  /// What the URL served while the source was still busy.
  int? clipBytes;

  Map<String, dynamic> toJson() => {
        'id': metaId,
        'url': url,
        'since': since.millisecondsSinceEpoch,
        if (clipBytes != null) 'clip': clipBytes,
      };

  factory _Pending.fromJson(Map<String, dynamic> j) => _Pending(
        metaId: j['id'] as String,
        url: j['url'] as String,
        since: DateTime.fromMillisecondsSinceEpoch(j['since'] as int),
      )..clipBytes = j['clip'] as int?;
}

/// [ready]'s value, notifying when [ready] or [fetching] changes.
class _Tags extends ChangeNotifier implements ValueListenable<Set<String>> {
  _Tags(this._ready, ValueNotifier<Set<String>> fetching) {
    _ready.addListener(notifyListeners);
    fetching.addListener(notifyListeners);
  }

  final ValueNotifier<Set<String>> _ready;

  @override
  Set<String> get value => _ready.value;
}
