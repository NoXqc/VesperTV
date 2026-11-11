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
///
/// The playlist editor's Move / Copy to group (2026-11-11) adds two more
/// maps, written only when used: `pmoves` {Channel.id: GroupRef} = a
/// channel moved into a provider group (of any playlist), and `copies`
/// {Channel.id: [GroupRef, ...]} = groups that also show a channel while it
/// stays where it is (own or provider groups). `porder` {GroupRef of a
/// provider group: [Channel.id, ...]} is the Move Up / Down order of a
/// provider group once channels were moved or copied into it (its own and
/// the placed ones together, which may span playlists); it stays the
/// group's order after they leave.
class UserGroups {
  List<String> groups = [];
  Map<String, String> moves = {};
  Map<String, List<String>> order = {};

  /// Channel.id -> [GroupRef.encode] of the provider group it was moved into.
  Map<String, String> pmoves = {};

  /// Channel.id -> [GroupRef.encode] of every group that also shows it.
  Map<String, List<String>> copies = {};

  /// [GroupRef.encode] of a provider group -> its channel order.
  Map<String, List<String>> porder = {};

  void load(String? json) {
    groups = [];
    moves = {};
    order = {};
    pmoves = {};
    copies = {};
    porder = {};
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
      pmoves = {
        for (final e in ((d['pmoves'] as Map?) ?? const {}).entries)
          if (GroupRef.decode(e.value) != null)
            e.key as String: e.value as String,
      };
      for (final e in ((d['copies'] as Map?) ?? const {}).entries) {
        final refs = [
          for (final r in e.value as List)
            if (GroupRef.decode(r) != null) r as String
        ];
        if (refs.isNotEmpty) copies[e.key as String] = refs;
      }
      porder = {
        for (final e in ((d['porder'] as Map?) ?? const {}).entries)
          if (GroupRef.decode(e.key) != null)
            e.key as String: [for (final id in e.value as List) id as String],
      };
    } catch (_) {
      groups = [];
      moves = {};
      order = {};
      pmoves = {};
      copies = {};
      porder = {};
    }
  }

  String toJson() => jsonEncode({
        'groups': groups,
        'moves': moves,
        'order': order,
        if (pmoves.isNotEmpty) 'pmoves': pmoves,
        if (copies.isNotEmpty) 'copies': copies,
        if (porder.isNotEmpty) 'porder': porder,
      });

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
    pmoves.remove(channelId);
    if (title == null) {
      moves.remove(channelId);
      return;
    }
    if (!groups.contains(title)) groups = [title, ...groups];
    moves[channelId] = title;
    // It lives there now: a copy into the same group would list it twice.
    removeCopy(channelId, GroupRef.own(title));
  }

  void delete(String title) {
    groups = [...groups]..remove(title);
    moves.removeWhere((_, g) => g == title);
    order.remove(title);
    final gone = GroupRef.own(title);
    for (final id in copies.keys.toList()) {
      removeCopy(id, gone);
    }
  }

  // --- Move / Copy into provider groups, and copies (playlist editor) ------

  /// The provider group [channelId] was moved into, if any.
  GroupRef? providerMoveOf(String channelId) =>
      GroupRef.decode(pmoves[channelId]);

  /// Every group that also shows [channelId] (it stays where it is).
  List<GroupRef> copiesOf(String channelId) => [
        for (final r in copies[channelId] ?? const <String>[])
          if (GroupRef.decode(r) case final g?) g
      ];

  /// Whether anything was moved into a provider group or copied.
  bool get hasPlacements => pmoves.isNotEmpty || copies.isNotEmpty;

  /// Channels the editor moved (into a provider group) or copied into
  /// [ref]: their ids, moves first. Own-group moves are [moves].
  List<String> idsInto(GroupRef ref) {
    final enc = ref.encode();
    return [
      for (final e in pmoves.entries)
        if (e.value == enc) e.key,
      for (final e in copies.entries)
        if (e.value.contains(enc)) e.key,
    ];
  }

  /// Whether provider group [ref] keeps its own order here: something
  /// was moved or copied into it, or was once and the user reordered it.
  bool ordersHere(GroupRef ref) =>
      porder.containsKey(ref.encode()) || idsInto(ref).isNotEmpty;

  /// Every channel id with a provider move or a copy.
  Set<String> get placedIds => {...pmoves.keys, ...copies.keys};

  /// Moves [channelId] into the provider group [dest].
  void moveToProvider(String channelId, GroupRef dest) {
    final from = moves.remove(channelId);
    if (from != null) order[from]?.remove(channelId);
    pmoves[channelId] = dest.encode();
    removeCopy(channelId, dest);
  }

  /// [dest] shows [channelId] too; it stays where it is.
  void addCopy(String channelId, GroupRef dest) {
    final list = copies[channelId] ??= [];
    final enc = dest.encode();
    if (!list.contains(enc)) list.add(enc);
  }

  void removeCopy(String channelId, GroupRef dest) {
    final list = copies[channelId];
    if (list == null) return;
    list.remove(dest.encode());
    if (list.isEmpty) copies.remove(channelId);
  }

  /// Back in its own group with no copies anywhere.
  void clearPlacement(String channelId) {
    move(channelId, null);
    copies.remove(channelId);
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
  List<Channel> ordered(String title, List<Channel> channels) =>
      _inOrder(order[title], channels);

  /// [channels] (provider group [ref] with what was placed into it) in the
  /// order the user gave it here, if any.
  List<Channel> orderedIn(GroupRef ref, List<Channel> channels) =>
      _inOrder(porder[ref.encode()], channels);

  static List<Channel> _inOrder(List<String>? ids, List<Channel> channels) {
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
          String title, String channelId, int delta, List<Channel> shown) =>
      _move(shown, channelId, delta, (ids) => order[title] = ids);

  /// [moveChannel] for provider group [ref] (kept in [porder]).
  int? moveChannelIn(
          GroupRef ref, String channelId, int delta, List<Channel> shown) =>
      _move(shown, channelId, delta, (ids) => porder[ref.encode()] = ids);

  static int? _move(List<Channel> shown, String channelId, int delta,
      void Function(List<String>) save) {
    final ids = [for (final c in shown) c.id];
    final from = ids.indexOf(channelId);
    if (from < 0) return null;
    final to = (from + delta).clamp(0, ids.length - 1);
    ids
      ..removeAt(from)
      ..insert(to, channelId);
    save(ids);
    return to;
  }
}

/// Where the editor's Move / Copy puts a channel: one of the viewer's own
/// groups ([GroupRef.own]) or a provider group of any playlist
/// ([GroupRef.provider], by the title the TV shows).
class GroupRef {
  const GroupRef.own(this.title) : playlistId = null;
  const GroupRef.provider(String this.playlistId, this.title);

  final String? playlistId;
  final String title;

  bool get isOwn => playlistId == null;

  /// `o:<title>` or `p:<playlistId>` + NUL + `<title>` (an id has no NUL).
  String encode() => isOwn ? 'o:$title' : 'p:$playlistId\u0000$title';

  static GroupRef? decode(Object? raw) {
    if (raw is! String || raw.length < 3) return null;
    if (raw.startsWith('o:')) return GroupRef.own(raw.substring(2));
    if (raw.startsWith('p:')) {
      final at = raw.indexOf('\u0000');
      if (at < 3 || at == raw.length - 1) return null;
      return GroupRef.provider(raw.substring(2, at), raw.substring(at + 1));
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is GroupRef &&
      other.playlistId == playlistId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(playlistId, title);
}
