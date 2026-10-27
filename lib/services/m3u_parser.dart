import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/catchup.dart';
import '../models/channel.dart';
import '../l10n/l10n.dart';

/// Parses M3U / M3U8 playlists into [Channel] objects.
///
/// Supports the common extended attributes (`tvg-id`, `tvg-logo`,
/// `group-title`), the `#EXTGRP:` fallback tag, and an optional external
/// subtitle track via `#EXTVLCOPT:sub-file=`.
class M3uParser {
  /// The same group classification used by the Movies/TV Shows catalogs.
  /// Series takes precedence over movie/VOD in combined group names.
  static String groupCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('series') || lower.contains('show')) return 'series';
    if (lower.contains('vod') || lower.contains('movie')) return 'vod';
    return 'tv';
  }

  /// Also upgrades caches written before M3U playback type was stored.
  static Channel withCatalogType(Channel channel) =>
      channel.copyWith(onDemand: groupCategory(channel.group) != 'tv');

  static final RegExp _attrPattern = RegExp(r'([a-zA-Z0-9_-]+)="([^"]*)"');

  static final RegExp _xcUrlPattern =
      RegExp(r'^https?://[^/]+/(live/)?[^/]+/[^/]+/\d+(\.(ts|m3u8))?$');

  /// Catch-up of one entry from its `#EXTINF` attributes, falling back to
  /// the `#EXTM3U` header's (Kodi IPTV Simple conventions): `catchup` /
  /// `catchup-type`, `catchup-days` / `tvg-rec` / `timeshift`,
  /// `catchup-source`. A type without days means 7; days without a type
  /// mean `xc` for an Xtream-style URL, `default` with a source, else
  /// `shift`. Days are clamped to 0..30. On-demand entries get none.
  static ({int days, CatchupKind? kind, String? source}) catchupOf(
      Map<String, String> attrs, Map<String, String> header,
      {required String url, required bool onDemand}) {
    const none = (days: 0, kind: null, source: null);
    if (onDemand) return none;
    String? pick(List<String> keys) {
      for (final map in [attrs, header]) {
        for (final k in keys) {
          final v = map[k]?.trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
      return null;
    }

    final type = pick(const ['catchup', 'catchup-type'])?.toLowerCase();
    final source = pick(const ['catchup-source']);
    final rawDays = pick(const ['catchup-days', 'tvg-rec', 'timeshift']);
    var days = rawDays == null ? null : int.tryParse(rawDays);
    if (type == null && (days == null || days <= 0)) return none;
    CatchupKind? kind = switch (type) {
      null => null,
      'default' => CatchupKind.defaultKind,
      'append' => CatchupKind.append,
      'shift' => CatchupKind.shift,
      'flussonic' || 'flussonic-hls' || 'fs' => CatchupKind.flussonic,
      'flussonic-ts' || 'fs-ts' => CatchupKind.flussonicTs,
      'xc' => CatchupKind.xc,
      _ => null,
    };
    if (type != null && kind == null) return none;
    kind ??= _xcUrlPattern.hasMatch(url.trim())
        ? CatchupKind.xc
        : source != null
            ? CatchupKind.defaultKind
            : CatchupKind.shift;
    days ??= 7;
    days = days.clamp(0, 30);
    if (days == 0) return none;
    return (days: days, kind: kind, source: source);
  }

  /// Streams the response line-by-line rather than buffering the whole body
  /// into one String — Xtream `get.php` playlists with tens of thousands of
  /// entries can be well over 100MB of text, and materializing that as a
  /// single contiguous allocation is what triggers an OutOfMemoryError on
  /// phones with a capped per-app heap (Android's default ~256MB ceiling).
  static Future<List<Channel>> fetchAndParse(String url,
      {required String playlistId}) async {
    if (Uri.tryParse(url)?.scheme == 'file') {
      final state = _ParseState(playlistId: playlistId);
      await File.fromUri(Uri.parse(url))
          .openRead()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(state.consumeLine);
      return state.channels;
    }
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse =
          await client.send(request).timeout(const Duration(seconds: 30));

      if (streamedResponse.statusCode != 200) {
        throw Exception(tr(
            'Failed to load playlist from {host} (HTTP {code})', {
          'host': Uri.parse(url).host,
          'code': streamedResponse.statusCode
        }));
      }

      final state = _ParseState(playlistId: playlistId);
      await streamedResponse.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .forEach(state.consumeLine)
          .timeout(const Duration(minutes: 5));

      return state.channels;
    } finally {
      client.close();
    }
  }

  /// Parses an already-in-memory M3U string. Kept for convenience (tests,
  /// small local files) — [fetchAndParse] is what avoids buffering large
  /// remote playlists whole.
  static List<Channel> parse(String content, {required String playlistId}) {
    final state = _ParseState(playlistId: playlistId);
    for (final line in content.split(RegExp(r'\r?\n'))) {
      state.consumeLine(line);
    }
    return state.channels;
  }
}

