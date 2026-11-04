import 'dart:convert';

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
