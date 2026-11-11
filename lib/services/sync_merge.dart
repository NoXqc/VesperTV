import 'dart:convert';

import '../utils/constants.dart';

/// On the first join, independently added copies of the same provider must
/// adopt the server's playlist id before [mergeSync]. Only a unique remote
/// account matches: mode + server URL + exact username, or the full M3U URL.
/// Passwords, names, EPG URLs and backup hosts never determine identity.
///
/// [playlistSource] supplies still-loaded old definitions while a prior join
/// is held until cold start; the values being merged remain [local].
/// This transforms a snapshot, never storage or either input. Only known
/// reference fields are rewritten; a title, URL or token that happens to
/// contain an old id stays byte-for-byte intact. Use on first join or while that identity migration remains held.
Map<String, Object?> matchSyncPlaylists(
    Map<String, Object?> local, Map<String, Object?> remote,
    {Map<String, Object?>? playlistSource}) {
  final ours = _idList((playlistSource ?? local)[AppConstants.keyPlaylists]);
  final theirs = _idList(remote[AppConstants.keyPlaylists]);
  if (ours == null || theirs == null) return local;
  final byAccount = <(String, String, String), List<String>>{};
  for (final p in theirs) {
    final account = _syncPlaylistAccount(p);
    if (account != null) {
      byAccount.putIfAbsent(account, () => []).add(p['id'] as String);
    }
  }
  final ids = <String, String>{};
  for (final p in ours) {
    final matches = byAccount[_syncPlaylistAccount(p)];
    if (matches == null || matches.length != 1 || matches.single == p['id']) {
      continue;
    }
    ids[p['id'] as String] = matches.single;
  }
  if (ids.isEmpty) return local;
  final definitions = _idList(local[AppConstants.keyPlaylists]);
  return definitions == null
      ? local
      : _SyncPlaylistRemap(ids).rewrite(local, definitions);
}

(String, String, String)? _syncPlaylistAccount(Map<String, Object?> p) {
  final mode = p['mode'];
  final raw = mode == 'xtream' ? p['xtreamServer'] : p['m3uUrl'];
  if ((mode != 'xtream' && mode != 'm3u') || raw is! String) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  var url = uri.normalizePath().toString();
  // A trailing slash is immaterial for a server root, but can distinguish
  // M3U resources. Preserve the full query (including credential casing).
  if (mode == 'xtream' && !uri.hasQuery && !uri.hasFragment) {
    url = url.replaceFirst(RegExp(r'/+$'), '');
  }
  final user = mode == 'xtream' ? p['xtreamUsername'] : '';
  if (user is! String || (mode == 'xtream' && user.isEmpty)) return null;
  return (mode as String, url, user);
}

class _SyncPlaylistRemap {
  _SyncPlaylistRemap(this.ids);
  final Map<String, String> ids;

  String playlist(String id) => ids[id] ?? id;

  String composite(String id) {
    final split = id.indexOf('::');
    return split < 0
        ? id
        : '${playlist(id.substring(0, split))}${id.substring(split)}';
  }

  static const _playlistKeys = [
    AppConstants.keyHiddenGroups,
    AppConstants.keyShownGroups,
    AppConstants.keyHiddenChannels,
    AppConstants.keyPlaylistEdits,
    AppConstants.keyEpgIdOverrides,
    AppConstants.keyChannelLinks,
    AppConstants.keyAutoPairedChannelLinks,
    AppConstants.keyAutoPairedEpgOverrides,
    AppConstants.keyFavoritedGroups,
    AppConstants.keyChannelOrder,
    '${AppConstants.keyGroupOrder}_tv',
    '${AppConstants.keyGroupOrder}_vod',
    '${AppConstants.keyGroupOrder}_series',
  ];

  String key(String original) {
    final at = original.indexOf(AppConstants.viewerKeySuffix);
    var bare = at < 0 ? original : original.substring(0, at);
    final suffix = at < 0 ? '' : original.substring(at);
    for (final prefix in _playlistKeys) {
      if (bare.startsWith('${prefix}_')) {
        bare = '${prefix}_${playlist(bare.substring(prefix.length + 1))}';
        return '$bare$suffix';
      }
    }
    for (final prefix in [
      AppConstants.keyLastPositionPrefix,
      AppConstants.keyLastDurationPrefix
    ]) {
      if (!bare.startsWith(prefix)) continue;
      final id = bare.substring(prefix.length);
      return '$prefix${id.startsWith('frac:') ? 'frac:${composite(id.substring(5))}' : composite(id)}$suffix';
    }
    return original;
  }

