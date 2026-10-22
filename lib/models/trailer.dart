/// Only validated YouTube identities cross the trailer boundary. Local/server
/// playback URLs and arbitrary external links are deliberately not candidates.
class TrailerLinks {
  static List _rows(Object? raw) => raw is List ? raw : const [];
  static String? videoId(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    final id = RegExp(r'^[A-Za-z0-9_-]{11}$');
    if (id.hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    String? candidate;
    if (host == 'youtu.be') {
      candidate = uri.pathSegments.firstOrNull;
    }
    if ([
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com'
    ].contains(host)) {
      candidate = uri.path == '/watch'
          ? uri.queryParameters['v']
          : uri.pathSegments.length == 2 &&
                  ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)
              ? uri.pathSegments.last
              : null;
    }
    return candidate != null && id.hasMatch(candidate) ? candidate : null;
  }

  static List<String> fromMetadata(Map data) => {
        if (videoId(data['youtube_trailer']) case final id?) id,
        for (final row in [
          ..._rows(data['trailers']),
          ..._rows(data['trailerStreams']),
          ..._rows(data['RemoteTrailers'])
        ])
          if (row is Map && row['type'] != 'Clip')
            if (videoId(
                    row['ytId'] ?? row['source'] ?? row['Url'] ?? row['url'])
                case final id?)
              id,
      }.toList();
}
