import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_service.dart';
import '../services/storage_service.dart';
import '../services/vesper_ai/watch_list.dart';
import '../widgets/poster_card.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';

/// Media Hub > Watch list: the viewer's Media Hub titles on their watch
/// list (Watch list button on a movie / show page, or Vesper AI), in two
/// rows, Movies and TV Shows. OK opens the title, hold OK takes it off.
class ArchiveWatchListScreen extends StatefulWidget {
  const ArchiveWatchListScreen({super.key});

  @override
  State<ArchiveWatchListScreen> createState() => _ArchiveWatchListScreenState();
}

class _ArchiveWatchListScreenState extends State<ArchiveWatchListScreen> {
  static const _cardWidth = 120.0;
  static const _posterHeight = 172.0;

  final _movieNodes = <FocusNode>[];
  final _showNodes = <FocusNode>[];
  bool _focusedOnce = false;

  @override
  void initState() {
    super.initState();
    WatchList.instance.changes.addListener(_changed);
  }

  @override
  void dispose() {
    WatchList.instance.changes.removeListener(_changed);
    for (final n in [..._movieNodes, ..._showNodes]) {
      n.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// One node per card, kept across rebuilds (a removed card's node stays
  /// unused until the row grows again).
  List<FocusNode> _nodes(List<FocusNode> pool, int count, String label) {
    while (pool.length < count) {
      pool.add(FocusNode(debugLabel: '$label-${pool.length}'));
    }
    return pool;
  }

  Future<void> _open(HubTitle title, ArchiveSource? source) async {
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr("This title's Media Hub source is not available."))));
      return;
    }
    if (title.meta.type == ArchiveType.series) {
      await openArchiveSeries(context, source, title.meta);
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ArchiveDetailScreen(source: source, preview: title.meta)));
    }
  }

  Future<void> _remove(WatchListItem item) async {
    await WatchList.instance.remove(context.read<StorageService>(), item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('Removed from watch list')),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Up / Down between the two rows, to the card in the same position (or
  /// the row's last one). Left / Right stay inside the row.
  KeyEventResult _onRowKey(
      KeyEvent event, int row, List<List<FocusNode>> rows) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final delta = key == LogicalKeyboardKey.arrowDown
        ? 1
        : key == LogicalKeyboardKey.arrowUp
            ? -1
            : 0;
    if (delta == 0) return KeyEventResult.ignored;
    final target = row + delta;
    if (target < 0 || target >= rows.length || rows[target].isEmpty) {
      return KeyEventResult.handled;
    }
    final index = rows[row].indexWhere((n) => n.hasFocus);
    final next = rows[target][index.clamp(0, rows[target].length - 1)];
    next.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final hub = context.watch<ArchiveService>();
    final byUrl = {for (final s in hub.enabledSources) s.manifestUrl: s};
    final items = [
      for (final i in WatchList.instance.load(storage))
        if (i.hub != null) i
    ];
    final movies = items.where((i) => !i.isShow).toList();
    final shows = items.where((i) => i.isShow).toList();
    final movieNodes = _nodes(_movieNodes, movies.length, 'hub-watch-movie')
        .take(movies.length)
        .toList();
    final showNodes = _nodes(_showNodes, shows.length, 'hub-watch-show')
        .take(shows.length)
        .toList();
    final rows = [
      if (movies.isNotEmpty) movieNodes,
      if (shows.isNotEmpty) showNodes,
    ];
    if (!_focusedOnce && rows.isNotEmpty) {
      _focusedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && rows.first.first.context != null) {
          rows.first.first.requestFocus();
        }
      });
    }

    Widget section(String title, List<WatchListItem> list,
        List<FocusNode> nodes, int rowIndex) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('$title (${list.length})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            height: _posterHeight +
                PosterCard.titleHeight * (_cardWidth / PosterCard.width) +
                16,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (_, e) => _onRowKey(e, rowIndex, rows),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final item = list[i];
                  final title = item.hub!;
                  return PosterCard(
                    title: title.meta.name,
                    imageUrl: title.meta.posterUrl,
                    rating: title.meta.rating,
                    cardWidth: _cardWidth,
                    cardPosterHeight: _posterHeight,
                    focusNode: nodes[i],
                    onTap: () => _open(title, byUrl[title.sourceUrl]),
                    onToggleFavorite: () => _remove(item),
                    onFocusGained: () {
                      final ctx = nodes[i].context;
                      if (ctx != null) {
                        Scrollable.ensureVisible(ctx,
                            alignmentPolicy:
                                ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(tr('Watch list')),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Nothing on your watch list yet. Open a movie or show and choose Watch list.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : ListView(
              children: [
                if (movies.isNotEmpty)
                  section(tr('Movies'), movies, movieNodes, 0),
                if (shows.isNotEmpty)
                  section(tr('TV Shows'), shows, showNodes,
                      movies.isNotEmpty ? 1 : 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Text(
                    tr('Hold OK on a title to take it off the list.'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
