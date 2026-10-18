import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_service.dart';
import '../widgets/detail_header.dart';
import '../widgets/live_resume_hint.dart';
import '../widgets/poster_card.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';
import 'settings/archive_sources_screen.dart';

/// The Archive tab: classic, public-domain films and series from the
/// user's own sources (Settings > Archive sources, any server speaking the
/// Stremio catalog/stream schema). Same shape as Movies/TV Shows — a rail
/// on the left (Movies / TV Shows, then each catalog as a jump target), a
/// hero with the focused title's backdrop and description, and one
/// [PosterCard] row per catalog. Its own page (like Sports Trak), not a
/// column of TvHomeScreen: nothing here belongs to a playlist.
///
/// D-pad: explicit dispatch inside the rows (Up/Down = neighbour row at
/// its remembered card, Left on the first card = rail), per CLAUDE.md's
/// rule that default traversal is unreliable across differently shaped
/// rows. Rows are a non-lazy Column so a neighbour row's card always has
/// a context to focus; each row's cards are lazy horizontally, so moving
/// along a row jumps its own scroll controller to the card first (a card
/// the list hasn't built can't take focus), and nearing the end of a row
/// loads its next page. Search (rail) puts the results first.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  ArchiveType _type = ArchiveType.movie;
  final _railScope = FocusScopeNode(debugLabel: 'archive-rail');
  final _contentScope = FocusScopeNode(debugLabel: 'archive-content');
  final _firstRailNode = FocusNode(debugLabel: 'archive-rail-first');
  final _emptyActionNode = FocusNode(debugLabel: 'archive-empty-action');
  final _scroll = ScrollController();

  /// Card focus nodes by row key, created on demand.
  final Map<String, List<FocusNode>> _nodes = {};

  /// Last focused card index per row, so Up/Down lands where you were.
  final Map<String, int> _lastIndex = {};
  final Map<String, GlobalKey> _rowKeys = {};
  final Map<String, ScrollController> _rowScrolls = {};

  int _focusedRow = 0;
  ArchiveMeta? _focused;
  ArchiveSource? _focusedSource;
  late final VoidCallback _releaseResumeHint;

  @override
  void initState() {
    super.initState();
    _releaseResumeHint = LiveResumeHint.hideWhileMounted();
    // PopScope's canPop reads _contentScope.hasFocus at build time; moving
    // focus rows -> rail doesn't rebuild by itself, which left Back stuck
    // sending focus to the rail forever. Rebuild whenever that flips.
    _contentScope.addListener(_onContentFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ArchiveService>().open();
      _firstRailNode.requestFocus();
    });
  }

  bool _contentHadFocus = false;

  void _onContentFocus() {
    final has = _contentScope.hasFocus;
    if (has == _contentHadFocus || !mounted) return;
    _contentHadFocus = has;
    setState(() {});
  }

  @override
  void dispose() {
    _contentScope.removeListener(_onContentFocus);
    _releaseResumeHint();
    _railScope.dispose();
    _contentScope.dispose();
    _firstRailNode.dispose();
    _emptyActionNode.dispose();
    _scroll.dispose();
    for (final c in _rowScrolls.values) {
      c.dispose();
    }
    for (final list in _nodes.values) {
      for (final n in list) {
        n.dispose();
      }
    }
    super.dispose();
  }

  FocusNode _node(String rowKey, int i) {
    final list = _nodes.putIfAbsent(rowKey, () => []);
    while (list.length <= i) {
      list.add(FocusNode(debugLabel: 'archive-card'));
    }
    return list[i];
  }

  GlobalKey _rowKey(String key) => _rowKeys.putIfAbsent(key, GlobalKey.new);

  ScrollController _rowScroll(String key) =>
      _rowScrolls.putIfAbsent(key, ScrollController.new);

  /// Card slot width in a row: the card plus its 4 px padding each side.
  static const _cardExtent = PosterCard.width + 8;
  static const _rowPadding = 20.0;

  /// Scrolls [row] so card [i] is on screen (with a card of room past it),
  /// then focuses it — after a frame when the jump had to build it.
  void _focusCard(ArchiveRow row, int i) {
    final c = _rowScrolls[row.key];
    if (c != null && c.hasClients) {
      final pos = c.position;
      final start = _rowPadding + i * _cardExtent;
      double? to;
      if (start - _cardExtent < pos.pixels) {
        to = start - _cardExtent;
      } else if (start + 2 * _cardExtent > pos.pixels + pos.viewportDimension) {
        to = start + 2 * _cardExtent - pos.viewportDimension;
      }
      if (to != null) c.jumpTo(to.clamp(0.0, pos.maxScrollExtent));
    }
    final node = _node(row.key, i);
    if (node.context != null) {
      node.requestFocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) node.requestFocus();
      });
    }
  }

  /// Provider rows ("Popular", "New", "Featured") are translated; a
  /// source's own catalog names are shown as sent.
  String _rowTitle(ArchiveRow row) {
    if (row.isSearch) {
      return tr('Results for "{query}"', {'query': row.searchQuery});
    }
    return row.source.streamOnly ? tr(row.title) : row.title;
  }

  Future<void> _openSearch(ArchiveService service) async {
    final type = _type;
    final controller =
        TextEditingController(text: service.searchQuery(type) ?? '');
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == ArchiveType.movie
            ? tr('Search movies')
            : tr('Search TV shows')),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
                hintText: tr('Title'), prefixIcon: const Icon(Icons.search)),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('Cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(tr('Search'))),
        ],
      ),
    );
    if (query == null || query.trim().isEmpty || !mounted) return;
    setState(() => _focusedRow = 0);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await service.search(type, query);
    if (!mounted || type != _type) return;
    final rows = service.rows(type);
    if (rows.isNotEmpty && rows.first.isSearch) {
      _lastIndex[rows.first.key] = 0;
      _rowScrolls[rows.first.key]?.jumpTo(0);
      _focusRow(rows, 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr('No results for "{query}"', {'query': query.trim()}))));
    }
  }

  void _clearSearch(ArchiveService service) {
    setState(() => _focusedRow = 0);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    service.clearSearch(_type);
  }

  void _setType(ArchiveType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _focusedRow = 0;
      _focused = null;
      _focusedSource = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Focuses row [r]'s remembered card and scrolls the row into view.
  void _focusRow(List<ArchiveRow> rows, int r) {
    if (rows.isEmpty) return;
    r = r.clamp(0, rows.length - 1);
    final row = rows[r];
    final i = (_lastIndex[row.key] ?? 0).clamp(0, row.items.length - 1);
    final ctx = _rowKey(row.key).currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.05);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCard(row, i);
    });
  }

  KeyEventResult _onContentKey(
      List<ArchiveRow> rows, FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (rows.isEmpty) return KeyEventResult.ignored;
    final row = rows[_focusedRow.clamp(0, rows.length - 1)];
    final i = _lastIndex[row.key] ?? 0;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusedRow < rows.length - 1) _focusRow(rows, _focusedRow + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedRow > 0) _focusRow(rows, _focusedRow - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < row.items.length - 1) _focusCard(row, i + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) {
        _focusCard(row, i - 1);
      } else {
        _railScope.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Shows open the regular series page (episode cards, Play SxEy);
  /// movies the Archive movie page.
  void _open(ArchiveSource source, ArchiveMeta meta) {
    if (meta.type == ArchiveType.series) {
      openArchiveSeries(context, source, meta);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveDetailScreen(source: source, preview: meta)));
  }

  void _openSources() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ArchiveSourcesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final rows = service.rows(_type);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final scheme = Theme.of(context).colorScheme;

    final focused = _focused;
    final backdrop = focused?.backgroundUrl ?? focused?.posterUrl;

    return PopScope(
      // Back from the rows goes to the rail first, then leaves.
      canPop: !_contentScope.hasFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_contentScope.hasFocus) {
          _railScope.requestFocus();
        } else {
          // canPop was stale (built while the rows had focus): leave anyway.
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (backdrop != null)
              Positioned(
                top: 0,
                right: 0,
                left: narrow ? 0 : MediaQuery.sizeOf(context).width * 0.35,
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: DetailBackdrop(url: backdrop, fadeLeft: true),
              ),
            SafeArea(
              child: narrow
                  ? Column(children: [
                      _buildTopBar(service),
                      Expanded(child: _buildContent(service, rows, scheme)),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 190, child: _buildRail(service, rows)),
                        Expanded(child: _buildContent(service, rows, scheme)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(ArchiveService service, List<ArchiveRow> rows) {
    return FocusScope(
      node: _railScope,
      child: Focus(
        // Right from anywhere in the rail = into the rows.
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (rows.isNotEmpty) {
              _focusRow(rows, _focusedRow);
            } else if (_emptyActionNode.context != null) {
              _emptyActionNode.requestFocus();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Text(tr('Extras'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              _RailTile(
                focusNode: _firstRailNode,
                icon: Icons.movie,
                label: tr('Movies'),
                selected: _type == ArchiveType.movie,
                onTap: () => _setType(ArchiveType.movie),
              ),
              _RailTile(
                icon: Icons.video_library,
                label: tr('TV Shows'),
                selected: _type == ArchiveType.series,
                onTap: () => _setType(ArchiveType.series),
              ),
              if (service.canSearch(_type)) ...[
                _RailTile(
                  icon: Icons.search,
                  label: service.searching
                      ? tr('Searching…')
                      : service.searchQuery(_type) ?? tr('Search'),
                  selected: service.searchQuery(_type) != null,
                  onTap: () => _openSearch(service),
                ),
                if (service.searchQuery(_type) != null)
                  _RailTile(
                    icon: Icons.close,
                    label: tr('Clear search'),
                    small: true,
                    onTap: () => _clearSearch(service),
                  ),
              ],
              const Divider(height: 20, color: Colors.white24),
              for (var r = 0; r < rows.length; r++)
                _RailTile(
                  icon:
                      rows[r].isSearch ? Icons.search : Icons.grid_view_rounded,
                  label: _rowTitle(rows[r]),
                  small: true,
                  onTap: () => _focusRow(rows, r),
                ),
              if (rows.isNotEmpty)
                const Divider(height: 20, color: Colors.white24),
              _RailTile(
                icon: Icons.refresh,
                label: service.refreshing ? tr('Updating…') : tr('Refresh'),
                small: true,
                onTap: () => service.refresh(force: true),
              ),
              _RailTile(
                icon: Icons.extension_outlined,
                label: tr('Extras sources'),
                small: true,
                onTap: _openSources,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Phone / narrow window: the rail's two choices + sources as a row.
  Widget _buildTopBar(ArchiveService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: FocusScope(
        node: _railScope,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _RailTile(
                  focusNode: _firstRailNode,
                  icon: Icons.movie,
                  label: tr('Movies'),
                  selected: _type == ArchiveType.movie,
                  onTap: () => _setType(ArchiveType.movie),
                ),
                const SizedBox(width: 8),
                _RailTile(
                  icon: Icons.video_library,
                  label: tr('TV Shows'),
                  selected: _type == ArchiveType.series,
                  onTap: () => _setType(ArchiveType.series),
                ),
              ]),
            ),
          ),
          if (service.canSearch(_type))
            IconButton(
              icon: Icon(service.searchQuery(_type) == null
                  ? Icons.search
                  : Icons.search_off),
              onPressed: () => service.searchQuery(_type) == null
                  ? _openSearch(service)
                  : _clearSearch(service),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.refresh(force: true),
          ),
          IconButton(
            icon: const Icon(Icons.extension_outlined),
            onPressed: _openSources,
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(
      ArchiveService service, List<ArchiveRow> rows, ColorScheme scheme) {
    if (service.sources.isEmpty) {
      return _EmptyState(
        text: tr(
            'Add a source to browse films and series. Any source that follows the catalog/stream add-on format works.'),
        action: tr('Add a source'),
        onAction: _openSources,
        focusNode: _emptyActionNode,
      );
    }
    if (rows.isEmpty) {
      if (service.refreshing) {
        return const Center(child: CircularProgressIndicator());
      }
      return _EmptyState(
        text: service.hasAny(_type)
            ? (service.lastError != null
                ? tr("Couldn't load the catalog: {error}",
                    {'error': service.lastError})
                : tr('Nothing here yet.'))
            : (_type == ArchiveType.movie
                ? tr('None of your sources has movies.')
                : tr('None of your sources has TV shows.')),
        action: tr('Refresh'),
        onAction: () => service.refresh(force: true),
        focusNode: _emptyActionNode,
      );
    }

    final focused = _focused;
    return FocusScope(
      node: _contentScope,
      child: Focus(
        onKeyEvent: (node, e) => _onContentKey(rows, node, e),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero: the focused title.
            SizedBox(
              height: 150,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: focused == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(focused.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4, children: [
                            if (focused.year != null)
                              DetailMetaChip(
                                  scale: 1, label: focused.year!, strong: true),
                            if (focused.runtime != null)
                              DetailMetaChip(scale: 1, label: focused.runtime!),
                            for (final g in focused.genres.take(3))
                              DetailMetaChip(scale: 1, label: g),
                            if (_focusedSource != null)
                              DetailMetaChip(
                                  scale: 1, label: _focusedSource!.name),
                          ]),
                          const SizedBox(height: 8),
                          if (focused.description != null)
                            Flexible(
                              child: SizedBox(
                                width: 560,
                                child: Text(focused.description!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white70)),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var r = 0; r < rows.length; r++)
                      _buildRow(rows, r, scheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<ArchiveRow> rows, int r, ColorScheme scheme) {
    final row = rows[r];
    return Column(
      key: _rowKey(row.key),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Text(_rowTitle(row),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: r == _focusedRow && _contentScope.hasFocus
                      ? scheme.primary
                      : Colors.white)),
        ),
        SizedBox(
          height: PosterCard.height + 16,
          child: ListView.builder(
            controller: _rowScroll(row.key),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
            itemCount: row.items.length,
            itemBuilder: (_, i) {
              final meta = row.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: PosterCard(
                  focusNode: _node(row.key, i),
                  title: meta.name,
                  imageUrl: meta.posterUrl,
                  rating: meta.year,
                  tapToPreview:
                      Theme.of(context).platform == TargetPlatform.android &&
                          MediaQuery.sizeOf(context).width < 700,
                  onTap: () => _open(row.source, meta),
                  onFocusGained: () {
                    _lastIndex[row.key] = i;
                    if (i >= row.items.length - 12) {
                      context.read<ArchiveService>().loadMore(row);
                    }
                    if (_focused?.id == meta.id && _focusedRow == r) return;
                    setState(() {
                      _focusedRow = r;
                      _focused = meta;
                      _focusedSource = row.source;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A rail row: same focus look as the detail pages' pills.
class _RailTile extends StatefulWidget {
  const _RailTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.small = false,
    this.focusNode,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool small;
  final FocusNode? focusNode;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = (_focused || widget.selected) ? scheme.primary : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 10, vertical: widget.small ? 7 : 10),
          decoration: detailFocusDecoration(scheme,
              focused: _focused, selected: widget.selected, radius: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: widget.small ? 16 : 20, color: fg),
            const SizedBox(width: 10),
            Flexible(
              child: Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg,
                      fontSize: widget.small ? 13 : 15,
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.text,
      required this.action,
      required this.onAction,
      required this.focusNode});

  final FocusNode focusNode;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_movies_outlined,
              size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
              focusNode: focusNode, onPressed: onAction, child: Text(action)),
        ]),
      ),
    );
  }
}
