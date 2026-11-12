import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/hub_collection.dart';
import '../services/app_preferences.dart';
import '../services/archive_service.dart';
import '../utils/desktop_platform.dart';
import '../utils/image_urls.dart';
import '../widgets/detail_header.dart';
import '../widgets/hd_network_image.dart';
import '../widgets/poster_card.dart';
import '../widgets/trimmed_logo.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';

/// A collection tile's page (OK on "Netflix" in the Media Hub tab's
/// Streaming row): the folder's backdrop and title logo, then one poster
/// row per catalog it names ("Latest Disney+ (Movies)", "Disney+ Top 10
/// (Series)"…), from the user's own add-ons. Movies and shows together.
///
/// D-pad like the Media Hub tab (CLAUDE.md §10): explicit Up/Down between
/// rows at their remembered card, Left/Right along a row; the rows are
/// lazy, so a move scrolls the destination in before asking its card for
/// focus. Back leaves.
class HubFolderScreen extends StatefulWidget {
  const HubFolderScreen({super.key, required this.folder, this.collection});

  final HubFolder folder;

  /// The collection's name, under the title ("Streaming").
  final String? collection;

  @override
  State<HubFolderScreen> createState() => _HubFolderScreenState();
}

class _HubFolderScreenState extends State<HubFolderScreen> {
  final _scroll = ScrollController();
  final Map<String, ScrollController> _rowScrolls = {};
  final Map<String, Map<int, FocusNode>> _nodes = {};
  final Map<String, int> _lastIndex = {};
  int _row = 0;
  ArchiveMeta? _focused;
  bool _entered = false;

  static const _slot = PosterCard.width + 12 + 8;

  /// The focused card's slot once it has opened wide (backdrop + title
  /// logo), like the Media Hub tab's rows (owner, 2026-11-11: "the 2 sec
  /// card expansion" was missing on the collections' pages).
  static const _wideSlot = PosterCard.wideCardWidth + 12 + 8;
  static const _rowPadding = 20.0;
  static const _headerHeight = 34.0;
  static const _rowExtent = _headerHeight + PosterCard.height + 16;

  /// The card held for two seconds: (row key, index, title id).
  (String, int, String)? _expanded;
  Timer? _wideTimer;

  /// TV and computer widths only (a phone row has no room).
  bool get _wideCards => MediaQuery.sizeOf(context).width >= 700;

  /// The card of [row] drawn wide, if any (it must still be that title and
  /// still have the focus).
  int? _wideIndex(ArchiveRow row) {
    final e = _expanded;
    if (e == null || e.$1 != row.key || e.$2 >= row.items.length) return null;
    final meta = row.items[e.$2];
    if (meta.id != e.$3 || !(_nodes[row.key]?[e.$2]?.hasFocus ?? false)) {
      return null;
    }
    return (meta.backgroundUrl?.isNotEmpty ?? false) ? e.$2 : null;
  }

  /// Closes the wide card (another card took the focus, a page opened).
  bool _clearWide() {
    _wideTimer?.cancel();
    _wideTimer = null;
    final had = _expanded != null;
    _expanded = null;
    return had;
  }

