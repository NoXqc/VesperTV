import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mv;
import 'package:provider/provider.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../models/archive_models.dart';
import '../models/trailer.dart';
import '../models/youtube_embed.dart';
import '../services/archive_service.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import '../services/trailer_service.dart';
import '../utils/route_observer.dart';
import 'youtube_platform_view.dart';
import 'detail_header.dart';

/// One opt-in preview per detail route. Never uses the main playback service,
/// history, tracking, resume positions or the episode queue for its trailer.
class DetailTrailer extends StatefulWidget {
  const DetailTrailer(
      {super.key,
      required this.enabled,
      required this.request,
      required this.child,
      this.resolve,
      this.youtubeBuilder});
  final bool enabled;
  final TrailerRequest request;
  final Widget child;
  final Future<Uri?> Function(TrailerRequest, List<ArchiveSource>)? resolve;
  final YouTubeViewBuilder? youtubeBuilder;

  @override
  State<DetailTrailer> createState() => DetailTrailerState();
}

class DetailTrailerState extends State<DetailTrailer>
    with RouteAware, WidgetsBindingObserver {
  var _playerKey = GlobalKey<_PreviewState>();
  PageRoute<void>? _route;
  Uri? _uri;
  bool _picture = false;
  Future<void>? _pausing;
  bool _foreground = true, _visible = true, _stopped = false, _finished = false;
  int _generation = 0;
  String? _signature;
  Future<void> _closing = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<ArchiveService?>();
    final route = ModalRoute.of(context);
    if (route != _route && route is PageRoute<void>) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
    _visible = route?.isCurrent ?? true;
    _schedule();
  }

  @override
  void didUpdateWidget(DetailTrailer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.cacheKey != widget.request.cacheKey) {
      _finished = false;
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.request.cacheKey != widget.request.cacheKey) {
      ++_generation;
    }
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _closePlayer() {
    final player = _playerKey.currentState;
    return _closing = _closing.then((_) => player?.close());
  }

  /// Awaited before movie/episode/manual-trailer startup, including stream
  /// pickers. Route notifications alone arrive too late for await play().
  Future<void> stop() async {
    _stopped = true;
    ++_generation;
    final closing = _closePlayer();
    if (mounted) setState(() => _uri = null);
    await closing;
    try {
      await _pausing;
    } catch (_) {/* A failed live pause must not prevent the selected movie. */}
  }

  Future<void> _refresh() async {
    final sources = context.read<ArchiveService?>()?.enabledSources ??
        const <ArchiveSource>[];
    final allowed =
        widget.enabled && _foreground && _visible && !_stopped && !_finished;
    final signature =
        '$allowed:${widget.request.cacheKey}:${sources.map((s) => s.key).join('|')}';
    if (_signature == signature) return;
    _signature = signature;
    final generation = ++_generation;
    final closing = _closePlayer();
    setState(() {
      _uri = null;
      _picture = false;
    });
    await closing;
    if (!allowed || !mounted || generation != _generation) return;
    try {
      final uri = await (widget.resolve?.call(widget.request, sources) ??
          TrailerService.instance.resolve(widget.request, addons: sources));
      if (!mounted || generation != _generation || uri == null) return;
      // Pause an existing channel before using another decoder. As with the
      // manual Trailer action, opening details never starts/resumes live TV.
      if (Platform.isWindows) {
        _pausing = DesktopMiniPlayer.instance.controller?.player.pause();
      } else {
        _pausing = context.read<PlaybackService?>()?.controller?.pause();
      }
      await _pausing;
      if (mounted && generation == _generation && (_route?.isCurrent ?? true)) {
        setState(() {
          _playerKey = GlobalKey<_PreviewState>();
          _uri = uri;
        });
      }
    } catch (_) {
      /* Keep the artwork; never launch another app automatically. */
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    unawaited(_refresh());
  }

  void _visibility(bool visible) {
    _visible = visible;
    if (mounted) unawaited(_refresh());
  }

  @override
  void didPushNext() => _visibility(false);
  @override
  void didPopNext() => _visibility(true);
  @override
  void didPop() => _visibility(false);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) unawaited(_refresh());
  }

  @override
  void dispose() {
    ++_generation;
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_closePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = _uri;
    if (uri == null) return widget.child;
    final youtube = TrailerLinks.videoId(uri.toString()) != null;
    final preview = _Preview(
        key: _playerKey,
        uri: uri,
        onFinished: _finish,
        onPlaying: () {
          if (mounted) setState(() => _picture = true);
        },
        youtubeBuilder: widget.youtubeBuilder);
    if (!youtube) {
      return Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: preview),
        DetailTrailerBackdrop(playing: _picture, child: widget.child),
      ]);
    }
    // YouTube's official player must stay visible, at least 200x200, with no
    // details/gradients over its controls. Direct videos can be full backdrops.
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 900 && c.maxHeight >= 300) {
        return Row(children: [
          Expanded(flex: 3, child: widget.child),
          Expanded(
              flex: 2,
              child: Center(
                  child: SizedBox(
                      width: c.maxWidth * .4,
                      height:
                          (c.maxWidth * .4 * 9 / 16).clamp(200, c.maxHeight),
                      child: preview))),
        ]);
      }
      if (c.maxHeight < 400 || c.maxWidth < 200) return widget.child;
      return Column(children: [
        SizedBox(
            width: double.infinity,
            height: (c.maxWidth * 9 / 16).clamp(200, c.maxHeight * .5),
            child: preview),
        Expanded(child: widget.child),
      ]);
    });
  }
}

