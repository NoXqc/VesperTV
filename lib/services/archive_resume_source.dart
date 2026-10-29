import 'stream_headers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'archive_service.dart';
import 'archive_stream_size.dart';
import 'storage_service.dart';

enum ArchiveResumeReason {
  notResuming,
  noChoice,
  invalidChoice,
  missingSource,
  unmatched,
  unavailable,
  exactUrl,
  fileIdentity,
  description,
}

class ArchiveResumeChoice {
  const ArchiveResumeChoice(this.options,
      {this.picked, this.url, this.reason = ArchiveResumeReason.noChoice});
  final List<ArchiveStreamOption> options;
  final ArchiveStreamOption? picked;
  final String? url;
  final ArchiveResumeReason reason;
}

/// A movie's selected stream, scoped like its progress to the active viewer.
/// Store only fingerprints, not provider credentials or signed playback URLs.
class ArchiveResumeSource {
  ArchiveResumeSource(this.storage, this.channelId,
      {Future<String?> Function(String)? probe})
      : viewerId = storage.getActiveViewerId(),
        _viewerGeneration = storage.viewerGeneration,
        _probe = probe;

  final StorageService storage;
  final String channelId;
  final String viewerId;
  final int _viewerGeneration;
  final Future<String?> Function(String)? _probe;
  bool get isCurrent =>
      storage.getActiveViewerId() == viewerId &&
      storage.viewerGeneration == _viewerGeneration;
  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static String _description(ArchiveStreamOption option) =>
      jsonEncode([option.stream.name, option.stream.title]);
  static String? _fileIdentity(ArchiveStreamOption option) {
    final videoHash = option.stream.videoHash?.trim().toLowerCase();
    if (videoHash != null && videoHash.isNotEmpty) {
      return _hash('video:$videoHash');
    }
    final filename = option.stream.fileName?.trim();
    return filename == null || filename.isEmpty
        ? null
        : _hash('file:$filename');
  }

  static String _fileKind(ArchiveStreamOption option) =>
      (option.stream.videoHash ?? '').trim().isNotEmpty ? 'hash' : 'filename';

  Future<void> remember(ArchiveStreamOption option) async {
    if (!isCurrent || option.stream.ytId != null) return;
    await storage.setArchiveResumeSource(
        channelId,
        jsonEncode({
          'source': _hash(option.source.manifestUrl),
          'url': _hash(option.stream.url),
          if (_fileIdentity(option) case final file?) 'file': file,
          if (_fileIdentity(option) != null) 'fileKind': _fileKind(option),
          if (archiveStreamBytes(option) > 0)
            'bytes': archiveStreamBytes(option),
          if ((option.stream.sizeBytes ?? 0) > 0) 'bytesExact': true,
          if ((option.stream.name ?? '').isNotEmpty ||
              (option.stream.title ?? '').isNotEmpty)
            'description': _hash(_description(option)),
        }),
        viewerId: viewerId);
  }

