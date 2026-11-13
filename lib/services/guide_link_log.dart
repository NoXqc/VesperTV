import 'dart:convert';

/// One TV guide change an AI made (EPG matching tool), in one or more
/// playlists: links set or cleared, extra guides added or removed. Kept so
/// it can be undone without touching what the viewer changed since, like
/// the playlist editor's `AiEditLog`. See dev-notes/vesper-ai.md (EPG
/// matching tool).
class GuideChange {
  GuideChange({
    required this.id,
    required this.at,
    required this.summary,
    required this.links,
    required this.guides,
  });

  /// Short, never reused on this device ("g3").
  final String id;
  final DateTime at;

  /// English, for the AI: "link 212 channels to the guide".
  final String summary;

  /// playlistId -> rawId -> (before, after) guide id; null = no link (the
  /// channel's own id).
  final Map<String, Map<String, (String?, String?)>> links;

  /// playlistId -> (before, after) extra guide addresses.
  final Map<String, (List<String>, List<String>)> guides;

  int get linkCount => links.values.fold(0, (n, m) => n + m.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'sum': summary,
        'l': {
          for (final p in links.entries)
            p.key: {
              for (final e in p.value.entries) e.key: [e.value.$1, e.value.$2]
            }
        },
        'g': {
          for (final p in guides.entries) p.key: [p.value.$1, p.value.$2]
        },
      };

  static GuideChange? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['at'] is! int) {
      return null;
    }
    List<String> strings(Object? v) => [
          if (v is List)
            for (final x in v)
              if (x is String) x
        ];
    return GuideChange(
      id: json['id'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      summary: (json['sum'] as String?) ?? '',
      links: {
        if (json['l'] is Map)
          for (final p in (json['l'] as Map).entries)
            if (p.value is Map)
              '${p.key}': {
                for (final e in (p.value as Map).entries)
                  if (e.value is List && (e.value as List).length == 2)
                    '${e.key}': (
                      (e.value as List)[0] as String?,
                      (e.value as List)[1] as String?
                    )
              }
      },
      guides: {
        if (json['g'] is Map)
          for (final p in (json['g'] as Map).entries)
            if (p.value is List && (p.value as List).length == 2)
              '${p.key}': (
                strings((p.value as List)[0]),
                strings((p.value as List)[1])
              )
      },
    );
  }
}

/// The AI's guide changes, newest last, capped at [max]. The caller stores
/// [encode] (device-only).
class GuideLinkLog {
  GuideLinkLog([List<GuideChange>? changes, this.nextId = 1])
      : changes = changes ?? [];

  static const max = 30;

  final List<GuideChange> changes;
  int nextId;

  GuideChange add(
    String summary, {
    Map<String, Map<String, (String?, String?)>> links = const {},
    Map<String, (List<String>, List<String>)> guides = const {},
  }) {
    final change = GuideChange(
      id: 'g${nextId++}',
      at: DateTime.now(),
      summary: summary,
      links: links,
      guides: guides,
    );
    changes.add(change);
    while (changes.length > max) {
      changes.removeAt(0);
    }
    return change;
  }

  /// [id], or the newest change when null.
  GuideChange? find(String? id) {
    if (changes.isEmpty) return null;
    if (id == null || id.isEmpty) return changes.last;
    for (final c in changes) {
      if (c.id == id.trim().toLowerCase()) return c;
    }
    return null;
  }

  String encode() => jsonEncode({
        'next': nextId,
        'c': [for (final c in changes) c.toJson()],
      });

  static GuideLinkLog decode(String? s) {
    if (s == null || s.isEmpty) return GuideLinkLog();
    try {
      final json = jsonDecode(s);
      if (json is! Map) return GuideLinkLog();
      return GuideLinkLog([
        if (json['c'] is List)
          for (final c in json['c'] as List)
            if (GuideChange.fromJson(c) case final change?) change,
      ], (json['next'] as int?) ?? 1);
    } catch (_) {
      return GuideLinkLog();
    }
  }
}

/// What undoing [links] does to [current] overrides: back to `before` where
/// the link is still what the change set; the rest is left (kept).
(Map<String, String?>, int) revertLinks(
    Map<String, (String?, String?)> links, Map<String, String> current) {
  final out = <String, String?>{};
  var kept = 0;
  for (final e in links.entries) {
    if (current[e.key] == e.value.$2) {
      out[e.key] = e.value.$1;
    } else {
      kept++;
    }
  }
  return (out, kept);
}

/// [current] extra guides with a change's additions removed and its
/// removals back (in their old place when possible).
List<String> revertGuides(
    (List<String>, List<String>) change, List<String> current) {
  final (before, after) = change;
  final added = after.where((u) => !before.contains(u)).toSet();
  final removed = before.where((u) => !after.contains(u));
  final out = [
    for (final u in current)
      if (!added.contains(u)) u
  ];
  for (final u in removed) {
    if (out.contains(u)) continue;
    final at = before.indexOf(u).clamp(0, out.length);
    out.insert(at, u);
  }
  return out;
}
