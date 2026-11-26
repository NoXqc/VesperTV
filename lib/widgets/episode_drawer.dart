import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../utils/refined_finish.dart';
import 'gold_tag.dart';

/// One row of the player's Episodes list.
class EpisodeEntry {
  const EpisodeEntry({
    required this.channel,
    required this.current,
    this.season,
    this.progress,
    this.watched = false,
  });

  final Channel channel;

  /// The episode playing now.
  final bool current;

  /// Its season, when the show page knew it (Left / Right jump by it).
  final int? season;

  /// Watched so far (0..1), null = never started.
  final double? progress;
  final bool watched;
}

/// The show's episodes from inside the player (Kal-el23, Discord
/// 2026-11-25: "if you open episode 5 but realize you were still on
/// episode 3, you could switch right there without backing out to the
/// show page"). Opens on the episode playing; Up / Down browse, Left /
/// Right (or CH+ / CH-) jump a season, OK plays, Back closes. Returns the
/// picked row's index, null = closed or the episode playing. Same look and
/// keys as the Sources drawers.
Future<int?> showEpisodeDrawer(BuildContext context,
        {required List<EpisodeEntry> entries}) =>
    showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: tr('Close'),
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width >= 800
              ? math.min(400, MediaQuery.sizeOf(context).width * 0.36)
              : math.min(500, MediaQuery.sizeOf(context).width * 0.9),
          height: double.infinity,
          child: EpisodeDrawer(entries: entries),
        ),
      ),
    );

class EpisodeDrawer extends StatefulWidget {
  const EpisodeDrawer({super.key, required this.entries});
  final List<EpisodeEntry> entries;

  @override
  State<EpisodeDrawer> createState() => _EpisodeDrawerState();
}

class _EpisodeDrawerState extends State<EpisodeDrawer> {
  final _focus = FocusNode(debugLabel: 'episode-drawer');
  final _scroll = ScrollController();
  late int _index = math.max(0, widget.entries.indexWhere((e) => e.current));
  bool _closing = false;

  bool get _compact => MediaQuery.sizeOf(context).width >= 800;
  double get _rowHeight =>
      (_compact ? 72 : 88) *
      math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14);

  /// Index of each season's first episode, in order.
  late final List<int> _seasonStarts = [
    for (final (i, e) in widget.entries.indexed)
      if (e.season != null &&
          (i == 0 || widget.entries[i - 1].season != e.season))
        i,
  ];

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

  void _dismiss([int? index]) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(index);
  }

  /// Keeps the row with the remote on screen; [center] puts it mid-list
  /// (on open, so the episodes before it show too).
  void _reveal({bool center = false}) {
    if (!mounted || !_scroll.hasClients) return;
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
    if (widget.entries.isEmpty) return;
    setState(() => _index = index.clamp(0, widget.entries.length - 1));
    _reveal();
  }

  /// The first episode of the next (+1) or previous (-1) season; -1 from
  /// inside a season goes to its own first episode first.
  void _season(int step) {
    if (_seasonStarts.length < 2) return;
    final here = _seasonStarts.lastWhere((s) => s <= _index,
        orElse: () => _seasonStarts.first);
    final at = _seasonStarts.indexOf(here);
    if (step < 0 && _index > here) {
      _moveTo(here);
      return;
    }
    final next = (at + step).clamp(0, _seasonStarts.length - 1);
    _moveTo(_seasonStarts[next]);
  }

  void _select(int index) {
    if (index < 0 || index >= widget.entries.length) return;
    _dismiss(widget.entries[index].current ? null : index);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _dismiss();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      _moveTo(_index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1));
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageDown) {
      _season(1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageUp) {
      // One season, or the drawer closes like the Sources drawer's Left.
      if (_seasonStarts.length < 2) {
        if (event is KeyDownEvent) _dismiss();
      } else {
        _season(-1);
      }
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _select(_index);
    }
    // Keys stay in the drawer, never reach the player under it.
    return KeyEventResult.handled;
  }

  Widget _row(int i) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.entries[i];
    final focused = i == _index;
    final progress = e.watched ? 1.0 : e.progress;
    final detail = [
      if (e.season != null) tr('Season {season}', {'season': '${e.season}'}),
      if (e.watched) tr('Watched'),
    ].join(' · ');
    return GestureDetector(
      onTap: () => _select(i),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
            horizontal: _compact ? 10 : 12, vertical: _compact ? 6 : 8),
        decoration: RefinedFinish.decorate(
            context,
            BoxDecoration(
              color: focused
                  ? scheme.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: focused
                      ? scheme.primary
                      : e.current
                          ? Colors.amber
                          : Colors.white24,
                  width: focused
                      ? 2
                      : e.current
                          ? 1.2
                          : 1),
            ),
            focused: focused),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Expanded(
                child: Text(e.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: _compact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: e.watched && !focused ? Colors.white70 : null)),
              ),
              if (e.current)
                GoldTag(
                    label: tr('Playing'),
                    compact: true,
                    margin: const EdgeInsets.only(left: 6)),
            ]),
            if (detail.isNotEmpty) ...[
              SizedBox(height: _compact ? 2 : 4),
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white70, fontSize: _compact ? 11 : 12)),
            ],
            if (progress != null && progress > 0) ...[
              SizedBox(height: _compact ? 4 : 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasons = _seasonStarts.length > 1;
    return Material(
      key: const ValueKey('episode-drawer'),
      color: RefinedFinish.surface(context, const Color(0xF011131A)),
      child: SafeArea(
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(children: [
                Expanded(
                  child: Text(tr('Episodes'),
                      style: TextStyle(
                          fontSize: _compact ? 18 : 22,
                          fontWeight: FontWeight.bold)),
                ),
                ExcludeFocus(
                  child: IconButton(
                      tooltip: tr('Close'),
                      onPressed: _dismiss,
                      icon: const Icon(Icons.close)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                  seasons
                      ? tr(
                          'Up/Down: browse · Left/Right: season · OK: play · Back: close')
                      : tr('Up/Down: browse · OK: play · Back: close'),
                  style: TextStyle(
                      color: Colors.white70, fontSize: _compact ? 10 : 12)),
            ),
            Expanded(
              child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemExtent: _rowHeight,
                  itemCount: widget.entries.length,
                  itemBuilder: (_, i) => _row(i)),
            ),
          ]),
        ),
      ),
    );
  }
}
