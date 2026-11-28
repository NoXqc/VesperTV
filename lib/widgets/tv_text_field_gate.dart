import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import '../services/device_defaults.dart';
import '../utils/desktop_platform.dart';

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
/// While editing, arrows belong to the field/IME. A disappearing keyboard
/// inset, focus loss, or Back delivered to the app ends editing. Overlay
/// keyboards may consume the first Back without reporting dismissal; another
/// Back then returns the field to navigation without closing its page.
/// A [FocusNode] created and disposed with this widget, for a
/// [TvTextFieldGate] in a dialog or a picker that has no node of its own:
/// `FocusNodeOwner(builder: (_, node) => TvTextFieldGate(focusNode: node, …))`.
class FocusNodeOwner extends StatefulWidget {
  const FocusNodeOwner({super.key, required this.builder});

  final Widget Function(BuildContext context, FocusNode node) builder;

  @override
  State<FocusNodeOwner> createState() => _FocusNodeOwnerState();
}

class _FocusNodeOwnerState extends State<FocusNodeOwner> {
  final _node = FocusNode(debugLabel: 'gated-text-field');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _node);
}

class TvTextFieldGate extends StatefulWidget {
  const TvTextFieldGate({
    super.key,
    required this.focusNode,
    required this.builder,
  });

  final FocusNode focusNode;
  final Widget Function(BuildContext context, bool readOnly) builder;

  static final _editors = <FocusNode, _TvTextFieldGateState>{};

  /// Screen-level shortcuts must leave arrows with an actively edited field.
  /// Never on Apple TV ([_fullScreenKeyboard]): an arrow only reaches the app
  /// once its keyboard is gone. Screens ask this from their own key handlers,
  /// some of which run before the gate's ([_TvTextFieldGateState._onKey]
  /// ends typing): Add Playlist's fields, the Multiview picker, channel
  /// linking, EPG matching. So the first Down after the keyboard is theirs.
  static bool isEditing(FocusNode? node) =>
      !_fullScreenKeyboard && (_editors[node]?._typing ?? false);

  /// Apple TV: the system keyboard is a full-screen page that has the remote
  /// to itself, and Menu closes it without telling the app (no inset, no
  /// Back, the input connection stays open). So an arrow that reaches the
  /// field means that keyboard is gone: typing ends and the arrow moves
  /// focus. Before this, Down moved the field's cursor: Search's results
  /// could never be reached (Mycue66), and Add Playlist's Xtream fields
  /// needed Menu before Down (cleverclogs17), TestFlight 954, 2026-11-22.
  /// Not on Android: Gboard and other overlay keyboards forward cursor
  /// arrows while they are up.
  @visibleForTesting
  static bool? debugFullScreenKeyboard;

  static bool get _fullScreenKeyboard => debugFullScreenKeyboard ?? isAppleTv;

  /// Closes [node]'s keyboard and leaves the field focused, read-only (a
  /// search key with nothing to move on to).
  static void stopEditing(FocusNode node) => _editors[node]?._stopTyping();

  @override
  State<TvTextFieldGate> createState() => _TvTextFieldGateState();
}

/// Navigation shortcuts yield to text editing, including zero-inset TV IMEs.
class TvNavigationActivator extends SingleActivator {
  const TvNavigationActivator(super.trigger);

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      !TvTextFieldGate.isEditing(FocusManager.instance.primaryFocus) &&
      super.accepts(event, state);
}

