import '../widgets/glass_menu.dart';
import '../utils/refined_finish.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart'
    show NoVideoControls, Video;
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/sports.dart';
import '../models/viewer_profile.dart';
import '../models/xtream_series.dart';
import '../services/app_preferences.dart';
import '../services/archive_service.dart';
import '../services/desktop_mini_player.dart';
import '../services/epg_service.dart';
import '../services/episode_alerts.dart';
import '../services/home_rows.dart';
import '../services/home_wallpaper.dart';
import '../services/logo_colors.dart';
import '../services/multiview_sports.dart';
import '../services/playback_service.dart';
import '../services/playlist_manager.dart';
import '../services/recording_service.dart';
import '../services/storage_service.dart';
import '../services/viewer_profile_service.dart';
import '../utils/image_urls.dart';
import '../utils/time_format.dart';
import '../widgets/hd_network_image.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/player_controls.dart' show VideoPlayerPane;
import '../widgets/tv_dialog_option.dart';
import '../widgets/video_tap_layer.dart';
import 'archive_detail_screen.dart';
import 'archive_playback.dart';
import 'desktop_player_screen.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';
import 'settings/profile_editor_screen.dart';
import '../widgets/profile_card.dart';
import 'sports_screen.dart';
import '../services/vesper_ai/watch_list.dart';
import '../utils/desktop_platform.dart';

/// The Home page (top of the tabs column, or Settings > Startup > Open on:
/// Home): the viewer's profiles strip, a hero for the focused card, then
/// rows bringing the app together — today's games, Continue Watching across
/// playlists and Media Hub, recent and favourite channels, new movies and
/// shows. Each viewer picks and orders their rows (hold OK on a card,
/// [HomeRows]). User request (Samiam23, Discord, 2026-10-23); the profiles
/// strip replaces the tabs column's profile row (owner).
///
/// D-pad: explicit dispatch like the Media Hub rows (one handler for the
/// page, exact card slots, `jumpTo` only — CLAUDE.md §10).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Narrower than this (a phone), Home has no mini player.
  static const miniPlayerMinWidth = 720.0;

  /// Whether Home shows its mini player: TvHomeScreen then leaves a
  /// playing live channel running when Home opens instead of parking it.
  static bool showsMiniPlayer(BuildContext context) =>
      context.read<AppPreferences>().homeMiniPlayer &&
      MediaQuery.sizeOf(context).width >= miniPlayerMinWidth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// One card on the page, whatever it opens.
class _HomeItem {
  const _HomeItem({
    required this.key,
    required this.title,
    required this.open,
    this.subtitle,
    this.imageUrl,
    this.backdropUrl,
    this.description,
    this.progress,
    this.live = false,
    this.game,
    this.removeFromHistory,
    this.removeLabel = 'Remove from history',
    this.tag,
    this.tagHighlight = false,
    this.preview,
    this.logoUrl,
    this.programme,
  });

  final String key;

  /// The live channel the mini player plays when the remote stops on this
  /// card (a channel, or a game's first matched channel).
  final Channel? preview;

  /// A live channel's logo and what's on now: the hero shows the logo large
  /// above the programme, the backdrop glows in the logo's colours.
  final String? logoUrl;
  final EpgProgram? programme;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? backdropUrl;
  final String? description;
  final double? progress;
  final bool live;
  final SportsGame? game;
  final Future<void> Function()? removeFromHistory;

  /// Untranslated hold-menu label for [removeFromHistory].
  final String removeLabel;

  /// Top-right corner tag on the card ("NEW", "Airs in 5 days"); gold
  /// when [tagHighlight].
  final String? tag;
  final bool tagHighlight;
  final Future<void> Function(BuildContext context) open;
}

/// Poster (movies/shows) or wide (channels, games, Continue Watching).
enum _CardShape { poster, wide }

class _HomeRow {
  const _HomeRow(this.kind, this.shape, this.items);
  final HomeRowKind kind;
  final _CardShape shape;
  final List<_HomeItem> items;
}

class _HomeScreenState extends State<HomeScreen> {
  static const _posterW = 100.0, _posterH = 150.0;
  static const _wideW = 176.0, _wideH = 99.0;
  static const _gap = 14.0;
  static const _sidePad = 40.0;

  late HomeRows _rowsConfig;
  List<_HomeRow> _rows = const [];
  bool _loading = true;

  /// Bumped per load: an older, slower load never overwrites a newer one.
  int _loadId = 0;

  /// Which zone has the selector: the profiles strip or the rows.
  bool _inProfiles = false;
  int _profileIndex = 0;
  int _row = 0;
  final Map<HomeRowKind, int> _cardIndex = {};
  _HomeItem? _focused;

  /// Fades the page out and back in around a profile switch.
  bool _switching = false;

  /// False until the remote moves the selector: a slower row appearing
  /// above (Today's games) then takes it, so the page starts at the top.
  bool _userMoved = false;

  final _pageScroll = ScrollController();
  final Map<HomeRowKind, ScrollController> _rowScrolls = {};
  final Map<String, FocusNode> _nodes = {};
  final Map<HomeRowKind, GlobalKey> _rowKeys = {};
  final List<FocusNode> _profileNodes = [];
  final _addProfileNode = FocusNode(debugLabel: 'home add profile');
  final _emptyFocus = FocusNode(debugLabel: 'home empty');
  bool _profilesHidden = false;
  Timer? _hubProgressRefresh;

  /// The viewer's Home wallpaper (Settings > Interface > Tabs), if any.
  Uint8List? _wallpaper;

  Future<void> _loadWallpaper() async {
    final viewer = context.read<ViewerProfileService>().active.id;
    final bytes = await HomeWallpaper.instance.load(viewer);
    if (mounted) setState(() => _wallpaper = bytes);
  }

