import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/archive_library.dart';
import '../models/archive_models.dart';
import '../models/channel.dart';
import '../models/xtream_series.dart';
import 'app_preferences.dart';
import 'archive_service.dart';
import 'episode_alerts.dart';
import 'playback_service.dart';
import 'playlist_manager.dart';
import 'storage_service.dart';
import 'vesper_ai/watch_list.dart';

/// One card on the TV launcher: what it shows ([toMap], read by
/// LauncherChannels.kt) and what it opens (screens/launcher_open.dart):
/// [channel] (an IPTV movie's page, or a live channel to play), [series]
/// (an IPTV show's page), [hubItem] (a Media Hub title to resume),
/// [hubTitle] (a Media Hub title's page) or [followed] (a "Notify me" show's
/// page).
class LauncherCard {
  LauncherCard({
    required this.key,
    required this.kind,
    required this.type,
    required this.title,
    this.description,
    this.episodeTitle,
    this.season,
    this.episode,
    this.image,
    this.poster = false,
    this.positionMs,
    this.durationMs,
    this.engagedMs,
    this.channel,
    this.series,
    this.hubItem,
    this.hubTitle,
    this.followed,
    this.showKey,
  });

  /// The card's own id, also in its link: one per episode, so a show's
  /// card changes (and Projectivy redraws it) when the next episode starts.
  /// Hashed ([LauncherChannels.cardKey]): launchers read it, and a Media Hub
  /// source's address can hold a debrid key.
  final String key;

  /// Watch Next: 'continue', 'next', 'new' or 'watchlist'; a channel row:
  /// 'row'.
  final String kind;

  /// 'movie', 'episode', 'series' or 'channel'.
  final String type;
  final String title;
  final String? description;
  final String? episodeTitle;
  final int? season;
  final int? episode;
  final String? image;

  /// [image] is a 2:3 poster (else a 16:9 backdrop or logo).
  final bool poster;
  final int? positionMs;
  final int? durationMs;

  /// When it was last watched (Watch Next's order): see
  /// [LauncherChannels.stampEngaged].
  int? engagedMs;

  final Channel? channel;
  final XtreamSeries? series;
  final ArchiveContinueItem? hubItem;
  final HubTitle? hubTitle;
  final FollowedShow? followed;

  /// The show it belongs to, in [FollowedShow.key]'s form (not sent): a
  /// show already in Continue watching gets no New episode card too.
  final String? showKey;

  Map<String, Object?> toMap() => {
        'key': key,
        'kind': kind,
        'type': type,
        'title': title,
        'description': description,
        'episodeTitle': episodeTitle,
        'season': season,
        'episode': episode,
        'image': image,
        'aspect': poster ? 'poster' : 'wide',
        'position': positionMs,
        'duration': durationMs,
        'engaged': engagedMs,
      };
}

/// Settings > Interface > TV home screen (Android TV, on by default): what's
/// in progress and the Watch list in the launcher's Watch Next row, and the
/// favourite channels as our own app channel, "Favourite channels". Android
/// TV launchers read these from the system (TvProvider): Projectivy, the
/// stock Android TV home, Projectivy on a Fire TV stick. Native side:
/// android/.../LauncherChannels.kt, channel `vespertv/launcher`.
///
/// A launcher shows only what the app sends, and only while the app is
/// away, so this publishes when the app is hidden (and once after startup),
/// for the active viewer, the same titles as Home's rows. A launcher reads
/// on its own schedule (Projectivy: about a minute after you come back to
/// it), so a card can be a minute late.
///
/// A card opens the app with its key ([openPending]): resolved again
/// against the active viewer's data, never against what was sent.
class LauncherChannels {
  LauncherChannels._();
  static final instance = LauncherChannels._();

  static const _channel = MethodChannel('vespertv/launcher');

  /// Watch Next cards of each kind we send (Android TV may keep fewer).
  static const maxContinue = 10;
  static const maxWatchList = 10;
  static const maxNew = 5;
  static const maxFavourites = 30;

  StorageService? _storage;
  PlaybackService? _playback;
  PlaylistManager? _playlist;
  ArchiveService? _hub;
  AppPreferences? _prefs;
  EpisodeAlerts? _alerts;