  /// Card [i] of [row] opens wide after two seconds of focus, when it has
  /// a backdrop and the page is in front.
  void _armWide(ArchiveRow row, int i) {
    _wideTimer?.cancel();
    _wideTimer = null;
    final meta = row.items[i];
    if (!_wideCards || !(meta.backgroundUrl?.isNotEmpty ?? false)) return;
    final node = _node(row.key, i);
    _wideTimer = Timer(const Duration(seconds: 2), () {
      _wideTimer = null;
      if (!mounted ||
          !node.hasFocus ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      setState(() => _expanded = (row.key, i, meta.id));
      // The wider card stays in view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node.hasFocus) _reveal(row, i, wide: true);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Marks the folder loading before its first await.
      context.read<ArchiveService>().loadFolder(widget.folder);
      setState(() => _requested = true);
    });
  }

  /// The catalogs were asked for (no "nothing here" before the request).
  bool _requested = false;

  @override
  void dispose() {
    _wideTimer?.cancel();
    _scroll.dispose();
    for (final c in _rowScrolls.values) {
      c.dispose();
    }
    for (final row in _nodes.values) {
      for (final n in row.values) {
        n.dispose();
      }
    }
    super.dispose();
  }

  FocusNode _node(String key, int i) => _nodes
      .putIfAbsent(key, () => {})
      .putIfAbsent(i, () => FocusNode(debugLabel: 'folder-card'));

  ScrollController _rowScroll(String key) =>
      _rowScrolls.putIfAbsent(key, ScrollController.new);

  bool get _touch =>
      Theme.of(context).platform == TargetPlatform.android &&
      !(context.read<AppPreferences?>()?.isTelevision ?? false);

  void _focusWhenBuilt(FocusNode node, [int framesLeft = 4]) {
    if (node.context != null) {
      node.requestFocus();
    } else if (framesLeft > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusWhenBuilt(node, framesLeft - 1);
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  /// Scrolls card [i] of [row] in (a lazy row can't focus an unbuilt card)
  /// and focuses it.
  void _focusCard(ArchiveRow row, int i) {
    // The wide card closes first, so every slot is a poster's again.
    if (_clearWide()) setState(() {});
    _reveal(row, i);
    _focusWhenBuilt(_node(row.key, i));
  }

  /// Scrolls [row] so card [i] (wide once expanded) is in view.
  void _reveal(ArchiveRow row, int i, {bool wide = false}) {
    final c = _rowScrolls[row.key];
    if (c == null || !c.hasClients) return;
    final start = _rowPadding + i * _slot;
    final width = wide ? _wideSlot : _slot;
    final pos = c.position;
    if (start - _slot < pos.pixels) {
      c.jumpTo((start - _slot).clamp(0.0, pos.maxScrollExtent));
    } else if (start + width + _slot > pos.pixels + pos.viewportDimension) {
      c.jumpTo((start + width + _slot - pos.viewportDimension)
          .clamp(0.0, pos.maxScrollExtent));
    }
  }

  void _focusRow(List<ArchiveRow> rows, int r) {
    if (rows.isEmpty) return;
    r = r.clamp(0, rows.length - 1);
    final row = rows[r];
    if (_scroll.hasClients) {
      final pos = _scroll.position;
      final top = r * _rowExtent;
      if (top < pos.pixels ||
          top + _rowExtent > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo(top.clamp(0.0, pos.maxScrollExtent));
      }
    }
    final i = (_lastIndex[row.key] ?? 0).clamp(0, row.items.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCard(row, i);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  KeyEventResult _onKey(List<ArchiveRow> rows, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (rows.isEmpty) return KeyEventResult.ignored;
    final r = _row.clamp(0, rows.length - 1);
    final row = rows[r];
    final i = _lastIndex[row.key] ?? 0;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (r < rows.length - 1) _focusRow(rows, r + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (r > 0) _focusRow(rows, r - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < row.items.length - 1) _focusCard(row, i + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) _focusCard(row, i - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _open(ArchiveSource source, ArchiveMeta meta) async {
    if (meta.type == ArchiveType.series) {
      await openArchiveSeries(context, source, meta);
    } else {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArchiveDetailScreen(source: source, preview: meta)));
    }
  }

  /// A row's name without its leading emoji ("🎬 Netflix" -> "Netflix").
  static String _plain(String name) {
    final clean =
        name.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    return clean.isEmpty ? name : clean;
  }

  String _rowName(ArchiveRow row) {
    if (row.customTitle != null) return row.customTitle!;
    return _plain(row.source.streamOnly || row.source.tracker != null
        ? tr(row.title)
        : row.title);
  }

  /// The row header: its name, plus "(Movies)" / "(TV Shows)" when another
  /// row on the page has the same name (the pack names both "🎬 Netflix").
  String _rowTitle(List<ArchiveRow> rows, ArchiveRow row) {
    final name = _rowName(row);
    final twin = rows.any((r) => !identical(r, row) && _rowName(r) == name);
    if (!twin) return name;
    return row.catalog.type == ArchiveType.movie
        ? '$name (${tr('Movies')})'
        : '$name (${tr('TV Shows')})';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final folder = widget.folder;
    final rows = service.folderRows(folder);
    final loading = service.folderLoading(folder);
    final installed = service.folderCatalogs(folder).isNotEmpty;
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;
    final short = size.height < 520;
    // The first row in: focus its first title once (the remote needs a
    // target; touch doesn't, an iPhone neither).
    if (!_entered && rows.isNotEmpty && !_touch && !isIosTarget) {
      _entered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_nodes.values.any((m) => m.values.any((n) => n.hasFocus))) {
          _focusRow(rows, 0);
        }
      });
    }
    final focused = _focused;
    final backdrop =
        focused?.backgroundUrl ?? focused?.posterUrl ?? folder.backdropUrl;
    return CallbackShortcuts(
      bindings: {
        if (isDesktop)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              left: narrow ? 0 : size.width * 0.2,
              child: Stack(fit: StackFit.expand, children: [
                DetailBackdrop(url: backdrop, fadeLeft: true),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x99000000),
                        Color(0xE6000000),
                      ],
                      stops: [0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ]),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: narrow ? 150 : (short ? 96 : 200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: _Hero(
                        folder: folder,
                        collection: widget.collection,
                        focused: focused,
                        compact: narrow || short,
                        onBack: needsBackArrow || _touch
                            ? () => Navigator.of(context).maybePop()
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: loading || !_requested
                                ? const CircularProgressIndicator()
                                : Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      installed
                                          ? tr('Nothing here yet.')
                                          : tr(
                                              "This tile's catalogs aren't in your add-ons. Add the add-on its collection was made for (AIOMetadata) with the same catalogs."),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                  ),
                          )
                        : Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            onKeyEvent: (_, e) => _onKey(rows, e),
                            child: ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.only(bottom: 40),
                              itemExtent: _rowExtent,
                              itemCount: rows.length,
                              itemBuilder: (_, r) =>
                                  _buildRow(service, rows, r),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(ArchiveService service, List<ArchiveRow> rows, int r) {
    final row = rows[r];
    final scheme = Theme.of(context).colorScheme;
    final wideAt = _wideIndex(row);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _headerHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
            child: Text(_rowTitle(rows, row),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: r == _row ? scheme.primary : Colors.white)),
          ),
        ),
        SizedBox(
          height: PosterCard.height + 16,
          child: ListView.builder(
            controller: _rowScroll(row.key),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
            // A builder even with no wide card: switching between
            // itemExtent and a builder would rebuild the cards and drop
            // the focus (same as the Media Hub tab).
            itemExtentBuilder: (i, _) => i >= row.items.length
                ? null
                : (i == wideAt ? _wideSlot : _slot),
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
                  wideWidth: i == wideAt ? PosterCard.wideCardWidth : null,
                  wideImageUrl: meta.backgroundUrl,
                  wideLogoUrl: meta.logo,
                  tapToPreview: _touch,
                  onTap: () => _open(row.sourceAt(i), meta),
                  isFavorite: service.isFavorite(row.sourceAt(i), meta),
                  onToggleFavorite: () =>
                      holdArchiveTitle(context, row, row.sourceAt(i), meta),
                  onFocusGained: () {
                    _lastIndex[row.key] = i;
                    if (i >= row.items.length - 12) service.loadMore(row);
                    final e = _expanded;
                    if (e != null && (e.$1 != row.key || e.$2 != i)) {
                      _clearWide();
                    }
                    _armWide(row, i);
                    setState(() {
                      _row = r;
                      _focused = meta;
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

/// The page's top: the focused title (logo or name, year, description),
/// else the folder's title logo and collection.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.folder,
    required this.collection,
    required this.focused,
    required this.compact,
    this.onBack,
  });

  final HubFolder folder;
  final String? collection;
  final ArchiveMeta? focused;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final meta = focused;
    final logo = meta == null ? folder.logoUrl : meta.logo;
    final name = meta?.name ?? folder.title;
    final height = compact ? 36.0 : 64.0;
    final title = Align(
      alignment: Alignment.bottomLeft,
      child: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: compact ? 24 : 30, fontWeight: FontWeight.w700)),
    );
    final line = meta == null
        ? collection
        : [
            meta.type == ArchiveType.movie ? tr('Movie') : tr('Series'),
            ...meta.genres.take(2),
            if (meta.year != null) meta.year!,
          ].join('  •  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: tr('Back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          Expanded(
            child: SizedBox(
              height: height,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: logo == null
                    ? title
                    : meta == null
                        // The pack's logo sits on a wide transparent canvas.
                        ? Align(
                            alignment: Alignment.bottomLeft,
                            child: TrimmedLogo(
                              key: ValueKey(logo),
                              url: logo,
                              height: height,
                              maxWidth: 360,
                              tint: TrimmedLogo.brandColor(folder.title),
                              fallback: title,
                            ),
                          )
                        : Align(
                            alignment: Alignment.bottomLeft,
                            child: HdNetworkImage(
                              key: ValueKey(logo),
                              url: logo,
                              kind: ImageKind.poster,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomLeft,
                              decodeWidth: HdNetworkImage.cardDecodeWidth(
                                  context, 360,
                                  oversample: 1),
                              fadeInDuration: const Duration(milliseconds: 200),
                              errorWidget: (_) => title,
                            ),
                          ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (line != null && line.isNotEmpty)
          Text(line,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        const SizedBox(height: 8),
        if (meta?.description case final text? when !compact)
          Flexible(
            child: SizedBox(
              width: 520,
              child: Text(text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: Colors.white70)),
            ),
          ),
      ],
    );
  }
}