  // --- Mini player (Settings > Interface > Tabs, per viewer) ---------------
  // The live channel card the remote stops on plays at the top right, by
  // the TV guide's Preview on highlight rules: only after a remote move,
  // once the remote has rested [_miniDelay] on the card (holding Right past
  // 20 channels opens one stream, not 20), and History only once it has
  // played [_miniHistoryAfter]. Focus landing on a card by itself (Home
  // opening, Back from full screen) never changes what plays.
  static const _miniDelay = Duration(milliseconds: 800);
  static const _miniHistoryAfter = Duration(seconds: 10);
  static final _navKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };
  DateTime _lastKeyAt = DateTime(0);
  DateTime _lastNavKeyAt = DateTime(0);
  Timer? _miniTimer;
  Timer? _miniHistory;

  /// Turned off (Play/Pause, Stop, hold OK > Stop mini player): resting on
  /// a card plays nothing until OK or Play/Pause plays one (owner, 2026-11-09: it
  /// came back on the next highlight). Kept for the app run, across Home
  /// visits; a channel playing in it again (back from full screen, from
  /// the TV tab) turns it back on.
  static bool _miniOff = false;

  EpisodeAlerts? _episodeAlerts;

  /// A check found a new episode (or a follow changed): redraw that row.
  void _episodesChanged() {
    if (!mounted || _loading) return;
    final rows = <HomeRowKind, _HomeRow?>{
      for (final row in _rows) row.kind: row
    };
    if (!_rowsConfig.visible.contains(HomeRowKind.newEpisodes)) return;
    rows[HomeRowKind.newEpisodes] = _newEpisodesRow();
    _apply(_loadId, rows, focusFirst: false, done: true);
  }

  @override
  void initState() {
    super.initState();
    try {
      _episodeAlerts = context.read<EpisodeAlerts>()
        ..addListener(_episodesChanged);
    } on ProviderNotFoundException {
      _episodeAlerts = null;
    }
    _rowsConfig = HomeRows.load(context.read<StorageService>());
    HardwareKeyboard.instance.addHandler(_noteKey);
    _playback = context.read<PlaybackService>()..addListener(_historyChanged);
    _historyLoads = _playback.historyLoads;
    WatchList.instance.changes.addListener(_watchListChanged);
    HomeWallpaper.instance.changes.addListener(_loadWallpaper);
    unawaited(_loadWallpaper());
    unawaited(_load(focusFirst: true));
    if (_rowsConfig.visible.contains(HomeRowKind.continueWatching)) {
      unawaited(
          context.read<ArchiveService>().refreshHistoryDetails(onProgress: () {
        if (!mounted) return;
        final rows = <HomeRowKind, _HomeRow?>{
          for (final row in _rows) row.kind: row
        };
        rows[HomeRowKind.continueWatching] = _continueRow();
        _apply(_loadId, rows, focusFirst: false, done: !_loading);
      }));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hidden = context.watch<AppPreferences>().hideProfiles;
    if (hidden != _profilesHidden) {
      _profilesHidden = hidden;
      if (_inProfiles || _rows.isEmpty) {
        _inProfiles = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusProfiles();
        });
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_noteKey);
    _playback.removeListener(_historyChanged);
    // _miniHistory keeps running: the channel plays on behind TV (Back).
    _miniTimer?.cancel();
    WatchList.instance.changes.removeListener(_watchListChanged);
    HomeWallpaper.instance.changes.removeListener(_loadWallpaper);
    _episodeAlerts?.removeListener(_episodesChanged);
    _hubProgressRefresh?.cancel();
    _pageScroll.dispose();
    for (final c in _rowScrolls.values) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    for (final n in _profileNodes) {
      n.dispose();
    }
    _addProfileNode.dispose();
    _emptyFocus.dispose();
    super.dispose();
  }

  late final PlaybackService _playback;
  int _historyLoads = 0;

  /// The viewer's history was read from disk after this page loaded: Home
  /// opened at launch reads it before the app does, and its Continue
  /// Watching / Recent channels rows stayed empty until a trip to the TV
  /// tab (owner, 2026-11-09). Only a new read reloads, never a play
  /// joining History (that would reorder a row under the remote).
  void _historyChanged() {
    if (_playback.historyLoads == _historyLoads) return;
    _historyLoads = _playback.historyLoads;
    if (mounted) unawaited(_load(focusFirst: !_userMoved));
  }

  FocusNode _node(HomeRowKind kind, int i) =>
      _nodes.putIfAbsent('${kind.id}#$i', () => FocusNode());

  ScrollController _rowScroll(HomeRowKind kind) =>
      _rowScrolls.putIfAbsent(kind, ScrollController.new);

  GlobalKey _rowKey(HomeRowKind kind) =>
      _rowKeys.putIfAbsent(kind, GlobalKey.new);

  // ---------------------------------------------------------------- data --

  Future<void> _load({bool focusFirst = false}) async {
    final id = ++_loadId;
    final storage = context.read<StorageService>();
    final playlist = context.read<PlaylistManager>();
    final epg = context.read<EpgService>();
    final prefs = context.read<AppPreferences>();
    final visible = _rowsConfig.visible;

    // The quick rows first, so the page is never empty while the guide /
    // catalog queries run.
    final quick = <HomeRowKind, _HomeRow?>{
      if (visible.contains(HomeRowKind.continueWatching))
        HomeRowKind.continueWatching: _continueRow(),
      if (visible.contains(HomeRowKind.newEpisodes))
        HomeRowKind.newEpisodes: _newEpisodesRow(),
      if (visible.contains(HomeRowKind.recentChannels))
        HomeRowKind.recentChannels: _recentRow(epg),
      if (visible.contains(HomeRowKind.watchList))
        HomeRowKind.watchList: _watchListRow(storage),
      if (visible.contains(HomeRowKind.favourites))
        HomeRowKind.favourites: _favouritesRow(epg, playlist, prefs),
    };
    _apply(id, quick, focusFirst: focusFirst, done: false);

    final slow = <HomeRowKind, _HomeRow?>{...quick};
    // Each slow row shows as soon as it's ready (they used to wait for one
    // another), and Today's games twice: straight from the scores feed,
    // then with their channels — matching waits for the whole live list
    // (owner, 2026-11-05: the game cards took seconds to appear).
    void arrived(HomeRowKind kind, _HomeRow? row) {
      slow[kind] = row;
      _apply(id, slow, focusFirst: focusFirst, done: false);
    }

    await Future.wait(<Future<void>>[
      // At launch the live lists load after the UI shows (the TV tab asks
      // for them): Home opened then had no Favourite channels until a trip
      // to the TV tab (owner, 2026-11-09). Already loaded = at once.
      if (visible.contains(HomeRowKind.favourites))
        playlist.ensureLiveChannelsLoaded().then((_) => arrived(
            HomeRowKind.favourites, _favouritesRow(epg, playlist, prefs))),
      if (visible.contains(HomeRowKind.games))
        () async {
          arrived(HomeRowKind.games,
              await _gamesRow(storage, playlist, epg, match: false));
          arrived(HomeRowKind.games, await _gamesRow(storage, playlist, epg));
        }(),
      if (visible.contains(HomeRowKind.newMovies))
        _newMoviesRow(playlist).then((r) => arrived(HomeRowKind.newMovies, r)),
      if (visible.contains(HomeRowKind.newShows))
        _newShowsRow(playlist).then((r) => arrived(HomeRowKind.newShows, r)),
    ].map((f) => f.catchError((Object e, StackTrace st) {
          // The first frames of the stack say which row and which call:
          // "RangeError (length) 0..5440: 40600" (LOG-NDQPJU) had no origin.
          final where = st.toString().split('\n').take(6).join(' | ');
          debugPrint('HomeScreen: row failed: $e [$where]');
          return null;
        })));
    _apply(id, slow, focusFirst: focusFirst, done: true);
  }

  void _apply(int id, Map<HomeRowKind, _HomeRow?> byKind,
      {required bool focusFirst, required bool done}) {
    if (!mounted || id != _loadId) return;
    final hadFocus = _rows.isNotEmpty;
    final previous =
        _rows.isEmpty ? null : _rows[_row.clamp(0, _rows.length - 1)].kind;
    setState(() {
      _rows = [
        for (final k in _rowsConfig.visible)
          if (byKind[k] case final r? when r.items.isNotEmpty) r,
      ];
      _loading = !done;
      // Keep the selector on the same row when a slower row appears above.
      final keep =
          previous == null ? -1 : _rows.indexWhere((r) => r.kind == previous);
      _row = keep >= 0
          ? keep
          : _row.clamp(0, _rows.isEmpty ? 0 : _rows.length - 1);
      if (_focused == null && _rows.isNotEmpty) {
        _focused = _rows[_row].items.first;
      }
    });
    if (focusFirst && done && hadFocus && !_userMoved && _rows.isNotEmpty) {
      _row = 0;
      _focused = _rows.first.items.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_userMoved) _focusCard(0, 0);
      });
    } else if (focusFirst && !hadFocus && _rows.isNotEmpty) {
      // The profiles strip only held the remote because no row was there
      // yet (the launch, see below): the first row takes it once it comes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (!_inProfiles || !_userMoved)) {
          _focusCard(_row, _cardIndex[_rows[_row].kind] ?? 0);
        }
      });
    } else if (focusFirst && _rows.isEmpty && !_inProfiles) {
      // Nothing to show yet (slow rows still loading, or none at all): the
      // remote needs a target, so the profiles strip takes it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rows.isEmpty) _focusProfiles();
      });
    }
  }

  _HomeRow? _continueRow() {
    final playback = context.read<PlaybackService>();
    final storage = context.read<StorageService>();
    final hub = context.read<ArchiveService>();
    final items = <({int at, _HomeItem item})>[];
    final played = playback.recentlyPlayed;

    // Playlists' movies and episodes (one card per show), newest first.
    final seenSeries = <String>{};
    for (var i = 0; i < played.length; i++) {
      final c = played[i];
      if (c.isLive ||
          c.playlistId == ArchiveService.playlistId ||
          storage.getLastPosition(c.id) <= 0 ||
          storage.isFullyWatched(c.id)) {
        continue;
      }
      final isEpisode = c.rawId.startsWith('xt_ep_');
      if (isEpisode && c.seriesId != null) {
        if (!seenSeries.add('${c.playlistId}:${c.seriesId}')) continue;
        final series = XtreamSeries(
          seriesId: c.seriesId!,
          playlistId: c.playlistId,
          name: c.seriesName ?? c.name,
          categoryId: '',
          coverUrl: c.seriesCoverUrl,
        );
        items.add((
          at: i,
          item: _HomeItem(
            key: 'cw:${c.id}',
            removeFromHistory: () => playback.removeFromHistory(c),
            title: c.seriesName ?? c.name,
            subtitle: c.name,
            imageUrl: c.backdropUrl ?? c.seriesCoverUrl ?? c.logoUrl,
            backdropUrl: c.backdropUrl,
            progress: storage.getWatchedFraction(c.id),
            open: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(series: series))),
          )
        ));
      } else if (!isEpisode) {
        items.add((
          at: i,
          item: _HomeItem(
            key: 'cw:${c.id}',
            removeFromHistory: () => playback.removeFromHistory(c),
            title: c.name,
            subtitle: tr('Movie'),
            imageUrl: c.backdropUrl ?? c.posterUrl ?? c.logoUrl,
            backdropUrl: c.backdropUrl,
            progress: storage.getWatchedFraction(c.id),
            open: (ctx) => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => MovieDetailScreen(channel: c))),
          )
        ));
      }
    }

    // Media Hub (add-ons / debrid / Jellyfin): its own history, placed
    // where its last play sits among the playlists' plays.
    for (final entry in [
      ...hub.continueWatching(ArchiveType.movie),
      ...hub.continueWatching(ArchiveType.series)
    ]) {
      final source = entry.source, meta = entry.meta;
      final vod = 'arc_vod_${source.key}_${meta.id}';
      final ep = 'arc_ep_${source.key}_${meta.id}';
      var at =
          played.indexWhere((c) => c.rawId == vod || c.rawId.startsWith(ep));
      if (at < 0) at = played.length;
      items.add((
        at: at,
        item: _HomeItem(
          key: 'hub:${source.key}:${meta.id}',
          removeFromHistory: () => hub.removeFromHistory(source, meta),
          title: meta.name,
          subtitle:
              entry.episodeLabel.isNotEmpty ? entry.episodeLabel : source.name,
          imageUrl: meta.backgroundUrl ?? meta.posterUrl,
          backdropUrl: meta.backgroundUrl,
          description: meta.description,
          progress: entry.progress,
          open: (ctx) => openArchiveContinuation(ctx, entry),
        )
      ));
    }
    items.sort((a, b) => a.at.compareTo(b.at));
    return _HomeRow(HomeRowKind.continueWatching, _CardShape.wide,
        [for (final e in items.take(20)) e.item]);
  }

  /// "Notify me" shows: a new episode first ("S1 E3 is available"), then
  /// the next scheduled ones ("S1 E4 · Airs in 5 days"), like Nuvio.
  _HomeRow? _newEpisodesRow() {
    final alerts = _episodeAlerts;
    if (alerts == null) return null;
    final now = DateTime.now();
    final noticed = <String>{};
    final items = <_HomeItem>[
      for (final n in alerts.notices)
        if (alerts.show(n.showKey) case final show? when noticed.add(n.showKey))
          _HomeItem(
            key: 'ne:${n.showKey}',
            title: n.title,
            subtitle: n.count > 1
                ? tr('{count} new episodes - {code} is available',
                    {'count': '${n.count}', 'code': n.code})
                : tr('{code} is available', {'code': n.code}),
            description: n.episodeTitle,
            imageUrl: show.backdropUrl ?? show.posterUrl,
            backdropUrl: show.backdropUrl,
            tag: tr('NEW'),
            tagHighlight: true,
            removeLabel: 'Dismiss',
            removeFromHistory: () => alerts.dismiss(n.showKey),
            open: (ctx) => _openFollowed(ctx, show),
          ),
    ];
    final upcoming = [
      for (final s in alerts.shows)
        if (s.next case final next?
            when !noticed.contains(s.key) && next.upcoming(now))
          (show: s, next: next)
    ]..sort((a, b) => a.next.date.compareTo(b.next.date));
    for (final (:show, :next) in upcoming) {
      items.add(_HomeItem(
        key: 'ne:${show.key}',
        title: show.title,
        subtitle: next.season != null && next.episode != null
            ? 'S${next.season} E${next.episode}'
            : null,
        tag: _airsIn(next.displayDate, now),
        imageUrl: show.backdropUrl ?? show.posterUrl,
        backdropUrl: show.backdropUrl,
        open: (ctx) => _openFollowed(ctx, show),
      ));
    }
    return _HomeRow(HomeRowKind.newEpisodes, _CardShape.wide, items);
  }

  static String _airsIn(DateTime date, DateTime now) {
    final days = DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days <= 0) return tr('Airs today');
    if (days == 1) return tr('Airs tomorrow');
    return tr('Airs in {count} days', {'count': '$days'});
  }

  Future<void> _openFollowed(BuildContext ctx, FollowedShow show) async {
    if (!show.isMediaHub) {
      final playlistId = show.playlistId, seriesId = show.seriesId;
      if (playlistId == null || seriesId == null) return;
      await Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
              series: XtreamSeries(
                  seriesId: seriesId,
                  playlistId: playlistId,
                  name: show.title,
                  categoryId: show.categoryId ?? '',
                  coverUrl: show.posterUrl,
                  backdropUrl: show.backdropUrl,
                  tmdbId: show.tmdbId))));
      return;
    }
    final hub = ctx.read<ArchiveService>();
    ArchiveSource? source;
    for (final s in hub.sources) {
      if (s.manifestUrl == show.sourceUrl) source = s;
    }
    final meta = show.meta == null ? null : ArchiveMeta.fromJson(show.meta!);
    if (source == null || meta == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(tr("This show's Media Hub source was removed."))));
      return;
    }
    await openArchiveSeries(ctx, source, meta);
  }

  /// A Media Hub title on the watch list, through its source.
  Future<void> _openHubTitle(BuildContext ctx, HubTitle title) async {
    ArchiveSource? source;
    for (final s in ctx.read<ArchiveService>().enabledSources) {
      if (s.manifestUrl == title.sourceUrl) source = s;
    }
    if (source == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(tr("This title's Media Hub source is not available."))));
      return;
    }
    if (title.meta.type == ArchiveType.series) {
      await openArchiveSeries(ctx, source, title.meta);
    } else {
      await Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) =>
              ArchiveDetailScreen(source: source!, preview: title.meta)));
    }
  }

  _HomeItem _channelItem(Channel c, EpgService epg, String prefix) {
    final now = epg.getCurrentProgram(c.epgId);
    return _HomeItem(
      key: '$prefix:${c.id}',
      removeFromHistory: prefix == 'rc'
          ? () => context.read<PlaybackService>().removeFromHistory(c)
          : null,
      title: c.name,
      subtitle: now?.title ?? c.group,
      imageUrl: c.logoUrl,
      logoUrl: c.logoUrl,
      programme: now,
      live: true,
      preview: c,
      open: (ctx) => _playChannel(ctx, c),
    );
  }

  /// Vesper AI / AI apps changed the watch list (maybe from the phone).
  void _watchListChanged() {
    if (mounted) unawaited(_load());
  }

  /// The viewer's watch list (Vesper AI's `watchlist` tool fills it).
  _HomeRow? _watchListRow(StorageService storage) {
    final list = WatchList.instance;
    return _HomeRow(HomeRowKind.watchList, _CardShape.poster, [
      for (final i in list.load(storage).take(40))
        _HomeItem(
          key: 'wl:${i.id}',
          title: i.title,
          subtitle: i.note,
          imageUrl: i.posterUrl,
          backdropUrl: i.backdropUrl,
          removeFromHistory: () => list.remove(storage, i.id),
          removeLabel: 'Remove from watch list',
          preview: (i.channel?.isLive ?? false) ? i.channel : null,
          open: (ctx) {
            if (i.hub case final h?) return _openHubTitle(ctx, h);
            if (i.series case final s?) {
              return Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => SeriesDetailScreen(series: s)));
            }
            final c = i.channel!;
            if (c.isLive) return _playChannel(ctx, c);
            return Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => MovieDetailScreen(channel: c)));
          },
        ),
    ]);
  }

  _HomeRow? _recentRow(EpgService epg) {
    final seen = <String>{};
    final live = [
      for (final c in context.read<PlaybackService>().recentlyPlayed)
        if (c.isLive && seen.add(c.id)) c,
    ];
    return _HomeRow(HomeRowKind.recentChannels, _CardShape.wide,
        [for (final c in live.take(20)) _channelItem(c, epg, 'rc')]);
  }

  _HomeRow? _favouritesRow(
      EpgService epg, PlaylistManager playlist, AppPreferences prefs) {
    final channels = playlist.orderedFavoriteLiveChannels(
        mixPlaylists: prefs.mixFavoritePlaylists);
    return _HomeRow(HomeRowKind.favourites, _CardShape.wide,
        [for (final c in channels.take(30)) _channelItem(c, epg, 'fav')]);
  }

  /// [match] false: the cards without channels yet (see [_load]); a tap
  /// then opens Sports Trak, like a game no channel carries.
  Future<_HomeRow?> _gamesRow(
      StorageService storage, PlaylistManager playlist, EpgService epg,
      {bool match = true}) async {
    final games = await MultiviewSports.todaysGames(
        storage: storage, playlist: playlist, epg: epg, match: match);
    final hideScores = storage.getSportsHideScores();
    return _HomeRow(HomeRowKind.games, _CardShape.wide, [
      for (final g in games.take(20))
        _HomeItem(
          key: 'game:${g.game.id}',
          title: g.game.title,
          subtitle: g.matches.isEmpty
              ? g.game.league.name
              : '${g.game.league.name} · ${g.matches.first.channel.name}',
          live: g.game.state == GameState.live,
          game: g.game,
          // Only a game on now: an upcoming one's channel shows another show.
          preview: g.matches.isEmpty || g.game.state != GameState.live
              ? null
              : g.matches.first.channel,
          description: hideScores ? null : _scoreLine(g.game),
          open: (ctx) async {
            if (g.matches.isEmpty) {
              await Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const SportsScreen()));
            } else {
              await MultiviewSports.rememberPick(
                  storage, g.game, g.matches.first.channel);
              if (ctx.mounted) await _playChannel(ctx, g.matches.first.channel);
            }
          },
        ),
    ]);
  }

  Future<_HomeRow?> _newMoviesRow(PlaylistManager playlist) async {
    final movies = await playlist.whatsNewVod(limit: 20);
    return _HomeRow(HomeRowKind.newMovies, _CardShape.poster, [
      for (final c in movies)
        _HomeItem(
          key: 'nm:${c.id}',
          title: c.name,
          subtitle: c.rating,
          imageUrl: c.posterUrl ?? c.logoUrl,
          backdropUrl: c.anyBackdropUrl,
          open: (ctx) => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => MovieDetailScreen(channel: c))),
        ),
    ]);
  }

  Future<_HomeRow?> _newShowsRow(PlaylistManager playlist) async {
    final shows = await playlist.whatsNewSeries(limit: 20);
    return _HomeRow(HomeRowKind.newShows, _CardShape.poster, [
      for (final s in shows)
        _HomeItem(
          key: 'ns:${s.id}',
          title: s.name,
          subtitle: s.rating,
          imageUrl: s.posterUrl ?? s.coverUrl,
          backdropUrl: s.anyBackdropUrl,
          open: (ctx) => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: s))),
        ),
    ]);
  }

  static String? _scoreLine(SportsGame g) {
    if (g.state == GameState.pre) return null;
    final a = g.first.score, b = g.second.score;
    if (a == null || b == null) return null;
    return '${g.first.abbreviation} $a – $b ${g.second.abbreviation}';
  }

  /// Plays [c] full screen (Windows: its own player), like the live list.
  /// The mini player's stream goes full screen as it is (no reconnect) and
  /// Back returns it there.
  static Future<void> _playChannel(BuildContext context, Channel c) async {
    if (isDesktop) {
      final mini = DesktopMiniPlayer.instance;
      final session = mini.channel.value?.id == c.id ? mini.take() : null;
      if (session == null) mini.clear();
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DesktopPlayerScreen(
              channel: c,
              existingPlayer: session?.$1,
              existingController: session?.$2)));
      return;
    }
    final playback = context.read<PlaybackService>();
    // OK is a real pick: a highlight play hasn't joined History yet.
    if (playback.currentChannel?.id == c.id) {
      unawaited(playback.recordWatched(c));
    }
    // Awaited: PlayerScreen's own play() must find it current (see
    // TvHomeScreen._selectChannel).
    await playback.play(c);
    if (!context.mounted) return;
    // Grows out of the mini player when the native surface draws it.
    await Navigator.of(context)
        .push(PlayerGlideRoute.open(playback, (_) => PlayerScreen(channel: c)));
  }

  /// The remote moved: a live card it rests on plays in the mini player
  /// (see [_miniDelay]).
  bool _noteKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final now = DateTime.now();
    _lastKeyAt = now;
    if (_navKeys.contains(event.logicalKey)) _lastNavKeyAt = now;
    return false;
  }

  /// [item] took the focus: restarts the mini player's wait. Only with
  /// Settings > Interface > Guide > Preview on highlight on (owner,
  /// 2026-11-10: a user with it off still got previews while scrolling
  /// Home); off, OK (or Play/Pause) on a card plays it.
  void _scheduleMini(_HomeItem item) {
    _miniTimer?.cancel();
    _miniTimer = null;
    final channel = item.preview;
    if (channel == null ||
        !HomeScreen.showsMiniPlayer(context) ||
        !context.read<AppPreferences>().guideFocusPreview) {
      return;
    }
    final armedAt = DateTime.now();
    if (armedAt.difference(_lastNavKeyAt) > const Duration(milliseconds: 500)) {
      return;
    }
    _miniTimer = Timer(_miniDelay, () {
      _miniTimer = null;
      // Any key since (OK, Back, a hold) = the remote didn't rest here.
      if (_lastKeyAt.isAfter(armedAt)) return;
      if (!mounted || _inProfiles || _focused?.key != item.key) return;
      if (_miniOff) {
        if (_miniChannelId() == null) return;
        _miniOff = false;
      }
      unawaited(_miniPlay(channel));
    });
  }

  /// Plays [channel] in the mini player; false when it can't (a recording
  /// holds the account's only connection, or Home is covered).
  Future<bool> _miniPlay(Channel channel) async {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final playback = context.read<PlaybackService>();
    if (isDesktopTarget) {
      final mini = DesktopMiniPlayer.instance;
      if (mini.channel.value?.id == channel.id) return true;
      mini.play(channel);
      unawaited(context.read<StorageService>().setLastChannelId(channel.id));
      _recordAfterWatching(playback, channel,
          () => DesktopMiniPlayer.instance.channel.value?.id == channel.id);
      return true;
    }
    if (playback.liveChannel?.id == channel.id) return true;
    // A recording holds this account's only connection: OK asks Stop
    // recording / Cancel first, a highlight never pops that up.
    final profiles = context.read<PlaylistManager>().profiles;
    if (RecordingService.instance.conflictFor(channel, profiles) != null) {
      return false;
    }
    _recordAfterWatching(
        playback, channel, () => playback.currentChannel?.id == channel.id);
    await playback.play(channel, recordHistory: false);
    return true;
  }

  /// History for a mini player play once it has played [_miniHistoryAfter]
  /// (still playing then, mini player or full screen).
  void _recordAfterWatching(
      PlaybackService playback, Channel channel, bool Function() stillPlaying) {
    _miniHistory?.cancel();
    _miniHistory = Timer(_miniHistoryAfter, () {
      _miniHistory = null;
      if (stillPlaying()) unawaited(playback.recordWatched(channel));
    });
  }

  static final _playKeys = {
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
    LogicalKeyboardKey.mediaStop,
  };

  /// The remote's Play/Pause (owner, 2026-11-09: a way to turn the mini
  /// player off that isn't Back, which leaves Home): turns it off
  /// whatever card the remote is on (owner, 2026-11-10: OK plays a card,
  /// Play/Pause turns it off). With nothing playing, it plays the live card
  /// the remote is on. Stop always stops.
  void _onPlayKey(LogicalKeyboardKey key) {
    _miniTimer?.cancel();
    _miniTimer = null;
    final card = _inProfiles ? null : _focused?.preview;
    if (key != LogicalKeyboardKey.mediaStop &&
        card != null &&
        _miniChannelId() == null) {
      _miniOff = false;
      unawaited(_miniPlay(card));
    } else {
      unawaited(_stopMini());
    }
  }

  /// The live channel the mini player shows, if any.
  String? _miniChannelId() {
    if (isDesktopTarget) return DesktopMiniPlayer.instance.channel.value?.id;
    final playback = context.read<PlaybackService>();
    final channel = playback.currentChannel;
    if (channel == null || (!channel.isLive && playback.catchup == null)) {
      return null;
    }
    return playback.liveChannel?.id;
  }

  /// Turns the mini player off: its channel stops and highlights stay
  /// quiet until OK or Play/Pause plays a card ([_miniOff]).
  Future<void> _stopMini() async {
    _miniOff = true;
    _miniHistory?.cancel();
    _miniHistory = null;
    if (_miniChannelId() == null) return;
    if (isDesktopTarget) {
      DesktopMiniPlayer.instance.clear();
      return;
    }
    final playback = context.read<PlaybackService>();
    if (playback.isFullscreenActive) return;
    await playback.stop();
  }

  /// A movie, show or Media Hub title opened from Home: the mini player's
  /// channel stops, as on entering Movies / TV Shows, and stays resumable
  /// (see TvHomeScreen._parkLiveChannel). Android only.
  Future<void> _parkMini() async {
    if (isDesktopTarget) return;
    final playback = context.read<PlaybackService>();
    final channel = playback.currentChannel;
    final resumeTo = playback.catchup?.live ?? channel;
    if (channel == null ||
        playback.isFullscreenActive ||
        (!channel.isLive && playback.catchup == null)) {
      return;
    }
    await playback.stop();
    playback.setPendingResumeChannel(resumeTo);
  }

  Future<void> _open(_HomeItem item) async {
    _miniTimer?.cancel();
    // OK on a live card plays it in the mini player, OK on the card it
    // plays opens it full screen, like the TV guide's preview (owner,
    // 2026-11-10). No mini player (phones, switched off) = full screen.
    final channel = item.preview;
    if (channel != null &&
        HomeScreen.showsMiniPlayer(context) &&
        _miniChannelId() != channel.id) {
      _miniOff = false;
      // A recording on the account's only connection: full screen asks.
      if (await _miniPlay(channel)) return;
      if (!mounted) return;
    }
    if (item.preview == null && item.game == null) await _parkMini();
    if (!mounted) return;
    await item.open(context);
    // Back on Home: what was watched moves to the front of its rows.
    if (mounted) {
      unawaited(_load());
      _hubProgressRefresh?.cancel();
      _hubProgressRefresh = Timer(const Duration(milliseconds: 600), () {
        if (mounted) unawaited(_load());
      });
    }
  }

  // --------------------------------------------------------------- focus --

  double _extent(_CardShape s) =>
      (s == _CardShape.poster ? _posterW : _wideW) + _gap;

  void _focusCard(int r, int i) {
    if (_rows.isEmpty) return;
    r = r.clamp(0, _rows.length - 1);
    final row = _rows[r];
    i = i.clamp(0, row.items.length - 1);
    _row = r;
    _inProfiles = false;
    final c = _rowScrolls[row.kind];
    if (c != null && c.hasClients) {
      final pos = c.position;
      final ext = _extent(row.shape);
      final start = i * ext;
      double? to;
      if (start - ext < pos.pixels) {
        to = start - ext;
      } else if (start + 2 * ext > pos.pixels + pos.viewportDimension) {
        to = start + 2 * ext - pos.viewportDimension;
      }
      if (to != null) c.jumpTo(to.clamp(0.0, pos.maxScrollExtent));
    }
    final ctx = _rowKey(row.kind).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.0, duration: Duration.zero);
    }
    _focusWhenBuilt(_node(row.kind, i));
  }

  void _focusWhenBuilt(FocusNode node, [int framesLeft = 4]) {
    if (node.context != null) {
      node.requestFocus();
    } else if (framesLeft > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusWhenBuilt(node, framesLeft - 1);
      });
    }
  }

  void _focusProfiles([int? index]) {
    if (context.read<AppPreferences>().hideProfiles) {
      if (_inProfiles) setState(() => _inProfiles = false);
      if (_rows.isEmpty) {
        _emptyFocus.requestFocus();
      } else {
        _focusCard(0, _cardIndex[_rows.first.kind] ?? 0);
      }
      return;
    }
    final count = context.read<ViewerProfileService>().profiles.length;
    _profileIndex = (index ?? _activeProfileIndex()).clamp(0, count);
    setState(() => _inProfiles = true);
    if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
    _focusWhenBuilt(
        _profileIndex == count ? _addProfileNode : _profileNode(_profileIndex));
  }

  int _activeProfileIndex() {
    final viewers = context.read<ViewerProfileService>();
    final i = viewers.profiles.indexWhere((p) => p.id == viewers.active.id);
    return i < 0 ? 0 : i;
  }

  FocusNode _profileNode(int i) {
    while (_profileNodes.length <= i) {
      _profileNodes.add(FocusNode(debugLabel: 'home profile $i'));
    }
    return _profileNodes[i];
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (_playKeys.contains(key) && HomeScreen.showsMiniPlayer(context)) {
      if (event is KeyDownEvent) _onPlayKey(key);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _userMoved = true;
    }
    if (_inProfiles) {
      final count = context.read<ViewerProfileService>().profiles.length;
      if (key == LogicalKeyboardKey.arrowRight) {
        if (_profileIndex < count) _focusProfiles(_profileIndex + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        // The first profile card still leads to the tabs column (with every
        // content tab hidden, that's the way to Settings).
        if (_profileIndex > 0) {
          _focusProfiles(_profileIndex - 1);
        } else {
          Navigator.of(context).maybePop();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        if (_rows.isNotEmpty) {
          _focusCard(0, _cardIndex[_rows.first.kind] ?? 0);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
      return KeyEventResult.ignored;
    }
    if (_rows.isEmpty) {
      if (key == LogicalKeyboardKey.arrowLeft) Navigator.of(context).maybePop();
      if ([
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown
      ].contains(key)) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final row = _rows[_row.clamp(0, _rows.length - 1)];
    final i = _cardIndex[row.kind] ?? 0;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_row < _rows.length - 1) {
        _focusCard(_row + 1, _cardIndex[_rows[_row + 1].kind] ?? 0);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_row > 0) {
        _focusCard(_row - 1, _cardIndex[_rows[_row - 1].kind] ?? 0);
      } else {
        _focusProfiles();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < row.items.length - 1) _focusCard(_row, i + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      // First card of a row: stay. Left there kept dropping out of Home to
      // the IPTV home (owner, 2026-11-05); Back, or Up to the profiles
      // strip then Left, still leaves.
      if (i > 0) _focusCard(_row, i - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ profiles --

  Future<void> _switchProfile(ViewerProfile p) async {
    final viewers = context.read<ViewerProfileService>();
    if (p.id == viewers.active.id) {
      if (_rows.isNotEmpty) _focusCard(0, 0);
      return;
    }
    setState(() => _switching = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    final switched = await viewers.switchTo(context, p.id);
    if (!mounted) return;
    if (switched) {
      _rowsConfig = HomeRows.load(context.read<StorageService>());
      _cardIndex.clear();
      _focused = null;
      _row = 0;
      _rows = const [];
      _loading = true;
      for (final c in _rowScrolls.values) {
        if (c.hasClients) c.jumpTo(0);
      }
      unawaited(_loadWallpaper());
      unawaited(_load());
    }
    setState(() => _switching = false);
    _focusProfiles();
  }

  Future<void> _manageProfiles() async {
    final viewers = context.read<ViewerProfileService>();
    if (!await viewers.requireUnlock(context) || !mounted) return;
    final id = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const AddProfileScreen()));
    if (mounted) {
      final index = viewers.profiles.indexWhere((p) => p.id == id);
      _focusProfiles(index < 0 ? null : index);
    }
  }

  Future<void> _editProfile(ViewerProfile profile) async {
    await openProfileEditor(context, profile.id);
    if (mounted) _focusProfiles();
  }

  // ---------------------------------------------------------- row editing --

  Future<void> _rowMenu(HomeRowKind kind, [_HomeItem? item]) async {
    final storage = context.read<StorageService>();
    final viewer = storage.getActiveViewerId();
    final shown = _rowsConfig.visible;
    final i = shown.indexOf(kind);
    // The mini player's off switch for remotes without Play/Pause; first,
    // so a hold then OK turns it off.
    final stopMini =
        HomeScreen.showsMiniPlayer(context) && _miniChannelId() != null;
    final firstFree = !stopMini && item?.removeFromHistory == null;
    final choice = await showGlassMenu<String>(
      context: context,
      builder: (context) => GlassMenuDialog(
        title: Text(tr(kind.title)),
        children: [
          if (stopMini)
            TvDialogOption(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop('stopmini'),
              child: Text(tr('Stop mini player')),
            ),
          if (item?.removeFromHistory != null)
            TvDialogOption(
              autofocus: !stopMini,
              onPressed: () => Navigator.of(context).pop('remove'),
              child: Text(tr(item!.removeLabel)),
            ),
          if (i > 0)
            TvDialogOption(
              autofocus: firstFree,
              onPressed: () => Navigator.of(context).pop('up'),
              child: Text(tr('Move row up')),
            ),
          if (i < shown.length - 1)
            TvDialogOption(
              autofocus: i == 0 && firstFree,
              onPressed: () => Navigator.of(context).pop('down'),
              child: Text(tr('Move row down')),
            ),
          TvDialogOption(
            autofocus: shown.length == 1 && firstFree,
            onPressed: () => Navigator.of(context).pop('hide'),
            child: Text(tr('Hide this row')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('edit'),
            child: Text(tr('Edit Home rows…')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || storage.getActiveViewerId() != viewer) {
      return;
    }
    if (choice == 'stopmini') {
      _miniTimer?.cancel();
      await _stopMini();
      return;
    }
    if (choice == 'remove') {
      await item?.removeFromHistory?.call();
      if (!mounted || storage.getActiveViewerId() != viewer) return;
      _focused = null;
      // _load paints the quick history rows before fetching games/catalogs.
      // Restore remote focus on that first frame, without waiting on a feed.
      unawaited(_load());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || storage.getActiveViewerId() != viewer) return;
        if (_rows.isEmpty) {
          _focusProfiles();
        } else {
          final row = _rows.indexWhere((r) => r.kind == kind);
          _focusCard(row < 0 ? 0 : row, _cardIndex[kind] ?? 0);
        }
      });
      return;
    }
    switch (choice) {
      case 'up' || 'down':
        _rowsConfig.move(kind, choice == 'up' ? -1 : 1);
      case 'hide':
        _rowsConfig.setHidden(kind, true);
      case 'edit':
        await _editRows();
        return;
    }
    await _saveRows(keep: choice == 'hide' ? null : kind);
  }

  /// Every row with a switch (a hidden row comes back from here).
  Future<void> _editRows() async {
    await showGlassMenu<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => GlassMenuDialog(
          title: Text(tr('Home rows')),
          children: [
            for (final (n, k) in _rowsConfig.order.indexed)
              TvDialogOption(
                autofocus: n == 0,
                onPressed: () => setDialog(() =>
                    _rowsConfig.setHidden(k, !_rowsConfig.hidden.contains(k))),
                child: Row(children: [
                  Icon(
                      _rowsConfig.hidden.contains(k)
                          ? Icons.check_box_outline_blank
                          : Icons.check_box,
                      size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr(k.title))),
                ]),
              ),
            TvDialogOption(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Done')),
            ),
          ],
        ),
      ),
    );
    if (mounted) await _saveRows();
  }

  Future<void> _saveRows({HomeRowKind? keep}) async {
    await _rowsConfig.save(context.read<StorageService>());
    if (!mounted) return;
    await _load();
    if (!mounted || _rows.isEmpty) return;
    final r = keep == null ? 0 : _rows.indexWhere((x) => x.kind == keep);
    _focusCard(r < 0 ? 0 : r, keep == null ? 0 : (_cardIndex[keep] ?? 0));
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final hideProfiles = prefs.hideProfiles;
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    // Profiles + hero stay put; only the rows scroll under them.
    final heroHeight = (size.height * 0.34).clamp(150.0, 380.0);
    final focused = _focused;
    // 16:9 in the hero's right side, its room kept even while nothing
    // plays (the hero text doesn't jump when a channel starts).
    final mini =
        prefs.homeMiniPlayer && size.width >= HomeScreen.miniPlayerMinWidth;
    final miniHeight = heroHeight - 16;
    final miniWidth = math.min(miniHeight * 16 / 9, size.width * 0.38);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _emptyFocus,
        canRequestFocus: hideProfiles && _rows.isEmpty,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(item: focused, wallpaper: _wallpaper),
            AnimatedOpacity(
              opacity: _switching ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              // Below the phone's status bar / notch: the profile cards sat
              // on the clock (owner, 2026-11-02). The backdrop stays full
              // screen behind it.
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hideProfiles && (isDesktop || size.width >= 800))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Row(children: [
                          if (isDesktop)
                            ExcludeFocus(
                                child: IconButton(
                              tooltip: tr('Back'),
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: () => Navigator.of(context).maybePop(),
                            )),
                          const Spacer(),
                          if (size.width >= 800) const _HomeClock(),
                        ]),
                      ),
                    if (!hideProfiles)
                      _ProfilesStrip(
                        compact: !_inProfiles,
                        nodes: _profileNode,
                        addNode: _addProfileNode,
                        onPick: _switchProfile,
                        onEdit: _editProfile,
                        onAdd: _manageProfiles,
                        onFocus: (i) {
                          if (!_inProfiles || _profileIndex != i) {
                            setState(() {
                              _inProfiles = true;
                              _profileIndex = i;
                            });
                          }
                        },
                      ),
                    SizedBox(
                      height: heroHeight,
                      child: Row(children: [
                        Expanded(child: _Hero(item: focused, scheme: scheme)),
                        if (mini)
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(0, 8, _sidePad, 8),
                            child: _MiniPlayer(
                                width: miniWidth,
                                height: miniHeight,
                                focusedChannelId: focused?.preview?.id),
                          ),
                      ]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _pageScroll,
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_rows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: _sidePad, vertical: 24),
                                child: _loading
                                    ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5))
                                    : Text(
                                        tr(
                                            'Nothing here yet. Watch a channel, a movie or a show and it shows up on Home.'),
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16)),
                              ),
                            for (var r = 0; r < _rows.length; r++)
                              _buildRow(r, scheme),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int r, ColorScheme scheme) {
    final row = _rows[r];
    final poster = row.shape == _CardShape.poster;
    final w = poster ? _posterW : _wideW;
    final h = poster ? _posterH : _wideH;
    final active = !_inProfiles && r == _row;
    return Column(
      key: _rowKey(row.kind),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_sidePad, 10, _sidePad, 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: active ? scheme.primary : Colors.white),
            child: Text(tr(row.kind.title)),
          ),
        ),
        SizedBox(
          // Room for the focused card's zoom and its title underneath.
          height: h + 48,
          child: ListView.builder(
            controller: _rowScroll(row.kind),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _sidePad - 8),
            itemExtent: w + _gap,
            clipBehavior: Clip.none,
            itemCount: row.items.length,
            itemBuilder: (_, i) {
              final item = row.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                child: _HomeCard(
                  item: item,
                  width: w,
                  height: h,
                  poster: poster,
                  focusNode: _node(row.kind, i),
                  onTap: () => _open(item),
                  onHold: () => _rowMenu(row.kind, item),
                  onFocus: () {
                    _cardIndex[row.kind] = i;
                    _scheduleMini(item);
                    if (identical(_focused, item) &&
                        _row == r &&
                        !_inProfiles) {
                      return;
                    }
                    setState(() {
                      _row = r;
                      _inProfiles = false;
                      _focused = item;
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

/// Full-screen art of the focused card, cross-faded, darkened toward the
/// rows and the left edge so text always reads.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.item, this.wallpaper});
  final _HomeItem? item;

  /// The viewer's Home wallpaper: behind any card without art of its own,
  /// in place of a live channel's glow (owner, 2026-11-10).
  final Uint8List? wallpaper;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final url = item?.backdropUrl;
    final game = item?.game;
    final size = MediaQuery.sizeOf(context);
    final teamGame = game != null && game.league.kind == SportsKind.team;
    final art = url != null && url.isNotEmpty;
    final wall = !teamGame && !art ? wallpaper : null;
    final glow = !teamGame && !art && wall == null && (item?.live ?? false);
    final Widget child;
    if (teamGame) {
      child = _GameBackdrop(key: ValueKey('game:${game.id}'), game: game);
    } else if (art) {
      child = Align(
        key: ValueKey(url),
        alignment: Alignment.topRight,
        child: FractionallySizedBox(
          widthFactor: 0.75,
          heightFactor: 0.7,
          alignment: Alignment.topRight,
          child: HdNetworkImage(
            url: url,
            kind: ImageKind.backdrop,
            decodeWidth: (size.width * 0.75).round(),
            errorWidget: (_) => const SizedBox.shrink(),
          ),
        ),
      );
    } else if (wall != null) {
      child = Image.memory(
        wall,
        key: ValueKey(wall),
        fit: BoxFit.cover,
        width: size.width,
        height: size.height,
        cacheWidth: HdNetworkImage.screenDecodeWidth(context, size.width),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (glow) {
      // One key for every channel: the glow morphs from one channel's
      // colours to the next instead of fading out and in.
      child = _ChannelGlow(key: const ValueKey('glow'), logoUrl: item!.logoUrl);
    } else {
      child = const SizedBox.expand(key: ValueKey('none'));
    }
    return Stack(fit: StackFit.expand, children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: child,
      ),
      if (wall != null) ...const [
        // The picture stays visible; the hero text and the rows stay
        // readable over it.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xB3000000), Color(0x00000000)],
              stops: [0, 0.6],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x40000000),
                Color(0x00000000),
                Color(0x99000000),
                Color(0xE6000000)
              ],
              stops: [0, 0.25, 0.55, 1],
            ),
          ),
        ),
      ] else if (glow) ...const [
        // The glow fills the hero and fades out before the rows.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x00000000), Colors.black],
              stops: [0, 0.3, 0.66],
            ),
          ),
        ),
      ] else ...const [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black, Color(0xCC000000), Color(0x33000000)],
              stops: [0.25, 0.5, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Colors.black],
              stops: [0, 0.3, 0.68],
            ),
          ),
        ),
      ],
    ]);
  }
}