  Map<String, Object?> rewrite(
      Map<String, Object?> local, List<Map<String, Object?>> playlists) {
    final out = <String, Object?>{};
    // Existing canonical keys win scalar collisions. Additional copies add
    // their list members through the same join rule as remote/local lists.
    final entries = local.entries.toList()
      ..sort((a, b) {
        final ac = key(a.key) == a.key ? 0 : 1;
        final bc = key(b.key) == b.key ? 0 : 1;
        return ac != bc ? ac.compareTo(bc) : a.key.compareTo(b.key);
      });
    for (final entry in entries) {
      final target = key(entry.key);
      final value = _value(entry.key, entry.value);
      out[target] = out.containsKey(target) ? _join(value, out[target]) : value;
    }
    final seen = <String>{};
    final preferred = <String, Map<String, Object?>>{};
    for (final p in playlists) {
      final id = playlist(p['id'] as String);
      if (!preferred.containsKey(id) || !ids.containsKey(p['id'])) {
        preferred[id] = p;
      }
    }
    out[AppConstants.keyPlaylists] = _tag(
        's',
        jsonEncode([
          for (final p in playlists)
            if (seen.add(playlist(p['id'] as String)))
              {
                ...preferred[playlist(p['id'] as String)]!,
                'id': playlist(p['id'] as String)
              },
        ]));
    return out;
  }

  Object? _value(String originalKey, Object? value) {
    if (value is! Map) return value;
    final bare = originalKey.split(AppConstants.viewerKeySuffix).first;
    final raw = value['v'];
    Object? changed = raw;
    if (value['t'] == 'l' && raw is List) {
      if ([
        AppConstants.keyFavorites,
        AppConstants.keyFavoriteSeries,
        AppConstants.keyFavoriteLiveOrder,
        AppConstants.keyReal4kChannels
      ].contains(bare)) {
        changed =
            raw.map((id) => id is String ? composite(id) : id).toSet().toList();
      } else if (bare.startsWith('${AppConstants.keyHiddenPlaylistGroups}_')) {
        changed =
            raw.map((id) => id is String ? playlist(id) : id).toSet().toList();
      }
    } else if (value['t'] == 's' && raw is String) {
      if (bare == AppConstants.keyLastChannelId) {
        changed = composite(raw);
      } else if (bare == AppConstants.keySportsPreferredPlaylist) {
        changed = playlist(raw);
      } else {
        try {
          final decoded = jsonDecode(raw);
          final mapped = RegExp(r'^file:recently_played(_vp_[A-Za-z0-9_-]+)?$')
                  .hasMatch(bare)
              ? _history(decoded)
              : _json(bare, decoded);
          if (!syncValuesEqual(decoded, mapped)) changed = jsonEncode(mapped);
        } catch (_) {
          // Malformed preferences remain intact for their normal reader.
        }
      }
    }
    return syncValuesEqual(raw, changed) ? value : {...value, 'v': changed};
  }

  /// A `UserGroups` group reference: only a provider group (`p:<playlist
  /// id>` + NUL + title) holds a playlist id; own groups (`o:`) stay as is.
  String _groupRef(String raw) {
    final at = raw.indexOf('\u0000');
    if (!raw.startsWith('p:') || at < 3) return raw;
    return 'p:${playlist(raw.substring(2, at))}${raw.substring(at)}';
  }

  Object? _mapKeys(Object? data) => data is Map
      ? {for (final e in data.entries) composite(e.key as String): e.value}
      : data;

  Object? _list(Object? data, {bool plain = false}) => data is List
      ? data
          .map((v) => v is String ? (plain ? playlist(v) : composite(v)) : v)
          .toSet()
          .toList()
      : data;

  Object? _values(Object? data) => data is Map
      ? {
          for (final e in data.entries)
            e.key: e.value is String ? composite(e.value as String) : e.value
        }
      : data;

  Object? _filters(Object? data) => data is Map
      ? {
          ...data,
          if (data.containsKey('Playlist'))
            'Playlist': _list(data['Playlist'], plain: true),
          if (data.containsKey('Group')) 'Group': _list(data['Group']),
        }
      : data;

