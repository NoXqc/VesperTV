import 'dart:convert';

import 'playlist_edits.dart';

/// What one change did to a playlist's [PlaylistEdits] (stream test
/// results excluded): kept so the change can be undone later without
/// touching anything changed since, by the viewer in the editor page or by
/// another change. See `dev-notes/vesper-ai.md` (Playlist editor tool).
class EditsDiff {
  EditsDiff._({
    required this.maps,
    required this.sets,
    required this.fallbacks,
    required this.rulesAdded,
    required this.rulesRemoved,
    required this.flags,
  });

  /// field ('names' / 'logos' / 'groupNames') -> key -> (before, after);
  /// null = absent.
  final Map<String, Map<String, (String?, String?)>> maps;

  /// field ('hidden' / 'shown') -> (added, removed).
  final Map<String, (Set<String>, Set<String>)> sets;

  /// rawId -> (before, after); null = no fallbacks.
  final Map<String, (List<String>?, List<String>?)> fallbacks;

  /// Rules as JSON (a rule is its fields, see [EditRule.toJson]).
  final List<Map<String, dynamic>> rulesAdded;
  final List<Map<String, dynamic>> rulesRemoved;

  /// 'hideLowerCopies' / 'hideSeparators' -> (before, after).
  final Map<String, (bool, bool)> flags;

  static const _mapFields = ['names', 'logos', 'groupNames'];
  static const _setFields = ['hidden', 'shown'];
  static const _flagFields = ['hideLowerCopies', 'hideSeparators'];

  static Map<String, String> _map(PlaylistEdits e, String field) =>
      switch (field) {
        'names' => e.names,
        'logos' => e.logos,
        _ => e.groupNames,
      };

  static Set<String> _set(PlaylistEdits e, String field) =>
      field == 'hidden' ? e.hidden : e.shown;

  static bool _flag(PlaylistEdits e, String field) =>
      field == 'hideLowerCopies' ? e.hideLowerCopies : e.hideSeparators;

  static void _setFlag(PlaylistEdits e, String field, bool value) {
    if (field == 'hideLowerCopies') {
      e.hideLowerCopies = value;
    } else {
      e.hideSeparators = value;
    }
  }

  static String _ruleKey(Map<String, dynamic> r) => jsonEncode(r);

  static bool _sameList(List<String>? a, List<String>? b) =>
      a == null || b == null
          ? a == b
          : a.length == b.length &&
              Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  /// From [before] to [after].
  factory EditsDiff.between(PlaylistEdits before, PlaylistEdits after) {
    final maps = <String, Map<String, (String?, String?)>>{};
    for (final f in _mapFields) {
      final a = _map(before, f), b = _map(after, f);
      final changed = <String, (String?, String?)>{
        for (final k in {...a.keys, ...b.keys})
          if (a[k] != b[k]) k: (a[k], b[k]),
      };
      if (changed.isNotEmpty) maps[f] = changed;
    }
    final sets = <String, (Set<String>, Set<String>)>{};
    for (final f in _setFields) {
      final a = _set(before, f), b = _set(after, f);
      final added = b.difference(a), removed = a.difference(b);
      if (added.isNotEmpty || removed.isNotEmpty) sets[f] = (added, removed);
    }
    final fallbacks = <String, (List<String>?, List<String>?)>{
      for (final k in {...before.fallbacks.keys, ...after.fallbacks.keys})
        if (!_sameList(before.fallbacks[k], after.fallbacks[k]))
          k: (before.fallbacks[k], after.fallbacks[k]),
    };
    // Rules compared as multisets of their JSON: order changes alone are
    // not a change.
    final beforeRules = [for (final r in before.rules) r.toJson()];
    final afterRules = [for (final r in after.rules) r.toJson()];
    List<Map<String, dynamic>> minus(
        List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
      final left = [for (final r in b) _ruleKey(r)];
      final out = <Map<String, dynamic>>[];
      for (final r in a) {
        if (!left.remove(_ruleKey(r))) out.add(r);
      }
      return out;
    }

    final flags = <String, (bool, bool)>{
      for (final f in _flagFields)
        if (_flag(before, f) != _flag(after, f))
          f: (_flag(before, f), _flag(after, f)),
    };
    return EditsDiff._(
      maps: maps,
      sets: sets,
      fallbacks: fallbacks,
      rulesAdded: minus(afterRules, beforeRules),
      rulesRemoved: minus(beforeRules, afterRules),
      flags: flags,
    );
  }

