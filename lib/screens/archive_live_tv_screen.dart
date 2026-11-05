import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/channel.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_service.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import 'desktop_player_screen.dart';
import 'player_screen.dart';

/// One row of Media Hub > Live TV: a TV add-on catalog, or one genre of it.
class LiveTvRow {
  const LiveTvRow(this.source, this.title, this.metas);
  final ArchiveSource source;
  final String title;
  final List<ArchiveMeta> metas;
}

/// [catalog]'s channels as rows: one per genre the manifest offers (in its
/// order; a channel can sit in several), then all of them. A catalog
/// without genre options (or with one row's worth) stays a single row.
List<LiveTvRow> liveTvRowsFor(
    ArchiveSource source, ArchiveCatalog catalog, List<ArchiveMeta> metas) {
  if (metas.isEmpty) return const [];
  final all = LiveTvRow(source, catalog.name, metas);
  if (catalog.genres.isEmpty || metas.length <= 30) return [all];
  return [
    for (final genre in catalog.genres)
      if (metas.where((m) => m.genres.contains(genre)).toList()
          case final list when list.isNotEmpty)
        LiveTvRow(source, '${catalog.name} · $genre', list),
    all,
  ];
}

/// Media Hub > Live TV (owner, 2026-11-05): the channels of the user's TV
/// add-ons ([ArchiveSource.isLiveTv]: Stremio `tv`/`channel` types, or the
/// "TV add-on" switch), as rows of channel tiles. OK plays full screen as a
/// live channel: Up/Down zap through the row, no resume or history.
///
/// One focus target with a virtual cursor (row, column) instead of a node
/// per tile: a TV add-on can list well over a thousand channels, and lazy
/// rows can't focus a tile they haven't built (CLAUDE.md §10).
class ArchiveLiveTvScreen extends StatefulWidget {
  const ArchiveLiveTvScreen({super.key});

  @override
  State<ArchiveLiveTvScreen> createState() => _ArchiveLiveTvScreenState();
}

class _ArchiveLiveTvScreenState extends State<ArchiveLiveTvScreen> {
  static const _rowExtent = 168.0;
  static const _tileExtent = 188.0;

  List<LiveTvRow>? _rows;
  int _row = 0;
  final Map<int, int> _cols = {};
  final _vertical = ScrollController();
  final Map<int, ScrollController> _horizontal = {};
  String? _starting;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _vertical.dispose();
    for (final c in _horizontal.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<ArchiveService>();
    final jobs = [
      for (final s in service.liveTvSources)
        for (final c in s.catalogs)
          if (!c.searchOnly)
            service
                .liveCatalog(s, c)
                .timeout(const Duration(seconds: 25))
                .then((metas) => liveTvRowsFor(s, c, metas))
                .catchError((Object e) {
              debugPrint('HubLive: catalog failed ${e.runtimeType}');
              return const <LiveTvRow>[];
            }),
    ];
    final rows = [for (final r in await Future.wait(jobs)) ...r];
    if (mounted) setState(() => _rows = rows);
  }

  int _col(int row) => _cols[row] ?? 0;

  ScrollController _hFor(int row) =>
      _horizontal.putIfAbsent(row, () => ScrollController());

  /// Jumps (never animates, CLAUDE.md §10) so the cursor's tile is on screen.
  void _reveal() {
    void keep(ScrollController c, double start, double extent) {
      if (!c.hasClients) return;
      final p = c.position;
      if (start < p.pixels) {
        c.jumpTo(start.clamp(0, p.maxScrollExtent));
      } else if (start + extent > p.pixels + p.viewportDimension) {
        c.jumpTo((start + extent - p.viewportDimension)
            .clamp(0, p.maxScrollExtent));
      }
    }

    keep(_vertical, _row * _rowExtent, _rowExtent);
    keep(_hFor(_row), _col(_row) * _tileExtent, _tileExtent);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final rows = _rows;
    if (event is KeyUpEvent || rows == null || rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = rows[_row].metas.length;
    void move(int row, int col) {
      setState(() {
        _row = row.clamp(0, rows.length - 1);
        _cols[_row] = col.clamp(0, rows[_row].metas.length - 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      move(_row, _col(_row) + 1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      move(_row, _col(_row) - 1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      move(_row + 1, _col(_row + 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      move(_row - 1, _col(_row - 1));
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      if (count > 0) unawaited(_play(rows[_row], _col(_row)));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _play(LiveTvRow row, int index) async {
    if (_starting != null) return;
    final service = context.read<ArchiveService>();
    final playback = context.read<PlaybackService>();
    final channels = [
      for (final m in row.metas)
        service.liveChannelFor(row.source, m, group: row.title)
    ];
    final target = channels[index];
    setState(() => _starting = target.id);
    try {
      final options = await service.liveStreams(target.id);
      if (!mounted) return;
      if (options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('No playable stream for this title.'))));
        return;
      }
      // The add-on's first stream, like a TV channel; others are in the
      // player's Sources (options row).
      final picked = options.first;
      final channel = await ArchiveService.withLiveStream(target, picked);
      if (!mounted) return;
      final selected = <String, ArchiveStreamOption>{channel.id: picked};
      Channel? byId(String id) => channels.where((c) => c.id == id).firstOrNull;
      final sources = ArchivePlaybackSources(
        load: service.liveStreams,
        current: (id) => selected[id],
        select: (id, option) async {
          final base = byId(id);
          return base == null
              ? null
              : ArchiveService.withLiveStream(base, option);
        },
        remember: (id, option) async => selected[id] = option,
      );
      playback.zapList = channels;
      playback.resolveLive = service.resolveLive;
      if (Platform.isWindows) {
        DesktopMiniPlayer.instance.clear();
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                DesktopPlayerScreen(channel: channel, sources: sources)));
      } else {
        await playback.play(channel);
        if (!mounted) return;
        await Navigator.of(context).push(PlayerPageRoute(
            builder: (_) => PlayerScreen(channel: channel, sources: sources)));
      }
    } catch (e) {
      debugPrint('HubLive: play failed ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('No playable stream for this title.'))));
      }
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(tr('Live TV')),
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: rows == null
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr('No live channels. In Media Hub sources, turn on TV add-on for a source of live channels.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _vertical,
                    itemExtent: _rowExtent,
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _buildRow(rows[i], i),
                  ),
      ),
    );
  }

  Widget _buildRow(LiveTvRow row, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            '${row.title} · ${tr('{n} channels', {
                  'n': row.metas.length
                })}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: index == _row ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _hFor(index),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemExtent: _tileExtent,
            itemCount: row.metas.length,
            itemBuilder: (context, i) => _tile(row, index, i),
          ),
        ),
      ],
    );
  }

  Widget _tile(LiveTvRow row, int rowIndex, int i) {
    final meta = row.metas[i];
    final selected = rowIndex == _row && i == _col(rowIndex);
    final accent = Theme.of(context).colorScheme.primary;
    final image = meta.logoUrl ?? meta.posterUrl;
    return GestureDetector(
      onTap: () {
        setState(() {
          _row = rowIndex;
          _cols[rowIndex] = i;
        });
        unawaited(_play(row, i));
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: selected ? accent : Colors.transparent, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null && image.isNotEmpty)
                      Image.network(
                        image,
                        fit: BoxFit.contain,
                        cacheWidth: 360,
                        errorBuilder: (_, __, ___) => const Icon(Icons.live_tv,
                            color: Colors.white38, size: 36),
                      )
                    else
                      const Icon(Icons.live_tv,
                          color: Colors.white38, size: 36),
                    if (_starting != null &&
                        selected &&
                        _starting!.isNotEmpty)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                            child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3))),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
