import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/channel.dart';
import '../../models/xtream_series.dart';
import '../storage_service.dart';

/// One title on the viewer's watch list.
class WatchListItem {
  WatchListItem({this.channel, this.series, DateTime? added, this.note})
      : added = added ?? DateTime.now(),
        assert(channel != null || series != null);

  final Channel? channel;
  final XtreamSeries? series;
  final DateTime added;

  /// Why it's there ("for Friday night"), from the viewer or their AI.
  final String? note;

  String get title => channel?.name ?? series!.name;
  String get kind =>
      series != null ? 'series' : (channel!.isLive ? 'live' : 'movie');

  /// Same title, whichever copy: the composite id.
  String get id => series != null ? 's:${series!.id}' : 'c:${channel!.id}';

  Map<String, Object?> toJson() => {
        if (channel != null) 'channel': channel!.toJson(),
        if (series != null) 'series': series!.toJson(),
        'added': added.millisecondsSinceEpoch,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  static WatchListItem? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final c = json['channel'];
      final s = json['series'];
      return WatchListItem(
        channel: c is Map ? Channel.fromJson(c.cast<String, dynamic>()) : null,
        series:
            s is Map ? XtreamSeries.fromJson(s.cast<String, dynamic>()) : null,
        added: DateTime.fromMillisecondsSinceEpoch(
            (json['added'] as num?)?.toInt() ?? 0),
        note: json['note'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The viewer's watch list (per profile, `vesper_watchlist`): built by
/// Vesper or a linked AI app ("make me a movie night list for Friday"),
/// shown as a Home row. Part of the setup: transferred and synced.
class WatchList {
  WatchList._();
  static final instance = WatchList._();

  /// Bumped on every change (Home reloads its row).
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

  Future<int> clear(StorageService storage) async {
    final n = load(storage).length;
    await _save(storage, const []);
    return n;
  }
}
