import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/app_preferences.dart';
import '../services/audio_delay.dart';

/// The Audio sync adjuster (player bar button and Settings > Playback >
/// Audio > Audio delay). One focus target: Left/Right change the delay by
/// [AudioDelay.stepMs] (holding repeats), OK or Back closes. Every change
/// applies at once to the playing stream, so the viewer lines it up by eye.
/// Touch: the - / + / Reset buttons, which never take D-pad focus.
Future<void> showAudioDelayAdjuster(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => const _AudioDelayDialog(),
  );
}

class _AudioDelayDialog extends StatefulWidget {
  const _AudioDelayDialog();

  @override
  State<_AudioDelayDialog> createState() => _AudioDelayDialogState();
}

class _AudioDelayDialogState extends State<_AudioDelayDialog> {
  void _change(int direction) {
    final prefs = context.read<AppPreferences>();
    prefs.setAudioDelayMs(AudioDelay.step(prefs.audioDelayMs, direction));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _change(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _change(1);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    // Up/Down stay here: nothing else in the dialog takes focus.
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _touchButton(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white10,
    shape: const CircleBorder(),
    child: InkWell(
      canRequestFocus: false,
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ms = context.watch<AppPreferences>().audioDelayMs;
    final accent = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: const Color(0xE61A1A1A),
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Audio sync'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _touchButton(Icons.remove, () => _change(-1)),
                    Expanded(
                      child: Text(
                        AudioDelay.label(ms),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ms == 0 ? Colors.white : accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _touchButton(Icons.add, () => _change(1)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    'Sound ahead of the picture? Press Right. Sound late? Press Left. OK when it matches.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (ms != 0)
                  TextButton(
                    style: ButtonStyle(
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                    onPressed: () =>
                        context.read<AppPreferences>().setAudioDelayMs(0),
                    child: Text(
                      tr('Reset'),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
