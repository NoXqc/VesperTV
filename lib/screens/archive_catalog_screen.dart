import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_service.dart';
import '../utils/tv_theme.dart';
import '../widgets/poster_card.dart';
import '../widgets/settings_scaffold.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';

/// One Media Hub row (Popular / New / Featured / Recently watched / a
/// source's catalog) expanded into a full poster grid — "Expand catalog" in
/// the menu that rolls down when a floating-bar row button is held (see
/// `_ArchiveScreenState._showRowMenu`). The Media Hub twin of the IPTV
/// [GroupCatalogScreen]: a pushed route, so Back is just Navigator's pop.
///
/// Reads the row live from [ArchiveService] by key, so pages appended by
/// [ArchiveService.loadMore] (asked for as focus nears the end) show up in
/// place; the grid keeps whatever order the source sent.
class ArchiveCatalogScreen extends StatefulWidget {
  const ArchiveCatalogScreen({
    super.key,
    required this.type,
    required this.rowKey,
    required this.title,
  });

  final ArchiveType type;

  /// [ArchiveRow.key] of the expanded row.
  final String rowKey;
  final String title;

  @override
  State<ArchiveCatalogScreen> createState() => _ArchiveCatalogScreenState();
}

class _ArchiveCatalogScreenState extends State<ArchiveCatalogScreen> {
  /// The first poster takes focus on entry — the lazy grid otherwise left
  /// the remote with nothing (or a random visible card) focused.
  final FocusNode _firstPoster = FocusNode(debugLabel: 'archive-grid-first');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstPoster.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstPoster.dispose();
    super.dispose();
  }

  void _open(ArchiveSource source, ArchiveMeta meta) {
    if (meta.type == ArchiveType.series) {
      openArchiveSeries(context, source, meta);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveDetailScreen(source: source, preview: meta)));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    ArchiveRow? row;
    for (final r in service.rows(widget.type)) {
      if (r.key == widget.rowKey) row = r;
    }
    final items = row?.items ?? const <ArchiveMeta>[];
    final touchPreview = Theme.of(context).platform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width < 700;
    return withTvThemeIfNeeded(
      context,
      (context) => Stack(
        children: [
          const Positioned.fill(child: SettingsGradientBackground()),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Text(
                  items.isEmpty
                      ? widget.title
                      : '${widget.title} · ${items.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            body: row == null || items.isEmpty
                ? Center(child: Text(tr('No items in this group.')))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: PosterCard.width + 12,
                      mainAxisExtent: PosterCard.height + 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final current = row!;
                      final meta = items[i];
                      return PosterCard(
                        focusNode: i == 0 ? _firstPoster : null,
                        title: meta.name,
                        imageUrl: meta.posterUrl,
                        rating: meta.year,
                        tapToPreview: touchPreview,
                        onTap: () => _open(current.sourceAt(i), meta),
                        // Hold OK on a watched title: out of the history
                        // (same as the row it came from).
                        onToggleFavorite: current.isHistory
                            ? () => context
                                .read<ArchiveService>()
                                .removeFromHistory(current.sourceAt(i), meta)
                            : null,
                        onFocusGained: () {
                          // A grid row holds several cards: ask for the
                          // next page a few rows before the end.
                          if (i >= items.length - 24) {
                            context.read<ArchiveService>().loadMore(current);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
