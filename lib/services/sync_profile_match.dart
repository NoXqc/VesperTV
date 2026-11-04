import 'dart:convert';

import '../utils/constants.dart';
import '../utils/title_search.dart';
import 'sync_merge.dart';

/// The shared pre-merge join boundary. Both identity namespaces must be
/// mapped before merging; old loaded definitions are retained while held.
Map<String, Object?> matchSyncJoin(
        Map<String, Object?> local, Map<String, Object?> remote,
        {Map<String, Object?>? source}) =>
    matchSyncProfiles(
        matchSyncPlaylists(local, remote, playlistSource: source), remote,
        profileSource: source);

/// A joining device's profiles adopt matching server ids before [mergeSync].
/// Main is never matched by name. Only the first local profile can claim a
/// unique unclaimed remote name; existing shared ids keep their identity, and an
/// ambiguous remote name is left alone. Neither input is mutated.
///
/// [profileSource] supplies still-loaded old definitions while a previous
/// identity migration is held until cold start. [local] remains the snapshot
/// to transform, including the server values of untouched held keys.
Map<String, Object?> matchSyncProfiles(
    Map<String, Object?> local, Map<String, Object?> remote,
    {Map<String, Object?>? profileSource}) {
  final source =
      _profiles((profileSource ?? local)[AppConstants.keyViewerProfiles]);
  final definitions = _profiles(local[AppConstants.keyViewerProfiles]);
  final synced = _profiles(remote[AppConstants.keyViewerProfiles]);
  if (source == null || definitions == null || synced == null) {
    return local;
  }

  final byName = <String, List<Map<String, Object?>>>{};
  final remoteIds = <String>{};
  for (final profile in synced) {
    final id = profile['id'] as String;
    remoteIds.add(id);
    if (id == AppConstants.mainViewerId) continue;
    final name = _nameKey(profile['name'] as String);
    if (name.isNotEmpty) byName.putIfAbsent(name, () => []).add(profile);
  }
  // A profile already known on both sides must not be consumed by another
  // same-name local profile, even when it occurs later in the local list.
  final claimed = source.map((p) => p['id']).where(remoteIds.contains).toSet();
  final aliases = <String, Map<String, Object?>>{};
  for (final profile in source) {
    final id = profile['id'] as String;
    if (id == AppConstants.mainViewerId || remoteIds.contains(id)) continue;
    final matches = byName[_nameKey(profile['name'] as String)]
        ?.where((target) => !claimed.contains(target['id']))
        .toList();
    if (matches == null || matches.length != 1) continue;
    final target = matches.single;
    if (!claimed.add(target['id'])) continue;
    aliases[id] = target;
  }
  if (aliases.isEmpty) return local;

  final remap = _ProfileRemap(aliases);
  final entries = local.entries.toList()
    ..sort((a, b) {
      // Canonical values win scalar collisions with old orphan keys. Lists
      // combine through the ordinary sync join rule so no members disappear.
      final ac = remap.key(a.key) == a.key ? 0 : 1;
      final bc = remap.key(b.key) == b.key ? 0 : 1;
      return ac != bc ? ac.compareTo(bc) : a.key.compareTo(b.key);
    });
  final out = <String, Object?>{};
  for (final entry in entries) {
    final key = remap.key(entry.key);
    final value = remap.value(entry.value);
    out[key] = !out.containsKey(key)
        ? value
        : mergeSync(
            base: null,
            local: {key: value},
            remote: SyncSnapshot({key: out[key]}, const {}),
            pending: const {},
          ).values[key];
  }
  out[AppConstants.keyViewerProfiles] = {
    't': 's',
    'v': jsonEncode([
      for (final profile in definitions)
        // The synced profile's restriction and metadata are authoritative.
        aliases[profile['id']] ?? profile,
    ]),
  };
  return out;
}

List<Map<String, Object?>>? _profiles(Object? tagged) {
  if (tagged is! Map || tagged['t'] != 's' || tagged['v'] is! String) {
    return null;
  }
  try {
    final rows = jsonDecode(tagged['v'] as String);
    if (rows is! List) return null;
    final ids = <String>{};
    final out = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          row['name'] is! String ||
          (row['id'] as String).isEmpty ||
          !ids.add(row['id'] as String)) {
        return null;
      }
      out.add(Map<String, Object?>.from(row));
    }
    return out;
  } catch (_) {
    return null;
  }
}

// Reuse the catalog's established accent folding, but only on letters:
// punctuation, emoji and interior whitespace distinguish profile names.
// Combining accents also fold when the name uses decomposed Unicode.
String _nameKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
    .replaceAllMapped(RegExp(r'\p{L}', unicode: true),
        (match) => TitleSearch.fold(match[0]!));

class _ProfileRemap {
  _ProfileRemap(this.aliases);
  final Map<String, Map<String, Object?>> aliases;

  String id(String original) => aliases[original]?['id'] as String? ?? original;

  String key(String original) {
    const history = 'file:recently_played_vp_';
    if (original.startsWith(history)) {
      return '$history${id(original.substring(history.length))}';
    }
    for (final old in aliases.keys) {
      final suffix = '${AppConstants.viewerKeySuffix}$old';
      if (original.endsWith(suffix)) {
        return '${original.substring(0, original.length - suffix.length)}'
            '${AppConstants.viewerKeySuffix}${id(old)}';
      }
    }
    return original;
  }

  Object? value(Object? tagged) {
    if (tagged is! Map || tagged['t'] != 's' || tagged['v'] is! String) {
      return tagged;
    }
    try {
      final original = jsonDecode(tagged['v'] as String);
      final changed = _references(original);
      return syncValuesEqual(original, changed)
          ? tagged
          : {...tagged, 'v': jsonEncode(changed)};
    } catch (_) {
      return tagged;
    }
  }

  // Rewrite explicit viewer references only. Unrelated ids, source user ids,
  // names, URLs, tokens and text containing an id remain untouched.
  Object? _references(Object? data) => switch (data) {
        List list => [for (final item in list) _references(item)],
        Map map => {
            for (final entry in map.entries)
              entry.key: switch (entry.key) {
                'viewerId' ||
                'profileId' ||
                'viewer_id' ||
                'profile_id' when entry.value is String =>
                  id(entry.value as String),
                'viewerIds' ||
                'profileIds' ||
                'viewer_ids' ||
                'profile_ids' when entry.value is List =>
                  [
                    for (final item in entry.value as List)
                      item is String ? id(item) : _references(item),
                  ],
                _ => _references(entry.value),
              }
          },
        _ => data,
      };
}
