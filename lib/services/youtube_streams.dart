import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/app_store.dart';
import '../utils/desktop_platform.dart';

/// A YouTube trailer as files our own player can open.
@immutable
class YouTubeTrailerStream {
  const YouTubeTrailerStream({this.hls, this.muxed, this.muxedHeight = 0});

  /// HLS playlist with picture and sound, up to 1080p (Vision Pro client).
  final Uri? hls;

  /// One mp4 with picture and sound, usually 360p (Android client).
  final Uri? muxed;
  final int muxedHeight;

  /// A full-screen trailer (title pages): the HD playlist first.
  Uri? get large => hls ?? muxed;

  /// A small card: the single file starts at once and is plenty for it.
  Uri? get small => muxed ?? hls;
}

/// Plays YouTube trailers in our own player instead of YouTube's web
/// player, which took 6-7 s to start on the Homatics (owner, 2026-11-26,
/// measured; "1 but not muted"). Asks YouTube's player API the way YouTube's
/// own apps do and hands back the trailer's file addresses. Adapted from
/// ARVIO's InAppYouTubeExtractor (Apache-2.0, github.com/ProdigyV21/ARVIO).
///
/// No API key: the player API answers without one. The Vision Pro client
/// needs YouTube's anonymous visitor id, read from `sw.js_data` and kept
/// 6 hours. This goes against YouTube's terms and breaks when YouTube
/// changes its apps: callers fall back to the official embed when it
/// returns null. Never on App Store builds or Apple TV ([supported]).
class YouTubeStreams {
  YouTubeStreams({http.Client? client, DateTime Function()? now})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  static final instance = YouTubeStreams();

  /// Android and computers only (owner: keep it out of the Apple builds).
  static bool get supported => !appStoreBuild && !isAppleTv;

  final http.Client _client;
  final DateTime Function() _now;
  final _cache = <String, ({DateTime until, YouTubeTrailerStream? stream})>{};
  final _pending = <String, Future<YouTubeTrailerStream?>>{};

  /// A card's file ([resolveSmall]) while the lookup still runs: the Android
  /// client's single file answers first (~250 ms; Vision Pro's playlist
  /// takes ~600-750 ms on the Homatics).
  final _early = <String, Completer<Uri?>>{};
  String? _visitor;
  DateTime? _visitorUntil;
  Future<String?>? _visitorLoad;

  static const _webAgent = 'Mozilla/5.0 (Linux; Android 12; Android TV) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

  /// The clients asked, all at once. Quest (ANDROID_VR) answers "Sign in to
  /// confirm you're not a bot" since 2026-11 and is left out.
  static const _clients = [
    (
      key: 'visionos',
      id: '101',
      version: '1.02',
      agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
      context: <String, Object>{
        'clientName': 'VISIONOS',
        'clientVersion': '1.02',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'platform': 'MOBILE',
      },
    ),
    (
      key: 'android',
      id: '3',
      version: '20.10.35',
      agent:
          'com.google.android.youtube/20.10.35 (Linux; U; Android 14; en_US) gzip',
      context: <String, Object>{
        'clientName': 'ANDROID',
        'clientVersion': '20.10.35',
        'osName': 'Android',
        'osVersion': '14',
        'platform': 'MOBILE',
        'androidSdkVersion': 34,
      },
    ),
    (
      key: 'ios',
      id: '5',
      version: '20.10.1',
      agent:
          'com.google.ios.youtube/20.10.1 (iPhone16,2; U; CPU iOS 17_4 like Mac OS X)',
      context: <String, Object>{
        'clientName': 'IOS',
        'clientVersion': '20.10.1',
        'deviceModel': 'iPhone16,2',
        'osName': 'iPhone',
        'osVersion': '17.4.0.21E219',
        'platform': 'MOBILE',
      },
    ),
  ];