/// A live channel's banner when there is no wallpaper (owner, 2026-11-10,
/// from a Discord idea): two soft glows in the logo's own colours
/// ([LogoColors]) behind the hero, the theme's colour for a black / white
/// logo. Moving to another channel blends the colours over.
class _ChannelGlow extends StatefulWidget {
  const _ChannelGlow({super.key, required this.logoUrl});
  final String? logoUrl;

  @override
  State<_ChannelGlow> createState() => _ChannelGlowState();
}

class _ChannelGlowState extends State<_ChannelGlow> {
  List<Color>? _colors;
  String? _url;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_ChannelGlow old) {
    super.didUpdateWidget(old);
    if (old.logoUrl != widget.logoUrl) _read();
  }

  void _read() {
    final url = widget.logoUrl;
    _url = url;
    if (url == null || url.isEmpty) {
      _colors = const [];
      return;
    }
    LogoColors.of(url).then((c) {
      if (mounted && _url == url) setState(() => _colors = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final accent = Theme.of(context).colorScheme.primary;
    final first = colors == null
        ? null
        : colors.isEmpty
            ? accent.withValues(alpha: 0.32)
            : LogoColors.glow(colors.first).withValues(alpha: 0.55);
    final second = colors == null
        ? null
        : colors.length > 1
            ? LogoColors.glow(colors[1]).withValues(alpha: 0.4)
            : (colors.isEmpty ? accent : LogoColors.glow(colors.first))
                .withValues(alpha: 0.18);
    const duration = Duration(milliseconds: 600);
    // Nothing known yet (first channel loading): no glow rather than a
    // flash of the theme colour.
    Color clear(Color? c) => c ?? const Color(0x00000000);
    return Stack(fit: StackFit.expand, children: [
      AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.7, -1.0),
            radius: 1.25,
            colors: [clear(first), clear(first?.withValues(alpha: 0))],
          ),
        ),
      ),
      AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.45, -1.1),
            radius: 1.0,
            colors: [clear(second), clear(second?.withValues(alpha: 0))],
          ),
        ),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.scheme});
  final _HomeItem? item;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 48, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(a),
              child: child),
        ),
        child: item == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Align(
                key: ValueKey(item.key),
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: item.live && item.game == null
                      ? _LiveHero(item: item)
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.live)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: _LivePill(),
                        ),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      if (item.game?.statusText.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              [
                                if (item.description != null) item.description!,
                                item.game!.state == GameState.pre
                                    ? TimeFormat.hm
                                        .format(item.game!.start.toLocal())
                                    : item.game!.statusText,
                              ].join('  ·  '),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary)),
                        ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70)),
                        ),
                      if (item.game == null &&
                          (item.description?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(item.description!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: Colors.white70)),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// The hero for a live channel (owner, 2026-11-10, Discord idea): its logo
/// large with the LIVE pill, what's on now as the title, the channel and
/// the programme's times under it, then the guide's description. Sized to
/// the hero's height (a 1080p TV has ~170 px of it).
class _LiveHero extends StatelessWidget {
  const _LiveHero({required this.item});
  final _HomeItem item;

  @override
  Widget build(BuildContext context) {
    final now = item.programme;
    final logo = item.logoUrl;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight.isFinite ? box.maxHeight : 200.0;
      final logoH = (h * 0.32).clamp(28.0, 72.0);
      final title = now?.title ?? item.title;
      final line = now == null
          ? item.subtitle
          : '${item.title}  ·  ${TimeFormat.hm.format(now.start.toLocal())} – '
              '${TimeFormat.hm.format(now.stop.toLocal())}';
      final description = now?.description?.trim();
      // What's left under logo + title + channel line, in 18 px lines.
      final room = h - logoH - 10 - 32 - 24 - 10;
      final lines = (room / 18).floor().clamp(0, 3);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (logo != null && logo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: logoH * 4, maxHeight: logoH),
                  child: CachedNetworkImage(
                    imageUrl: logo,
                    height: logoH,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    memCacheHeight: (logoH * dpr).round(),
                    fadeInDuration: const Duration(milliseconds: 200),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const _LivePill(),
          ]),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (line != null && line.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          if (lines > 0 && description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(description,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: Colors.white70)),
            ),
        ],
      );
    });
  }
}

