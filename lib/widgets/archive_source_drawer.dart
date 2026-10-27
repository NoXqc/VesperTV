import '../utils/refined_finish.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_service.dart';
import '../services/archive_stream_size.dart';
import 'gold_tag.dart';

Future<ArchiveSourceSelection?> showArchiveSourceDrawer(BuildContext context,
        {required ArchivePlaybackSources sources, required String channelId}) =>
    showGeneralDialog<ArchiveSourceSelection>(
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
              ? math.min(320, MediaQuery.sizeOf(context).width * 0.30)
              : math.min(500, MediaQuery.sizeOf(context).width * 0.9),
          height: double.infinity,
          child: _ArchiveSourceDrawer(sources: sources, channelId: channelId),
        ),
      ),
    );

class _ArchiveSourceDrawer extends StatefulWidget {
  const _ArchiveSourceDrawer({required this.sources, required this.channelId});
  final ArchivePlaybackSources sources;
  final String channelId;

  @override
  State<_ArchiveSourceDrawer> createState() => _ArchiveSourceDrawerState();
}

class _ArchiveSourceDrawerState extends State<_ArchiveSourceDrawer> {
  double get _rowHeight => _compact
      ? 124 * math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14)
      : 186;
  bool get _compact => MediaQuery.sizeOf(context).width >= 800;
  bool _closing = false;

  void _dismiss([ArchiveSourceSelection? selection]) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(selection);
  }

  final _focus = FocusNode(debugLabel: 'media-hub-source-drawer');
  final _scroll = ScrollController();
  List<ArchiveStreamOption> _options = const [];
  bool _loading = true;
  bool _selecting = false;
  String? _error;
  int _index = 0;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _load() async {
    try {
      final options = await widget.sources.load(widget.channelId);
      if (!mounted) return;
      var playable = options.where((o) => o.stream.ytId == null).toList();
      final playing = widget.sources.current(widget.channelId);
      var currentIndex = archiveCurrentStreamIndex(playable, playing);
      if (currentIndex < 0 && playing != null && playing.stream.ytId == null) {
        // Retain the known playing selection rather than labelling an ambiguous
        // refreshed alternative as current. No URL is probed or exposed.
        playable = [playing, ...playable];
        currentIndex = 0;
      }
      setState(() {
        _options = playable;
        _currentIndex = currentIndex;
        _index = math.max(0, _currentIndex);
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr('Could not load stream sources.');
        });
      }
    }
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

  Future<void> _select(int index) async {
    if (_closing || _selecting || _loading || index >= _options.length) return;
    final option = _options[index];
    if (index == _currentIndex) {
      _dismiss();
      return;
    }
    setState(() {
      _selecting = true;
      _index = index;
      _error = null;
    });
    try {
      final channel = await widget.sources.select(widget.channelId, option);
      if (!mounted || _closing || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (channel == null) throw StateError('Selection no longer current');
      _dismiss(ArchiveSourceSelection(channel, option));
    } catch (_) {
      if (mounted) {
        setState(() {
          _selecting = false;
          _error = tr('Could not switch stream. Try another source.');
        });
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) _dismiss();
    } else if (!_loading && !_selecting && _options.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        setState(() => _index =
            (_index + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, _options.length - 1));
        _reveal();
      } else if (event is KeyDownEvent &&
          (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter)) {
        _select(_index);
      }
    }
    // Keep arrows inside this drawer; never search the underlying poster grid.
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('media-hub-source-drawer'),
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
            if (_selecting) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.orange))),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _options.isEmpty
                      ? Center(
                          child: Text(tr('No playable stream for this title.')))
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemExtent: _rowHeight,
                          itemCount: _options.length,
                          itemBuilder: (_, index) {
                            final option = _options[index];
                            final info = archiveMediaFileInfo(option);
                            final formats = archiveStreamFormats(option);
                            final current = index == _currentIndex;
                            return GestureDetector(
                              onTap: () => _select(index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: EdgeInsets.all(_compact ? 8 : 12),
                                decoration: RefinedFinish.decorate(
                                    context,
                                    BoxDecoration(
                                      color: index == _index
                                          ? scheme.primary
                                              .withValues(alpha: 0.2)
                                          : Colors.white
                                              .withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: index == _index
                                              ? scheme.primary
                                              : current
                                                  ? Colors.amber
                                                  : Colors.white24,
                                          width: index == _index
                                              ? 2
                                              : current
                                                  ? 1.2
                                                  : 1),
                                    ),
                                    focused: index == _index),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(info.source,
                                              maxLines: _compact ? 1 : 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: _compact ? 14 : 16,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      if (current)
                                        GoldTag(
                                            label: tr('Current stream'),
                                            compact: true,
                                            margin:
                                                const EdgeInsets.only(left: 6)),
                                    ]),
                                    SizedBox(height: _compact ? 4 : 6),
                                    if (formats.isNotEmpty)
                                      Text(formats.join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: _compact ? 11 : 13)),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Text(
                                          archiveStreamLabel(
                                              option.stream.title ?? ''),
                                          maxLines: _compact ? 1 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: _compact ? 11 : 12)),
                                    ),
                                    Text(
                                        info.formattedSize == null
                                            ? tr('Size unknown')
                                            : tr('File size: {size}',
                                                {'size': info.formattedSize!}),
                                        style: TextStyle(
                                            fontSize: _compact ? 12 : 14)),
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
