import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_menu.dart';
import 'tv_menu_tile.dart';

/// One Settings row (owner, 2026-11-10: Settings in the glass look of the
/// app's menus): an icon, a title, a one-line description and, on the
/// right, what it is set to — a [SettingValue], a [GlassSwitch] or a
/// chevron. Focus is the glass outline, never a fill.
///
/// [onLeft] / [onRight] make it a stepper (Left/Right change the value
/// while it has focus, e.g. Guide transparency); otherwise Left and Right
/// go on to the parent (the Settings menu's panel switch).
class SettingRow extends StatefulWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.trailing,
    this.onTap,
    this.onLeft,
    this.onRight,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.toggled,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;

  /// A switch row: read out as a toggle.
  final bool? toggled;

  /// "You are here" (the Settings menu's open category).
  final bool selected;

  @override
  State<SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<SettingRow> {
  bool _focused = false;

  void _revealSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focused) return;
      Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && widget.onLeft != null) {
      widget.onLeft!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
      widget.onRight!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = CompactMenus.of(context);
    final lit = _focused || widget.selected;
    final title = Text(widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: !widget.enabled
                ? Colors.white38
                : lit
                    ? scheme.primary
                    : Colors.white,
            fontWeight: widget.selected ? FontWeight.w700 : null));
    return Semantics(
      toggled: widget.toggled,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent:
              widget.onLeft == null && widget.onRight == null ? null : _onKey,
          // Its own layer and its own Material: the ListTile's focus ink is
          // painted by the nearest Material, the whole panel, so every step
          // redrew every row of it for the length of the animation (Settings
          // on the Homatics, 2026-11-13).
          child: RepaintBoundary(
              child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    decoration: GlassMenuSurface.rowDecoration(context,
                        focused: _focused,
                        selected: widget.selected,
                        radius: 10,
                        quiet: true),
                    child: ListTile(
                      focusNode: widget.focusNode,
                      autofocus: widget.autofocus,
                      enabled: widget.enabled,
                      dense: compact,
                      // The row's own outline shows focus; no theme wash under it.
                      focusColor: Colors.transparent,
                      hoverColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                      minLeadingWidth: compact ? 24 : 32,
                      horizontalTitleGap: compact ? 12 : 16,
                      onFocusChange: (f) {
                        setState(() => _focused = f);
                        widget.onFocusChange?.call(f);
                        if (f) _revealSoon();
                      },
                      leading: Icon(widget.icon,
                          size: compact ? 20 : 24,
                          color: lit ? scheme.tertiary : Colors.white70),
                      title: title,
                      subtitle: widget.subtitle == null
                          ? null
                          : Text(widget.subtitle!,
                              maxLines: widget.subtitleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6))),
                      trailing: widget.trailing,
                      onTap: widget.enabled ? widget.onTap : null,
                    ),
                  ))),
        ),
      ),
    );
  }
}

/// A row's current value ("English", "Gold", "40%") and its hint icon:
/// a chevron (opens a page), a drop arrow (a choice) or arrows (a stepper).
class SettingValue extends StatelessWidget {
  const SettingValue({super.key, this.text, this.icon = Icons.chevron_right});

  final String? text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final compact = CompactMenus.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 200 : 160),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (text != null && text!.isNotEmpty)
          Flexible(
            child: Text(text!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compact ? 13.5 : 14, color: Colors.white70)),
          ),
        if (icon != null) ...[
          const SizedBox(width: 2),
          Icon(icon, size: compact ? 20 : 22, color: Colors.white54),
        ],
      ]),
    );
  }
}

/// The on/off pill of a switch row. Not a control itself (the whole row
/// is, one focus stop per setting), so the remote never lands on it.
class GlassSwitch extends StatelessWidget {
  const GlassSwitch({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = CompactMenus.of(context);
    final w = compact ? 38.0 : 44.0, h = compact ? 22.0 : 26.0;
    final knob = h - 6;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: w,
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          color: value ? scheme.primary : Colors.white.withValues(alpha: 0.16),
          border: Border.all(
              color: value ? scheme.primary : Colors.white24, width: 1),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob - 2,
            height: knob - 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? scheme.onPrimary : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
