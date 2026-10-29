import '../widgets/archive_discovery_panel.dart';
import '../widgets/detail_trailer.dart';
import '../services/app_preferences.dart';
import '../widgets/trailer_button.dart';
import '../services/trailer_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_service.dart';
import '../services/storage_service.dart';
import '../services/tracker_sync.dart';
import '../widgets/cast_bubbles.dart';
import '../widgets/detail_header.dart';
import 'archive_playback.dart';

/// An Archive movie's page: backdrop, poster, year/genres, description and
/// Play. Built from the same `detail_header.dart` pieces as
/// MovieDetailScreen. Play goes through [playArchiveTitle] (stream lookup,
/// picker when there are several, then the normal player), so resume
/// positions work like any VOD. Archive shows open the regular
/// SeriesDetailScreen instead — see [openArchiveSeries].
class ArchiveDetailScreen extends StatefulWidget {
  const ArchiveDetailScreen(
      {super.key, required this.source, required this.preview});

  final ArchiveSource source;
  final ArchiveMeta preview;

  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  final _backgroundTrailer = GlobalKey<DetailTrailerState>();
  TrailerRequest get _trailerRequest => TrailerRequest(
      title: _meta.name,
      series: false,
      year: int.tryParse(_meta.year ?? ''),
      imdbId: _meta.imdb,
      supplied: widget.source.suppliesOwnMetadata ? _meta.trailers : const [],
      suppliedStreams:
          widget.source.suppliesOwnMetadata ? _meta.trailerStreams : const [],
      language: L10n.code,
      tmdbKey: context.read<StorageService>().getTmdbApiKey() ?? '');

  final _trailerNode = FocusNode(debugLabel: 'trailer');
  final _playNode = FocusNode(debugLabel: 'archive-play');
  final _restartNode = FocusNode(debugLabel: 'archive-restart');
  final _discoveryNode = FocusNode(debugLabel: 'archive-discovery');
  final _castNode = FocusNode(debugLabel: 'archive-cast');
  final _pageScroll = ScrollController();
  bool _showCast = false;

  ArchiveMeta? _full;
  bool _starting = false;

  ArchiveMeta get _meta => _full ?? widget.preview;

