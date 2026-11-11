import 'dart:convert';

import '../models/channel.dart';

/// A video in the network folder, as another device browsing it sees it
/// (Recordings tab, "Network folder"): played from the share, or copied
/// to this device for watching offline (a trip, the car).
class NetworkFile {
  const NetworkFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    this.details,
  });

  /// `smb://host/share/folder/…/name.mkv`.
  final String path;
  final String name;
  final int size;
  final DateTime modified;

  /// The `.vespertv/<name>.json` the saving device wrote (title, poster…);
  /// null for a file put there by hand or by an older version.
  final Map<String, dynamic>? details;

  static NetworkFile? fromJson(Map m) {
    final path = m['path'];
    final name = m['name'];
    if (path is! String || name is! String) return null;
    Map<String, dynamic>? details;
    if (m['details'] case final String raw) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) details = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return NetworkFile(
      path: path,
      name: name,
      size: (m['size'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(
          (m['modified'] as num?)?.toInt() ?? 0),
      details: details,
    );
  }

  String? _s(String key) {
    final v = details?[key];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  /// "72 Hours", or the cleaned file name.
  String get title => _s('title') ?? titleFromName(name);

  /// The show for an episode, the league for a game; '' for a movie.
  String get group => _s('group') ?? '';

  String? get poster => _s('poster') ?? _s('logo');

  int get durationSec => (details?['durationSec'] as num?)?.toInt() ?? 0;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'mkv' : name.substring(dot + 1).toLowerCase();
  }

  /// Named like VesperTV names what it saves (`2026-11-10_Title_<id>.mkv`).
  bool get savedByVesper => _vesperName.hasMatch(name);

  /// Ready to play or copy. A file VesperTV saves gets its details only
  /// once it's complete, so one without them is still being written (or
  /// comes from a version before details: it shows once that device opens
  /// the app again).
  bool get ready => details != null || !savedByVesper;

  /// The same title as a player channel: a stable id (the resume point
  /// follows the file), the share path as its URL (played through the
  /// recorder's local server, see RecordingService.playbackUrl).
  Channel toChannel() => Channel(
        id: '${Channel.recordingPrefix}net_${stableHash(path)}',
        rawId: '${Channel.recordingPrefix}net_${stableHash(path)}',
        playlistId: '',
        name: group.isEmpty ? title : '$group · $title',
        group: group,
        url: path,
        logoUrl: poster,
      );

  static final _vesperName = RegExp(
      r'^\d{4}-\d{2}-\d{2}_.+_(dl[0-9a-z]+_\d+|[0-9a-z]{8,14})\.[A-Za-z0-9]{2,4}$');

  /// "2026-11-10_72_HOURS_dlx1_0.mkv" -> "72 HOURS";
  /// "The.Batman.2022.2160p.mkv" -> "The Batman 2022 2160p".
  static String titleFromName(String name) {
    var t = name;
    final dot = t.lastIndexOf('.');
    if (dot > 0) t = t.substring(0, dot);
    final m =
        RegExp(r'^\d{4}-\d{2}-\d{2}_(.+)_(dl[0-9a-z]+_\d+|[0-9a-z]{8,14})$')
            .firstMatch(t);
    if (m != null) t = m.group(1)!;
    t = t.replaceAll(RegExp(r'[._]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    return t.trim().isEmpty ? name : t.trim();
  }

  /// FNV-1a, so the id doesn't change between runs (String.hashCode may).
  static String stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(36);
  }
}

/// The share's videos this device should offer: ready ones, not this
/// device's own files there ([ownPaths]) nor ones already copied here
/// ([copiedFrom]), newest first.
List<NetworkFile> networkFilesToShow(List<NetworkFile> all,
    {required Set<String> ownPaths, required Set<String> copiedFrom}) {
  final list = [
    for (final f in all)
      if (f.ready && !ownPaths.contains(f.path) && !copiedFrom.contains(f.path))
        f,
  ]..sort((a, b) => b.modified.compareTo(a.modified));
  return list;
}

/// `smb://…/dir/name.mkv` -> `smb://…/dir/.vespertv/name.mkv.json` (same
/// rule as NetworkFolder.detailsUrl in Kotlin).
String networkDetailsPath(String path) {
  final slash = path.lastIndexOf('/');
  return '${path.substring(0, slash)}/.vespertv/${path.substring(slash + 1)}.json';
}