/// Holds the mutable state needed to parse M3U one line at a time, so the
/// same logic can drive either a fully-buffered string ([M3uParser.parse])
/// or a live stream ([M3uParser.fetchAndParse]).
class _ParseState {
  _ParseState({required this.playlistId});

  final String playlistId;
  final List<Channel> channels = [];
  Map<String, String> _attrs = {};
  Map<String, String> _headerAttrs = const {};
  String? _pendingName;
  String? _pendingSubtitleUrl;
  int _autoId = 0;

  void consumeLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return;

    if (line.startsWith('#EXTM3U')) {
      // Header-level attributes (catch-up defaults for every entry).
      _headerAttrs = {
        for (final match in M3uParser._attrPattern.allMatches(line))
          match.group(1)!.toLowerCase(): match.group(2)!
      };
    } else if (line.startsWith('#EXTINF')) {
      _attrs = {};
      for (final match in M3uParser._attrPattern.allMatches(line)) {
        _attrs[match.group(1)!.toLowerCase()] = match.group(2)!;
      }
      final commaIndex = line.lastIndexOf(',');
      _pendingName = commaIndex != -1
          ? line.substring(commaIndex + 1).trim()
          : 'Unnamed Channel';
      _pendingSubtitleUrl = null;
    } else if (line.startsWith('#EXTVLCOPT:sub-file=')) {
      _pendingSubtitleUrl = line.split('=').skip(1).join('=').trim();
    } else if (line.startsWith('#EXTGRP:')) {
      _attrs['group-title'] = line.substring('#EXTGRP:'.length).trim();
    } else if (line.startsWith('#')) {
      // Unsupported directive (#EXTM3U, #EXT-X-*, ...) — ignore.
      return;
    } else {
      // A bare, non-comment line is the stream URL that finishes the
      // pending #EXTINF entry.
      if (_pendingName != null) {
        _autoId++;
        final tvgId = _attrs['tvg-id'];
        final rawId =
            (tvgId != null && tvgId.isNotEmpty) ? tvgId : 'ch_$_autoId';
        final groupTitle = _attrs['group-title'];
        final onDemand = M3uParser.groupCategory(groupTitle ?? '') != 'tv';
        final catchup = M3uParser.catchupOf(_attrs, _headerAttrs,
            url: line, onDemand: onDemand);
        channels.add(
          Channel(
            id: '$playlistId::$rawId',
            rawId: rawId,
            playlistId: playlistId,
            onDemand: onDemand,
            name: _pendingName!,
            group: (groupTitle != null && groupTitle.isNotEmpty)
                ? groupTitle
                : 'Uncategorized',
            url: line,
            logoUrl: _attrs['tvg-logo'],
            subtitleUrl: _pendingSubtitleUrl,
            catchupDays: catchup.days,
            catchupKind: catchup.kind,
            catchupSource: catchup.source,
          ),
        );
      }
      _pendingName = null;
      _attrs = {};
      _pendingSubtitleUrl = null;
    }
  }
}