  /// The trailer's files, or null (no stream, or YouTube refused us).
  /// Answers are kept 20 minutes (links last hours), "none" 2 minutes; one
  /// lookup per video at a time.
  Future<YouTubeTrailerStream?> resolve(String videoId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      return Future.value();
    }
    final cached = _cache[videoId];
    if (cached != null && cached.until.isAfter(_now())) {
      return Future.value(cached.stream);
    }
    return _pending.putIfAbsent(videoId, () async {
      final watch = Stopwatch()..start();
      final early = _early[videoId] = Completer<Uri?>();
      final outcome = <String>[];
      YouTubeTrailerStream? stream;
      try {
        stream = await _resolve(videoId, early, outcome)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        stream = null;
      }
      if (!early.isCompleted) early.complete(stream?.small);
      _early.remove(videoId);
      if (_cache.length >= 64) _cache.remove(_cache.keys.first);
      _cache[videoId] = (
        until: _now().add(stream == null ? const Duration(minutes: 2) : _keep),
        stream: stream,
      );
      debugPrint(stream == null
          ? 'Trailer: no YouTube stream for $videoId '
              '(${watch.elapsedMilliseconds} ms; ${outcome.join(', ')})'
          : 'Trailer: YouTube stream ${stream.hls != null ? 'hls' : ''}'
              '${stream.hls != null && stream.muxed != null ? '+' : ''}'
              '${stream.muxed != null ? 'mp4 ${stream.muxedHeight}p' : ''} '
              'in ${watch.elapsedMilliseconds} ms (${outcome.join(', ')})');
      return stream;
    }).whenComplete(() => _pending.remove(videoId));
  }

  static const _keep = Duration(minutes: 20);

  /// A small card's file ([YouTubeTrailerStream.small]): the single file as
  /// soon as one client has it, without waiting for the others.
  Future<Uri?> resolveSmall(String videoId) {
    final cached = _cache[videoId];
    if (cached != null && cached.until.isAfter(_now())) {
      return Future.value(cached.stream?.small);
    }
    final full = resolve(videoId);
    return _early[videoId]?.future ?? full.then((s) => s?.small);
  }

  /// A link that failed to play: ask YouTube again next time.
  void forget(String videoId) => _cache.remove(videoId);

  /// Starts the visitor id lookup early (the first trailer is then one
  /// round trip shorter).
  void warmUp() => unawaited(_visitorId());

  Future<YouTubeTrailerStream?> _resolve(
      String videoId, Completer<Uri?> early, List<String> outcome) async {
    final visitor = await _visitorId();
    Uri? hls;
    Uri? muxed;
    var muxedHeight = 0;
    await Future.wait([
      for (final c in _clients)
        _player(videoId, c, visitor).then((answer) {
          outcome.add('${c.key} ${answer.status}');
          final streaming = answer.data?['streamingData'];
          if (streaming is! Map) return;
          hls ??= _https(streaming['hlsManifestUrl']);
          for (final f in streaming['formats'] is List
              ? streaming['formats'] as List
              : const []) {
            if (f is! Map) continue;
            final url = _https(f['url']);
            final mime = '${f['mimeType'] ?? ''}';
            final height =
                f['height'] is num ? (f['height'] as num).toInt() : 0;
            // Ciphered formats (no url) need YouTube's player code: skipped.
            if (url == null || !mime.startsWith('video/mp4') || height > 1080) {
              continue;
            }
            if (height > muxedHeight) {
              muxed = url;
              muxedHeight = height;
            }
          }
          if (muxed != null && !early.isCompleted) early.complete(muxed);
        }, onError: (Object e) {
          outcome.add('${c.key} ${e.runtimeType}');
        })
    ]);
    if (hls == null && muxed == null) return null;
    return YouTubeTrailerStream(
        hls: hls, muxed: muxed, muxedHeight: muxedHeight);
  }

  static Uri? _https(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  Future<({String status, Map? data})> _player(
      String videoId,
      ({
        String key,
        String id,
        String version,
        String agent,
        Map<String, Object> context
      }) client,
      String? visitor) async {
    final response = await _client
        .post(
          Uri.https('www.youtube.com', '/youtubei/v1/player',
              {'prettyPrint': 'false'}),
          headers: {
            'content-type': 'application/json',
            'origin': 'https://www.youtube.com',
            'accept-language': 'en-US,en;q=0.9',
            'x-youtube-client-name': client.id,
            'x-youtube-client-version': client.version,
            'user-agent': client.agent,
            if (visitor != null) 'x-goog-visitor-id': visitor,
          },
          body: jsonEncode({
            'videoId': videoId,
            'contentCheckOk': true,
            'racyCheckOk': true,
            'context': {
              'client': {
                ...client.context,
                'hl': 'en',
                'gl': 'US',
                'userAgent': client.agent,
                if (visitor != null) 'visitorData': visitor,
              }
            },
            'playbackContext': {
              'contentPlaybackContext': {'html5Preference': 'HTML5_PREF_WANTS'}
            },
          }),
        )
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      return (status: 'HTTP ${response.statusCode}', data: null);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) return (status: 'no answer', data: null);
    final status = '${(data['playabilityStatus'] as Map?)?['status'] ?? 'OK'}';
    return (status: status, data: status == 'OK' ? data : null);
  }

  /// YouTube's anonymous visitor id (`sw.js_data`, the service worker's
  /// configuration): kept 6 hours, retried after a minute when missing.
  Future<String?> _visitorId() {
    final until = _visitorUntil;
    if (until != null && until.isAfter(_now())) return Future.value(_visitor);
    return _visitorLoad ??= () async {
      String? visitor;
      try {
        final response = await _client.get(
            Uri.https('www.youtube.com', '/sw.js_data', {'hl': 'en'}),
            headers: {
              'user-agent': _webAgent,
              'referer': 'https://www.youtube.com/sw.js',
              'accept-language': 'en-US,en;q=0.9',
            }).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          visitor =
              visitorFromServiceWorkerData(utf8.decode(response.bodyBytes));
        }
      } catch (_) {/* Most clients answer without one. */}
      _visitor = visitor;
      _visitorUntil = _now().add(visitor == null
          ? const Duration(minutes: 1)
          : const Duration(hours: 6));
      return visitor;
    }()
        .whenComplete(() => _visitorLoad = null);
  }

  /// `)]}'` then JSON: the visitor id is [0][2][0][0][13].
  @visibleForTesting
  static String? visitorFromServiceWorkerData(String body) {
    try {
      var text = body.trimLeft();
      if (text.startsWith(")]}'")) text = text.substring(4);
      final root = jsonDecode(text);
      final value = ((((root as List)[0] as List)[2] as List)[0] as List)[0];
      final visitor = (value as List)[13];
      return visitor is String && visitor.isNotEmpty ? visitor : null;
    } catch (_) {
      return null;
    }
  }
}