  /// main.dart: true once a card can open (UI up, viewer chosen).
  bool Function() canOpen = () => false;

  /// Opens a card on the app's navigator (screens/launcher_open.dart).
  Future<void> Function(LauncherCard card)? open;

  bool _publishing = false;
  bool _again = false;
  String? _lastSent;
  DateTime? _openedAt;

  bool get _supported =>
      _storage != null && Platform.isAndroid && (_prefs?.isTelevision ?? false);

  void attach({
    required StorageService storage,
    required PlaybackService playback,
    required PlaylistManager playlist,
    required ArchiveService hub,
    required AppPreferences prefs,
    EpisodeAlerts? alerts,
  }) {
    _storage = storage;
    _playback = playback;
    _playlist = playlist;
    _hub = hub;
    _prefs = prefs;
    _alerts = alerts;
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link') unawaited(openPending());
    });
  }

  /// A card opened the app in the last minute: startup's "resume last
  /// channel" stays out of its way (main.dart).
  bool get openedRecently =>
      _openedAt != null &&
      DateTime.now().difference(_openedAt!) < const Duration(minutes: 1);

  /// A card's link is waiting to be opened.
  Future<bool> get hasPendingLink async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasLink') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the card the app was started with (or brought back by), when the
  /// app can show it; otherwise it waits for the next call (main.dart calls
  /// again once the UI is up and a viewer is picked).
  Future<void> openPending() async {
    if (!_supported || !canOpen()) return;
    String? link;
    try {
      link = await _channel.invokeMethod<String>('takeLink');
    } catch (_) {
      return;
    }
    final key = link == null ? null : Uri.tryParse(link)?.queryParameters['k'];
    if (key == null) return;
    _openedAt = DateTime.now();
    if (key.startsWith('fav:')) await _playlist?.ensureLiveChannelsLoaded();
    LauncherCard? card;
    for (final c in [...watchNextCards(), ...favouriteCards()]) {
      if (c.key == key) card = c;
    }
    if (card == null) {
      // Watched to the end, removed, or another viewer's card.
      debugPrint('Launcher: card ${key.split(':').first} no longer here');
      return;
    }
    debugPrint('Launcher: open ${card.kind} ${card.type}');
    await open?.call(card);
  }

  /// The app went to the background: the launcher is about to show. A
  /// moment later, so the player's last position is saved first.
  void appHidden() {
    if (!_supported) return;
    unawaited(Future<void>.delayed(const Duration(seconds: 2), publish));
  }

  /// Sends the cards. Unchanged since the last send = nothing to do, unless
  /// [force] (the setting was switched).
  Future<void> publish({bool force = false}) async {
    final storage = _storage;
    if (storage == null || !_supported) return;
    if (_publishing) {
      _again = true;
      return;
    }
    _publishing = true;
    try {
      final Map<String, Object?> payload;
      if (!storage.getLauncherRows()) {
        payload = {'watchNext': const [], 'channels': const []};
      } else {
        await _playlist?.ensureLiveChannelsLoaded();
        final watchNext = watchNextCards();
        final previous = _decodeState(storage.getLauncherState());
        final state = stampEngaged(
            watchNext, previous, DateTime.now().millisecondsSinceEpoch);
        await storage.setLauncherState(jsonEncode(state));
        payload = {
          'watchNext': [for (final c in watchNext) c.toMap()],
          'channels': [
            {
              'id': 'favourites',
              'name': tr('Favourite channels'),
              'items': [for (final c in favouriteCards()) c.toMap()],
            }
          ],
        };
      }
      final sent = jsonEncode(payload);
      if (!force && sent == _lastSent) return;
      final report = await _channel.invokeMethod<Map>('publish', payload);
      if (report?['error'] == null) _lastSent = sent;
      // Send log: counts only, never titles.
      debugPrint('Launcher: $report');
    } catch (e) {
      debugPrint('Launcher: publish failed: $e');
    } finally {
      _publishing = false;
      if (_again) {
        _again = false;
        unawaited(publish());
      }
    }
  }

  static Map<String, List<int>> _decodeState(String? raw) {
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      return {
        for (final e in map.entries)
          if (e.value is List && (e.value as List).length == 2)
            '${e.key}': [
              for (final v in e.value as List) (v as num).toInt(),
            ],
      };
    } catch (_) {
      return {};
    }
  }

  /// Watch Next is sorted by when each card was last watched, which nothing
  /// else here stores. Per card: the time from the last send while its
  /// position hasn't moved, now when it has (it was watched). New cards keep
  /// the app's order, a millisecond apart. Cards that come with their own
  /// time (the Watch list's date added) keep it. Returns the new state:
  /// key -> [position, time].
  @visibleForTesting
  static Map<String, List<int>> stampEngaged(
      List<LauncherCard> cards, Map<String, List<int>> previous, int now) {
    final state = <String, List<int>>{};
    var i = 0;
    for (final c in cards) {
      final position = c.positionMs ?? -1;
      if (c.engagedMs == null) {
        final before = previous[c.key];
        c.engagedMs =
            before != null && before[0] == position ? before[1] : now - i;
      }
      state[c.key] = [position, c.engagedMs!];
      i++;
    }
    return state;
  }

  /// Only plain public images go to the launcher (other apps load them): a
  /// media server's image link carries its access key (Jellyfin / Emby
  /// `api_key`, Plex `X-Plex-Token`), and a playlist's can carry its login.
  @visibleForTesting
  static String? safeImage(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    const secret = {
      'api_key',
      'apikey',
      'x-plex-token',
      'token',
      'access_token',
      'key',
      'username',
      'user',
      'password',
      'pass',
    };
    for (final k in uri.queryParameters.keys) {
      if (secret.contains(k.toLowerCase())) return null;
    }
    return url;
  }

  /// A Media Hub title's art: its own images when they're public, else
  /// Cinemeta's by IMDb id (a media server's own images carry its key).
  @visibleForTesting
  static ({String? image, bool poster}) hubArt(
      {String? background, String? poster, String? imdb}) {
    final wide = safeImage(background);
    if (wide != null) return (image: wide, poster: false);
    final tall = safeImage(poster);
    if (tall != null) return (image: tall, poster: true);
    if (imdb != null && RegExp(r'^tt\d+$').hasMatch(imdb)) {
      return (
        image: 'https://images.metahub.space/background/medium/$imdb/img',
        poster: false
      );
    }
    return (image: null, poster: false);
  }

  /// An IPTV title's art: its backdrop, else its poster / logo.
  static ({String? image, bool poster}) _iptvArt(
      String? backdrop, String? cover) {
    final wide = safeImage(backdrop);
    if (wide != null) return (image: wide, poster: false);
    final tall = safeImage(cover);
    return (image: tall, poster: tall != null);
  }

  /// [prefix] (readable in the Send log) + a hash of what the card is.
  @visibleForTesting
  static String cardKey(String prefix, String identity) =>
      '$prefix:${sha1.convert(utf8.encode(identity)).toString().substring(0, 16)}';

  /// Continue watching (playlists' movies and episodes, next episodes,
  /// Media Hub titles, in Home's order), new episodes of "Notify me" shows,
  /// then the Watch list's movies and shows.
  List<LauncherCard> watchNextCards() {
    final storage = _storage, playback = _playback, hub = _hub;
    if (storage == null || playback == null || hub == null) return [];
    final continuing =
        _continueCards(storage, playback, hub).take(maxContinue).toList();
    final shows = {
      for (final c in continuing)
        if (c.showKey != null) c.showKey!
    };
    return [
      ...continuing,
      ..._newEpisodeCards(hub, shows).take(maxNew),
      ..._watchListCards(storage, hub).take(maxWatchList),
    ];
  }

  /// The episode noted after [after] in a show (PlaybackService
  /// ._rememberNextEpisode), if [after] is still the last one left there.
  static Channel? _nextEpisode(Object? entry, {required String after}) {
    if (entry is! Map || entry['after'] != after || entry['next'] is! Map) {
      return null;
    }
    try {
      return Channel.fromJson(Map<String, dynamic>.from(entry['next'] as Map));
    } catch (_) {
      return null;
    }
  }

  LauncherCard _episodeCard(Channel c, String kind, XtreamSeries series,
      {int? positionMs, int? durationMs}) {
    final art = _iptvArt(c.anyBackdropUrl, c.seriesCoverUrl ?? c.logoUrl);
    return LauncherCard(
      key: cardKey(kind == 'next' ? 'nx' : 'cw', c.id),
      kind: kind,
      type: 'episode',
      title: c.seriesName ?? c.name,
      episodeTitle: c.name,
      image: art.image,
      poster: art.poster,
      positionMs: positionMs,
      durationMs: durationMs,
      series: series,
      showKey: FollowedShow.iptvKey(series.playlistId, series.seriesId),
    );
  }

  /// Same titles as Home's Continue Watching row (HomeScreen._continueRow).
  List<LauncherCard> _continueCards(
      StorageService storage, PlaybackService playback, ArchiveService hub) {
    final cards = <({int at, LauncherCard card})>[];
    final played = playback.recentlyPlayed;
    ({int? position, int? duration}) progress(String id) =>
        storage.isResumeFraction(id)
            ? (position: null, duration: null)
            : (
                position: storage.getLastPosition(id),
                duration: storage.getLastDuration(id) > 0
                    ? storage.getLastDuration(id)
                    : null,
              );

    final nextEpisodes = storage.getNextEpisodes();
    final seenSeries = <String>{};
    for (var i = 0; i < played.length; i++) {
      final c = played[i];
      if (c.isLive || c.playlistId == ArchiveService.playlistId) continue;
      final isEpisode = c.rawId.startsWith('xt_ep_');
      if (isEpisode && c.seriesId != null) {
        final show = '${c.playlistId}:${c.seriesId}';
        final series = XtreamSeries(
          seriesId: c.seriesId!,
          playlistId: c.playlistId,
          name: c.seriesName ?? c.name,
          categoryId: '',
          coverUrl: c.seriesCoverUrl,
        );
        if (storage.isFullyWatched(c.id)) {
          // Watched to the end: the episode after it, when the show's
          // queue named one. Not started yet, so no position.
          final next = _nextEpisode(nextEpisodes[show], after: c.id);
          if (next == null ||
              storage.getLastPosition(next.id) > 0 ||
              !seenSeries.add(show)) {
            continue;
          }
          cards.add((at: i, card: _episodeCard(next, 'next', series)));
          continue;
        }
        if (storage.getLastPosition(c.id) <= 0 || !seenSeries.add(show)) {
          continue;
        }
        final p = progress(c.id);
        cards.add((
          at: i,
          card: _episodeCard(c, 'continue', series,
              positionMs: p.position, durationMs: p.duration)
        ));
      } else if (!isEpisode) {
        if (storage.getLastPosition(c.id) <= 0 ||
            storage.isFullyWatched(c.id)) {
          continue;
        }
        final p = progress(c.id);
        final art = _iptvArt(c.anyBackdropUrl, c.posterUrl ?? c.logoUrl);
        cards.add((
          at: i,
          card: LauncherCard(
            key: cardKey('cw', c.id),
            kind: 'continue',
            type: 'movie',
            title: c.name,
            image: art.image,
            poster: art.poster,
            positionMs: p.position,
            durationMs: p.duration,
            channel: c,
          )
        ));
      }
    }

    // Media Hub: placed where its last play sits among the playlists'.
    for (final entry in [
      ...hub.continueWatching(ArchiveType.movie),
      ...hub.continueWatching(ArchiveType.series)
    ]) {
      final source = entry.source, meta = entry.meta, ep = entry.episode;
      // A show with no episode list has no place to resume from.
      if (meta.type == ArchiveType.series && ep == null) continue;
      final vod = 'arc_vod_${source.key}_${meta.id}';
      final epPrefix = 'arc_ep_${source.key}_${meta.id}';
      var at = played
          .indexWhere((c) => c.rawId == vod || c.rawId.startsWith(epPrefix));
      if (at < 0) at = played.length;
      final id = ep == null
          ? ArchiveService.channelId(source, meta.id, episode: false)
          : ArchiveService.channelId(source, ep.id, episode: true);
      final p = entry.resume ? progress(id) : (position: null, duration: null);
      final art = hubArt(
          background: meta.backgroundUrl,
          poster: meta.posterUrl,
          imdb: meta.imdb);
      cards.add((
        at: at,
        card: LauncherCard(
          key: cardKey('hub', id),
          // Not started yet = the next episode after the last one watched.
          kind: ep != null && !entry.resume ? 'next' : 'continue',
          type: ep == null ? 'movie' : 'episode',
          title: meta.name,
          description: meta.description,
          episodeTitle: ep == null || ep.title.isEmpty ? null : ep.title,
          season: ep?.season,
          episode: ep?.episode,
          image: art.image,
          poster: art.poster,
          positionMs: p.position,
          durationMs: p.duration,
          hubItem: entry,
          showKey: FollowedShow.hubKey(source.manifestUrl, meta.id),
        )
      ));
    }
    cards.sort((a, b) => a.at.compareTo(b.at));
    return [for (final e in cards) e.card];
  }

  /// The Watch list's movies and shows (live channels have Favourites).
  List<LauncherCard> _watchListCards(
      StorageService storage, ArchiveService hub) {
    final cards = <LauncherCard>[];
    for (final i in WatchList.instance.load(storage)) {
      if (i.channel?.isLive ?? false) continue;
      if (i.hub case final h?) {
        final source = hub.enabledSources
            .where((s) => s.manifestUrl == h.sourceUrl)
            .firstOrNull;
        if (source == null || source.underOther) continue;
      }
      final art = i.hub != null
          ? hubArt(
              background: i.backdropUrl,
              poster: i.posterUrl,
              imdb: i.hub!.meta.imdb)
          : _iptvArt(i.backdropUrl, i.posterUrl);
      cards.add(LauncherCard(
        key: cardKey('wl', i.id),
        kind: 'watchlist',
        type: i.isShow ? 'series' : 'movie',
        title: i.title,
        description: i.hub?.meta.description,
        image: art.image,
        poster: art.poster,
        engagedMs: i.added.millisecondsSinceEpoch,
        channel: i.channel,
        series: i.series,
        hubTitle: i.hub,
      ));
    }
    return cards;
  }

  /// "Notify me" shows with a new episode (Home's New episodes row), newest
  /// first, unless the show is already in Continue watching.
  List<LauncherCard> _newEpisodeCards(ArchiveService hub, Set<String> shows) {
    final alerts = _alerts;
    if (alerts == null) return [];
    final cards = <LauncherCard>[];
    final noticed = <String>{};
    for (final n in alerts.notices) {
      final show = alerts.show(n.showKey);
      if (show == null ||
          shows.contains(n.showKey) ||
          !noticed.add(n.showKey)) {
        continue;
      }
      if (show.isMediaHub) {
        final source = hub.enabledSources
            .where((s) => s.manifestUrl == show.sourceUrl)
            .firstOrNull;
        if (source == null || source.underOther || show.meta == null) continue;
      } else if (show.playlistId == null || show.seriesId == null) {
        continue;
      }
      final art = show.isMediaHub
          ? hubArt(
              background: show.backdropUrl,
              poster: show.posterUrl,
              imdb: show.imdbId)
          : _iptvArt(show.backdropUrl, show.posterUrl);
      cards.add(LauncherCard(
        key: cardKey('ne', '${n.showKey}|${n.season}|${n.episode}'),
        kind: 'new',
        type: 'episode',
        title: n.title,
        description: n.count > 1
            ? tr('{count} new episodes - {code} is available',
                {'count': '${n.count}', 'code': n.code})
            : tr('{code} is available', {'code': n.code}),
        episodeTitle: n.episodeTitle,
        season: n.season,
        episode: n.episode,
        image: art.image,
        poster: art.poster,
        engagedMs: n.at.millisecondsSinceEpoch,
        followed: show,
        showKey: n.showKey,
      ));
    }
    return cards;
  }

  /// The favourite live channels in the app's order (Home's Favourites row).
  List<LauncherCard> favouriteCards() {
    final playlist = _playlist, prefs = _prefs;
    if (playlist == null || prefs == null) return [];
    return [
      for (final c in playlist
          .orderedFavoriteLiveChannels(mixPlaylists: prefs.mixFavoritePlaylists)
          .take(maxFavourites))
        LauncherCard(
          key: cardKey('fav', c.id),
          kind: 'row',
          type: 'channel',
          title: c.name,
          image: safeImage(c.logoUrl),
          channel: c,
        ),
    ];
  }
}
