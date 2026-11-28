import '../models/playlist_profile.dart';

/// A live channel on the playlist's other server addresses
/// ([PlaylistProfile.backupServers]): the same `/live/user/pass/id.ts` path
/// on another host of the same account. Used by Android's
/// `PlaybackService._retryOnBackupServers` (a channel that failed to open)
/// and by [BackupServerWalk] in `DesktopLiveRecovery` (computers, iPhone,
/// Apple TV: a channel that stopped and didn't come back on its own
/// address).
class LiveBackupServers {
  LiveBackupServers._();

  /// The `scheme://host:port` of a URL, with nothing after it — what has
  /// to change to point the same stream at a different server.
  static String originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  /// Rebuilds a stream URL against [server], keeping the whole path
  /// (`/live/user/pass/12345.ts`) as-is — a backup server for the same
  /// account serves the same stream ids under the same credentials, so
  /// only the origin ever differs.
  static String swapOrigin(String url, String server) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    var base = server.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '$base${uri.path}$query';
  }

  /// The servers to try, in order, for a live stream at [failedUrl] that
  /// didn't play: [PlaylistProfile.serverCandidates] (the one that last
  /// worked first, then the primary, then the backups) without the server
  /// [failedUrl] is on. Empty for an M3U playlist (its links are not one
  /// account's paths) or when [profile] is null.
  static List<String> candidatesFor(
      PlaylistProfile? profile, String failedUrl) {
    if (profile == null || !profile.isXtream) return const [];
    final currentOrigin = originOf(failedUrl);
    return profile.serverCandidates
        .where((s) => originOf(s) != currentOrigin)
        .toList();
  }
}

/// One pass over a playlist's other servers for a live channel that won't
/// come back ([LiveBackupServers.candidatesFor], fixed at the first ask),
/// one server per reopen. [reset] when the channel plays again or another
/// channel starts.
class BackupServerWalk {
  List<String>? _servers;
  int _next = 0;

  List<String> _listFor(PlaylistProfile? profile, String failedUrl) =>
      _servers ??= LiveBackupServers.candidatesFor(profile, failedUrl);

  /// Whether [next] has a server left (works out the list on the first ask).
  bool hasNext(PlaylistProfile? profile, String failedUrl) =>
      _next < _listFor(profile, failedUrl).length;

  /// The next server to try, null when none is left (or none configured).
  String? next(PlaylistProfile? profile, String failedUrl) {
    final list = _listFor(profile, failedUrl);
    return _next < list.length ? list[_next++] : null;
  }

  /// Servers handed out so far in this pass.
  int get tried => _next;

  /// Servers in this pass (0 before the first ask).
  int get total => _servers?.length ?? 0;

  void reset() {
    _servers = null;
    _next = 0;
  }
}
