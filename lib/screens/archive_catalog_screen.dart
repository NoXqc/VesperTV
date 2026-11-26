import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/hub_collection.dart';
import '../services/app_preferences.dart';
import '../services/archive_ready_watch.dart';
import '../services/archive_service.dart';
import '../utils/display_title.dart';
import '../utils/hub_title_order.dart';
import '../utils/tv_theme.dart';
import '../widgets/card_trailer.dart';
import '../widgets/detail_header.dart';
import '../widgets/glass_menu.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/ink_layer.dart';
import '../widgets/poster_card.dart';
import '../widgets/title_hold_menu.dart';
import '../widgets/tv_dialog_option.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';
import 'hub_folder_screen.dart';

/// One Media Hub row (Popular / New / Featured / Recently watched / a
/// source's catalog) expanded into a full poster grid — "Expand catalog" in
/// the menu that rolls down when a floating-bar row button is held (see
/// `_ArchiveScreenState._showRowMenu`). The Media Hub twin of the IPTV
/// [GroupCatalogScreen]: a pushed route, so Back is just Navigator's pop.
///
/// Reads the row live from [ArchiveService] by key, so pages appended by
/// [ArchiveService.loadMore] (asked for as focus nears the end) show up in
/// place; the grid keeps whatever order the source sent.
///
/// [ArchiveCatalogScreen.folder]: a collection tile (Netflix, Disney+...)
/// expanded instead: every title of all its catalogs in one grid, each
/// title once (hold OK on the tile, Media Hub tab and Home).
///
/// Settings > Interface > Tabs > Wide cards gives 16:9 backdrop cards, as
/// in the IPTV Movies / TV Shows expanded catalog.
class ArchiveCatalogScreen extends StatefulWidget {
  const ArchiveCatalogScreen({
    super.key,
    required ArchiveType this.type,
    required String this.rowKey,
    required this.title,
  }) : folder = null;

  ArchiveCatalogScreen.folder({
    super.key,
    required HubFolder this.folder,
    String? collection,
  })  : type = null,
        rowKey = null,
        title = collection == null || collection.isEmpty
            ? folder.title
            : '$collection   ·   ${folder.title}';

  final ArchiveType? type;

  /// [ArchiveRow.key] of the expanded row.
  final String? rowKey;
  final String title;

  /// The expanded collection tile (instead of [rowKey]).
  final HubFolder? folder;

  @override
  State<ArchiveCatalogScreen> createState() => _ArchiveCatalogScreenState();
}

class _ArchiveCatalogScreenState extends State<ArchiveCatalogScreen> {
  /// The first poster takes focus on entry — the lazy grid otherwise left
  /// the remote with nothing (or a random visible card) focused.
  final FocusNode _firstPoster = FocusNode(debugLabel: 'archive-grid-first');

  /// The focused title, shown full screen behind the grid like the IPTV
  /// expanded catalog (owner, 1.0.51). A notifier: moving focus must not
  /// rebuild the grid.
  final ValueNotifier<ArchiveMeta?> _spot = ValueNotifier(null);

  /// Settings > Playback > Trailers on Media Hub cards with Wide cards on
  /// (owner, 2026-11-26: "Inside the focused card"): the focused 16:9 card
  /// plays the title's trailer. A poster grid plays none.
  final _cardTrailer = CardTrailerSlot();

  void _armCardTrailer(
      int i, ArchiveMeta meta, ArchiveSource source, bool wide) {
    if (!wide || !CardTrailer.enabledIn(context)) {
      _cardTrailer.stop();
      return;
    }
    final node = FocusManager.instance.primaryFocus;
    _cardTrailer.arm(
        place: 'grid:$i',
        id: meta.id,
        stillHere: () =>
            mounted && (node?.hasFocus ?? false) && _focusIndex == i,
        find: () => CardTrailer.findIn(context, meta, source));
  }

  /// A tile mixing movies and shows: All / Movies / TV Shows at the top
  /// (owner: no way to tell them apart). null = All.
  ArchiveType? _type;

