import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import 'hold_to_activate.dart';
import 'glass_menu.dart';
import '../utils/refined_finish.dart';

/// One choice in a [showRollDownMenu].
class RollDownMenuItem<T> {
  const RollDownMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.selected = false,
    this.dimmed = false,
    this.action,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;

  /// Marked (gold, check) and focused first — "you are here".
  final bool selected;

  /// Greyed (e.g. a playlist hidden here) — still pickable.
  final bool dimmed;

  /// A second, smaller button at the row's right end, reached with Right
  /// (a `›` until focused, then its label) — e.g. Hide / Show a playlist.
  final RollDownMenuAction<T>? action;
}

/// See [RollDownMenuItem.action]; picking it pops [value].
class RollDownMenuAction<T> {
  const RollDownMenuAction(
      {required this.value, required this.icon, required this.label});

  final T value;
  final IconData icon;
  final String label;
}

/// The on-screen rect of [context]'s widget, for [showRollDownMenu]'s
/// `anchor`; null when it isn't laid out.
Rect? rollDownAnchorOf(BuildContext? context) {
  final box = context?.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// A small menu in the floating bar's black-and-gold look that unrolls from
/// under [anchor] (Media Hub row buttons, the groups column's Playlists
/// row). Pops the picked item's value, or null on Back / a tap outside.
/// [centered]: centred under the anchor (a bar button); otherwise its left
/// edge lines up with the anchor's (a column row). Held-OK repeats from the
/// press that opened it are swallowed ([SwallowHeldActivate]).
Future<T?> showRollDownMenu<T>(
  BuildContext context, {
  required Rect? anchor,
  required String title,
  required List<RollDownMenuItem<T>> items,
  bool centered = true,
  double width = 280,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // No full-screen dimming over Multiview's videos: one more layer
      // for a GPU already busy putting them on screen (GlassBlur.motion).
      barrierColor: GlassBlur.live ? Colors.black38 : Colors.transparent,
      transitionDuration: GlassBlur.motion(const Duration(milliseconds: 200)),
      pageBuilder: (ctx, animation, _) => SwallowHeldActivate(
        child: _RollDownMenu<T>(
          anchor: anchor,
          animation: animation,
          title: title,
          items: items,
          centered: centered,
          width: width,
        ),
      ),
    );

class _RollDownMenu<T> extends StatelessWidget {
  const _RollDownMenu({
    required this.anchor,
    required this.animation,
    required this.title,
    required this.items,
    required this.centered,
    required this.width,
  });

  final Rect? anchor;
  final Animation<double> animation;
  final String title;
  final List<RollDownMenuItem<T>> items;
  final bool centered;
  final double width;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final a = anchor;
    final w = width.clamp(160.0, screen.width - 24);
    final double left = (a == null
            ? (screen.width - w) / 2
            : centered
                ? a.center.dx - w / 2
                : a.left)
        .clamp(12.0, screen.width - w - 12);
    final topEdge = padding.top + 12;
    final bottomEdge = (screen.height - padding.bottom - insets.bottom - 12)
        .clamp(topEdge + 1, screen.height);
    final preferredTop = (a?.bottom ?? 72) + 8;
    final below = (bottomEdge - preferredTop).clamp(0.0, screen.height);
    final anchorTop = (a?.top ?? topEdge).clamp(topEdge + 8, bottomEdge + 8);
    final above = (anchorTop - 8 - topEdge).clamp(0.0, screen.height);
    final opensAbove = a != null && below < 160 && above > below;
    final top = preferredTop.clamp(topEdge, bottomEdge - 1);
    final maxHeight = (opensAbove ? above : below).clamp(1.0, screen.height);
    final focusIndex = items.indexWhere((i) => i.selected);
    final curve =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: opensAbove ? null : top,
          bottom: opensAbove ? screen.height - anchorTop + 8 : null,
          width: w,
          child: Material(
            type: MaterialType.transparency,
            child: FadeTransition(
              opacity: curve,
              child: SizeTransition(
                sizeFactor: curve,
                alignment:
                    opensAbove ? Alignment.bottomCenter : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: GlassMenuSurface(
                    radius: 24,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w600)),
                          ),
                          // Non-lazy: every item has a context, so focus can
                          // reach any of them (a long list scrolls).
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          bottom:
                                              i == items.length - 1 ? 0 : 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _RollDownMenuButton(
                                              item: items[i],
                                              autofocus: i ==
                                                  (focusIndex < 0
                                                      ? 0
                                                      : focusIndex),
                                              onTap: () => Navigator.of(context)
                                                  .pop(items[i].value),
                                            ),
                                          ),
                                          if (items[i].action
                                              case final action?) ...[
                                            const SizedBox(width: 4),
                                            _RollDownActionButton(
                                              icon: action.icon,
                                              label: action.label,
                                              onTap: () => Navigator.of(context)
                                                  .pop(action.value),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RollDownMenuButton extends StatefulWidget {
  const _RollDownMenuButton(
      {required this.item, required this.autofocus, required this.onTap});

  final RollDownMenuItem<Object?> item;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  State<_RollDownMenuButton> createState() => _RollDownMenuButtonState();
}

class _RollDownMenuButtonState extends State<_RollDownMenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final lit = _focused || item.selected;
    final dim = item.dimmed && !_focused;
    // Its own layer and Material: a step (ink + the 150 ms fade) redraws
    // this row, not the whole menu over Multiview's moving tiles.
    return RepaintBoundary(
        child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              autofocus: widget.autofocus,
              onFocusChange: (f) {
                setState(() => _focused = f);
                if (f) Scrollable.ensureVisible(context, alignment: 0.5);
              },
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: GlassBlur.motion(const Duration(milliseconds: 150)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: GlassMenuSurface.rowDecoration(context,
                    focused: _focused, selected: item.selected, radius: 20),
                child: Row(
                  children: [
                    Icon(item.selected ? Icons.check : item.icon,
                        size: 20, color: lit ? scheme.primary : Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: dim
                                      ? Colors.white38
                                      : lit
                                          ? Colors.white
                                          : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: item.selected
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          if (item.subtitle != null)
                            Text(item.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )));
  }
}

/// [RollDownMenuItem.action]'s button: a `›` that opens into its label
/// while focused, so a row reads "Playlist ›" and Right shows "Hide".
class _RollDownActionButton extends StatefulWidget {
  const _RollDownActionButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RollDownActionButton> createState() => _RollDownActionButtonState();
}

class _RollDownActionButtonState extends State<_RollDownActionButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onFocusChange: (f) => setState(() => _focused = f),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: GlassBlur.motion(const Duration(milliseconds: 150)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: GlassMenuSurface.rowDecoration(context,
            focused: _focused, radius: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Touch / mouse: the action's own icon (an eye says "hide"; a
            // bare › didn't, owner 2026-10-20). Remote: a › that opens into
            // icon + label when Right reaches it.
            Icon(
                _focused || !context.read<AppPreferences>().isTelevision
                    ? widget.icon
                    : Icons.chevron_right,
                size: 20,
                color: _focused ? scheme.primary : Colors.white54),
            if (_focused) ...[
              const SizedBox(width: 6),
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
