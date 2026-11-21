// Apple TV player smoke test (tvOS workflow only, `-t lib/tvos_player_smoke.dart`).
//
// Not part of the app: plays three public test files through media_kit on the
// Apple TV simulator, one after the other, and prints the player's state every
// 2 s, so CI shows whether the tvOS libmpv (third_party/media_kit_video_tvos)
// loads, decodes what Apple's player can't (raw .ts, MKV) and draws. The
// workflow takes screenshots while it runs. dev-notes/apple-tv.md.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _samples = <(String, String)>[
  ('HLS', 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
  ('TS', 'https://filesamples.com/samples/video/ts/sample_640x360.ts'),
  (
    'MKV',
    'https://test-videos.co.uk/vids/bigbuckbunny/mkv/1080/'
        'Big_Buck_Bunny_1080_10s_1MB.mkv'
  ),
];

/// Seconds each sample plays before the next one.
const _perSample = 25;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized(libmpv: 'Mpv.framework/Mpv');
    debugPrint('Smoke: libmpv loaded');
  } catch (e) {
    debugPrint('Smoke: libmpv NOT loaded: $e');
    runApp(_Message('libmpv not loaded\n$e'));
    return;
  }
  runApp(const _SmokeApp());
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(text,
                style: const TextStyle(color: Colors.red, fontSize: 28)),
          ),
        ),
      );
}

class _SmokeApp extends StatefulWidget {
  const _SmokeApp();

  @override
  State<_SmokeApp> createState() => _SmokeAppState();
}

class _SmokeAppState extends State<_SmokeApp> {
  final _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn));
  late final _controller = VideoController(_player);
  int _index = 0;
  String _error = '';
  Timer? _status;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    // As the app (desktop_stream_setup.dart): mpv can't create its disk
    // cache inside the sandbox ("Failed to create file cache", then no
    // streams for .ts / MKV); the demuxer cache stays in memory.
    unawaited(
        (_player.platform as NativePlayer).setProperty('cache-on-disk', 'no'));
    _player.stream.log.listen((l) =>
        debugPrint('Smoke mpv: [${l.prefix}] ${l.level}: ${l.text.trim()}'));
    _player.stream.error.listen((e) {
      debugPrint('Smoke: ${_samples[_index].$1} error: $e');
      setState(() => _error = e);
    });
    _status = Timer.periodic(const Duration(seconds: 2), (_) {
      final s = _player.state;
      debugPrint('Smoke: ${_samples[_index].$1} playing=${s.playing} '
          'buffering=${s.buffering} position=${s.position.inMilliseconds}ms '
          'size=${s.width}x${s.height} '
          'video=${s.track.video.id} audio=${s.track.audio.id}');
    });
    _play(0);
  }

  void _play(int index) {
    _index = index;
    _error = '';
    final (name, url) = _samples[index];
    debugPrint('Smoke: open $name $url');
    unawaited(_player.open(Media(url)));
    if (index > 0) setState(() {});
    _next?.cancel();
    if (index + 1 < _samples.length) {
      _next =
          Timer(const Duration(seconds: _perSample), () => _play(index + 1));
    } else {
      _next = Timer(const Duration(seconds: _perSample), () {
        debugPrint('Smoke: done');
      });
    }
  }

  @override
  void dispose() {
    _status?.cancel();
    _next?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child:
                    Video(controller: _controller, controls: NoVideoControls),
              ),
              Positioned(
                left: 40,
                top: 30,
                child: Text(
                  'media_kit on Apple TV: ${_samples[_index].$1}'
                  '${_error.isEmpty ? '' : '\n$_error'}',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 32,
                      backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
}
