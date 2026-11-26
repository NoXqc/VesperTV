import 'dart:convert';

/// DRM a playlist entry declares: Kodi `inputstream.adaptive` `#KODIPROP`
/// lines (the format TiviMate, OTT Navigator and Kodi read). Public
/// broadcaster playlists (m3upt.com: RTP, SIC and 65 more Portuguese
/// channels, 2026-11-22) give DASH `.mpd` links with ClearKey key pairs:
///
/// ```
/// #KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey
/// #KODIPROP:inputstream.adaptive.license_key=<kid hex>:<key hex>
/// ```
///
/// The channel carries it inside its headers under [headerKey] (see
/// `Channel.playlistHeaders`), so every place that swaps a stream (Sources,
/// copy fallback, the native-zap check) takes it along with the URL. The
/// Android player removes it before any request ([HttpVideoAsset]) and
/// builds ExoPlayer's DRM setup from it. Other players drop it
/// ([withoutDrm]): the bundled libmpv's DASH reader (FFmpeg 6.0) crashed on
/// these live manifests.
class StreamDrm {
  const StreamDrm({
    required this.system,
    this.keys = const {},
    this.licenseUrl,
    this.licenseHeaders = const {},
  });

  /// [clearKey], [widevine] or [playReady].
  final String system;

  /// ClearKey key id -> key, both lower-case hex (32 characters).
  final Map<String, String> keys;

  /// A license server (Widevine, PlayReady, or ClearKey without [keys]).
  final String? licenseUrl;
  final Map<String, String> licenseHeaders;

  static const clearKey = 'clearkey';
  static const widevine = 'widevine';
  static const playReady = 'playready';

  /// Never sent to a server: the Android player takes it out first.
  static const headerKey = 'X-VesperTV-DRM';

  bool get isClearKey => system == clearKey;

  String encode() => jsonEncode({
        'system': system,
        if (keys.isNotEmpty) 'license': clearKeyLicense(),
        if (licenseUrl != null) 'url': licenseUrl,
        if (licenseHeaders.isNotEmpty) 'headers': licenseHeaders,
      });

  /// The DRM in [headers], if the playlist declared one.
  static StreamDrm? of(Map<String, String> headers) {
    final raw = headers[headerKey];
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final keys = <String, String>{};
      final license = json['license'];
      if (license is Map && license['keys'] is List) {
        for (final k in license['keys'] as List) {
          if (k is! Map) continue;
          final kid = _hexOf(k['kid']);
          final key = _hexOf(k['k']);
          if (kid != null && key != null) keys[kid] = key;
        }
      }
      return StreamDrm(
        system: json['system'] as String,
        keys: keys,
        licenseUrl: json['url'] as String?,
        licenseHeaders:
            (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      );
    } catch (_) {
      return null;
    }
  }

  /// Request-lineage tag: like [headerKey], never sent to a server.
  static const _lineageKey = 'x-rq-origin-M4tP9z';

  /// [headers] for a player or a request that can't use the DRM.
  static Map<String, String> withoutDrm(Map<String, String> headers) =>
      headers.containsKey(headerKey) || headers.containsKey(_lineageKey)
          ? ({...headers}
            ..remove(headerKey)
            ..remove(_lineageKey))
          : headers;

  /// The ClearKey license ExoPlayer's `LocalMediaDrmCallback` answers every
  /// key request with: a JWK set, ids and keys base64url without padding
  /// (W3C Encrypted Media Extensions, ClearKey).
  Map<String, Object> clearKeyLicense() => {
        'keys': [
          for (final e in keys.entries)
            {'kty': 'oct', 'kid': _base64Url(e.key), 'k': _base64Url(e.value)}
        ],
        'type': 'temporary',
      };

  /// The entry's DRM from its `#KODIPROP` lines ([props]: names
  /// lower-cased, without `inputstream.adaptive.`). Null when it declares
  /// none or nothing usable.
  ///
  /// Three spellings: `license_type` + `license_key` (most playlists),
  /// `drm_legacy=<system>|<keys or license url>|<headers>` and
  /// `drm=<JSON>` (Kodi 21).
  static StreamDrm? fromKodiProps(Map<String, String> props) {
    final legacy = props['drm_legacy'];
    if (legacy != null) {
      final parts = legacy.split('|');
      final drm = _build(parts.first, parts.length > 1 ? parts[1] : '',
          parts.length > 2 ? parts[2] : '');
      if (drm != null) return drm;
    }
    final json = props['drm'];
    if (json != null) {
      final drm = _fromDrmJson(json);
      if (drm != null) return drm;
    }
    final type = props['license_type'];
    final key = props['license_key'];
    if (type == null && key == null) return null;
    // A key pair without a type is ClearKey: only ClearKey takes keys.
    if (type == null) return _build(clearKey, key!, '');
    if (key == null) return null;
    // Widevine / PlayReady: <url>|<headers>|<body>|<response>. Only the
    // plain kind (raw challenge, raw license: R{SSM}, the default) works.
    final parts = key.split('|');
    return _build(type, parts.first, parts.length > 1 ? parts[1] : '');
  }

