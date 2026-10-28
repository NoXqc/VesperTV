import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/refined_finish.dart';
import 'hold_to_activate.dart';
import 'sports_widgets.dart';

class SportsModeRailEntry {
  const SportsModeRailEntry({
    required this.id,
    required this.label,
    required this.focusNode,
    required this.onTap,
    this.icon,
    this.logoUrl,
    this.onHold,
    this.selected = false,
    this.enabled = true,
    this.moving = false,
  });
  final String id;
  final String label;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onHold;
  final IconData? icon;
  final String? logoUrl;
  final bool selected;
  final bool enabled;
  final bool moving;
}

/// Media Hub's rail / floating controls / content arrangement. Every rail node
/// stays mounted, including those scrolled off-screen, so arrows can find it.
class SportsModeShell extends StatefulWidget {
  const SportsModeShell({
    super.key,
    required this.entries,
    required this.leagueCount,
    required this.bar,
    required this.content,
    required this.onEnterContent,
    required this.onRailFocusChanged,
    this.moving = false,
    this.onMove,
  });
  final List<SportsModeRailEntry> entries;
  final int leagueCount;
  final Widget bar;
  final Widget content;
  final VoidCallback onEnterContent;
  final ValueChanged<bool> onRailFocusChanged;
  final bool moving;
  final ValueChanged<int>? onMove;

  @override
  State<SportsModeShell> createState() => SportsModeShellState();
}

class SportsModeShellState extends State<SportsModeShell> {
  final _rail = FocusScopeNode(debugLabel: 'sports-mode-rail');
  String? _lastRail;

  void focusRail() {
    final enabled = widget.entries.where((e) => e.enabled).toList();
    if (enabled.isEmpty) return;
    final entry = enabled.where((e) => e.id == _lastRail).firstOrNull ??
        widget.entries
            .take(widget.leagueCount)
            .where((e) => e.selected && e.enabled)
            .firstOrNull ??
        enabled.first;
    entry.focusNode.requestFocus();
    _reveal(entry.focusNode);
  }

  void _reveal(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = node.context;
      if (mounted && context != null && context.mounted) {
        Scrollable.ensureVisible(context, alignment: 0.5);
      }
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (widget.moving) {
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        widget.onMove?.call(key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onEnterContent();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) return KeyEventResult.handled;
    final delta = key == LogicalKeyboardKey.arrowDown
        ? 1
        : key == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
    if (delta == 0) return KeyEventResult.ignored;
    final entries = widget.entries.where((e) => e.enabled).toList();
    final index = entries.indexWhere((e) => e.focusNode.hasFocus);
    if (index >= 0) {
      final target = (index + delta).clamp(0, entries.length - 1);
      entries[target].focusNode.requestFocus();
      _reveal(entries[target].focusNode);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _rail.dispose();
    super.dispose();
  }

  Widget _tile(SportsModeRailEntry entry, bool narrow) => HoldToActivate(
        key: ValueKey('sports-mode-${entry.id}'),
        onTap: () {
          if (entry.enabled) entry.onTap();
        },
        onHold: entry.enabled ? entry.onHold : null,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (focused) {
            if (focused) {
              _lastRail = entry.id;
              _reveal(entry.focusNode);
            }
          },
          child: Builder(builder: (context) {
            return InkWell(
              focusNode: entry.focusNode,
              canRequestFocus: entry.enabled,
              onTap: entry.enabled ? entry.onTap : null,
              onFocusChange: (_) {
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: RefinedFinish.decorate(
                    context,
                    BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: entry.focusNode.hasFocus
                          ? null
                          : entry.selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .10)
                              : Colors.transparent,
                      gradient: entry.focusNode.hasFocus
                          ? sportsFocusSheen(Theme.of(context).colorScheme)
                          : null,
                      border: Border.all(
                          width: 2,
                          color: entry.focusNode.hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent),
                    ),
                    focused: entry.focusNode.hasFocus),
                child: Opacity(
                    opacity: entry.enabled ? 1 : .35,
                    child: Row(
                      mainAxisSize:
                          narrow ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        if (entry.logoUrl != null)
                          SportsLogo(
                              url: entry.logoUrl,
                              size: 22,
                              fallback: entry.label)
                        else
                          Icon(entry.icon, size: 20, color: Colors.white70),
                        const SizedBox(width: 8),
                        if (narrow)
                          Text(entry.label,
                              style: const TextStyle(fontSize: 13))
                        else
                          Expanded(
                              child: Text(entry.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13))),
                        if (entry.moving) const Icon(Icons.swap_vert, size: 16),
                      ],
                    )),
              ),
            );
          }),
        ),
      );

  Widget _buildRail(bool narrow) => FocusScope(
        node: _rail,
        onFocusChange: widget.onRailFocusChanged,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: _onKey,
          child: Container(
            key: const ValueKey('sports-mode-rail'),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              scrollDirection: narrow ? Axis.horizontal : Axis.vertical,
              padding: const EdgeInsets.all(8),
              child: narrow
                  ? Row(children: [
                      for (final e in widget.entries) _tile(e, true)
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const Padding(
                              padding: EdgeInsets.fromLTRB(10, 8, 0, 14),
                              child: Text(AppConstants.sportsTabName,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          for (final (index, entry)
                              in widget.entries.indexed) ...[
                            if (index == widget.leagueCount)
                              const Divider(color: Colors.white24),
                            _tile(entry, false),
                          ],
                        ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        final main = Expanded(
            child: Column(children: [
          Container(
            key: const ValueKey('sports-mode-floating-bar'),
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: RefinedFinish.decorate(
                context,
                BoxDecoration(
                  color: Colors.black.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                )),
            child: widget.bar,
          ),
          Expanded(child: widget.content),
        ]));
        return SafeArea(
            child: narrow
                ? Column(children: [
                    SizedBox(height: 62, child: _buildRail(true)),
                    main,
                  ])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        SizedBox(
                            width: 180,
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                child: _buildRail(false))),
                        main,
                      ]));
      });
}