  // Channel.toJson() history files now travel through sync too. Only their
  // identity fields change; stream URLs, raw provider ids and labels do not.
  Object? _history(Object? data) => data is List
      ? [
          for (final row in data)
            if (row is Map)
              {
                ...row,
                if (row['id'] is String) 'id': composite(row['id'] as String),
                if (row['playlistId'] is String)
                  'playlistId': playlist(row['playlistId'] as String),
              }
            else
              row,
        ]
      : data;

  Object? _json(String bare, Object? data) {
    if (data is! Map) return data;
    if (bare == AppConstants.keySeriesSubtitles ||
        bare == AppConstants.keyAudioTrackChoices) {
      return _mapKeys(data);
    }
    if (bare == AppConstants.keyMyGroups) {
      return {
        ...data,
        'moves': _mapKeys(data['moves']),
        // Editor Move / Copy: channel ids as keys, playlist ids inside the
        // provider-group references (`p:<playlist id>\u0000<title>`).
        if (data['pmoves'] is Map)
          'pmoves': {
            for (final e in (data['pmoves'] as Map).entries)
              composite(e.key as String):
                  e.value is String ? _groupRef(e.value as String) : e.value,
          },
        if (data['copies'] is Map)
          'copies': {
            for (final e in (data['copies'] as Map).entries)
              composite(e.key as String): e.value is List
                  ? [
                      for (final r in e.value as List)
                        r is String ? _groupRef(r) : r
                    ]
                  : e.value,
          },
        if (data['order'] is Map)
          'order': {
            for (final e in (data['order'] as Map).entries)
              e.key: _list(e.value),
          },
        // A provider group's order (Move Up / Down after a Move / Copy):
        // a group reference as the key, channel ids inside.
        if (data['porder'] is Map)
          'porder': {
            for (final e in (data['porder'] as Map).entries)
              (e.key is String ? _groupRef(e.key as String) : e.key):
                  _list(e.value),
          },
      };
    }
    if (bare.startsWith('${AppConstants.keyPlaylistEdits}_')) {
      return {
        ...data,
        if (data['fallbacks'] is Map)
          'fallbacks': {
            for (final e in (data['fallbacks'] as Map).entries)
              e.key: _list(e.value),
          }
      };
    }
    if (bare.startsWith('${AppConstants.keyChannelLinks}_')) {
      return {
        for (final e in data.entries)
          e.key: e.value is Map && e.value['playlistId'] is String
              ? {
                  ...e.value as Map,
                  'playlistId': playlist(e.value['playlistId'] as String)
                }
              : e.value
      };
    }
    if (bare == AppConstants.keySportsChannelPicks) {
      return {
        ...data,
        'teams': _values(data['teams']),
        if (data['events'] is Map)
          'events': {
            for (final e in (data['events'] as Map).entries)
              e.key: e.value is Map && e.value['c'] is String
                  ? {...e.value as Map, 'c': composite(e.value['c'] as String)}
                  : e.value,
          }
      };
    }
    if (bare == AppConstants.keySportsChannelLists) {
      return {
        ...data,
        'picks': _values(data['picks']),
        if (data['tags'] is Map)
          'tags': {
            for (final e in (data['tags'] as Map).entries)
              composite(e.key as String): _filters(e.value),
          },
        if (data['sources'] is Map)
          'sources': {
            for (final e in (data['sources'] as Map).entries)
              e.key: e.value is Map
                  ? {...e.value as Map, 'ids': _list(e.value['ids'])}
                  : e.value,
          },
        if (data['lists'] is List)
          'lists': [
            for (final row in data['lists'] as List)
              if (row is Map)
                {
                  ...row,
                  'channels': _list(row['channels']),
                  'excluded': _list(row['excluded']),
                  'filters': _filters(row['filters'])
                }
              else
                row,
          ],
      };
    }
    // Per-playlist raw ids/group names, Media Hub sources, search text and
    // playlist edit labels are deliberately not arbitrary string-replaced.
    return data;
  }
}

/// The merge behind cloud sync (dev-notes/cloud-sync.md), done on the
/// device: the server only ever holds ciphertext.
///
/// Values are `StorageService`'s type-tagged transfer form
/// (`{"t": "s"|"b"|"i"|"d"|"l", "v": ...}` per preference key). Each key
/// also has a stamp (ms since epoch): when a device first saw it change.