/// Home's mini player (owner, 2026-11-09): the live channel playing, the
/// same stream as the TV guide's preview. Android: a [VideoPlayerPane] on
/// [PlaybackService]'s shared controller (with the native surface the
/// picture moves to this hole, the topmost one on screen); Windows:
/// [DesktopMiniPlayer]'s texture. Nothing live playing = an empty slot the
/// backdrop shows through. Its channel's name shows only when it isn't the
/// focused card's (the hero names that one). Tap = full screen.
class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer(
      {required this.width, required this.height, this.focusedChannelId});

  final double width;
  final double height;
  final String? focusedChannelId;

  @override
  Widget build(BuildContext context) {
    if (isDesktopTarget) {
      final mini = DesktopMiniPlayer.instance;
      return ValueListenableBuilder<Channel?>(
        valueListenable: mini.channel,
        builder: (context, channel, _) {
          final controller = mini.controller;
          if (channel == null || controller == null) return _empty();
          return _frame(
            context,
            name: channel.name,
            live: true,
            showName: channel.id != focusedChannelId,
            video: Video(controller: controller, controls: NoVideoControls),
            onTap: () => _HomeScreenState._playChannel(context, channel),
          );
        },
      );
    }
    final playback = context.watch<PlaybackService>();
    final channel = playback.currentChannel;
    final live = playback.liveChannel;
    if (channel == null ||
        live == null ||
        (!channel.isLive && playback.catchup == null)) {
      return _empty();
    }
    final failed = playback.error != null;
    return _frame(
      context,
      name: live.name,
      live: playback.catchup == null,
      showName: failed || live.id != focusedChannelId,
      // The error text needs the full screen: OK there shows it.
      video: failed
          ? const Center(
              child: Icon(Icons.error_outline, color: Colors.white54, size: 28))
          // Keyed by channel like the TV guide's preview pane (stale frame
          // vs. texture teardown, see tv_home_screen).
          : VideoPlayerPane(
              key: ValueKey(channel.id),
              showEpgBar: false,
              showControls: false),
      onTap: () => _HomeScreenState._playChannel(context, channel),
    );
  }

  Widget _empty() => SizedBox(width: width, height: height);

  Widget _frame(BuildContext context,
      {required String name,
      required bool live,
      required bool showName,
      required Widget video,
      required VoidCallback onTap}) {
    return SizedBox(
      width: width,
      height: height,
      // Not focusable: the remote stays on the cards (OK there = full
      // screen); touch / mouse tap the picture.
      child: ExcludeFocus(
        child: VideoTapLayer(
          onTap: onTap,
          // No clip around the video: a clip on a platform view costs weak
          // boxes a lot.
          child: DecoratedBox(
            // A light frame + soft shadow: the picture stands out from a
            // wallpaper or a channel glow (owner, 2026-11-10).
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7), width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 14),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Stack(fit: StackFit.expand, children: [
                video,
                if (showName)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Row(children: [
                      if (live) ...[
                        const _LivePill(),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black)
                                ])),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A focused game's backdrop, in the movie art's place: both logos large
/// with the time / score between, a glow in each team's colour, faded so
/// the backdrop's gradients keep the hero text readable.
class _GameBackdrop extends StatelessWidget {
  const _GameBackdrop({super.key, required this.game});
  final SportsGame game;

  static Color? _teamColor(String? hex) {
    final v = int.tryParse(hex ?? '', radix: 16);
    return v == null || hex!.length != 6 ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final hideScores = context.read<StorageService>().getSportsHideScores();
    return Align(
      alignment: Alignment.topRight,
      child: FractionallySizedBox(
        widthFactor: 0.62,
        heightFactor: 0.62,
        alignment: Alignment.topRight,
        child: LayoutBuilder(builder: (context, box) {
          final logoSize = box.maxHeight * 0.46;
          Widget side(SportsTeam t, Alignment glowAt) {
            final glow = _teamColor(t.color);
            return Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glow == null
                      ? null
                      : RadialGradient(
                          center: glowAt,
                          radius: 0.9,
                          colors: [
                            glow.withValues(alpha: 0.35),
                            glow.withValues(alpha: 0)
                          ],
                        ),
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: logoSize,
                    child: t.logoUrl == null
                        ? const Icon(Icons.shield_outlined,
                            color: Colors.white24, size: 96)
                        : HdNetworkImage(
                            url: t.logoUrl!,
                            kind: ImageKind.poster,
                            decodeWidth: (logoSize * 1.5).round(),
                            fit: BoxFit.contain,
                            errorWidget: (_) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),
            );
          }

          return Opacity(
            opacity: 0.55,
            child: Row(children: [
              side(game.first, Alignment.centerLeft),
              Text(_gameMiddle(game, hideScores),
                  style: TextStyle(
                      fontSize: (logoSize * 0.3).clamp(28.0, 64.0),
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              side(game.second, Alignment.centerRight),
            ]),
          );
        }),
      ),
    );
  }
}

/// Start time before the game, else the score (or the status when scores
/// are hidden / not posted) — shared by the card face and the backdrop.
String _gameMiddle(SportsGame game, bool hideScores) =>
    game.state == GameState.pre
        ? TimeFormat.hm.format(game.start.toLocal())
        : hideScores || game.first.score == null
            ? game.statusText
            : '${game.first.score} – ${game.second.score}';

/// Broadcast red whatever the theme (the palette's error colour came out
/// salmon on Neon Green).
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(4)),
        child: Text(tr('LIVE'),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Colors.white)),
      );
}

/// "NEW" (theme gold) or "Airs in 5 days" (dark glass) on a card's corner.
class _CornerTag extends StatelessWidget {
  const _CornerTag(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: highlight ? gold : Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? Colors.black : Colors.white)),
    );
  }
}

