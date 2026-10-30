import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../l10n/l10n.dart';
import '../services/skip_segments.dart';
import '../services/watch_tracker.dart';

/// Follows the playing episode's position and says which intro / recap /
/// credits range it's in ([visible]). Like Nuvio: the button shows when the
/// range starts, hides itself after [autoHide], and comes back while the
/// player bar is showing. Notifies only when that answer changes, not on
/// every position tick.
class SkipSegmentWatcher extends ChangeNotifier {
  SkipSegmentWatcher({SkipSegments? source})
      : _source = source ?? SkipSegments.instance;

  final SkipSegments _source;
  static const autoHide = Duration(seconds: 10);

  /// Not worth a button with less than this left of the range.
  static const _minLeft = Duration(milliseconds: 1500);

  VideoPlayerHdrController? _controller;
  String? _channelId;
  bool _requested = false;
  List<SkipSegment> _segments = const [];
  SkipSegment? _active;
  SkipSegment? _shownFor;
  final Set<SkipSegment> _skipped = {};
  bool _autoHidden = false;
  Timer? _hideTimer;

  /// The range to offer now, or null ([controlsVisible]: the player bar is
  /// showing, which brings an auto-hidden button back).
  SkipSegment? visibleWith(bool controlsVisible) =>
      _active != null && (!_autoHidden || controlsVisible) ? _active : null;

  /// For change checks: the answer with the bar hidden or shown.
  (SkipSegment?, SkipSegment?) get _state =>
      (visibleWith(false), visibleWith(true));

  /// Called on every player build: the playing controller and channel.
  /// Off ([enabled] false), a live channel or a channel without episode ids
  /// = no button.
  void attach(VideoPlayerHdrController? controller, String channelId,
      {required bool enabled,
      required bool episodeCandidate,
      String? tmdbKey}) {
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onTick);
      _controller = controller;
      controller?.addListener(_onTick);
    }
    if (channelId != _channelId) {
      // Called from the player's build: no notify (the button below is
      // rebuilt in the same pass anyway).
      _channelId = channelId;
      _requested = false;
      _segments = const [];
      _skipped.clear();
      _shownFor = null;
      _active = null;
      _hideTimer?.cancel();
    }
    if (_requested || !enabled || !episodeCandidate) return;
    final item = WatchTracker.instance.itemFor(channelId);
    // Ids are registered when the series page / Media Hub starts the
    // episode; until then later builds try again.
    if (item == null || !item.isEpisode) return;
    _requested = true;
    unawaited(_source
        .forEpisode(
            imdb: item.imdb,
            tmdb: item.tmdb,
            season: item.season!,
            episode: item.episode!,
            tmdbKey: tmdbKey)
        .then((segments) {
      if (_channelId != channelId) return;
      _segments = segments;
      _onTick();
    }));
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || _segments.isEmpty) return _setActive(null);
    final position = value.position;
    final duration = value.duration;
    SkipSegment? found;
    for (final s in _segments) {
      final end =
          duration > Duration.zero && s.end > duration ? duration : s.end;
      if (!_skipped.contains(s) &&
          s.contains(position) &&
          end - position > _minLeft) {
        found = s;
        break;
      }
    }
    _setActive(found);
  }

  void _setActive(SkipSegment? segment) {
    if (segment == _active) return;
    final before = _state;
    _active = segment;
    if (segment != null && segment != _shownFor) {
      // A new range (or the same one entered again after leaving it).
      _shownFor = segment;
      _autoHidden = false;
      _hideTimer?.cancel();
      _hideTimer = Timer(autoHide, () {
        final was = _state;
        _autoHidden = true;
        if (_state != was) notifyListeners();
      });
    } else if (segment == null) {
      _shownFor = null;
      _hideTimer?.cancel();
    }
    if (_state != before) notifyListeners();
  }

  /// Jumps past [segment]: credits with a next episode queued play it
  /// ([playNext]); otherwise the end of the range.
  Future<void> skip(SkipSegment segment, {VoidCallback? playNext}) async {
    final controller = _controller;
    if (controller == null) return;
    if (segment.kind == SkipKind.outro && playNext != null) {
      _skipped.add(segment);
      _setActive(null);
      playNext();
      return;
    }
    final duration = controller.value.duration;
    var target = segment.end;
    if (duration > Duration.zero &&
        target > duration - const Duration(milliseconds: 500)) {
      target = duration - const Duration(milliseconds: 500);
    }
    // Never offered again for this episode (the seek lands a moment later).
    _skipped.add(segment);
    _setActive(null);
    await controller.seekTo(target);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    super.dispose();
  }
}

/// The white "Skip intro ⏭" pill above the player bar. Always returns a
/// `Positioned` (it sits straight in the player's Stack; see `_UpNextBubble`
/// for why a bare widget there collapsed the whole player). A TV remote
/// uses OK (the player maps it while this shows), a touch screen taps it.
class SkipSegmentButton extends StatelessWidget {
  const SkipSegmentButton({
    super.key,
    required this.watcher,
    required this.controlsVisible,
    required this.hasNext,
    required this.showOkHint,
    required this.onSkip,
  });

  final SkipSegmentWatcher watcher;
  final bool controlsVisible;
  final bool hasNext;
  final bool showOkHint;
  final ValueChanged<SkipSegment> onSkip;

  static const _hidden = Positioned(
      right: 24, bottom: 200, width: 0, height: 0, child: SizedBox.shrink());

  static String label(SkipKind kind, bool hasNext) => switch (kind) {
        SkipKind.intro => tr('Skip intro'),
        SkipKind.recap => tr('Skip recap'),
        SkipKind.outro => hasNext ? tr('Next episode') : tr('Skip credits'),
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: watcher,
      builder: (context, _) {
        final segment = watcher.visibleWith(controlsVisible);
        if (segment == null) return _hidden;
        return Positioned(
          right: 24,
          // Above the player bar and the Up Next card.
          bottom: 200,
          child: Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const StadiumBorder(),
              canRequestFocus: false,
              onTap: () => onSkip(segment),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label(segment.kind, hasNext),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.skip_next_rounded,
                        color: Colors.black, size: 24),
                    if (showOkHint) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.black45),
                        ),
                        child: Text(tr('OK'),
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
