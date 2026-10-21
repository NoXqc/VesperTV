import 'dart:convert';

import '../models/channel.dart';

/// The viewer's own live groups (owner, 2026-10-21): made from hold OK on
/// a channel → Move to group… or on a group → New group…. Not tied to a
/// playlist — like Favourites, a group can hold channels from every
/// playlist and isn't hidden with one (a first, per-playlist version was).
/// A moved channel leaves its provider group and shows only in its new
/// one; deleting a group (or Remove from group) sends it back.
///
/// Stored per viewer as JSON (`AppConstants.keyMyGroups`):
/// `{"groups": [titles, in display order], "moves": {Channel.id: title},
/// "order": {title: [Channel.id, ...]}}` — `order` is the user's own
/// channel order inside a group (Move Up / Down); channels not in it
/// follow in playlist order.
class UserGroups {
  List<String> groups = [];
  Map<String, String> moves = {};
  Map<String, List<String>> order = {};

  void load(String? json) {
    groups = [];
    moves = {};
    order = {};
    if (json == null || json.isEmpty) return;
    try {
      final d = jsonDecode(json) as Map<String, dynamic>;
      groups = [
        for (final g in (d['groups'] as List? ?? const [])) g as String
      ];
      moves = {
        for (final e in ((d['moves'] as Map?) ?? const {}).entries)
          e.key as String: e.value as String,
      };
      order = {
        for (final e in ((d['order'] as Map?) ?? const {}).entries)
          e.key as String: [for (final id in e.value as List) id as String],
      };
    } catch (_) {
      groups = [];
      moves = {};
      order = {};
    }
  }

  String toJson() =>
      jsonEncode({'groups': groups, 'moves': moves, 'order': order});

  bool contains(String title) => groups.contains(title);

  /// The group channel [channelId] was moved into, if any.
  String? groupOf(String channelId) => moves[channelId];

  /// Adds a group named [name] (on top) and returns its title: [name], or
  /// "[name] 2", "[name] 3"... when [taken] (a provider group's title —
  /// groups are picked by title) or one of these already has it.
  String create(String name, {Set<String> taken = const {}}) {
    var title = name;
    for (var n = 2; groups.contains(title) || taken.contains(title); n++) {
      title = '$name $n';
    }
    groups = [title, ...groups];
    return title;
  }

  /// Moves [channelId] into [title] (added if new — on top), or back to its
  /// provider group when [title] is null.
  void move(String channelId, String? title) {
    final from = moves[channelId];
    if (from != null) order[from]?.remove(channelId);
    if (title == null) {
      moves.remove(channelId);
      return;
    }
    if (!groups.contains(title)) groups = [title, ...groups];
    moves[channelId] = title;
  }

  void delete(String title) {
    groups = [...groups]..remove(title);
    moves.removeWhere((_, g) => g == title);
    order.remove(title);
  }

  /// Moves group [title] by [delta] places (clamped). Returns its new
  /// index, or null if it isn't one of these.
  int? moveGroup(String title, int delta) {
    final from = groups.indexOf(title);
    if (from < 0) return null;
    final to = (from + delta).clamp(0, groups.length - 1);
    groups = [...groups]
      ..removeAt(from)
      ..insert(to, title);
    return to;
  }

  /// [channels] (every playlist's, already filtered to [title]) in the
  /// user's order for it.
  List<Channel> ordered(String title, List<Channel> channels) {
    final ids = order[title];
    if (ids == null || ids.isEmpty) return channels;
    final byId = {for (final c in channels) c.id: c};
    return [
      for (final id in ids)
        if (byId.remove(id) case final c?) c,
      ...channels.where((c) => byId.containsKey(c.id)),
    ];
  }

  /// Moves [channelId] by [delta] places within [shown] (the group's
  /// channels as listed). Returns its new index, or null if not listed.
  int? moveChannel(
      String title, String channelId, int delta, List<Channel> shown) {
    final ids = [for (final c in shown) c.id];
    final from = ids.indexOf(channelId);
    if (from < 0) return null;
    final to = (from + delta).clamp(0, ids.length - 1);
    ids
      ..removeAt(from)
      ..insert(to, channelId);
    order[title] = ids;
    return to;
  }
}
