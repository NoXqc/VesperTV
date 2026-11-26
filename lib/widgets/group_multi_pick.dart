import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'glass_menu.dart';

/// One group in [showGroupMultiPick].
class GroupPickEntry {
  const GroupPickEntry(
      {required this.title, this.detail, this.color, this.checked = false});

  final String title;

  /// Its playlist (2+ playlists) or "My groups".
  final String? detail;

  /// The colour it wears now, if any.
  final Color? color;

  /// Ticked when the list opens.
  final bool checked;
}

/// Ticks several groups (hold OK on a group > Colour… > Select more groups,
/// owner 2026-11-25: "select a bunch that they want the same color"). One
/// focus with its own Up / Down (a long list stays lazy: big playlists have
/// hundreds of groups); OK ticks. Back goes on to the colour with the
/// ticked groups (owner, 1016: scrolling down a big list to the button at
/// the bottom was a chore, and Back threw the ticks away); the button sits
/// at the top, reached with Right or Up from the first group. Back with
/// nothing ticked closes. Returns the ticked indexes, null = closed.
/// [action] names the button for how many are ticked.
Future<Set<int>?> showGroupMultiPick(BuildContext context,
        {required String title,
        required String Function(int count) action,
        required List<GroupPickEntry> entries,
        int start = 0}) =>
    showGlassMenu<Set<int>>(
      context: context,
      builder: (_) => GlassMenuDialog.custom(
        maxWidth: 460,
        child: GroupMultiPick(
            title: title, action: action, entries: entries, start: start),
      ),
    );

class GroupMultiPick extends StatefulWidget {
  const GroupMultiPick(
      {super.key,
      required this.title,
      required this.action,
      required this.entries,
      this.start = 0});

  final String title;
  final String Function(int count) action;
  final List<GroupPickEntry> entries;
  final int start;

  @override
  State<GroupMultiPick> createState() => _GroupMultiPickState();
}

class _GroupMultiPickState extends State<GroupMultiPick> {
  static const _rowHeight = 52.0;
  final _focus = FocusNode(debugLabel: 'group-multi-pick');
  final _scroll = ScrollController();
  late final Set<int> _ticked = {
    for (final (i, e) in widget.entries.indexed)
      if (e.checked) i,
  };
  late int _index =
      widget.start.clamp(0, math.max(0, widget.entries.length - 1));

  /// The group the remote left for the button (Down / Left come back).
  late int _lastRow = _index;
  bool _closing = false;

  /// The button above the list has the remote.
  bool get _onButton => _index < 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _reveal(center: true);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reveal({bool center = false}) {
    if (!mounted || !_scroll.hasClients || _onButton) return;
    final position = _scroll.position;
    final top = _index * _rowHeight;
    final bottom = top + _rowHeight;
    final target = center
        ? top - (position.viewportDimension - _rowHeight) / 2
        : top < position.pixels
            ? top
            : bottom > position.pixels + position.viewportDimension
                ? bottom - position.viewportDimension
                : position.pixels;
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  void _moveTo(int index) {
    setState(() {
      _index = index.clamp(-1, widget.entries.length - 1);
      if (_index >= 0) _lastRow = _index;
    });
    _reveal();
  }

  void _toButton() => setState(() => _index = -1);

  void _toggle(int i) =>
      setState(() => _ticked.contains(i) ? _ticked.remove(i) : _ticked.add(i));

  void _done() {
    if (_ticked.isEmpty || _closing) return;
    _closing = true;
    Navigator.of(context).pop(Set<int>.of(_ticked));
  }

  /// Back (the key, or the system's): on to the colour with what is
  /// ticked; nothing ticked = close.
  void _back() {
    if (_closing) return;
    if (_ticked.isNotEmpty) {
      _done();
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _back();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveTo(_onButton ? _lastRow : _index + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_index == 0) {
        _toButton();
      } else if (!_onButton) {
        _moveTo(_index - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _toButton();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (_onButton) _moveTo(_lastRow);
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _onButton ? _done() : _toggle(_index);
    }
    return KeyEventResult.handled;
  }

  Widget _row(int i) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.entries[i];
    final focused = i == _index;
    final on = _ticked.contains(i);
    return GestureDetector(
      onTap: () {
        setState(() => _index = i);
        _toggle(i);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: focused
              ? scheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: focused ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22, color: on ? scheme.primary : Colors.white70),
          const SizedBox(width: 12),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: e.color,
              border: e.color == null
                  ? Border.all(color: Colors.white38, width: 1.2)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (e.detail != null)
                  Text(e.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = _ticked.length;
    final button = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GestureDetector(
        onTap: _done,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _onButton
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _onButton ? Colors.white : Colors.transparent, width: 2),
          ),
          child: Text(widget.action(count),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: count == 0
                      ? Colors.white38
                      : _onButton
                          ? scheme.onPrimary
                          : Colors.white)),
        ),
      ),
    );
    // The system's Back (and a tap outside) comes here too.
    return PopScope<Set<int>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(tr('OK: tick · Back or Right: choose the colour'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            button,
            const Divider(height: 1, color: Colors.white12),
            Flexible(
              child: ListView.builder(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemExtent: _rowHeight,
                itemCount: widget.entries.length,
                itemBuilder: (_, i) => _row(i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