  /// Sort ▾ and Filter ▾ (owner, 2026-11-13: Latest / Popular / Year): the
  /// order, and one choice per filter kind (a tile's catalog, a genre, a
  /// decade). Kept per tile / row for the app run, like the type.
  HubSort _sort = HubSort.source;
  String? _catalog;
  String? _genre;
  int? _decade;
  static final Map<String, _GridChoice> _last = {};

  /// All, Movies, TV Shows.
  static const _types = <ArchiveType?>[
    null,
    ArchiveType.movie,
    ArchiveType.series
  ];
  final FocusNode _sortNode = FocusNode(debugLabel: 'archive-grid-sort');
  final FocusNode _filtersNode = FocusNode(debugLabel: 'archive-grid-filters');
  final List<FocusNode> _typeNodes = [
    for (var i = 0; i < 3; i++) FocusNode(debugLabel: 'archive-grid-filter')
  ];

  /// The header's buttons in order, as last built (Left / Right walk them).
  List<FocusNode> _header = const [];

  /// The focused card's index and the grid's columns: Up from the top row
  /// goes to the header (explicit: default traversal can land on the back
  /// arrow, CLAUDE.md §10).
  int _focusIndex = 0;
  int _columns = 1;

  /// A sort or filter needs the whole catalog: its remaining pages load
  /// once (rows by key), with a spinner beside the buttons.
  final Set<String> _restAsked = {};
  bool _loadingRest = false;

  String get _choiceKey => widget.folder?.id ?? widget.rowKey ?? '';

  @override
  void initState() {
    super.initState();
    final last = _last[_choiceKey];
    if (last != null) {
      _type = last.type;
      _sort = last.sort;
      _catalog = last.catalog;
      _genre = last.genre;
      _decade = last.decade;
    }
    // A tile's catalogs: the saved ones at once, the network for the rest
    // (the tab's refresh skips catalogs inside tiles).
    final folder = widget.folder;
    if (folder != null) {
      context.read<ArchiveService>().loadFolder(folder);
    }
    _focusFirst();
  }

  bool get _narrowed =>
      _sort != HubSort.source ||
      _catalog != null ||
      _genre != null ||
      _decade != null;

  void _changed(VoidCallback change) {
    setState(change);
    _last[_choiceKey] = _GridChoice(
        type: _type,
        sort: _sort,
        catalog: _catalog,
        genre: _genre,
        decade: _decade);
    _spot.value = null;
    _cardTrailer.stop();
  }