class _TvTextFieldGateState extends State<TvTextFieldGate>
    with WidgetsBindingObserver {
  bool _typing = false;

  /// The keyboard took screen space while typing (it reports an inset).
  bool _keyboardShown = false;

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool get _canRecover =>
      mounted && _foreground && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    TvTextFieldGate._editors[widget.focusNode] = this;
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addObserver(this);
  }

  /// The keyboard closed (Back on it) while typing: back to read-only, so
  /// the input connection closes and the D-pad moves focus again. Google
  /// TV (Chromecast): with the connection left open, Gboard kept taking the
  /// arrows as cursor moves and the remote could not leave the field (user
  /// report, 1.0.51). Only when the keyboard reported an inset: Fire OS
  /// draws its own over the app and keeps its existing handling.
  @override
  void didChangeMetrics() {
    if (!_typing || !mounted) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    final inset = view.viewInsets.bottom;
    if (inset > 0) {
      _keyboardShown = true;
      return;
    }
    if (!_keyboardShown) return;
    _keyboardShown = false;
    setState(() => _typing = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canRecover) return;
      final now = FocusManager.instance.primaryFocus;
      if (now == null || now is FocusScopeNode) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(TvTextFieldGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      if (TvTextFieldGate._editors[oldWidget.focusNode] == this) {
        TvTextFieldGate._editors.remove(oldWidget.focusNode);
      }
      TvTextFieldGate._editors[widget.focusNode] = this;
      _rehide?.cancel();
      _typing = false;
      _keyboardShown = false;
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _rehide?.cancel();
    widget.focusNode.removeListener(_onFocus);
    if (TvTextFieldGate._editors[widget.focusNode] == this) {
      TvTextFieldGate._editors.remove(widget.focusNode);
    }
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _rehide?.cancel();
    if (_typing) _log('$state while typing');
    // Inactive can mean that the TV keyboard owns the window. Only an actual
    // background transition ends typing; never steal focus from that IME.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _keyboardShown = false;
      // Apple TV: the keyboard, and Siri dictation into it (hold the Siri
      // button), are system pages. Ending typing here closes the input
      // connection under them, which would close the keyboard at once: the
      // likely cause of "voice search shuts it down immediately"
      // (cleverclogs17, TestFlight 954; the TextGate lines in Send log tell).
      // The next arrow or Menu ends typing there anyway.
      if (TvTextFieldGate._fullScreenKeyboard) return;
      if (_typing && mounted) setState(() => _typing = false);
    }
  }

  /// Apple TV keyboard trace for Send log (`TextGate:` lines).
  void _log(String what) {
    if (TvTextFieldGate._fullScreenKeyboard) debugPrint('TextGate: $what');
  }

  void _stopTyping() {
    if (!_typing) return;
    _keyboardShown = false;
    _rehide?.cancel();
    setState(() => _typing = false);
    if (_canRecover) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      if (!_isFireOs) _hideAgainLater();
    }
  }

  /// Apple TV: the full-screen keyboard closed without a word to the app.
  /// Read-only again closes the input connection (EditableText), so OK
  /// reopens the keyboard as usual; [direction] then moves focus unless the
  /// screen's own handling already did.
  void _keyboardGone(TraversalDirection direction) {
    _log('typing ended: ${direction.name}');
    _keyboardShown = false;
    _rehide?.cancel();
    setState(() => _typing = false);
    _move(direction);
  }

  /// The next field never opens its keyboard by itself, even after the
  /// keyboard's Next: Fire OS reports Back on its keyboard as that same
  /// Next, and keeping the keyboard up across fields made Back walk from
  /// field to field with the keyboard reopening each time (Fire Stick 4K
  /// Max, 2026-10-19). One more OK per field, never stuck.
  void _onFocus() {
    if (widget.focusNode.hasFocus || !_typing) return;
    _log('typing ended: focus left');
    _keyboardShown = false;
    setState(() => _typing = false);
    if (!_isFireOs && _canRecover) _hideAgainLater();
    // Fire OS: Back on its keyboard drops Flutter's focus altogether.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canRecover) return;
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
    if (!_canRecover) return false;
    if (!context.read<AppPreferences>().isTelevision) return false;
    final key = event.logicalKey;
    final ok = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;
    if (_typing) {
      final arrow = _arrows[key];
      if (arrow != null) {
        // Apple TV: the keyboard is gone ([TvTextFieldGate._fullScreenKeyboard]).
        // Typing ends here, before the screen's own shortcuts see this arrow
        // ([TvNavigationActivator]), and [_move] covers screens without them.
        if (TvTextFieldGate._fullScreenKeyboard) _keyboardGone(arrow);
        // Elsewhere IMEs may forward cursor arrows while visible (including
        // overlay Gboard with no inset): an arrow is not evidence of dismissal.
        return false;
      }
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
    _rehide?.cancel();
    _keyboardShown = (View.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;
    _log('typing');
    setState(() => _typing = true);
    return true;
  }

  /// Google TV: Gboard could stay up after focus left the field (the hide
  /// came before the input connection closed) and keep the D-pad, so the
  /// remote looked stuck on Add Playlist's source list (owner, 2026-11-02,
  /// +568). Once the field is read-only and focus has moved, hide again.
  Timer? _rehide;

  void _hideAgainLater() {
    _rehide?.cancel();
    _rehide = Timer(const Duration(milliseconds: 250), () {
      if (!_canRecover || _typing) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  static final _arrows = {
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
  };

  static bool get _isFireOs =>
      DeviceDefaults.fingerprint.manufacturer.toLowerCase() == 'amazon';

  /// D-pad arrows on the field move focus, not the cursor. Once a field has
  /// a cursor (typed in once), EditableText's own arrow actions move it —
  /// Up/Down to the start/end of a one-line field, Left/Right a character —
  /// and consume the key even with the keyboard closed and the field
  /// read-only, and Flutter's fallback for arrows in a text field is "stay".
  /// So on screens without their own arrow handling the remote could not
  /// get past a search field it had typed in (the long-standing "stuck in
  /// the text field" report, 2026-10-21). While the keyboard is up it owns
  /// the D-pad, so this only acts once it's closed.
  ///
  /// A screen's own key handler (Add Playlist's field-to-field Up/Down) gets
  /// the key first, but Flutter still delivers it to the field afterwards.
  /// Its focus change is applied in a microtask queued before this one, so
  /// the move only happens when nothing else has moved focus already.
  void _move(TraversalDirection direction) => scheduleMicrotask(() {
        if (_canRecover && !_typing && widget.focusNode.hasPrimaryFocus) {
          widget.focusNode.focusInDirection(direction);
        }
      });

  @override
  Widget build(BuildContext context) {
    if (!context.read<AppPreferences>().isTelevision) {
      return widget.builder(context, false);
    }
    // Apple TV: Menu reaches the app only once its keyboard is closed (Menu
    // on the keyboard closes it inside the system), so Back goes back at
    // once; it used to end typing first, one extra press before Down worked
    // (cleverclogs17's Xtream fields: "hit the back button and then go down").
    final fullScreenKeyboard = TvTextFieldGate._fullScreenKeyboard;
    return PopScope(
      canPop: !_typing || fullScreenKeyboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!_typing) return;
        if (fullScreenKeyboard) _log('typing ended: Back');
        // Popped: this field goes with its page. Kept (another PopScope
        // said no): typing ends, the keyboard closes.
        if (!didPop) _stopTyping();
      },
      child: Actions(
        actions: _typing
            ? const <Type, Action<Intent>>{}
            : {
                ExtendSelectionVerticallyToAdjacentLineIntent:
                    _FieldArrowAction<
                        ExtendSelectionVerticallyToAdjacentLineIntent>(
                  widget.focusNode,
                  (i) => _move(i.forward
                      ? TraversalDirection.down
                      : TraversalDirection.up),
                ),
                ExtendSelectionByCharacterIntent:
                    _FieldArrowAction<ExtendSelectionByCharacterIntent>(
                  widget.focusNode,
                  (i) => _move(i.forward
                      ? TraversalDirection.right
                      : TraversalDirection.left),
                ),
              },
        child: widget.builder(context, !_typing),
      ),
    );
  }
}

/// One of the gate's arrow overrides. Enabled only while the field itself
/// has focus: the gate's Actions also cover the field's own buttons (a
/// clear X, a password eye), where an always-enabled action took the arrow
/// and did nothing, so the remote was stuck there (cillfog, Settings search,
/// 2026-11-26). Disabled, the app's own arrow traversal runs.
class _FieldArrowAction<T extends Intent> extends Action<T> {
  _FieldArrowAction(this._node, this._onInvoke);

  final FocusNode _node;
  final void Function(T intent) _onInvoke;

  @override
  bool isEnabled(T intent) => _node.hasPrimaryFocus;

  @override
  Object? invoke(T intent) {
    _onInvoke(intent);
    return null;
  }
}
