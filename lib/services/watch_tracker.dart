import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/channel.dart';
import 'archive_service.dart';
import 'tracker_api.dart';
import 'tracker_sync.dart';

/// Reports Media Hub plays to the viewer's connected Trakt / Simkl
/// accounts (scrobbling). Off unless an account is connected: nothing is
/// sent anywhere otherwise.
///
/// A title is [register]ed by channel id when Media Hub starts it (movie
/// or episode, by IMDb id); the players then call [started] and [stopped]
/// for every channel — only registered ones are reported. Android:
/// `PlaybackService.play` / the controller swap; Windows:
/// `DesktopPlayerScreen` (it keeps no resume positions of its own).
class WatchTracker {
  WatchTracker._();
  static final instance = WatchTracker._();

  ArchiveService? _service;
  TrackerApi _api = TrackerApi();

  /// Called once at startup (main.dart).
  void attach(ArchiveService service, {TrackerApi? api}) {
    _service = service;
    if (api != null) _api = api;
  }

  final Map<String, TrackedItem> _items = {};

  /// Last state sent per channel ('start' / 'pause' / 'stop'), so the same
  /// stop isn't sent twice (both players report on several paths).
  final Map<String, String> _sent = {};

  void register(String channelId, TrackedItem item) {
    if (!item.hasIds) return _drop(channelId);
    _items[channelId] = item;
    _sent.remove(channelId);
  }

  bool isTracked(String channelId) => _items.containsKey(channelId);

  /// The registered ids of [channelId] (also what Skip intro looks up).
  TrackedItem? itemFor(String channelId) => _items[channelId];

  /// No ids at all (a provider title without a TMDB id): nothing to report.
  void _drop(String channelId) => _items.remove(channelId);

  Future<void> started(String channelId) => _report(channelId, 'start', 0);

  /// The players' start ([started]) with the channel: a provider movie
  /// played without its page (the launcher row, History, Vesper) is
  /// registered by its TMDB id, as the movie page does (owner, 2026-11-26:
  /// only plays started from the page were reported). Episodes still need
  /// their show's page (ids and numbers come from it).
  Future<void> startedChannel(Channel channel) {
    if (!_items.containsKey(channel.id)) {
      if (providerMovieTmdb(channel) case final tmdb?) {
        register(channel.id, TrackedItem.movie(null, tmdb: tmdb));
      }
    }
    return started(channel.id);
  }

  /// An Xtream movie's own TMDB id (`get_vod_streams`), if it sent one.
  @visibleForTesting
  static String? providerMovieTmdb(Channel channel) {
    if (!channel.rawId.startsWith('xt_vod_')) return null;
    final id = channel.tmdbId?.trim();
    return id == null || id.isEmpty || id == '0' ? null : id;
  }

  /// Playback of [channelId] ended at [position] of [duration]: watched
  /// (80 %+, both services' rule) or paused there.
  Future<void> stopped(
      String channelId, Duration position, Duration duration) async {
    if (duration <= Duration.zero) return;
    final progress =
        (position.inMilliseconds / duration.inMilliseconds * 100).clamp(0, 100);
    await _report(
        channelId, progress >= 80 ? 'stop' : 'pause', progress.toDouble());
  }

  Future<void> _report(String channelId, String action, double progress) async {
    final item = _items[channelId];
    final service = _service;
    if (item == null || service == null) return;
    if (_sent[channelId] == action && action != 'start') return;
    _sent[channelId] = action;
    final logins = await service.trackerLogins();
    await Future.wait([
      for (final login in logins) _api.scrobble(login, item, action, progress),
    ]);
    if (action != 'start') TrackerSync.instance.invalidate();
  }
}
