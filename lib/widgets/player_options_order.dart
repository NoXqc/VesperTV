import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import 'hold_to_activate.dart';

/// The TV player's options row in the viewer's own order (Reddit + owner,
/// 2026-11-21: "allow customizing of menu options when watching"). Hold OK
/// on a tile = move mode, like Sports Trak's leagues: Left / Right move it,
/// OK or Back is done. Saved per viewer on every step.
class PlayerOptionsOrder {
  PlayerOptionsOrder._();

  /// The tile in move mode, or null. The player's Back (PopScope) asks it
  /// before closing the row.
  static final ValueNotifier<String?> moving = ValueNotifier(null);

  static bool get isMoving => moving.value != null;

  static void endMove() => moving.value = null;

  /// [items] in the [saved] order. Ids the order doesn't know yet (a new
  /// button, one that only shows on some channels) keep their place after
  /// the item that comes before them by default.
  static List<T> arrange<T>(
    List<T> items,
    String Function(T) idOf,
    List<String> saved,
  ) {
    if (saved.isEmpty) return items;
    final rank = {for (final (i, id) in saved.indexed) id: i};
    final result = [
      for (final item in items)
        if (rank.containsKey(idOf(item))) item,
    ]..sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
    for (final (i, item) in items.indexed) {
      if (rank.containsKey(idOf(item))) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final k = result.indexOf(items[j]);
        if (k >= 0) {
          at = k + 1;
          break;
        }
      }
      result.insert(at, item);
    }
    return result;
  }

  /// The order to save after a move: [shown] (the ids on screen, in their
  /// new order) with the ids of [saved] that aren't on screen now (a tile
  /// only some channels have) kept after the id they followed.
  static List<String> merge(List<String> shown, List<String> saved) {
    final result = [...shown];
    for (final (i, id) in saved.indexed) {
      if (result.contains(id)) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final k = result.indexOf(saved[j]);
        if (k >= 0) {
          at = k + 1;
          break;
        }
      }
      result.insert(at, id);
    }
    return result;
  }
}

/// The options row's tiles ([tiles]: id + widget) in the saved order, each
/// one movable with a held OK.
class ReorderableOptionTiles extends StatefulWidget {
  const ReorderableOptionTiles({
    super.key,
    required this.tiles,
    this.active = true,
    this.onActivity,
  });

  final List<(String, Widget)> tiles;

  /// False while the row is hidden: a move in progress ends.
  final bool active;

  /// Keeps the row up (the player's hide timer) while moving: the keys
  /// handled here never reach the player's own key listener.
  final VoidCallback? onActivity;

  @override
  State<ReorderableOptionTiles> createState() => _ReorderableOptionTilesState();
}

class _ReorderableOptionTilesState extends State<ReorderableOptionTiles> {
  StorageService? _storage;
  List<String> _order = const [];

  @override
  void initState() {
    super.initState();
    try {
      _storage = context.read<StorageService>();
    } on ProviderNotFoundException {
      _storage = null;
    }
    _order = _storage?.getPlayerOptionsOrder() ?? const [];
    PlayerOptionsOrder.moving.addListener(_changed);
  }

  @override
  void didUpdateWidget(ReorderableOptionTiles old) {
    super.didUpdateWidget(old);
    if (!widget.active && PlayerOptionsOrder.isMoving) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => PlayerOptionsOrder.endMove(),
      );
    }
  }

  @override
  void dispose() {
    PlayerOptionsOrder.moving.removeListener(_changed);
    if (PlayerOptionsOrder.isMoving) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => PlayerOptionsOrder.endMove(),
      );
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<(String, Widget)> get _arranged =>
      PlayerOptionsOrder.arrange(widget.tiles, (t) => t.$1, _order);

  void _move(int delta) {
    widget.onActivity?.call();
    final id = PlayerOptionsOrder.moving.value;
    if (id == null) return;
    final ids = [for (final t in _arranged) t.$1];
    final i = ids.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= ids.length) return;
    ids
      ..removeAt(i)
      ..insert(j, id);
    setState(() => _order = PlayerOptionsOrder.merge(ids, _order));
    _storage?.setPlayerOptionsOrder(_order);
    // The tile keeps its element (keyed by id) and so its focus; keep it
    // on screen when the row scrolls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, duration: Duration.zero);
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!PlayerOptionsOrder.isMoving) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final arrow = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    final back =
        key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape;
    if (!arrow && !back) return KeyEventResult.ignored;
    if (event is KeyUpEvent) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.arrowLeft) _move(-1);
    if (key == LogicalKeyboardKey.arrowRight) _move(1);
    if (back) PlayerOptionsOrder.endMove();
    // Up / Down: stay on the tile until OK / Back says done.
    return KeyEventResult.handled;
  }

  /// A short OK: the tile's own action (the held-OK wrapper took the key).
  static void _activateFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null) Actions.maybeInvoke(ctx, const ActivateIntent());
  }

  @override
  Widget build(BuildContext context) {
    final moving = PlayerOptionsOrder.moving.value;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (id, tile) in _arranged)
            KeyedSubtree(
              key: ValueKey('option:$id'),
              child: HoldToActivate(
                onTap: () {
                  if (PlayerOptionsOrder.isMoving) {
                    PlayerOptionsOrder.endMove();
                  } else {
                    _activateFocused();
                  }
                },
                onHold: () {
                  if (PlayerOptionsOrder.isMoving) return;
                  widget.onActivity?.call();
                  PlayerOptionsOrder.moving.value = id;
                },
                child: _MoveFrame(moving: moving == id, child: tile),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tile being moved: arrows at its sides and an amber outline, like a
/// league chip in move mode. The same widget either way, so the tile under
/// it keeps its focus when move mode starts or ends.
class _MoveFrame extends StatelessWidget {
  const _MoveFrame({required this.moving, required this.child});

  final bool moving;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: moving ? Colors.amber : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: moving,
            maintainSize: false,
            child: const Icon(Icons.chevron_left, color: Colors.amber),
          ),
          child,
          Visibility(
            visible: moving,
            maintainSize: false,
            child: const Icon(Icons.chevron_right, color: Colors.amber),
          ),
        ],
      ),
    );
  }
}
