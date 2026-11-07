import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/archive_models.dart';
import '../../models/channel.dart';
import '../../models/xtream_series.dart';
import '../storage_service.dart';

/// A Media Hub title with the source it came from (its manifest URL): what
/// a watch list entry needs to open it again through that source.
class HubTitle {
  const HubTitle(this.sourceUrl, this.meta);
  final String sourceUrl;
  final ArchiveMeta meta;

  /// Same title from the same source, whichever copy of the meta.
  String get key => '$sourceUrl|${meta.id}|${meta.wire}';
}

/// One title on the viewer's watch list: an IPTV movie ([channel]), an IPTV
/// show ([series]) or a Media Hub movie / show ([hub]).
class WatchListItem {
  WatchListItem(
      {this.channel, this.series, this.hub, DateTime? added, this.note})
      : added = added ?? DateTime.now(),
        assert(channel != null || series != null || hub != null);

  final Channel? channel;
  final XtreamSeries? series;
  final HubTitle? hub;
  final DateTime added;

  /// Why it's there ("for Friday night"), from the viewer or their AI.
  final String? note;

  String get title => channel?.name ?? series?.name ?? hub!.meta.name;
  String get kind => hub != null
      ? (hub!.meta.type == ArchiveType.series ? 'hub_series' : 'hub_movie')
      : series != null
          ? 'series'
          : (channel!.isLive ? 'live' : 'movie');

  /// A show (IPTV or Media Hub), for the Movies / TV Shows rows.
  bool get isShow => series != null || hub?.meta.type == ArchiveType.series;

  /// Same title, whichever copy: the composite id.
  String get id => hub != null
      ? 'h:${hub!.key}'
      : series != null
          ? 's:${series!.id}'
          : 'c:${channel!.id}';

  String? get posterUrl =>
      hub?.meta.posterUrl ??
      series?.posterUrl ??
      series?.coverUrl ??
      channel?.posterUrl ??
      channel?.logoUrl;

  String? get backdropUrl =>
      hub?.meta.backgroundUrl ??
      series?.anyBackdropUrl ??
      channel?.anyBackdropUrl;

  Map<String, Object?> toJson() => {
        if (channel != null) 'channel': channel!.toJson(),
        if (series != null) 'series': series!.toJson(),
        if (hub != null)
          'hub': {'src': hub!.sourceUrl, 'meta': hub!.meta.toJson()},
        'added': added.millisecondsSinceEpoch,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  static WatchListItem? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final c = json['channel'];
      final s = json['series'];
      final h = json['hub'];
      final hubMeta = h is Map && h['meta'] is Map
          ? ArchiveMeta.fromJson(Map<String, dynamic>.from(h['meta'] as Map))
          : null;
      final item = WatchListItem(
        channel: c is Map ? Channel.fromJson(c.cast<String, dynamic>()) : null,
        series:
            s is Map ? XtreamSeries.fromJson(s.cast<String, dynamic>()) : null,
        hub: hubMeta == null ? null : HubTitle('${h['src']}', hubMeta),
        added: DateTime.fromMillisecondsSinceEpoch(
            (json['added'] as num?)?.toInt() ?? 0),
        note: json['note'] as String?,
      );
      return item;
    } catch (_) {
      return null;
    }
  }
}

/// The viewer's watch list (per profile, `vesper_watchlist`): filled by hand
/// (Watch list on a movie / show page) or by Vesper or a linked AI app
/// ("make me a movie night list for Friday"). Shown as a Home row, a row in
/// Movies / TV Shows and a page in Media Hub. Part of the setup:
/// transferred and synced.
class WatchList {
  WatchList._();
  static final instance = WatchList._();

  /// Bumped on every change (screens showing it reload).
  final changes = ValueNotifier<int>(0);

  static const maxItems = 200;

  List<WatchListItem> load(StorageService storage) {
    final raw = storage.getVesperWatchList();
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (WatchListItem.fromJson(e) case final item?) item
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(StorageService storage, List<WatchListItem> items) async {
    await storage.setVesperWatchList(
        jsonEncode([for (final i in items.take(maxItems)) i.toJson()]));
    changes.value++;
  }

  bool contains(StorageService storage, String id) =>
      load(storage).any((i) => i.id == id);

  /// Adds [item] at the front; false when it was already there.
  Future<bool> add(StorageService storage, WatchListItem item) async {
    final items = load(storage);
    if (items.any((i) => i.id == item.id)) return false;
    await _save(storage, [item, ...items]);
    return true;
  }

  Future<bool> remove(StorageService storage, String id) async {
    final items = load(storage);
    final kept = items.where((i) => i.id != id).toList();
    if (kept.length == items.length) return false;
    await _save(storage, kept);
    return true;
  }

  /// The Watch list button: adds [item], or removes it when it's already
  /// there. True when it is on the list afterwards.
  Future<bool> toggle(StorageService storage, WatchListItem item) async {
    if (await remove(storage, item.id)) return false;
    await add(storage, item);
    return true;
  }

  Future<int> clear(StorageService storage) async {
    final n = load(storage).length;
    await _save(storage, const []);
    return n;
  }
}