  @override
  void initState() {
    super.initState();
    context
        .read<ArchiveService>()
        .registerIdentity(widget.source, widget.preview);
    _loadMeta();
    _syncTrackers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _playNode.context != null) _playNode.requestFocus();
    });
  }

  /// Trakt / Simkl: a watch or pause made elsewhere fills in this movie's
  /// mark / resume point (by IMDb id). Its play is registered when it
  /// starts (`playArchiveTitle`).
  Future<void> _syncTrackers() async {
    final imdb = widget.preview.imdb;
    if (imdb == null) return;
    final changed = await TrackerSync.instance.applyToMovie(
        context.read<StorageService>(),
        imdb: imdb,
        channelId: ArchiveService.channelId(widget.source, widget.preview.id,
            episode: false));
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _trailerNode.dispose();
    _playNode.dispose();
    _restartNode.dispose();
    _castNode.dispose();
    _discoveryNode.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  /// The full meta has a longer description than the catalog preview.
  Future<void> _loadMeta() async {
    ArchiveMeta? full;
    try {
      full = await context
          .read<ArchiveService>()
          .meta(widget.source, widget.preview);
    } catch (_) {
      full = null; // the preview is enough for a movie
    }
    if (mounted && full != null) {
      context.read<ArchiveService>().registerIdentity(widget.source, full);
      setState(() => _full = full);
    }
  }

  Future<void> _play({bool restart = false}) async {
    if (_starting) return;
    await _backgroundTrailer.currentState?.stop();
    if (!mounted || _starting) return;
    setState(() => _starting = true);
    if (restart) {
      await context.read<StorageService>().setLastPosition(
          ArchiveService.channelId(widget.source, _meta.id, episode: false), 0);
    }
    if (!mounted) return;
    try {
      await playArchiveTitle(context, source: widget.source, meta: _meta);
    } finally {
      if (mounted) setState(() => _starting = false); // + refresh progress
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 700;
    final meta = _meta;
    final backdrop = meta.backgroundUrl;
    // Windows has no remote Back: Esc pops, and the arrow is shown at every
    // width (it was narrow-only, so wide windows had no way out).
    return CallbackShortcuts(
      bindings: {
        if (Platform.isWindows)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DetailTrailer(
          key: _backgroundTrailer,
          enabled: context.watch<AppPreferences?>()?.autoTrailers ?? false,
          request: _trailerRequest,
          child: Stack(
            children: [
              Positioned.fill(
                child: DetailBackdrop(
                    url: backdrop ?? meta.posterUrl, fadeLeft: !narrow),
              ),
              SafeArea(
                child: ListView(
                  controller: _pageScroll,
                  padding: EdgeInsets.fromLTRB(
                      narrow ? 16 : 40, narrow ? 8 : 32, narrow ? 16 : 40, 32),
                  children: [
                    if (narrow || Platform.isWindows)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ExcludeFocus(
                          excluding: !narrow,
                          child: IconButton(
                            tooltip: tr('Back'),
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    // Focus back on Play/Trailer (Up from Explore more) shows the
                    // whole header again: requestFocus alone never scrolled the
                    // page, so the title and description stayed cut off.
                    Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onFocusChange: (has) {
                          if (has &&
                              _pageScroll.hasClients &&
                              _pageScroll.offset != 0) {
                            _pageScroll.jumpTo(0);
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meta.posterUrl != null && !narrow) ...[
                              DetailPoster(url: meta.posterUrl!, width: 150),
                              const SizedBox(width: 24),
                            ],
                            // Wide: the right part stays clear for the cast
                            // bubbles (same split as MovieDetailScreen).
                            Expanded(
                              child: narrow
                                  ? _buildInfo(meta)
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxWidth: size.width * 0.6 -
                                                (meta.posterUrl != null
                                                    ? 174
                                                    : 0)),
                                        child: _buildInfo(meta),
                                      ),
                                    ),
                            ),
                          ],
                        )),
                    ArchiveDiscoveryPanel(
                        source: widget.source,
                        meta: meta,
                        entryNode: _discoveryNode,
                        onReturn: () => _playNode.requestFocus()),
                  ],
                ),
              ),
              Positioned.fill(
                child: CastBubbles(
                  names: CastBubbles.namesFrom(meta.cast),
                  visible: _showCast,
                  area: narrow ? CastBubbles.narrowArea : CastBubbles.wideArea,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(ArchiveMeta meta) {
    final storage = context.read<StorageService>();
    final scheme = Theme.of(context).colorScheme;
    final movieId =
        ArchiveService.channelId(widget.source, meta.id, episode: false);
    final positionMs = storage.getLastPosition(movieId);
    final watched = storage.isFullyWatched(movieId);
    final resume = positionMs > 0 && !watched;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(meta.name,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (meta.rating != null)
            DetailMetaChip(
              scale: 1,
              leading:
                  Icon(Icons.star_rounded, size: 14, color: scheme.primary),
              label: meta.rating!,
              strong: true,
            ),
          if (meta.year != null)
            DetailMetaChip(scale: 1, label: meta.year!, strong: true),
          if (meta.runtime != null)
            DetailMetaChip(scale: 1, label: meta.runtime!),
          for (final g in meta.genres.take(4))
            DetailMetaChip(scale: 1, label: g),
          DetailMetaChip(scale: 1, label: widget.source.name),
        ]),
        const SizedBox(height: 12),
        if (meta.description != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(meta.description!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ),
        if (meta.cast.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(tr('Cast: {names}', {'names': meta.cast.take(4).join(', ')}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          DetailPillButton(
            focusNode: _playNode,
            icon: _starting ? Icons.hourglass_top : Icons.play_arrow_rounded,
            label: resume ? tr('Resume') : tr('Play'),
            emphasized: true,
            scale: 1,
            onPressed: () => _play(restart: watched),
          ),
          TrailerButton(
              focusNode: _trailerNode,
              beforeOpen: () async => _backgroundTrailer.currentState?.stop(),
              request: _trailerRequest),
          if (resume)
            DetailPillButton(
              focusNode: _restartNode,
              icon: Icons.replay_rounded,
              label: tr('Restart'),
              scale: 1,
              onPressed: () => _play(restart: true),
            ),
          if (meta.cast.isNotEmpty)
            DetailPillButton(
              focusNode: _castNode,
              icon: Icons.groups_rounded,
              label: tr('Cast'),
              selected: _showCast,
              scale: 1,
              onPressed: () => setState(() => _showCast = !_showCast),
            ),
        ]),
      ],
    );
  }
}