  /// The rest of [rows]' pages, once per row (see [_restAsked]).
  void _loadRest(List<ArchiveRow> rows) {
    final fresh = [
      for (final r in rows)
        if (_restAsked.add(r.key)) r
    ];
    if (fresh.isEmpty) return;
    final service = context.read<ArchiveService>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _loadingRest = true);
      try {
        await service.loadRest(fresh);
      } finally {
        if (mounted) setState(() => _loadingRest = false);
      }
    });
  }

  KeyEventResult _onHeaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final i = _header.indexOf(node);
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) _header[i - 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i >= 0 && i < _header.length - 1) _header[i + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_firstPoster.context != null) _firstPoster.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  /// Up from the grid's top row: the selected type, else Sort.
  KeyEventResult _onGridKey(KeyEvent event, bool hasType) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowUp ||
        _focusIndex >= _columns) {
      return KeyEventResult.ignored;
    }
    (hasType ? _typeNodes[_types.indexOf(_type)] : _sortNode).requestFocus();
    return KeyEventResult.handled;
  }

  Future<void> _pickSort(bool popular) async {
    final picked = await showGlassMenu<HubSort>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
        child: GlassMenuDialog(
          title: Text(tr('Sort')),
          maxWidth: 420,
          children: [
            for (final s in HubSort.values)
              if (s != HubSort.popular || popular)
                TvDialogOption(
                  autofocus: s == _sort,
                  onPressed: () => Navigator.of(dialogContext).pop(s),
                  child: _MenuChoice(label: s.label, on: s == _sort),
                ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || picked == _sort) return;
    _changed(() => _sort = picked);
  }

  Future<void> _pickFilter(
      List<ArchiveRow> rows, List<ArchiveMeta> items) async {
    final genres = hubGenres(items);
    final decades = hubDecades(items);
    final catalogs = widget.folder != null && rows.length > 1;
    final any = _catalog != null || _genre != null || _decade != null;
    // The first option takes focus: Clear when something is on.
    var first = true;
    bool focusFirst() {
      final f = first;
      first = false;
      return f;
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white60)),
        );
    final picked = await showGlassMenu<String>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
        child: GlassMenuDialog(
          title: Text(tr('Filter')),
          maxWidth: 460,
          children: [
            if (any)
              TvDialogOption(
                autofocus: focusFirst(),
                onPressed: () => Navigator.of(dialogContext).pop('clear'),
                child: Text(tr('Clear filters')),
              ),
            if (catalogs) ...[
              section(tr('Catalog')),
              for (final r in rows)
                TvDialogOption(
                  autofocus: focusFirst(),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop('cat:${r.key}'),
                  child: _MenuChoice(
                      label: hubCatalogTitle(rows, r), on: _catalog == r.key),
                ),
            ],
            if (genres.isNotEmpty) ...[
              section(tr('Genre')),
              for (final g in genres)
                TvDialogOption(
                  autofocus: focusFirst(),
                  onPressed: () => Navigator.of(dialogContext).pop('genre:$g'),
                  child: _MenuChoice(label: hubGenreName(g), on: _genre == g),
                ),
            ],
            if (decades.isNotEmpty) ...[
              section(tr('Decade')),
              for (final d in decades)
                TvDialogOption(
                  autofocus: focusFirst(),
                  onPressed: () => Navigator.of(dialogContext).pop('dec:$d'),
                  child:
                      _MenuChoice(label: hubDecadeLabel(d), on: _decade == d),
                ),
            ],
            if (!catalogs && genres.isEmpty && decades.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(tr('These titles carry nothing to filter by.'),
                    style: const TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    _changed(() {
      if (picked == 'clear') {
        _catalog = _genre = null;
        _decade = null;
      } else if (picked.startsWith('cat:')) {
        final k = picked.substring(4);
        _catalog = _catalog == k ? null : k;
      } else if (picked.startsWith('genre:')) {
        final g = picked.substring(6);
        _genre = _genre == g ? null : g;
      } else if (picked.startsWith('dec:')) {
        final d = int.tryParse(picked.substring(4));
        _decade = _decade == d ? null : d;
      }
    });
  }

  bool _firstFocused = false;

  /// The first card, once there is one (a tile's grid can start empty
  /// while its catalogs load).
  void _focusFirst() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _firstFocused) return;
      if (_firstPoster.context != null) {
        _firstFocused = true;
        _firstPoster.requestFocus();
      }
    });
  }

  /// The grid's titles, the source of each and the rows (catalogs) each
  /// came from: one row's, or every catalog of the tile in order, each
  /// title once.
  (List<ArchiveMeta>, List<ArchiveSource>, List<ArchiveRow>, List<Set<String>>)
      _content(ArchiveService service) {
    final folder = widget.folder;
    if (folder == null) {
      for (final r in service.rows(widget.type!)) {
        if (r.key == widget.rowKey) {
          final only = {r.key};
          return (
            r.items,
            [for (var i = 0; i < r.items.length; i++) r.sourceAt(i)],
            [r],
            [for (var i = 0; i < r.items.length; i++) only],
          );
        }
      }
      return (const [], const [], const [], const []);
    }
    final rows = service.folderRows(folder);
    final items = <ArchiveMeta>[];
    final sources = <ArchiveSource>[];
    final inRows = <Set<String>>[];
    final at = <String, int>{};
    for (final r in rows) {
      for (var i = 0; i < r.items.length; i++) {
        final m = r.items[i];
        final id = '${m.type.wire}:${m.id}';
        final seen = at[id];
        if (seen != null) {
          inRows[seen].add(r.key);
          continue;
        }
        at[id] = items.length;
        items.add(m);
        sources.add(r.sourceAt(i));
        inRows.add({r.key});
      }
    }
    return (items, sources, rows, inRows);
  }

  /// The last [_view] and what it was made from: build runs on every
  /// change of the Media Hub and every focus step, and filtering and
  /// sorting a 2,100-title tile each time froze the UI (owner, 2026-11-14).
  List<Object?> _viewKey = const [];
  ({
    List<ArchiveMeta> all,
    List<ArchiveRow> rows,
    bool hasType,
    List<ArchiveMeta> typed,
    String? catalog,
    bool popular,
    List<ArchiveMeta> items,
    List<ArchiveSource> sources,
  })? _lastView;

  /// The grid's titles in order (type, filters, sort), remade only when a
  /// catalog's titles or a choice changed.
  ({
    List<ArchiveMeta> all,
    List<ArchiveRow> rows,
    bool hasType,
    List<ArchiveMeta> typed,
    String? catalog,
    bool popular,
    List<ArchiveMeta> items,
    List<ArchiveSource> sources,
  }) _view(ArchiveService service) {
    final folder = widget.folder;
    final current = folder != null
        ? service.folderRows(folder)
        : [
            for (final r in service.rows(widget.type!))
              if (r.key == widget.rowKey) r
          ];
    // A catalog's list is replaced (not grown) when pages arrive.
    final key = <Object?>[
      for (final r in current) ...[r.key, r.items],
      _type,
      _sort,
      _catalog,
      _genre,
      _decade,
    ];
    final last = _lastView;
    if (last != null && key.length == _viewKey.length) {
      var same = true;
      for (var i = 0; i < key.length && same; i++) {
        same = identical(key[i], _viewKey[i]) ||
            (key[i] is! List && key[i] == _viewKey[i]);
      }
      if (same) return last;
    }
    final (all, allSources, rows, inRows) = _content(service);
    // The type switch only when the tile has both kinds.
    final hasType = folder != null &&
        all.any((m) => m.type == ArchiveType.movie) &&
        all.any((m) => m.type == ArchiveType.series);
    final type = hasType ? _type : null;
    // The menus offer what the shown kind carries.
    final ofType = [
      for (var i = 0; i < all.length; i++)
        if (type == null || all[i].type == type) i
    ];
    final typed = [for (final i in ofType) all[i]];
    final catalog = rows.any((r) => r.key == _catalog) ? _catalog : null;
    final keep = [
      for (final i in ofType)
        if ((catalog == null || inRows[i].contains(catalog)) &&
            (_genre == null || all[i].genres.contains(_genre)) &&
            (_decade == null || hubDecade(all[i]) == _decade))
          i
    ];
    final popular = hubHasPopularity(typed);
    final sort = _sort == HubSort.popular && !popular ? HubSort.source : _sort;
    final kept = [for (final i in keep) all[i]];
    final order = hubSortOrder(kept, sort);
    _viewKey = key;
    return _lastView = (
      all: all,
      rows: rows,
      hasType: hasType,
      typed: typed,
      catalog: catalog,
      popular: popular,
      items: [for (final o in order) kept[o]],
      sources: [for (final o in order) allSources[keep[o]]],
    );
  }

  /// Wide cards, as on the IPTV expanded catalog (a portrait phone keeps
  /// posters).
  bool _wide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portraitPhone = size.width < 600 && size.height > size.width;
    return (context.watch<AppPreferences?>()?.wideCards ?? false) &&
        !portraitPhone;
  }

  @override
  void dispose() {
    for (final n in [_sortNode, _filtersNode, ..._typeNodes]) {
      n.dispose();
    }
    _firstPoster.dispose();
    _spot.dispose();
    _cardTrailer.dispose();
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
    final folder = widget.folder;
    final (
      :all,
      :rows,
      :hasType,
      :typed,
      :catalog,
      :popular,
      :items,
      :sources
    ) = _view(service);
    final sort = _sort == HubSort.popular && !popular ? HubSort.source : _sort;
    final filters = [catalog, _genre, _decade].where((x) => x != null).length;
    final loading = folder != null && service.folderLoading(folder);
    if (_narrowed && rows.isNotEmpty && !loading) _loadRest(rows);
    final wide = _wide(context);
    if (items.isNotEmpty && !_firstFocused) _focusFirst();
    final touchPreview = Theme.of(context).platform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).width < 700;
    _header = [
      _sortNode,
      _filtersNode,
      if (hasType) ..._typeNodes,
    ];
    final header = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(children: [
        _FilterChip(
          focusNode: _sortNode,
          icon: Icons.sort,
          label: sort == HubSort.source
              ? tr('Sort')
              : '${tr('Sort')}  ·  ${sort.label}',
          selected: sort != HubSort.source,
          onSelect: () => _pickSort(popular),
          onKey: (e) => _onHeaderKey(_sortNode, e),
        ),
        const SizedBox(width: 6),
        _FilterChip(
          focusNode: _filtersNode,
          icon: Icons.filter_list,
          label: filters == 0 ? tr('Filter') : '${tr('Filter')}  ·  $filters',
          selected: filters > 0,
          onSelect: () => _pickFilter(rows, typed),
          onKey: (e) => _onHeaderKey(_filtersNode, e),
        ),
        if (hasType) ...[
          const SizedBox(width: 18),
          for (var i = 0; i < _types.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                focusNode: _typeNodes[i],
                label: switch (_types[i]) {
                  null => tr('All'),
                  ArchiveType.movie => tr('Movies'),
                  ArchiveType.series => tr('TV Shows'),
                },
                selected: _types[i] == (hasType ? _type : null),
                onSelect: () {
                  if (_types[i] != _type) _changed(() => _type = _types[i]);
                },
                onKey: (e) => _onHeaderKey(_typeNodes[i], e),
              ),
            ),
        ],
        if (_loadingRest) ...[
          const SizedBox(width: 14),
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(tr('Loading every title…'),
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ]),
    );
    return withTvThemeIfNeeded(
      context,
      (context) => Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          // Same backdrop as GroupCatalogScreen: full height, faded left.
          Positioned.fill(
            child: ValueListenableBuilder<ArchiveMeta?>(
              valueListenable: _spot,
              builder: (context, spot, _) => DetailBackdrop(
                  url: spot?.backgroundUrl ?? spot?.posterUrl, fadeLeft: true),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: tr('Back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              toolbarHeight: 64,
              bottom: all.isEmpty
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(46),
                      child: Align(
                          alignment: Alignment.centerLeft, child: header)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      all.isEmpty
                          ? widget.title
                          : '${widget.title}   ·   ${tr('{n} titles', {
                                  'n': items.length
                                })}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70)),
                  ValueListenableBuilder<ArchiveMeta?>(
                    valueListenable: _spot,
                    builder: (context, spot, _) => _spotLine(context, spot),
                  ),
                ],
              ),
            ),
            body: items.isEmpty
                ? Center(
                    child: loading || _loadingRest
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(all.isEmpty
                            ? tr('No items in this group.')
                            : tr('No titles match these filters.')))
                : Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    // Up to the buttons, a title page, a hold menu: the
                    // card's trailer stops (a page under another stays
                    // built and would play on).
                    onFocusChange: (has) {
                      if (!has) _cardTrailer.stop();
                    },
                    onKeyEvent: (_, e) => _onGridKey(e, hasType),
                    child: LayoutBuilder(builder: (context, box) {
                      // SliverGridDelegateWithMaxCrossAxisExtent's columns.
                      final extent = (wide
                              ? PosterCard.wideStyleWidth
                              : PosterCard.width) +
                          12;
                      _columns = ((box.maxWidth - 48) / (extent + 8))
                          .ceil()
                          .clamp(1, 1000);
                      return _grid(context, items, sources, rows, wide,
                          touchPreview, folder);
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
      BuildContext context,
      List<ArchiveMeta> items,
      List<ArchiveSource> sources,
      List<ArchiveRow> rows,
      bool wide,
      bool touchPreview,
      HubFolder? folder) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent:
            (wide ? PosterCard.wideStyleWidth : PosterCard.width) + 12,
        mainAxisExtent:
            (wide ? PosterCard.wideStyleHeight : PosterCard.height) + 10,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final meta = items[i];
        final source = sources[i];
        return ValueListenableBuilder<Set<String>>(
          valueListenable: ArchiveReadyWatch.instance.tags,
          builder: (context, ready, _) => PosterCard(
            ready: ready.contains(meta.id),
            fetching:
                ArchiveReadyWatch.instance.fetching.value.contains(meta.id),
            focusNode: i == 0 ? _firstPoster : null,
            title: meta.name,
            imageUrl: meta.posterUrl,
            rating: meta.year,
            tag: meta.releaseTag?.label,
            tagStrong: meta.releaseTag == HubReleaseTag.isNew,
            cardWidth: wide ? PosterCard.wideStyleWidth : PosterCard.width,
            cardPosterHeight: wide
                ? PosterCard.wideStylePosterHeight
                : PosterCard.posterHeight,
            wideStyle: wide,
            backdropUrl: meta.backgroundUrl,
            wideVideo: wide && CardTrailer.enabledIn(context)
                ? _cardTrailer.video('grid:$i', meta.id)
                : null,
            artKey: 'hub:${meta.type.wire}:${meta.id}',
            tapToPreview: touchPreview,
            onTap: () => _open(source, meta),
            isFavorite: context.read<ArchiveService>().isFavorite(source, meta),
            // Same hold as the row it came from; a tile's
            // grid: favourite / mark watched.
            onToggleFavorite: () => folder == null
                ? holdArchiveTitle(context, rows.first, source, meta)
                : holdHubTitleMenu(context, source, meta),
            onFocusGained: () {
              _focusIndex = i;
              _spot.value = meta;
              _armCardTrailer(i, meta, source, wide);
              // A grid row holds several cards: ask for the
              // next page a few rows before the end (a tile:
              // of each of its catalogs).
              if (i >= items.length - 24) {
                final service = context.read<ArchiveService>();
                for (final r in rows) {
                  service.loadMore(r);
                }
              }
            },
          ),
        );
      },
    );
  }

  /// The focused title with its year and rating, one line (the IPTV
  /// expanded catalog's spotlight line).
  Widget _spotLine(BuildContext context, ArchiveMeta? spot) {
    if (spot == null) return const SizedBox.shrink();
    final info = [
      if (spot.year != null && spot.year!.isNotEmpty) spot.year!,
      if (spot.rating != null && spot.rating!.isNotEmpty) '★ ${spot.rating}',
    ];
    return Row(children: [
      Flexible(
        child: Text(cleanDisplayTitle(spot.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
      ),
      if (info.isNotEmpty) ...[
        const SizedBox(width: 14),
        Text(info.join('   ·   '),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
      ],
    ]);
  }
}

/// One of All / Movies / TV Shows: the glass row look of the menus, gold
/// outline when focused, filled when selected.
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.focusNode,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onKey,
    this.icon,
  });

  final FocusNode focusNode;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelect;
  final KeyEventResult Function(KeyEvent event) onKey;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent &&
            (e.logicalKey == LogicalKeyboardKey.select ||
                e.logicalKey == LogicalKeyboardKey.enter ||
                e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return widget.onKey(e);
      },
      child: InkLayer(
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            widget.focusNode.requestFocus();
            widget.onSelect();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: GlassMenuSurface.rowDecoration(context,
                focused: _focused, selected: widget.selected, radius: 20),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 16,
                    color: widget.selected || _focused
                        ? Colors.white
                        : Colors.white70),
                const SizedBox(width: 6),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          widget.selected ? FontWeight.w800 : FontWeight.w500,
                      color: widget.selected || _focused
                          ? Colors.white
                          : Colors.white70)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A menu row with a check when it's the one in use.
class _MenuChoice extends StatelessWidget {
  const _MenuChoice({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 26,
          child: on
              ? Icon(Icons.check,
                  size: 18, color: Theme.of(context).colorScheme.primary)
              : null,
        ),
        Expanded(child: Text(label)),
      ]);
}

/// The grid's choices for one tile / row, kept for the app run.
class _GridChoice {
  const _GridChoice(
      {this.type,
      this.sort = HubSort.source,
      this.catalog,
      this.genre,
      this.decade});
  final ArchiveType? type;
  final HubSort sort;
  final String? catalog;
  final String? genre;
  final int? decade;
}
