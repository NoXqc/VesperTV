import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../utils/refined_finish.dart';
import '../l10n/l10n.dart';
import 'hold_to_activate.dart';
import 'roll_down_menu.dart';
import 'sports_mode_live_panel.dart';
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
    this.topCount = 0,
    required this.leagueCount,
    required this.bar,
    required this.content,
    required this.onEnterContent,
    required this.onRailFocusChanged,
    this.moving = false,
    this.onMove,
    this.collapse = false,
    this.live,
  });
  final List<SportsModeRailEntry> entries;

  /// Entries before the leagues (Home, Search, Multiview: the top of the Live
  /// TV tabs column, owner 2026-10-28), then [leagueCount] leagues.
  final int topCount;
  final int leagueCount;
  final Widget bar;
  final Widget content;
  final VoidCallback onEnterContent;
  final ValueChanged<bool> onRailFocusChanged;
  final bool moving;
  final ValueChanged<int>? onMove;

  /// The rail shows only while it has focus (Left from the content's first
  /// control/card), like the Live TV columns; the content gets its width.
  final bool collapse;

  /// Sports Mode's Live TV panel (groups + see-through guide), drawn at the
  /// content's left: its groups column pushes the content right
  /// ([SportsModeLivePanel.groupsWidth]), the guide floats over it.
  final Widget? live;

  @override
  State<SportsModeShell> createState() => SportsModeShellState();
}

class SportsModeShellState extends State<SportsModeShell> {
  final _rail = FocusScopeNode(debugLabel: 'sports-mode-rail');
  String? _lastRail;
  bool _railFocused = false;

  /// Home / Search / Multiview (the top of the Live TV tabs column) sit
  /// behind one Menu row (owner, 2026-10-28). Narrow layouts (phones,
  /// portrait tablets) show the rail as a top strip of that Menu + the
  /// leagues, so their menu holds every other entry too: they couldn't
  /// find their way out of Sports Mode.
  bool _horizontal = false;
  final _menuNode = FocusNode(debugLabel: 'sports-mode-menu');

  late final _menuEntry = SportsModeRailEntry(
      id: 'menu',
      label: tr('Menu'),
      icon: Icons.menu,
      focusNode: _menuNode,
      onTap: openMenu);

  Iterable<SportsModeRailEntry> get _leagues =>
      widget.entries.skip(widget.topCount).take(widget.leagueCount);

  Iterable<SportsModeRailEntry> get _rest =>
      widget.entries.skip(widget.topCount + widget.leagueCount);

  /// What the rail shows and the arrows walk through.
  List<SportsModeRailEntry> get _shown => [
        if (widget.topCount > 0 || _horizontal) _menuEntry,
        ..._leagues,
        if (!_horizontal) ..._rest,
      ];

  List<SportsModeRailEntry> get _menuEntries => [
        ...widget.entries.take(widget.topCount),
        if (_horizontal) ..._rest,
      ];

  /// Where the leagues start in [_shown] (dividers before and after).
  int get _firstLeague => _shown.indexOf(_menuEntry) + 1;

  Future<void> openMenu() async {
    _menuNode.requestFocus();
    final box = _menuNode.context?.findRenderObject() as RenderBox?;
    final anchor = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final items = _menuEntries.where((e) => e.enabled).toList();
    final id = await showRollDownMenu<String>(context,
        anchor: anchor,
        centered: false,
        title: tr('Menu'),
        items: [
          for (final e in items)
            RollDownMenuItem(
                value: e.id,
                icon: e.icon ?? Icons.circle_outlined,
                label: e.label,
                selected: e.selected),
        ]);
    if (!mounted || id == null) return;
    items.where((e) => e.id == id).firstOrNull?.onTap();
  }

  /// Back from the content: the rail, or on a narrow layout its menu (the
  /// strip is always visible there, so focusing it alone showed nothing).
  void backToMenu() => _horizontal ? openMenu() : focusRail();

  void focusRail() {
    final enabled = _shown.where((e) => e.enabled).toList();
    if (enabled.isEmpty) return;
    final entry = enabled.where((e) => e.id == _lastRail).firstOrNull ??
        widget.entries
            .skip(widget.topCount)
            .take(widget.leagueCount)
            .where((e) => e.selected && e.enabled)
            .firstOrNull ??
        // A league, not the Menu at the top.
        _leagues.where((e) => e.enabled).firstOrNull ??
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
    final entries = _shown.where((e) => e.enabled).toList();
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
    _menuNode.dispose();
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
        onFocusChange: (focused) {
          if (focused != _railFocused) setState(() => _railFocused = focused);
          widget.onRailFocusChanged(focused);
        },
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
                  ? Row(children: [for (final e in _shown) _tile(e, true)])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const Padding(
                              padding: EdgeInsets.fromLTRB(10, 8, 0, 14),
                              child: Text(AppConstants.sportsTabName,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          for (final (index, entry) in _shown.indexed) ...[
                            if ((index == _firstLeague && index > 0) ||
                                index == _firstLeague + widget.leagueCount)
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
        _horizontal = narrow;
        final page = Column(children: [
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
        ]);
        final live = narrow ? null : widget.live;
        final main = Expanded(
            child: live == null
                ? page
                : Stack(children: [
                    Positioned.fill(
                        left: SportsModeLivePanel.groupsWidth, child: page),
                    Positioned(left: 0, top: 0, bottom: 0, child: live),
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
                        // Kept mounted while hidden: its nodes must take focus.
                        Offstage(
                          offstage: widget.collapse && !_railFocused,
                          child: SizedBox(
                              width: 180,
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                  child: _buildRail(false))),
                        ),
                        if (widget.collapse && !_railFocused)
                          // Says Left opens a menu; a click opens it too.
                          GestureDetector(
                            key: const ValueKey('sports-mode-rail-tab'),
                            behavior: HitTestBehavior.opaque,
                            onTap: focusRail,
                            child: const SizedBox(
                                width: 18,
                                child: Center(
                                    child: Icon(Icons.chevron_right,
                                        size: 20, color: Colors.white38))),
                          ),
                        main,
                      ]));
      });
}
