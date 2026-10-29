/// Reject malformed and transport-owned headers from add-on responses.
Map<String, String> streamRequestHeaders(Object? value) {
  if (value is! Map) return const {};
  const blocked = {
    'host',
    'connection',
    'content-length',
    'transfer-encoding',
    'range',
    'accept-encoding',
    'proxy-authorization',
    'proxy-connection'
  };
  return Map.unmodifiable({
    for (final e in value.entries)
      if (e.key is String &&
          e.value is String &&
          RegExp(r"^[!#$%&'*+.^_`|~0-9a-zA-Z-]+$").hasMatch(e.key) &&
          !blocked.contains((e.key as String).toLowerCase()) &&
          !(e.value as String).contains(RegExp(r'[\r\n]')))
        e.key as String: e.value as String,
  });
}

/// Credentials belong to the original origin. Only presentation headers may
/// follow a redirect to a different origin, and never an HTTPS downgrade.
Map<String, String> redirectedStreamHeaders(
    Map<String, String> headers, Uri from, Uri to) {
  if (from.scheme == 'https' && to.scheme != 'https') return const {};
  if (from.origin == to.origin) return headers;
  const portable = {
    'user-agent',
    'referer',
    'origin',
    'accept',
    'accept-language'
  };
  return Map.unmodifiable({
    for (final e in headers.entries)
      if (portable.contains(e.key.toLowerCase())) e.key: e.value,
  });
}
