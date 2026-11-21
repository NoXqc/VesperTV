import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../screens/desktop_player_screen.dart';
import '../services/app_preferences.dart';
import '../services/desktop_mini_player.dart';
import 'live_resume_hint.dart';
import '../l10n/l10n.dart';

/// Windows equivalent of `LiveResumeHint` — same "small reminder pill,
/// tap to resume fullscreen" idea, driven by `DesktopMiniPlayer` instead
/// of `PlaybackService` (see `DesktopPlayerScreen`'s own doc comment for
/// why those stay separate). No hold-key gesture here at all, unlike
/// `LiveResumeHint`'s hold-Right — a mouse click already does the job
/// that needs an extra "hold" gesture on a D-pad remote (where a plain
/// press is already claimed for normal navigation); there's no
/// equivalent conflict here since this pill is its own clickable target.
/// A TV remote (Apple TV) gets Android's: hold Right from anywhere, and
/// the pill says so (owner, 2026-11-20: both TV apps the same).
///
/// Lives directly above `MaterialApp`'s `Navigator` (see main.dart's
/// `builder`), same reason as `LiveResumeHint`: works from any screen,
/// not just whichever one happened to be open when the channel was
/// minimized.
class DesktopLiveResumeHint extends StatefulWidget {
  const DesktopLiveResumeHint({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<DesktopLiveResumeHint> createState() => _DesktopLiveResumeHintState();
}

class _DesktopLiveResumeHintState extends State<DesktopLiveResumeHint> {
  // LiveResumeHint's hold.
  static const _holdDuration = Duration(milliseconds: 1200);
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    DesktopMiniPlayer.instance.channel.addListener(_onChanged);
    LiveResumeHint.hiddenBy.addListener(_onHiddenChanged);
    LiveResumeHint.pillEnabled.addListener(_onHiddenChanged);
    FocusManager.instance.addEarlyKeyEventHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    DesktopMiniPlayer.instance.channel.removeListener(_onChanged);
    LiveResumeHint.hiddenBy.removeListener(_onHiddenChanged);
    LiveResumeHint.pillEnabled.removeListener(_onHiddenChanged);
    FocusManager.instance.removeEarlyKeyEventHandler(_handleGlobalKey);
    _holdTimer?.cancel();
    super.dispose();
  }

  bool get _remote => context.read<AppPreferences>().isTelevision;

  bool get _textFieldFocused =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  /// A remote: LiveResumeHint's hold Right (see its doc comment). The
  /// press itself goes on to the screen; only the repeats of a held key
  /// are kept back.
  KeyEventResult _handleGlobalKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowRight ||
        !_remote ||
        DesktopMiniPlayer.instance.channel.value == null ||
        _textFieldFocused) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _holdTimer?.cancel();
      _holdTimer = Timer(_holdDuration, () {
        _holdTimer = null;
        if (mounted && !_textFieldFocused) _resume();
      });
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    _holdTimer?.cancel();
    _holdTimer = null;
    return KeyEventResult.ignored;
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onHiddenChanged() =>
      rebuildResumeHintSafely(this, () => setState(() {}));

  void _resume() {
    final channel = DesktopMiniPlayer.instance.channel.value;
    final session = DesktopMiniPlayer.instance.take();
    if (channel == null || session == null) return;
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DesktopPlayerScreen(
          channel: channel,
          existingPlayer: session.$1,
          existingController: session.$2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Channel? channel = DesktopMiniPlayer.instance.channel.value;

    // Always Positioned, shown or not — see LiveResumeHint's identical
    // comment: a bare non-Positioned child here collapses this whole
    // Stack (the Navigator painted alongside it included) to 0x0.
    if (channel == null || !LiveResumeHint.pillAllowed) {
      return const Positioned(
          bottom: 24, left: 0, right: 0, child: SizedBox.shrink());
    }
    final remote = _remote;

    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        // Transparent Material: see LiveResumeHint — without it the Text
        // falls back to Flutter's yellow-underline debug style.
        child: Material(
          type: MaterialType.transparency,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _resume,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Colors.redAccent, size: 10),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          if (remote)
                            // LiveResumeHint's line: the D-pad's Right.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr('Hold '),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                                const Icon(Icons.keyboard_arrow_right,
                                    color: Colors.white70, size: 14),
                                Text(
                                  tr(' to resume'),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            )
                          else
                            Text(
                              tr('Click to resume'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (!remote) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.fullscreen,
                          color: Colors.white70, size: 18),
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
}
