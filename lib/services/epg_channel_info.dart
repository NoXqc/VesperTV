/// Channel branding from one XMLTV source, independent of programme filtering.
class EpgChannelInfo {
  const EpgChannelInfo(this.id, this.name, this.logoUrl);
  final String id;
  final String name;
  final String? logoUrl;
}

/// The editor's persisted logo layer supports at most 1000 characters per URL.
/// Reject an unusable URL rather than silently truncating a selected logo.
String? epgLogoUrl(String? value, {String? sourceUrl}) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty || raw.contains(RegExp(r'[\x00-\x20]'))) {
    return null;
  }
  try {
    final uri =
        sourceUrl == null ? Uri.parse(raw) : Uri.parse(sourceUrl).resolve(raw);
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.toString().length > 1000) {
      return null;
    }
    return uri.toString();
  } on FormatException {
    return null;
  }
}