/// One synced state: tagged values plus each key's stamp. A key missing
/// from [values] is absent (removed); its stamp can stay to date the
/// removal.
class SyncSnapshot {
  const SyncSnapshot(this.values, this.stamps);

  static const empty = SyncSnapshot({}, {});

  final Map<String, Object?> values;
  final Map<String, int> stamps;

  Map<String, Object?> toJson() => {'values': values, 'stamps': stamps};

  static SyncSnapshot fromJson(Object? json) {
    if (json is! Map) return empty;
    final values = json['values'];
    final stamps = json['stamps'];
    return SyncSnapshot(
      values is Map ? Map<String, Object?>.from(values) : const {},
      stamps is Map
          ? {
              for (final e in stamps.entries)
                if (e.value is int) '${e.key}': e.value as int
            }
          : const {},
    );
  }
}

/// Dates this device's own changes: every key that differs from [base]
/// keeps its earlier stamp in [pending], or gets [now] when first seen.
/// Run on every sync attempt (also offline), so a change made while the
/// server was down still carries roughly when it happened.
Map<String, int> stampLocalChanges(SyncSnapshot? base,
    Map<String, Object?> local, Map<String, int> pending, int now) {
  final baseValues = base?.values ?? const {};
  final out = <String, int>{};
  for (final key in {...local.keys, ...baseValues.keys}) {
    if (syncValuesEqual(local[key], baseValues[key])) continue;
    out[key] = pending[key] ?? now;
  }
  return out;
}

/// Three-way merge of this device's [local] values with the server's
/// [remote] snapshot, against [base] (the last snapshot both agreed on;
/// null = this device is joining the sync). [pending] dates the local
/// changes (see [stampLocalChanges]).
///
/// Per key: changed only here → ours; changed only on the server (or
/// unchanged) → theirs; changed on both → string lists merge as sets,
/// JSON lists of `{"id": …}` objects merge per id, anything else goes to
/// the newer stamp. Joining: lists merge in, every other value is the
/// server's.
///
/// [newestFirst]: keys holding a history (Continue Watching, Media Hub
/// Recently watched: newest entry first). Their entries merge per id the
/// same way, but the side that changed last goes first, so a title watched
/// here a minute ago stays at the front instead of under the server's list.
SyncSnapshot mergeSync({
  required SyncSnapshot? base,
  required Map<String, Object?> local,
  required SyncSnapshot remote,
  required Map<String, int> pending,
  bool Function(String key)? newestFirst,
}) {
  final values = <String, Object?>{};
  final stamps = <String, int>{...remote.stamps};
  final baseValues = base?.values ?? const {};
  final keys = {...remote.values.keys, ...local.keys, ...baseValues.keys};
  for (final key in keys) {
    final r = remote.values[key];
    final l = local[key];
    final localStamp = pending[key] ?? 0;
    final remoteStamp = remote.stamps[key] ?? 0;
    Object? result;
    if (base == null) {
      result = _join(l, r);
      if (!syncValuesEqual(result, r)) {
        stamps[key] = localStamp > remoteStamp ? localStamp : remoteStamp;
      }
    } else {
      final b = baseValues[key];
      final localChanged = !syncValuesEqual(l, b);
      final remoteChanged = !syncValuesEqual(r, b);
      if (!localChanged || syncValuesEqual(l, r)) {
        result = r;
      } else if (!remoteChanged) {
        result = l;
        stamps[key] = localStamp;
      } else {
        result = _both(b, l, r, localStamp > remoteStamp,
            recency: newestFirst?.call(key) ?? false);
        stamps[key] = localStamp > remoteStamp ? localStamp : remoteStamp;
      }
    }
    if (result != null) values[key] = result;
  }
  return SyncSnapshot(values, stamps);
}

/// A joining device's value: lists combined, otherwise the server's.
Object? _join(Object? l, Object? r) {
  if (r == null) return l;
  if (l == null) return r;
  final ls = _stringList(l), rs = _stringList(r);
  if (ls != null && rs != null) {
    return _tag('l', [...rs, ...ls.where((x) => !rs.contains(x))]);
  }
  final li = _idList(l), ri = _idList(r);
  if (li != null && ri != null) {
    final ids = {for (final e in ri) _entryId(e)};
    return _tag('s',
        jsonEncode([...ri, ...li.where((e) => !ids.contains(_entryId(e)))]));
  }
  return r;
}

