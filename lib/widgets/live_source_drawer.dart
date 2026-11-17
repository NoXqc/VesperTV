import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/channel_copy_fallback.dart';
import '../utils/refined_finish.dart';
import 'gold_tag.dart';
import 'tv_text_field_gate.dart';

/// [showLiveSourceDrawer]'s answer for the "Add another source" row.
const liveSourceAdd = -1;

/// One row of the live Sources drawer.
class LiveSourceEntry {
  const LiveSourceEntry(
      {required this.channel, required this.playlist, required this.current});

  final Channel channel;
  final String playlist;
  final bool current;
}

/// The quality a source's name claims (4K / FHD / HD / SD), or null.
String? liveSourceQuality(Channel c) =>
    switch (ChannelCopyFallback.qualityRank(c.sourceName)) {
      6 => '8K',
      5 => '4K',
      4 => 'FHD',
      3 => 'HD',
      1 => 'SD',
      _ => null,
    };

/// The other sources of the live channel playing (player options > Sources,
/// AMD's Dispatcharr "Switch Stream" request, 2026-11-16): its quality
/// copies, the playlist editor's fallbacks and link, and the same channel in
/// the other playlists. Returns the picked row's index, [liveSourceAdd]
/// for the "Add another source" row ([canAdd]), null = closed.
/// Same look and keys as Media Hub's source drawer.
Future<int?> showLiveSourceDrawer(BuildContext context,
        {required List<LiveSourceEntry> entries, bool canAdd = false}) =>
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
              ? math.min(360, MediaQuery.sizeOf(context).width * 0.34)
              : math.min(500, MediaQuery.sizeOf(context).width * 0.9),
          height: double.infinity,
          child: _LiveSourceDrawer(entries: entries, canAdd: canAdd),
        ),
      ),
    );

class _LiveSourceDrawer extends StatefulWidget {
  const _LiveSourceDrawer({required this.entries, required this.canAdd});
  final List<LiveSourceEntry> entries;
  final bool canAdd;

  int get rows => entries.length + (canAdd ? 1 : 0);

  @override
  State<_LiveSourceDrawer> createState() => _LiveSourceDrawerState();
}

