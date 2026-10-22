import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../services/app_preferences.dart';
import '../services/playback_service.dart';
import '../services/storage_service.dart';
import '../services/subtitle_tracks.dart';

/// Draws the current subtitle over the fullscreen video (Android): the
/// selected embedded track's cues, or a downloaded add-on file (the
/// controller's caption, see SubtitleTracks.useExternal). Nothing shows
/// until something is picked in the player's Subtitles button — the native
/// side starts every player with text off.
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({super.key, required this.controller});

  final VideoPlayerHdrController controller;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  StreamSubscription<SubtitleCueEvent>? _sub;
  String _cue = '';
  bool _closedCaptions = false;
  Timer? _pendingClear;

  // Broadcast captions can briefly clear between paint/roll-up commands.
  // Hold only CEA-608/708 blanks, never timed VOD or downloaded subtitles.
  static const _blankGrace = Duration(seconds: 1);

  int get _playerId => SubtitleTracks.playerIdOf(widget.controller);

  @override
  void initState() {
    super.initState();
    _sub = SubtitleTracks.cues.listen(_onCue);
    SubtitleTracks.externalFor.addListener(_onExternalChanged);
    _applySeriesChoice();
  }

  @override
  void didUpdateWidget(SubtitleOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _pendingClear?.cancel();
      _pendingClear = null;
      _cue = '';
      _closedCaptions = false;
      _applySeriesChoice();
    }
  }

  void _onExternalChanged() {
    if (SubtitleTracks.externalFor.value != _playerId) return;
    _clear();
  }

  void _clear() {
    _pendingClear?.cancel();
    _pendingClear = null;
    if (mounted) {
      setState(() {
        _cue = '';
        _closedCaptions = false;
      });
    }
  }

  void _onCue(SubtitleCueEvent event) {
    if (!mounted || event.playerId != _playerId) return;
    if (event.reset || !event.enabled) {
      _clear();
      return;
    }
    if (SubtitleTracks.externalFor.value == _playerId) return;
    final text = event.text.replaceAll(_tags, '').trim();
    if (text.isEmpty &&
        event.closedCaptions &&
        _cue.isNotEmpty &&
        _closedCaptions) {
      // Repeated blanks must not keep extending stale captions indefinitely.
      _pendingClear ??= Timer(_blankGrace, _clear);
      return;
    }
    _pendingClear?.cancel();
    _pendingClear = null;
    if (text != _cue || event.closedCaptions != _closedCaptions) {
      setState(() {
        _cue = text;
        _closedCaptions = event.closedCaptions;
      });
    }
  }

  /// A new episode's player: the subtitles picked earlier in this series
  /// come back on (SubtitleTracks.applyForSeries). Movies never do.
  void _applySeriesChoice() {
    final channel = context.read<PlaybackService>().currentChannel;
    if (channel == null) return;
    unawaited(SubtitleTracks.applyForSeries(
            context.read<StorageService>(), channel, widget.controller)
        .catchError((_) {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pendingClear?.cancel();
    SubtitleTracks.externalFor.removeListener(_onExternalChanged);
    super.dispose();
  }

  // SRT files carry <i>/<b>/<font> tags and ASS-style {\an8} codes.
  static final _tags = RegExp(r'<[^>]+>|\{\\[^}]*\}');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: SubtitleTracks.externalFor,
      builder: (context, external, _) {
        if (external != _playerId) return _box(context, _cue);
        return ValueListenableBuilder<VideoPlayerHdrValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) => _box(context, value.caption.text),
        );
      },
    );
  }

  Widget _box(BuildContext context, String raw) {
    final text = raw.replaceAll(_tags, '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final scale = context.watch<AppPreferences>().subtitleScale;
    final caption = Text(
      text,
      textAlign: TextAlign.center,
      // Broadcast snapshots already contain their row breaks. Wrapping a
      // 32-column CEA-608 row adds lines the broadcaster never intended.
      softWrap: !_closedCaptions,
      style: TextStyle(
        color: Colors.white,
        fontSize: (size.shortestSide / 22).clamp(16.0, 30.0) * scale,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    );
    return Center(
      child: Container(
        constraints: BoxConstraints(
            maxWidth: size.width * (_closedCaptions ? 0.9 : 0.8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        // Fit the complete CC snapshot to the actual available width,
        // including narrow parents and accessibility scaling. Only shrink
        // when necessary; keep the chosen size whenever the rows already fit.
        // Timed movie/file subtitles retain normal word wrapping.
        child: _closedCaptions
            ? FittedBox(fit: BoxFit.scaleDown, child: caption)
            : caption,
      ),
    );
  }
}