/// Both sides changed the key since [b].
Object? _both(Object? b, Object? l, Object? r, bool localNewer,
    {bool recency = false}) {
  final ls = _stringList(l), rs = _stringList(r);
  if (ls != null && rs != null) {
    final bs = _stringList(b) ?? const <String>[];
    final removed = bs.where((x) => !ls.contains(x)).toSet();
    return _tag('l', [
      for (final x in rs)
        if (!removed.contains(x)) x,
      for (final x in ls)
        if (!bs.contains(x) && !rs.contains(x)) x,
    ]);
  }
  final li = _idList(l), ri = _idList(r);
  if (li != null && ri != null) {
    final bi = _idList(b) ?? const <Map<String, Object?>>[];
    return _tag(
        's', jsonEncode(_mergeById(bi, li, ri, localNewer, recency: recency)));
  }
  return localNewer ? l : r;
}

/// Per id, the same rules as per key; an entry both sides changed goes to
/// the newer side. The server's order first, then entries added here; with
/// [recency], the newer side's order first (see [mergeSync]).
List<Map<String, Object?>> _mergeById(List<Map<String, Object?>> b,
    List<Map<String, Object?>> l, List<Map<String, Object?>> r, bool localNewer,
    {bool recency = false}) {
  Map<Object?, Map<String, Object?>> byId(List<Map<String, Object?>> list) =>
      {for (final e in list) _entryId(e): e};
  final bm = byId(b), lm = byId(l), rm = byId(r);
  final out = <Map<String, Object?>>[];
  final (first, second) = recency && localNewer ? (l, r) : (r, l);
  final order = {
    // A history: what either side watched since the base comes first
    // (newer side, then the other), then the rest in the newer side's order.
    if (recency) ...[
      for (final e in [...first, ...second])
        if (!bm.containsKey(_entryId(e))) _entryId(e),
    ],
    ...first.map(_entryId),
    ...second.map(_entryId),
  };
  for (final id in order) {
    final be = bm[id], le = lm[id], re = rm[id];
    final localChanged = !syncValuesEqual(le, be);
    final remoteChanged = !syncValuesEqual(re, be);
    final Map<String, Object?>? pick;
    if (!localChanged || syncValuesEqual(le, re)) {
      pick = re;
    } else if (!remoteChanged) {
      pick = le;
    } else {
      // Edited on one side, removed on the other: the edit keeps it.
      pick = le == null ? re : (re == null ? le : (localNewer ? le : re));
    }
    if (pick != null) out.add(pick);
  }
  return out;
}

Map<String, Object?> _tag(String t, Object v) => {'t': t, 'v': v};

List<String>? _stringList(Object? tagged) {
  if (tagged is! Map || tagged['t'] != 'l') return null;
  final v = tagged['v'];
  return v is List ? [for (final s in v) '$s'] : null;
}

/// An entry's identity: its `id`, or for a Media Hub history entry (no
/// `id`) its source + title id.
Object? _entryId(Map<String, Object?> e) {
  final id = e['id'];
  if (id is String) return id;
  final meta = e['meta'];
  return meta is Map ? '${e['src']}|${meta['id']}' : null;
}

/// A tagged string holding a JSON list of objects that all have an
/// identity ([_entryId]: playlists, Media Hub sources, viewer profiles,
/// histories), else null.
List<Map<String, Object?>>? _idList(Object? tagged) {
  if (tagged is! Map || tagged['t'] != 's') return null;
  final v = tagged['v'];
  if (v is! String || !v.startsWith('[')) return null;
  try {
    final list = jsonDecode(v);
    if (list is! List) return null;
    final out = <Map<String, Object?>>[];
    for (final e in list) {
      if (e is! Map) return null;
      final entry = Map<String, Object?>.from(e);
      if (_entryId(entry) == null) return null;
      out.add(entry);
    }
    return out;
  } catch (_) {
    return null;
  }
}

/// Deep equality of decoded JSON values (maps, lists, scalars).
bool syncValuesEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !syncValuesEqual(e.value, b[e.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!syncValuesEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}
