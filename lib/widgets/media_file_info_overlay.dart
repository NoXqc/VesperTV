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