class _Preview extends StatefulWidget {
  const _Preview(
      {super.key,
      required this.uri,
      required this.onFinished,
      required this.onPlaying,
      this.youtubeBuilder});
  final Uri uri;
  final VoidCallback onFinished;
  final VoidCallback onPlaying;
  final YouTubeViewBuilder? youtubeBuilder;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  VideoPlayerHdrController? _android;
  mk.Player? _windows;
  mv.VideoController? _windowsVideo;
  Future<void> Function(String)? _execute;
  StreamSubscription<bool>? _completed;
  StreamSubscription<String>? _errors;
  Timer? _timeout;
  Future<void>? _closed;
  late final String? _youtube = TrailerLinks.videoId(widget.uri.toString());
  late final YouTubeEmbedDocument? _document =
      _youtube == null ? null : YouTubeEmbedDocument(_youtube, muted: true);
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), widget.onFinished);
    if (_youtube == null) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final player = _windows = mk.Player();
        _windowsVideo = mv.VideoController(player);
        _completed = player.stream.completed.listen((done) {
          if (done && _closed == null) widget.onFinished();
        });
        _errors = player.stream.error.listen((_) {
          if (_closed == null) widget.onFinished();
        });
        await player.setVolume(0);
        if (_closed != null) return;
        await player.open(mk.Media(widget.uri.toString()));
      } else {
        final controller = _android = VideoPlayerHdrController.networkUrl(
            widget.uri,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
        await controller.initialize(viewType: VideoViewType.textureView);
        if (_closed != null) return;
        await controller.setVolume(0);
        if (_closed != null) return;
        controller.addListener(_androidChanged);
        await controller.play();
      }
      if (!mounted || _closed != null) return;
      _timeout?.cancel();
      setState(() => _ready = true);
      widget.onPlaying();
    } catch (_) {
      if (mounted && _closed == null) widget.onFinished();
    }
  }

  void _androidChanged() {
    final value = _android!.value;
    if (_closed == null && (value.hasError || value.isCompleted)) {
      widget.onFinished();
    }
  }

  void _event(Object? event) {
    if (!mounted || _closed != null || event is! Map) return;
    if (event['type'] == 'playing') _timeout?.cancel();
    if (event['type'] == 'error' || event['type'] == 'ended') {
      widget.onFinished();
    }
  }

  Future<void> close() =>
      _closed ??= _disposePlayers().catchError((Object _) {});
  Future<void> _disposePlayers() async {
    _timeout?.cancel();
    try {
      await _execute
          ?.call(YouTubeEmbedDocument.command('pause'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {/* Closing view. */}
    await _completed?.cancel();
    await _errors?.cancel();
    _android?.removeListener(_androidChanged);
    // A failed native create can leave the plugin's creation future pending.
    // Late initialization is already guarded by _closed; never hang Play on it.
    await _android?.dispose().timeout(const Duration(seconds: 3));
    await _windows?.dispose().timeout(const Duration(seconds: 3));
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_document case final document?) {
      return (widget.youtubeBuilder ??
              (doc, controller, event) => YouTubePlatformView(
                  document: doc, onController: controller, onEvent: event))(
          document, (execute) => _execute = execute, _event);
    }
    if (!_ready) return const SizedBox.shrink();
    final Widget video;
    if (_windowsVideo case final controller?) {
      video = mv.Video(
          controller: controller,
          controls: mv.NoVideoControls,
          fit: BoxFit.cover);
    } else {
      final controller = _android!;
      video = FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayerHdr(controller)));
    }
    return IgnorePointer(child: ExcludeFocus(child: video));
  }
}
