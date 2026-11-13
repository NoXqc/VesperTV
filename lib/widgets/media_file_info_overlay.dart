import '../utils/refined_finish.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/media_file_info.dart';

/// A brief, non-focusable cue triggered by OK or a video tap, not by playback.
class MediaFileInfoOverlay extends StatefulWidget {
  const MediaFileInfoOverlay(
      {super.key, required this.info, required this.requests, this.top = 16});
  final double top;
  final MediaFileInfo info;
  final ValueListenable<int> requests;

  @override
  State<MediaFileInfoOverlay> createState() => _MediaFileInfoOverlayState();
}

class _MediaFileInfoOverlayState extends State<MediaFileInfoOverlay> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.requests.addListener(_show);
  }

  void _show() {
    debugPrint('MediaFileInfo: sizeBytes=${widget.info.sizeBytes ?? 0}');
    _timer?.cancel();
    setState(() => _visible = true);
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didUpdateWidget(MediaFileInfoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      oldWidget.requests.removeListener(_show);
      widget.requests.addListener(_show);
    }
    if (oldWidget.info.source != widget.info.source ||
        oldWidget.info.sizeBytes != widget.info.sizeBytes) {
      _timer?.cancel();
      _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.requests.removeListener(_show);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        top: widget.top,
        right: 16,
        child: SafeArea(
          child: IgnorePointer(
            child: ExcludeSemantics(
              excluding: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth:
                          math.min(240, MediaQuery.sizeOf(context).width - 48)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: RefinedFinish.decorate(
                      context,
                      BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      focused: false),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr('Source: {source}',
                              {'source': widget.info.source}),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          widget.info.formattedSize == null
                              ? tr('File size unavailable')
                              : tr('File size: {size}',
                                  {'size': widget.info.formattedSize!}),
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Top-left show / episode (or movie) title, shown with [MediaFileInfoOverlay]
/// on the same OK requests and for the same 5 seconds.
class MediaTitleCue extends StatefulWidget {
  /// Show name over the episode name (its "S01E02 - " stays in the bottom
  /// bar), or the movie title alone.
  static MediaTitleCue forChannel(
      {Key? key,
      required String? seriesName,
      required String name,
      required ValueListenable<int> requests,
      double top = 16}) {
    final series = seriesName?.trim();
    if (series == null || series.isEmpty) {
      return MediaTitleCue(
          key: key, title: name.trim(), requests: requests, top: top);
    }
    final episode = name
        .replaceFirst(
            RegExp(r'^\s*S\d+\s*E\d+\s*(?:[-:–—.]\s*)?', caseSensitive: false),
            '')
        .trim();
    return MediaTitleCue(
        key: key,
        title: series,
        subtitle: episode.isEmpty || episode == series ? null : episode,
        requests: requests,
        top: top);
  }

  const MediaTitleCue(
      {super.key,
      required this.title,
      this.subtitle,
      required this.requests,
      this.top = 16});
  final String title;
  final String? subtitle;
  final double top;
  final ValueListenable<int> requests;

  @override
  State<MediaTitleCue> createState() => _MediaTitleCueState();
}

class _MediaTitleCueState extends State<MediaTitleCue> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.requests.addListener(_show);
  }

  void _show() {
    _timer?.cancel();
    setState(() => _visible = true);
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void didUpdateWidget(MediaTitleCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      oldWidget.requests.removeListener(_show);
      widget.requests.addListener(_show);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.requests.removeListener(_show);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.subtitle;
    return Positioned(
      top: widget.top,
      left: 24,
      child: SafeArea(
        child: IgnorePointer(
          child: ExcludeSemantics(
            excluding: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.55),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            shadows: _shadows)),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              shadows: _shadows)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _shadows = [
    Shadow(color: Colors.black, blurRadius: 8),
    Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
  ];
}