class _LiveSourceDrawerState extends State<_LiveSourceDrawer> {
  /// "Add another source": saved as a playlist editor fallback of the
  /// channel (owner, 2026-11-16: no trip to the editor).
  Widget _addRow(bool focused) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _select(widget.entries.length),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(_compact ? 8 : 12),
        decoration: RefinedFinish.decorate(
            context,
            BoxDecoration(
              color: focused
                  ? scheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: focused ? scheme.primary : Colors.white24,
                  width: focused ? 2 : 1),
            ),
            focused: focused),
        child: Row(children: [
          Icon(Icons.add, color: focused ? scheme.primary : Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('Add another source'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: _compact ? 14 : 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tr('Any channel, any playlist: tried first if this one fails'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white70, fontSize: _compact ? 11 : 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  final _focus = FocusNode(debugLabel: 'live-source-drawer');
  final _scroll = ScrollController();
  late int _index = math.max(0, widget.entries.indexWhere((e) => e.current));
  bool _closing = false;

  bool get _compact => MediaQuery.sizeOf(context).width >= 800;
  double get _rowHeight =>
      (_compact ? 84 : 104) *
      math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _reveal();
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

  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final top = _index * _rowHeight;
    final bottom = top + _rowHeight;
    final target = top < position.pixels
        ? top
        : bottom > position.pixels + position.viewportDimension
            ? bottom - position.viewportDimension
            : position.pixels;
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  void _select(int index) {
    if (index == widget.entries.length && widget.canAdd) {
      _dismiss(liveSourceAdd);
      return;
    }
    if (index >= widget.entries.length) return;
    _dismiss(widget.entries[index].current ? null : index);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _dismiss();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (widget.rows > 0) {
        setState(() => _index =
            (_index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, widget.rows - 1));
        _reveal();
      }
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _select(_index);
    }
    // Arrows stay in the drawer, never reach the player under it.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.entries;
    return Material(
      key: const ValueKey('live-source-drawer'),
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
                  child: Text(tr('Stream sources'),
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
              child: Text(tr('Up/Down: browse · OK: switch · Back: close'),
                  style: TextStyle(
                      color: Colors.white70, fontSize: _compact ? 10 : 12)),
            ),
            if (entries.length < 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(tr('No other source for this channel.'),
                    style: const TextStyle(color: Colors.white70)),
              ),
            Expanded(
              child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemExtent: _rowHeight,
                  itemCount: widget.rows,
                  itemBuilder: (_, i) {
                    if (i == entries.length) return _addRow(i == _index);
                    final e = entries[i];
                    final focused = i == _index;
                    final quality = liveSourceQuality(e.channel);
                    return GestureDetector(
                      onTap: () => _select(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: EdgeInsets.all(_compact ? 8 : 12),
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
                                child: Text(e.channel.sourceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: _compact ? 14 : 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (e.current)
                                GoldTag(
                                    label: tr('Current stream'),
                                    compact: true,
                                    margin: const EdgeInsets.only(left: 6)),
                            ]),
                            SizedBox(height: _compact ? 4 : 6),
                            Text(
                              [
                                if (e.playlist.isNotEmpty) e.playlist,
                                if (quality != null) quality,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: _compact ? 12 : 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Add another source" (the drawer's last row): any live channel of any
/// playlist, found by name in a panel the drawer's shape (the video stays
/// in view). Big setups have 100k+ channels: names are lower-cased once,
/// the list follows the typing after a short pause and shows
/// [_LiveSourceSearchState._max] at most. Before any typing it lists the
/// channels whose name holds [suggest] (the playing channel's main word).
/// Sports Trak's channel picker did this before: it rebuilt its channel
/// library on every key, slow on a box (owner, 2026-11-16).
Future<Channel?> showLiveSourceSearch(BuildContext context,
        {required String title,
        required List<Channel> channels,
        required String Function(Channel) describe,
        String suggest = '',
        Set<String> skipUrls = const {}}) =>
    showGeneralDialog<Channel>(
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
              ? math.min(460, MediaQuery.sizeOf(context).width * 0.42)
              : MediaQuery.sizeOf(context).width,
          height: double.infinity,
          child: _LiveSourceSearch(
              title: title,
              channels: channels,
              describe: describe,
              suggest: suggest,
              skipUrls: skipUrls),
        ),
      ),
    );

class _LiveSourceSearch extends StatefulWidget {
  const _LiveSourceSearch(
      {required this.title,
      required this.channels,
      required this.describe,
      required this.suggest,
      required this.skipUrls});
  final String title;
  final List<Channel> channels;
  final String Function(Channel) describe;
  final String suggest;
  final Set<String> skipUrls;

  @override
  State<_LiveSourceSearch> createState() => _LiveSourceSearchState();
}

class _LiveSourceSearchState extends State<_LiveSourceSearch> {
  static const _max = 150;
  final _field = FocusNode(debugLabel: 'live-source-search');
  final _list = FocusNode(debugLabel: 'live-source-results');
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final List<String> _names = [
    for (final c in widget.channels) c.name.toLowerCase()
  ];
  List<Channel> _results = const [];
  bool _more = false;
  bool _typed = false;
  int _index = 0;
  Timer? _pause;
  bool _closing = false;

  bool get _compact => MediaQuery.sizeOf(context).width >= 800;
  double get _rowHeight =>
      (_compact ? 64 : 76) *
      math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14);

  @override
  void initState() {
    super.initState();
    _search('');
    _list.addListener(_repaint);
    HardwareKeyboard.instance.addHandler(_fieldKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The suggestions are usually it: start on them, Up = the search box.
      (_results.isEmpty ? _field : _list).requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_fieldKey);
    _pause?.cancel();
    _list.removeListener(_repaint);
    _field.dispose();
    _list.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _search(String query) {
    var words = query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    final typed = words.isNotEmpty;
    if (!typed && widget.suggest.isNotEmpty) {
      words = [widget.suggest.toLowerCase()];
    }
    final found = <Channel>[];
    var more = false;
    if (words.isNotEmpty) {
      final list = words.toList();
      for (var i = 0; i < _names.length; i++) {
        final name = _names[i];
        if (!list.every(name.contains)) continue;
        final c = widget.channels[i];
        if (widget.skipUrls.contains(c.url)) continue;
        if (found.length == _max) {
          more = true;
          break;
        }
        found.add(c);
      }
    }
    void apply() {
      _typed = typed;
      _results = found;
      _more = more;
      _index = 0;
    }

    // initState runs it before the first build.
    mounted ? setState(apply) : apply();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onChanged(String value) {
    _pause?.cancel();
    _pause = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _search(value);
    });
  }

  void _close([Channel? picked]) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(picked);
  }

  /// Down out of the search box (EditableText keeps arrow keys); see
  /// `TmdbSettingsScreen._handleApiKeyFieldEscapeKey`.
  bool _fieldKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown ||
        FocusManager.instance.primaryFocus != _field ||
        !(ModalRoute.of(context)?.isCurrent ?? false) ||
        _results.isEmpty) {
      return false;
    }
    _list.requestFocus();
    return true;
  }

  void _reveal() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final top = _index * _rowHeight;
    final bottom = top + _rowHeight;
    final target = top < position.pixels
        ? top
        : bottom > position.pixels + position.viewportDimension
            ? bottom - position.viewportDimension
            : position.pixels;
    _scroll.jumpTo(target.clamp(0, position.maxScrollExtent));
  }

  KeyEventResult _onListKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp && _index == 0) {
      if (event is KeyDownEvent) _field.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      setState(() => _index =
          (_index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
              .clamp(0, math.max(0, _results.length - 1)));
      _reveal();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _close();
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      if (_index < _results.length) _close(_results[_index]);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listFocused = _list.hasFocus;
    final status = _results.isEmpty
        ? (_typed || widget.suggest.isNotEmpty
            ? tr('No results')
            : tr('Type a channel name.'))
        : _more
            ? tr('Showing the first {n}. Type more to narrow it down.',
                {'n': _max})
            : null;
    return Material(
      key: const ValueKey('live-source-search'),
      color: RefinedFinish.surface(context, const Color(0xF011131A)),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: _compact ? 17 : 20,
                        fontWeight: FontWeight.bold)),
              ),
              ExcludeFocus(
                child: IconButton(
                    tooltip: tr('Close'),
                    onPressed: _close,
                    icon: const Icon(Icons.close)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TvTextFieldGate(
              focusNode: _field,
              builder: (_, readOnly) => TextField(
                controller: _text,
                focusNode: _field,
                readOnly: readOnly,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (value) {
                  _pause?.cancel();
                  _search(value);
                  if (_results.isNotEmpty) _list.requestFocus();
                },
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  labelText: tr('Search channels'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(status,
                  style: TextStyle(
                      color: Colors.white70, fontSize: _compact ? 11 : 13)),
            ),
          Expanded(
            child: Focus(
              focusNode: _list,
              canRequestFocus: _results.isNotEmpty,
              onKeyEvent: _onListKey,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemExtent: _rowHeight,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final c = _results[i];
                  final focused = listFocused && i == _index;
                  return GestureDetector(
                    onTap: () => _close(c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: _compact ? 6 : 8),
                      decoration: RefinedFinish.decorate(
                          context,
                          BoxDecoration(
                            color: focused
                                ? scheme.primary.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: focused ? scheme.primary : Colors.white24,
                                width: focused ? 2 : 1),
                          ),
                          focused: focused),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: _compact ? 14 : 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(widget.describe(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: _compact ? 12 : 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