  Future<ArchiveResumeChoice> restore(List<ArchiveStreamOption> options) async {
    ArchiveResumeChoice fallback(ArchiveResumeReason reason) =>
        ArchiveResumeChoice(options, reason: reason);
    if (!isCurrent ||
        storage.getLastPosition(channelId) <= 0 ||
        storage.isFullyWatched(channelId)) {
      return fallback(ArchiveResumeReason.notResuming);
    }
    Map saved;
    try {
      final raw = jsonDecode(
          storage.getArchiveResumeSource(channelId, viewerId: viewerId) ??
              'null');
      if (raw == null) return fallback(ArchiveResumeReason.noChoice);
      if (raw is! Map) return fallback(ArchiveResumeReason.invalidChoice);
      saved = raw;
    } catch (_) {
      return fallback(ArchiveResumeReason.invalidChoice);
    }
    final sameSource = options
        .where((o) =>
            o.stream.ytId == null &&
            _hash(o.source.manifestUrl) == saved['source'])
        .toList();
    if (sameSource.isEmpty) return fallback(ArchiveResumeReason.missingSource);
    // Filenames/hashes survive rotating signed links and changing seed counts.
    // A known size conflict must never turn a selected 47 GB file into a 7 GB
    // file simply because a provider reused its URL or generic description.
    bool compatible(ArchiveStreamOption option) {
      final file = _fileIdentity(option);
      if (saved['file'] != null &&
          file != null &&
          saved['fileKind'] == _fileKind(option) &&
          saved['file'] != file) {
        return false;
      }
      // Labelled sizes can be rounded. Reject an otherwise exact URL on size
      // only when both sides supply structured byte counts.
      final bytes = option.stream.sizeBytes ?? 0;
      return saved['bytesExact'] != true ||
          saved['bytes'] is! num ||
          saved['bytes'] <= 0 ||
          bytes <= 0 ||
          saved['bytes'] == bytes;
    }

    final candidates = sameSource.where(compatible).toList();
    final exact =
        candidates.where((o) => _hash(o.stream.url) == saved['url']).toList();
    final files = candidates.where((o) {
      if (saved['file'] == null || _fileIdentity(o) != saved['file']) {
        return false;
      }
      final bytes = archiveStreamBytes(o);
      return _fileKind(o) == 'hash' ||
          saved['bytes'] is! num ||
          bytes <= 0 ||
          saved['bytes'] == bytes;
    }).toList();
    final described = candidates
        .where((o) =>
            saved['description'] != null &&
            _hash(_description(o)) == saved['description'])
        .toList();
    // A quality/name shared by several files is not an exact selection.
    final picked = exact.length == 1
        ? exact.single
        : files.length == 1
            ? files.single
            : described.length == 1
                ? described.single
                : null;
    if (picked == null) return fallback(ArchiveResumeReason.unmatched);
    final url = await (_probe?.call(picked.stream.url) ??
        probeArchiveResumeUrl(picked.stream.url,
            headers: picked.stream.requestHeaders));
    if (!isCurrent) return fallback(ArchiveResumeReason.notResuming);
    if (url == null) {
      return ArchiveResumeChoice(
          options.where((o) => !identical(o, picked)).toList(),
          reason: ArchiveResumeReason.unavailable);
    }
    return ArchiveResumeChoice(options,
        picked: picked,
        url: url,
        reason: exact.length == 1
            ? ArchiveResumeReason.exactUrl
            : files.length == 1
                ? ArchiveResumeReason.fileIdentity
                : ArchiveResumeReason.description);
  }

  /// Enough to distinguish resume/fallback from a display error in Send log;
  /// never log URLs, filenames, provider names, viewer IDs or access tokens.
  void traceChoice(ArchiveResumeChoice result, ArchiveStreamOption selected,
      {required String resolvedUrl, required String via}) {
    debugPrint('ArchiveResume: title=${_hash(channelId).substring(0, 12)} '
        'state=${result.reason.name} via=$via choices=${result.options.length} '
        'file=${(_fileIdentity(selected) ?? _hash(selected.stream.url)).substring(0, 12)} '
        'play=${_hash(resolvedUrl).substring(0, 12)} '
        'sizeBytes=${archiveStreamBytes(selected)} '
        'hintBytes=${selected.stream.sizeBytes ?? 0} '
        'labelBytes=${archiveStreamLabelBytes(selected)}');
  }
}

/// Resolve fresh redirects and confirm the saved selection is reachable.
/// A range request avoids downloading the movie or buffering its body.
Future<String?> probeArchiveResumeUrl(String url,
    {Duration timeout = const Duration(seconds: 8),
    Map<String, String> headers = const {}}) async {
  var uri = Uri.tryParse(url);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  var requestHeaders = streamRequestHeaders(headers);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    for (var hop = 0; hop < 8; hop++) {
      final request = await client.getUrl(uri!).timeout(timeout);
      request.followRedirects = false;
      requestHeaders.forEach((k, v) => request.headers.set(k, v));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final response = await request.close().timeout(timeout);
      final location = response.headers.value(HttpHeaders.locationHeader);
      unawaited(response.listen(null).cancel());
      if (response.isRedirect && location != null) {
        final next = uri.resolve(location);
        if (!['http', 'https'].contains(next.scheme)) return null;
        requestHeaders = redirectedStreamHeaders(requestHeaders, uri, next);
        uri = next;
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
