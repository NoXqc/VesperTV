import 'dart:convert';

import '../models/channel.dart';

/// Live channels the viewer saved (Favourites, own groups) are kept by
/// [Channel.id], and a live channel's id is the provider's EPG id
/// (`epg_channel_id` / `tvg-id`), else `xt_live_<stream id>` or an M3U
/// line's position (`ch_<n>`), plus a `#<stream id>` when copies share an
/// EPG id ([Channel.withUniqueIds]). A provider changes all of these: a
/// channel that gets an EPG id, loses one or gains a copy, an M3U line
/// added above it. The saved id then matched nothing and the channel
/// quietly left Favourites: Discord (Kal-el23, 2026-11-16) lost their
/// favourite channels after every update and re-added them by hand.
///
/// So each saved channel's identity ([SavedLiveKey]: stream, name, group)
/// is kept beside its id, and after a live list load a saved id the list
/// no longer has is looked up by it ([rescue]). Nothing is dropped when no
/// match is found: the provider may bring the channel back.
class SavedLiveKey {
  const SavedLiveKey(this.stream, this.name, this.group);

  /// [streamKeyOf]; empty = none.
  final String stream;

  /// The provider's name ([Channel.sourceName], not an editor rename).
  final String name;

  /// The provider's group.
  final String group;

  factory SavedLiveKey.of(Channel c) =>
      SavedLiveKey(streamKeyOf(c), c.sourceName, c.group);

  /// The stream behind a channel: the Xtream stream id, else the link's
  /// file name without its extension (`.../123.ts` -> `123`, which an M3U
  /// from an Xtream panel has too). A file name without a digit
  /// (`index.m3u8`, `playlist.m3u8`) names no channel: none. Plain string
  /// steps, no Uri / RegExp: [SavedLiveChannels.rescue] runs it on every
  /// channel of a list (350k on one user's M3U).
  static String streamKeyOf(Channel c) {
    final id = c.streamId;
    if (id != null && id.isNotEmpty) return id;
    final url = c.url;
    var end = url.length;
    final query = url.indexOf('?');
    if (query >= 0) end = query;
    final hash = url.indexOf('#');
    if (hash >= 0 && hash < end) end = hash;
    if (end == 0) return '';
    final start = url.lastIndexOf('/', end - 1) + 1;
    final dot = url.lastIndexOf('.', end - 1);
    if (dot > start) end = dot;
    for (var i = start; i < end; i++) {
      final u = url.codeUnitAt(i);
      if (u >= 0x30 && u <= 0x39) return url.substring(start, end);
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      other is SavedLiveKey &&
      other.stream == stream &&
      other.name == name &&
      other.group == group;

  @override
  int get hashCode => Object.hash(stream, name, group);
}

class SavedLiveChannels {
  /// `{Channel.id: [stream, name, group]}`.
  static Map<String, SavedLiveKey> decode(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final d = jsonDecode(json) as Map<String, dynamic>;
      return {
        for (final e in d.entries)
          if (e.value case [String s, String n, String g])
            e.key: SavedLiveKey(s, n, g),
      };
    } catch (_) {
      return {};
    }
  }

  static String encode(Map<String, SavedLiveKey> keys) => jsonEncode({
        for (final e in keys.entries)
          e.key: [e.value.stream, e.value.name, e.value.group],
      });

  static String _norm(String name) => name.trim().toLowerCase();

  /// Saved ids [live] (one playlist's live channels) no longer has, matched
  /// to the channel that took their place: old id -> that channel. Tried in
  /// turn, each only when it points at exactly one channel:
  /// 1. the same stream with the same name or group (a stream id alone could
  ///    be another channel after the provider renumbered them);
  /// 2. the same name in the same group;
  /// 3. the same name, when the saved group is gone from the list (renamed).
  /// Two saved ids never take the same channel. [missing] maps each missing
  /// id to its saved identity.
  static Map<String, Channel> rescue(
      Map<String, SavedLiveKey> missing, Iterable<Channel> live) {
    if (missing.isEmpty) return const {};
    final streams = {
      for (final k in missing.values)
        if (k.stream.isNotEmpty) k.stream
    };
    final names = {for (final k in missing.values) _norm(k.name)};
    final groups = {for (final k in missing.values) k.group};
    final byStream = <String, List<Channel>>{};
    final byName = <String, List<Channel>>{};
    final groupsHere = <String>{};
    for (final c in live) {
      if (groups.contains(c.group)) groupsHere.add(c.group);
      final stream = streams.isEmpty ? '' : SavedLiveKey.streamKeyOf(c);
      if (stream.isNotEmpty && streams.contains(stream)) {
        (byStream[stream] ??= []).add(c);
      }
      final name = _norm(c.sourceName);
      if (names.contains(name)) (byName[name] ??= []).add(c);
    }
    Channel? only(Iterable<Channel> list) =>
        list.length == 1 ? list.first : null;
    final found = <String, Channel>{};
    final taken = <String, int>{};
    for (final e in missing.entries) {
      final k = e.value;
      final name = _norm(k.name);
      final sameName = byName[name] ?? const <Channel>[];
      final inGroup = sameName.where((c) => c.group == k.group);
      final c = only(k.stream.isEmpty
              ? const <Channel>[]
              : (byStream[k.stream] ?? const <Channel>[]).where(
                  (c) => _norm(c.sourceName) == name || c.group == k.group)) ??
          only(inGroup) ??
          (inGroup.isEmpty && !groupsHere.contains(k.group)
              ? only(sameName)
              : null);
      if (c == null) continue;
      found[e.key] = c;
      taken[c.id] = (taken[c.id] ?? 0) + 1;
    }
    found.removeWhere((_, c) => taken[c.id]! > 1);
    return found;
  }
}
