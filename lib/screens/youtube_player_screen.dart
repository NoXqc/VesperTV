import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../models/media_file_info.dart';
import '../widgets/media_file_info_overlay.dart';
import '../models/youtube_embed.dart';
import '../services/device_memory_service.dart';
import '../widgets/youtube_platform_view.dart';

/// Official YouTube UI only. Deliberately separate from movie history, watched
/// positions, tracking, Ready-watch and the normal player's up-next queue.
class YouTubePlayerScreen extends StatefulWidget {
  const YouTubePlayerScreen(
      {super.key,
      required this.videoId,
      required this.title,
      this.viewBuilder,
      this.openExternal,
      this.television,
      this.mediaFileInfo});
  final MediaFileInfo? mediaFileInfo;
  final String videoId;
  final String title;
  final YouTubeViewBuilder? viewBuilder;
  final Future<bool> Function(Uri)? openExternal;
  final bool? television;
  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen>
    with WidgetsBindingObserver {
  late final _document = YouTubeEmbedDocument(widget.videoId);
  final _fileInfoRequests = ValueNotifier<int>(0);
  final _focus = FocusNode(debugLabel: 'youtube-remote');
  Future<void> Function(String)? _execute;
  Timer? _timeout;
  bool _loading = true, _externalTried = false, _tv = false;
  int? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timeout = Timer(const Duration(seconds: 20),
        () => _event({'type': 'error', 'code': -1}));
    _detectTv();
  }

  Future<void> _detectTv() async {
    final tv = widget.television ?? await DeviceTypeService.isTelevision();
    if (mounted) setState(() => _tv = tv);
  }

  Future<void> _command(String command) async {
    if (command == 'toggle' && widget.mediaFileInfo != null) {
      _fileInfoRequests.value++;
    }
    try {
      await _execute
          ?.call(YouTubeEmbedDocument.command(command))
          .timeout(const Duration(seconds: 2));
    } catch (_) {/* A closing WebView may already be disposed. */}
  }

  void _event(Object? value) {
    if (!mounted || value is! Map) return;
    if (value['type'] == 'ready') {
      _timeout?.cancel();
      setState(() => _loading = false);
      _focus.requestFocus();
    } else if (value['type'] == 'error' && value['code'] is num) {
      _timeout?.cancel();
      final code = (value['code'] as num).toInt();
      setState(() {
        _loading = false;
        _error = code;
      });
      unawaited(_command('pause'));
      if (YouTubeEmbedDocument.needsExternalPlayer(code) && !_externalTried) {
        _externalTried = true;
        unawaited(_external());
      }
    }
  }

  Future<void> _external() async {
    await _command('pause');
    try {
      await (widget.openExternal?.call(_document.externalUrl) ??
          launchUrl(_document.externalUrl,
              mode: LaunchMode.externalApplication));
    } catch (_) {/* The fallback button stays available. */}
  }

  void _close() {
    unawaited(_command('pause'));
    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_command('pause'));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    _fileInfoRequests.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if ([
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.browserBack
    ].contains(key)) {
      if (event is KeyDownEvent) _close();
      return KeyEventResult.handled;
    }
    if (_error != null) {
      if ([LogicalKeyboardKey.select, LogicalKeyboardKey.enter].contains(key)) {
        if (event is KeyDownEvent) unawaited(_external());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final action = key == LogicalKeyboardKey.arrowLeft
        ? 'back'
        : key == LogicalKeyboardKey.arrowRight
            ? 'forward'
            : [
                LogicalKeyboardKey.select,
                LogicalKeyboardKey.enter,
                LogicalKeyboardKey.numpadEnter,
                LogicalKeyboardKey.space,
                LogicalKeyboardKey.mediaPlayPause
              ].contains(key)
                ? 'toggle'
                : null;
    if (action == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent || action != 'toggle') {
      unawaited(_command(action));
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_command('pause'));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Focus(
                autofocus: true,
                focusNode: _focus,
                onKeyEvent: _key,
                child: Column(children: [
                  ExcludeFocus(
                      child: Row(children: [
                    IconButton(
                        tooltip: tr('Back'),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _close),
                    Expanded(
                        child: Text(widget.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 16)
                  ])),
                  Expanded(
                      child: _error != null
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                            _error == -1
                                                ? tr(
                                                    'YouTube playback needs Android System WebView or Microsoft Edge WebView2.')
                                                : tr(
                                                    'YouTube could not play this video ({code}).',
                                                    {'code': _error!}),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 16),
                                        ExcludeFocus(
                                            child: TextButton(
                                                onPressed: _external,
                                                child: Text(
                                                    tr('Open in YouTube')))),
                                      ])))
                          : Stack(children: [
                              Center(
                                  child: LayoutBuilder(
                                      builder: (context, limits) => SizedBox(
                                          width: limits.maxWidth,
                                          height: math.min(
                                              limits.maxHeight,
                                              math.max(200,
                                                  limits.maxWidth * 9 / 16)),
                                          child: ExcludeFocus(
                                              child: IgnorePointer(
                                                  ignoring: _tv,
                                                  child: widget.viewBuilder?.call(
                                                          _document,
                                                          (execute) =>
                                                              _execute =
                                                                  execute,
                                                          _event) ??
                                                      YouTubePlatformView(
                                                          document: _document,
                                                          onController:
                                                              (execute) =>
                                                                  _execute =
                                                                      execute,
                                                          onEvent: _event)))))),
                              if (widget.mediaFileInfo case final info?)
                                MediaFileInfoOverlay(
                                    info: info, requests: _fileInfoRequests),
                              if (_loading)
                                const Center(
                                    child: CircularProgressIndicator()),
                            ])),
                  ExcludeFocus(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        IconButton(
                            tooltip: tr('Back 10 seconds'),
                            onPressed: () => _command('back'),
                            icon: const Icon(Icons.replay_10)),
                        IconButton(
                            tooltip: tr('Play / pause'),
                            onPressed: () => _command('toggle'),
                            icon: const Icon(Icons.play_arrow_rounded)),
                        IconButton(
                            tooltip: tr('Forward 10 seconds'),
                            onPressed: () => _command('forward'),
                            icon: const Icon(Icons.forward_10)),
                      ])),
                ]))),
      ));
}
