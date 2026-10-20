import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';

/// "Press OK to type" for a text field on a TV box (remote, no touch).
///
/// A plain `TextField` raises the system keyboard the moment it *gains*
/// focus, so D-pad focus could never pass over one: on a Fire Stick the
/// keyboard took over the remote as soon as focus landed, and Back closing
/// it cleared Flutter's focus (nothing focused, remote "stuck"); a TCL
/// Android TV keyboard came up unusable on the Search screen (user reports,
/// 2026-10-19). Here the field is `readOnly` (no input connection, no
/// keyboard) until OK/Select is pressed on it; leaving the field closes it
/// again. If the keyboard closing left nothing focused, focus goes back to
/// the field so the remote keeps working. Phones and Windows get the plain
/// field ([builder] with `readOnly: false`).
///
/// The [builder] must pass `readOnly` and [focusNode] to its `TextField`.
class TvTextFieldGate extends StatefulWidget {
  const TvTextFieldGate({
    super.key,
    required this.focusNode,
    required this.builder,
  });

  final FocusNode focusNode;
  final Widget Function(BuildContext context, bool readOnly) builder;

  @override
  State<TvTextFieldGate> createState() => _TvTextFieldGateState();
}

class _TvTextFieldGateState extends State<TvTextFieldGate> {
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(TvTextFieldGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// The next field never opens its keyboard by itself, even after the
  /// keyboard's Next: Fire OS reports Back on its keyboard as that same
  /// Next, and keeping the keyboard up across fields made Back walk from
  /// field to field with the keyboard reopening each time (Fire Stick 4K
  /// Max, 2026-10-19). One more OK per field, never stuck.
  void _onFocus() {
    if (widget.focusNode.hasFocus || !_typing) return;
    setState(() => _typing = false);
    // Fire OS: Back on its keyboard drops Flutter's focus altogether.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = FocusManager.instance.primaryFocus;
      if (now == null || now is FocusScopeNode) {
        widget.focusNode.requestFocus();
      }
    });
  }

  /// A raw handler, not a `Focus.onKeyEvent`: it runs before anything in
  /// the field's own subtree can claim the key.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !widget.focusNode.hasFocus) return false;
    if (!context.read<AppPreferences>().isTelevision) return false;
    final key = event.logicalKey;
    final ok = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;
    if (_typing) {
      // Keyboard dismissed but the field kept focus (Formuler): OK raises
      // it again. Only the remote's own OK key: Fire OS turns Back on its
      // keyboard into a numpadEnter, which must not reopen it.
      if (!ok) return false;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return true;
    }
    if (!ok &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    // readOnly -> false while focused opens the input connection and shows
    // the keyboard (EditableText.didUpdateWidget).
    setState(() => _typing = true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppPreferences>().isTelevision) {
      return widget.builder(context, false);
    }
    return widget.builder(context, !_typing);
  }
}