  /// `{"org.w3.clearkey":{"license":{"keyids":{"<kid>":"<key>"}}}}` or
  /// `{"com.widevine.alpha":{"license":{"server_url":"…","req_headers":"…"}}}`.
  static StreamDrm? _fromDrmJson(String raw) {
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    for (final e in json.entries) {
      final license = e.value is Map ? (e.value as Map)['license'] : null;
      if (license is! Map) continue;
      final keyIds = license['keyids'];
      final drm = _build(
        '${e.key}',
        keyIds is Map
            ? jsonEncode(keyIds)
            : (license['server_url'] as String? ?? ''),
        license['req_headers'] as String? ?? '',
      );
      if (drm != null) return drm;
    }
    return null;
  }

  static StreamDrm? _build(String type, String data, String headers) {
    final system = _systemOf(type);
    if (system == null) return null;
    data = data.trim();
    final licenseHeaders = parseHeaderQuery(headers);
    if (data.startsWith('http://') || data.startsWith('https://')) {
      return StreamDrm(
          system: system, licenseUrl: data, licenseHeaders: licenseHeaders);
    }
    if (system != clearKey) return null;
    final keys = _clearKeys(data);
    return keys.isEmpty ? null : StreamDrm(system: system, keys: keys);
  }

  static String? _systemOf(String type) {
    switch (type.trim().toLowerCase()) {
      case 'clearkey':
      case 'org.w3.clearkey':
        return clearKey;
      case 'widevine':
      case 'com.widevine.alpha':
        return widevine;
      case 'playready':
      case 'com.microsoft.playready':
      case 'com.microsoft.playready.recommendation':
        return playReady;
    }
    return null;
  }

  /// `kid:key,kid:key`, a JSON object `{"kid":"key"}` or a JWK set
  /// `{"keys":[{"kid":…,"k":…}]}`; ids and keys hex or base64(url).
  static Map<String, String> _clearKeys(String data) {
    final keys = <String, String>{};
    if (data.startsWith('{')) {
      Object? json;
      try {
        json = jsonDecode(data);
      } catch (_) {
        return keys;
      }
      if (json is Map && json['keys'] is List) {
        for (final k in json['keys'] as List) {
          if (k is! Map) continue;
          final kid = _hexOf(k['kid']);
          final key = _hexOf(k['k']);
          if (kid != null && key != null) keys[kid] = key;
        }
      } else if (json is Map) {
        for (final e in json.entries) {
          final kid = _hexOf(e.key);
          final key = _hexOf(e.value);
          if (kid != null && key != null) keys[kid] = key;
        }
      }
      return keys;
    }
    for (final pair in data.split(',')) {
      final at = pair.indexOf(':');
      if (at < 0) continue;
      final kid = _hexOf(pair.substring(0, at));
      final key = _hexOf(pair.substring(at + 1));
      if (kid != null && key != null) keys[kid] = key;
    }
    return keys;
  }

  static final RegExp _hex32 = RegExp(r'^[0-9a-fA-F]{32}$');

  /// A 16-byte id or key as lower-case hex: hex (dashes allowed, the UUID
  /// spelling of a key id) or base64 / base64url.
  static String? _hexOf(Object? value) {
    if (value is! String) return null;
    final v = value.trim();
    final hex = v.replaceAll('-', '');
    if (_hex32.hasMatch(hex)) return hex.toLowerCase();
    try {
      final bytes = base64Url.decode(base64Url.normalize(
          v.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')));
      if (bytes.length != 16) return null;
      return [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')]
          .join();
    } catch (_) {
      return null;
    }
  }

  static String _base64Url(String hex) {
    final bytes = [
      for (var i = 0; i + 1 < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16)
    ];
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// `Name=value&Other=value` (Kodi's header spelling, values URL-encoded).
  static Map<String, String> parseHeaderQuery(String raw) {
    final headers = <String, String>{};
    for (final part in raw.split('&')) {
      final at = part.indexOf('=');
      if (at <= 0) continue;
      final name = _decode(part.substring(0, at)).trim();
      if (name.isEmpty) continue;
      headers[name] = _decode(part.substring(at + 1)).trim();
    }
    return headers;
  }

  static String _decode(String s) {
    try {
      return Uri.decodeQueryComponent(s);
    } catch (_) {
      return s;
    }
  }
}
