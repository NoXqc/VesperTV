import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'archive_service.dart';
import 'storage_service.dart';

class ArchiveResumeChoice {
  const ArchiveResumeChoice(this.options, {this.picked, this.url});
  final List<ArchiveStreamOption> options;
  final ArchiveStreamOption? picked;
  final String? url;
}

/// A movie's selected stream, scoped like its progress to the active viewer.
/// Store only fingerprints, not provider credentials or signed playback URLs.
class ArchiveResumeSource {
  ArchiveResumeSource(this.storage, this.channelId,
      {Future<String?> Function(String)? probe})
      : viewerId = storage.getActiveViewerId(),
        _probe = probe ?? probeArchiveResumeUrl;

  final StorageService storage;
  final String channelId;
  final String viewerId;
  final Future<String?> Function(String) _probe;
  bool get isCurrent => storage.getActiveViewerId() == viewerId;
  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static String _description(ArchiveStreamOption option) =>
      jsonEncode([option.stream.name, option.stream.title]);

  Future<void> remember(ArchiveStreamOption option) async {
    if (!isCurrent || option.stream.ytId != null) return;
    await storage.setArchiveResumeSource(
        channelId,
        jsonEncode({
          'source': _hash(option.source.manifestUrl),
          'url': _hash(option.stream.url),
          if ((option.stream.name ?? '').isNotEmpty ||
              (option.stream.title ?? '').isNotEmpty)
            'description': _hash(_description(option)),
        }),
        viewerId: viewerId);
  }

  Future<ArchiveResumeChoice> restore(List<ArchiveStreamOption> options) async {
    final fallback = ArchiveResumeChoice(options);
    if (!isCurrent ||
        storage.getLastPosition(channelId) <= 0 ||
        storage.isFullyWatched(channelId)) {
      return fallback;
    }
    Map saved;
    try {
      final raw = jsonDecode(
          storage.getArchiveResumeSource(channelId, viewerId: viewerId) ??
              'null');
      if (raw is! Map) return fallback;
      saved = raw;
    } catch (_) {
      return fallback;
    }
    final sameSource = options
        .where((o) =>
            o.stream.ytId == null &&
            _hash(o.source.manifestUrl) == saved['source'])
        .toList();
    final exact =
        sameSource.where((o) => _hash(o.stream.url) == saved['url']).toList();
    final described = sameSource
        .where((o) =>
            saved['description'] != null &&
            _hash(_description(o)) == saved['description'])
        .toList();
    // A quality/name shared by several files is not an exact selection.
    final picked = exact.length == 1
        ? exact.single
        : described.length == 1
            ? described.single
            : null;
    if (picked == null) return fallback;
    final url = await _probe(picked.stream.url);
    if (!isCurrent) return fallback;
    if (url == null) {
      return ArchiveResumeChoice(
          options.where((o) => !identical(o, picked)).toList());
    }
    return ArchiveResumeChoice(options, picked: picked, url: url);
  }
}

/// Resolve fresh redirects and confirm the saved selection is reachable.
/// A range request avoids downloading the movie or buffering its body.
Future<String?> probeArchiveResumeUrl(String url,
    {Duration timeout = const Duration(seconds: 8)}) async {
  var uri = Uri.tryParse(url);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    for (var hop = 0; hop < 8; hop++) {
      final request = await client.getUrl(uri!).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close().timeout(timeout);
      final location = response.headers.value(HttpHeaders.locationHeader);
      unawaited(response.listen(null).cancel());
      if (response.isRedirect && location != null) {
        uri = uri.resolve(location);
        continue;
      }
      return response.statusCode >= 200 && response.statusCode < 300
          ? uri.toString()
          : null;
    }
  } catch (_) {
    /* No URLs/errors logged: add-on links can contain credentials. */
  } finally {
    client.close(force: true);
  }
  return null;
}