  bool get isEmpty =>
      maps.isEmpty &&
      sets.isEmpty &&
      fallbacks.isEmpty &&
      rulesAdded.isEmpty &&
      rulesRemoved.isEmpty &&
      flags.isEmpty;

  /// [current] with this change taken back, plus how many parts were left
  /// alone because they were changed again since (those stay as they are
  /// now: an undo never overwrites a newer edit). [current] is not changed.
  (PlaylistEdits, int) revert(PlaylistEdits current) {
    final out = PlaylistEdits.fromJson(current.toJson());
    var skipped = 0;
    for (final e in maps.entries) {
      final map = _map(out, e.key);
      for (final k in e.value.entries) {
        final (before, after) = k.value;
        if (map[k.key] != after) {
          skipped++;
          continue;
        }
        if (before == null) {
          map.remove(k.key);
        } else {
          map[k.key] = before;
        }
      }
    }
    for (final e in sets.entries) {
      final set = _set(out, e.key);
      final (added, removed) = e.value;
      // Taking back an add that's gone already (or a removal re-added) is
      // simply already done: not a conflict.
      set.removeAll(added);
      set.addAll(removed);
    }
    for (final e in fallbacks.entries) {
      final (before, after) = e.value;
      if (!_sameList(out.fallbacks[e.key], after)) {
        skipped++;
        continue;
      }
      if (before == null) {
        out.fallbacks.remove(e.key);
      } else {
        out.fallbacks[e.key] = [...before];
      }
    }
    for (final r in rulesAdded) {
      final key = _ruleKey(r);
      final i = out.rules.indexWhere((x) => _ruleKey(x.toJson()) == key);
      if (i < 0) {
        skipped++;
      } else {
        out.rules.removeAt(i);
      }
    }
    for (final r in rulesRemoved) {
      if (EditRule.fromJson(r) case final rule?) out.rules.add(rule);
    }
    for (final e in flags.entries) {
      final (before, after) = e.value;
      if (_flag(out, e.key) != after) {
        skipped++;
        continue;
      }
      _setFlag(out, e.key, before);
    }
    return (out, skipped);
  }

  Map<String, dynamic> toJson() => {
        if (maps.isNotEmpty)
          'm': {
            for (final f in maps.entries)
              f.key: {
                for (final k in f.value.entries)
                  k.key: [k.value.$1, k.value.$2],
              },
          },
        if (sets.isNotEmpty)
          's': {
            for (final f in sets.entries)
              f.key: [f.value.$1.toList(), f.value.$2.toList()],
          },
        if (fallbacks.isNotEmpty)
          'f': {
            for (final k in fallbacks.entries) k.key: [k.value.$1, k.value.$2],
          },
        if (rulesAdded.isNotEmpty) 'ra': rulesAdded,
        if (rulesRemoved.isNotEmpty) 'rr': rulesRemoved,
        if (flags.isNotEmpty)
          'b': {
            for (final f in flags.entries) f.key: [f.value.$1, f.value.$2],
          },
      };