/// A card: art with rounded corners that grows and gets a gold edge when
/// focused, the title (and progress / LIVE) underneath.
class _HomeCard extends StatefulWidget {
  const _HomeCard({
    required this.item,
    required this.width,
    required this.height,
    required this.poster,
    required this.focusNode,
    required this.onTap,
    required this.onHold,
    required this.onFocus,
  });

  final _HomeItem item;
  final double width;
  final double height;
  final bool poster;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback onFocus;

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final url = item.imageUrl;
    // Channel logos sit on a panel; real art fills the card.
    final logo = item.live && !widget.poster && item.backdropUrl == null;
    final art = url == null || url.isEmpty
        ? Center(
            child: item.game != null
                ? _GameCardFace(game: item.game!)
                : Icon(widget.poster ? Icons.movie_outlined : Icons.live_tv,
                    color: Colors.white38, size: 36))
        : Padding(
            padding: logo ? const EdgeInsets.all(22) : EdgeInsets.zero,
            child: HdNetworkImage(
              url: url,
              kind: widget.poster ? ImageKind.poster : ImageKind.backdrop,
              decodeWidth: (widget.width * 2).round(),
              fit: logo ? BoxFit.contain : BoxFit.cover,
              errorWidget: (_) => const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: Colors.white24)),
            ),
          );
    final progress = item.progress;
    final card = AnimatedScale(
      scale: _focused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: widget.width,
        height: widget.height,
        foregroundDecoration: RefinedFinish.artworkRim(
            context, BorderRadius.circular(10),
            focused: _focused),
        decoration: RefinedFinish.decorate(
            context,
            BoxDecoration(
              color: const Color(0xFF16161A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _focused ? scheme.primary : Colors.white10,
                  width: _focused ? 3 : 1),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 1)
                    ]
                  : const [],
            ),
            focused: _focused,
            artwork: true),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          art,
          if (item.live) const Positioned(left: 8, top: 8, child: _LivePill()),
          if (item.tag case final tag?)
            Positioned(
                right: 8,
                top: 8,
                child: _CornerTag(tag, highlight: item.tagHighlight)),
          if (progress != null && progress > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.black54,
                color: scheme.primary,
              ),
            ),
        ]),
      ),
    );
    return HoldToActivate(
      onTap: widget.onTap,
      onHold: widget.onHold,
      child: InkWell(
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        onLongPress: widget.onHold,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) widget.onFocus();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            card,
            const SizedBox(height: 8),
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _focused ? Colors.white : Colors.white70)),
            if (!widget.poster &&
                item.subtitle != null &&
                item.subtitle!.isNotEmpty)
              Text(item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

/// A game card without art: both logos, the score or kick-off time.
class _GameCardFace extends StatelessWidget {
  const _GameCardFace({required this.game});
  final SportsGame game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hideScores = context.read<StorageService>().getSportsHideScores();
    Widget team(SportsTeam t) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 34,
              height: 34,
              child: t.logoUrl == null
                  ? const Icon(Icons.shield_outlined, color: Colors.white38)
                  : HdNetworkImage(
                      url: t.logoUrl!,
                      kind: ImageKind.poster,
                      decodeWidth: 68,
                      fit: BoxFit.contain,
                      errorWidget: (_) => const Icon(Icons.shield_outlined,
                          color: Colors.white38),
                    ),
            ),
            const SizedBox(height: 6),
            Text(t.abbreviation.isEmpty ? t.shortName : t.abbreviation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        );
    final middle = _gameMiddle(game, hideScores);
    if (game.league.kind != SportsKind.team) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events_outlined, color: Colors.white54),
          const SizedBox(height: 6),
          Text(game.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        team(game.first),
        Text(middle,
            style: TextStyle(
                fontSize: game.state == GameState.pre ? 13 : 18,
                fontWeight: FontWeight.w800,
                color: game.state == GameState.live
                    ? scheme.primary
                    : Colors.white)),
        team(game.second),
      ]),
    );
  }
}

