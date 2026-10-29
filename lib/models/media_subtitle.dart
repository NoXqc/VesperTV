/// Sidecar subtitles supplied with a playable file. Kept in memory with it.
class MediaSubtitle {
  const MediaSubtitle({required this.url, this.language = 'und', this.name});

  final String url;
  final String language;
  final String? name;

  static MediaSubtitle? fromJson(Map row) {
    final uri = Uri.tryParse('${row['url'] ?? ''}');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return null;
    }
    return MediaSubtitle(
      url: uri.toString(),
      language: '${row['lang'] ?? row['language'] ?? 'und'}',
      name: (row['name'] ?? row['id'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'lang': language,
        if (name != null) 'name': name,
      };
}