  /// Null for a broken blob.
  static EditsDiff? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      String? str(Object? v) => v is String ? v : null;
      List<String>? list(Object? v) =>
          v is List ? [for (final x in v) '$x'] : null;
      final maps = <String, Map<String, (String?, String?)>>{};
      if (json['m'] case final Map m) {
        for (final f in m.entries) {
          if (!_mapFields.contains(f.key) || f.value is! Map) continue;
          maps[f.key as String] = {
            for (final k in (f.value as Map).entries)
              if (k.value is List && (k.value as List).length == 2)
                '${k.key}': (str(k.value[0]), str(k.value[1])),
          };
        }
      }
      final sets = <String, (Set<String>, Set<String>)>{};
      if (json['s'] case final Map s) {
        for (final f in s.entries) {
          final v = f.value;
          if (!_setFields.contains(f.key) || v is! List || v.length != 2) {
            continue;
          }
          sets[f.key as String] = ({...?list(v[0])}, {...?list(v[1])});
        }
      }
      final fallbacks = <String, (List<String>?, List<String>?)>{};
      if (json['f'] case final Map f) {
        for (final k in f.entries) {
          final v = k.value;
          if (v is! List || v.length != 2) continue;
          fallbacks['${k.key}'] = (list(v[0]), list(v[1]));
        }
      }
      List<Map<String, dynamic>> rules(Object? v) => [
            if (v is List)
              for (final r in v)
                if (r is Map) Map<String, dynamic>.from(r),
          ];
      final flags = <String, (bool, bool)>{};
      if (json['b'] case final Map b) {
        for (final f in b.entries) {
          final v = f.value;
          if (!_flagFields.contains(f.key) || v is! List || v.length != 2) {
            continue;
          }
          flags[f.key as String] = (v[0] == true, v[1] == true);
        }
      }
      return EditsDiff._(
        maps: maps,
        sets: sets,
        fallbacks: fallbacks,
        rulesAdded: rules(json['ra']),
        rulesRemoved: rules(json['rr']),
        flags: flags,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One change an AI made, over one or more playlists.
class AiEditChange {
  AiEditChange({
    required this.id,
    required this.at,
    required this.summary,
    required this.diffs,
  });

  /// Short, never reused on this device ("c12").
  final String id;
  final DateTime at;

  /// English, for the AI: "hide 412 channels without guide data".
  final String summary;

  /// playlistId -> what changed there.
  final Map<String, EditsDiff> diffs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'sum': summary,
        'd': {for (final e in diffs.entries) e.key: e.value.toJson()},
      };

  static AiEditChange? fromJson(Object? json) {
    if (json is! Map ||
        json['id'] is! String ||
        json['at'] is! int ||
        json['d'] is! Map) {
      return null;
    }
    final diffs = <String, EditsDiff>{};
    for (final e in (json['d'] as Map).entries) {
      if (EditsDiff.fromJson(e.value) case final d?) diffs['${e.key}'] = d;
    }
    return AiEditChange(
      id: json['id'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      summary: (json['sum'] as String?) ?? '',
      diffs: diffs,
    );
  }
}

/// The AI's playlist editor changes, newest last, capped at [max]. The
/// caller stores [encode] (device-only, per viewer).
class AiEditLog {
  AiEditLog([List<AiEditChange>? changes, this.nextId = 1])
      : changes = changes ?? [];

  static const max = 30;

  final List<AiEditChange> changes;
  int nextId;

  AiEditChange add(String summary, Map<String, EditsDiff> diffs) {
    final change = AiEditChange(
      id: 'c${nextId++}',
      at: DateTime.now(),
      summary: summary,
      diffs: diffs,
    );
    changes.add(change);
    while (changes.length > max) {
      changes.removeAt(0);
    }
    return change;
  }

  /// [id], or the newest change when null.
  AiEditChange? find(String? id) {
    if (changes.isEmpty) return null;
    if (id == null || id.isEmpty) return changes.last;
    for (final c in changes) {
      if (c.id == id.trim().toLowerCase()) return c;
    }
    return null;
  }

  void remove(AiEditChange change) => changes.remove(change);

  String encode() => jsonEncode({
        'next': nextId,
        'c': [for (final c in changes) c.toJson()],
      });

  static AiEditLog decode(String? s) {
    if (s == null || s.isEmpty) return AiEditLog();
    try {
      final json = jsonDecode(s);
      if (json is! Map) return AiEditLog();
      return AiEditLog([
        if (json['c'] is List)
          for (final c in json['c'] as List)
            if (AiEditChange.fromJson(c) case final change?) change,
      ], (json['next'] as int?) ?? 1);
    } catch (_) {
      return AiEditLog();
    }
  }
}
