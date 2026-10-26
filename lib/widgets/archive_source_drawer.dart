import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_service.dart';
import '../services/archive_stream_size.dart';

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
          width: math.min(500, MediaQuery.sizeOf(context).width * 0.9),
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
  static const _rowHeight = 186.0;
  final _focus = FocusNode(debugLabel: 'media-hub-source-drawer');
  final _scroll = ScrollController();
  List<ArchiveStreamOption> _options = const [];
  bool _loading = true;
  bool _selecting = false;
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  bool _isCurrent(ArchiveStreamOption option) {
    final current = widget.sources.current(widget.channelId);
    if (current == null ||
        current.source.manifestUrl != option.source.manifestUrl) {
      return false;
    }
    if (current.stream.identity == option.stream.identity) return true;
    // A provider can refresh a signed URL between opening playback and this
    // drawer. Match metadata only when it identifies one file unambiguously.
    bool sameDescription(ArchiveStreamOption candidate) =>
        candidate.source.manifestUrl == current.source.manifestUrl &&
        candidate.stream.name == current.stream.name &&
        candidate.stream.title == current.stream.title;
    return ((current.stream.name ?? '').isNotEmpty ||
            (current.stream.title ?? '').isNotEmpty) &&
        sameDescription(option) &&
        _options.where(sameDescription).length == 1;
  }

  Future<void> _load() async {
    try {
      final options = await widget.sources.load(widget.channelId);
      if (!mounted) return;
      setState(() {
        _options = options.where((o) => o.stream.ytId == null).toList();
        _index = math.max(0, _options.indexWhere(_isCurrent));
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
    if (_selecting || _loading || index >= _options.length) return;
    final option = _options[index];
    if (_isCurrent(option)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _selecting = true;
      _index = index;
      _error = null;
    });
    try {
      final channel = await widget.sources.select(widget.channelId, option);
      if (!mounted) return;
      if (channel == null) throw StateError('Selection no longer current');
      Navigator.of(context).pop(ArchiveSourceSelection(channel, option));
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
      Navigator.of(context).pop();
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
      color: const Color(0xF011131A),
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
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                ExcludeFocus(
                  child: IconButton(
                      tooltip: tr('Close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(tr('Up/Down: browse · OK: switch · Back: close'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                            final current = _isCurrent(option);
                            return GestureDetector(
                              onTap: () => _select(index),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: index == _index
                                      ? scheme.primary.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: index == _index
                                          ? scheme.primary
                                          : Colors.white24,
                                      width: index == _index ? 2 : 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      if (current)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: Icon(Icons.check_circle,
                                              color: scheme.primary, size: 20),
                                        ),
                                      Expanded(
                                          child: Text(info.source,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ]),
                                    if (current)
                                      Text(tr('Current stream'),
                                          style: TextStyle(
                                              color: scheme.primary,
                                              fontSize: 11)),
                                    const SizedBox(height: 6),
                                    if (formats.isNotEmpty)
                                      Text(formats.join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Text(
                                          archiveStreamLabel(
                                              option.stream.title ?? ''),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                    ),
                                    Text(info.formattedSize == null
                                        ? tr('Size unknown')
                                        : tr('File size: {size}',
                                            {'size': info.formattedSize!})),
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