/// Portraits are all built so D-pad focus can reach even off-screen viewers.
class _ProfilesStrip extends StatelessWidget {
  const _ProfilesStrip(
      {required this.nodes,
      required this.addNode,
      required this.onPick,
      required this.onEdit,
      required this.onAdd,
      required this.onFocus,
      this.compact = false});
  final bool compact;
  final FocusNode Function(int) nodes;
  final FocusNode addNode;
  final void Function(ViewerProfile) onPick, onEdit;
  final VoidCallback onAdd;
  final void Function(int) onFocus;
  @override
  Widget build(BuildContext context) {
    final viewers = context.watch<ViewerProfileService>();
    final scale = MediaQuery.sizeOf(context).width < 600 ? .8 : 1.0;
    return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topLeft,
        child: Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 6 : 14, 20, 0),
            child: Row(children: [
              if (isDesktop)
                ExcludeFocus(
                  child: IconButton(
                    tooltip: tr('Back'),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          vertical: compact ? 4 : 12, horizontal: 12),
                      child: Row(children: [
                        for (final (i, p) in viewers.profiles.indexed)
                          Builder(
                              builder: (cardContext) => ProfileCard(
                                  profile: p,
                                  label: p.displayName,
                                  focusNode: nodes(i),
                                  active: p.id == viewers.active.id,
                                  scale: scale,
                                  compact: compact,
                                  onTap: () => onPick(p),
                                  onHold: () => onEdit(p),
                                  onFocused: () {
                                    onFocus(i);
                                    Scrollable.ensureVisible(cardContext,
                                        duration: Duration.zero,
                                        alignmentPolicy:
                                            ScrollPositionAlignmentPolicy
                                                .keepVisibleAtEnd);
                                  })),
                        Builder(
                            builder: (cardContext) => ProfileCard(
                                label: tr('Add Profile'),
                                focusNode: addNode,
                                scale: scale,
                                compact: compact,
                                onTap: onAdd,
                                onFocused: () {
                                  onFocus(viewers.profiles.length);
                                  Scrollable.ensureVisible(cardContext,
                                      duration: Duration.zero,
                                      alignmentPolicy:
                                          ScrollPositionAlignmentPolicy
                                              .keepVisibleAtEnd);
                                })),
                      ]))),
              if (MediaQuery.sizeOf(context).width >= 800) const _HomeClock(),
            ])));
  }
}

class _HomeClock extends StatelessWidget {
  const _HomeClock();

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
      stream: Stream<void>.periodic(const Duration(seconds: 20)),
      builder: (context, _) => Text(TimeFormat.hm.format(DateTime.now()),
          style: const TextStyle(fontSize: 20, color: Colors.white70)));
}
