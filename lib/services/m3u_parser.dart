import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

  /// The tab an entry belongs on ('tv', 'vod' or 'series'). An Xtream
  /// provider's `get.php` list links its movies as `/movie/<user>/<pass>/
  /// <id>.<ext>` and episodes as `/series/…`, whatever their group is
  /// called: LOG-ELUGMN's 1.28M-entry list had 1.08M movies and episodes in
  /// groups without "movie"/"series" in the title, all in Live TV (the
  /// provider has 27k live channels). Any other link goes by its group.
  static String entryCategory(String url, String group) =>
      xtreamOnDemandTab(url) ?? groupCategory(group);

  static String? xtreamOnDemandTab(String url) {
    for (final (marker, tab) in const [
      ('/movie/', 'vod'),
      ('/series/', 'series'),
    ]) {
      final at = url.indexOf(marker);
      if (at < 0) continue;
      final rest = url.substring(at + marker.length).split('/');
      if (rest.length == 3 &&
          rest[0].isNotEmpty &&
          rest[1].isNotEmpty &&
          _xtreamFile.hasMatch(rest[2])) {
        return tab;
      }
    }
    return null;
  }

  static final RegExp _xtreamFile = RegExp(r'^\d+\.[A-Za-z0-9]+$');

  /// Also upgrades caches written before M3U playback type was stored.
  static Channel withCatalogType(Channel channel) => channel.copyWith(
      onDemand: entryCategory(channel.url, channel.group) != 'tv');

  /// An `#EXTINF` line's title: after the first comma outside the quoted
  /// attributes. The last comma cut titles that have one ("Saturday Night
  /// Live - S12E09 - Walter Payton, Joe Montana/Debbie Harry" read as "Joe
  /// Montana/Debbie Harry": 90% of a provider's episodes lost their show,
  /// 2026-11-06). Unbalanced quotes fall back to the last comma.
  static String? titleOf(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line.codeUnitAt(i);
      if (c == 0x22) {
        quoted = !quoted;
      } else if (c == 0x2C && !quoted) {
        return line.substring(i + 1).trim();
      }
    }
    final last = line.lastIndexOf(',');
    return last == -1 ? null : line.substring(last + 1).trim();
  }

  /// A line's `key="value"` attributes, keys lower-cased: what the regex
  /// `([a-zA-Z0-9_-]+)="([^"]*)"` finds, scanned by hand. The regex was two
  /// thirds of the parse (4.0 of 6.4 s for 1.28M entries on a desktop,
  /// a minute or more on a TV box at every launch, LOG-ELUGMN).
  static Map<String, String> attributesOf(String line) {
    final out = <String, String>{};
    var from = 0;
    while (true) {
      final eq = line.indexOf('="', from);
      if (eq < 0) break;
      var start = eq;
      while (start > from && _isKeyChar(line.codeUnitAt(start - 1))) {
        start--;
      }
      if (start == eq) {
        from = eq + 1;
        continue;
      }
      final end = line.indexOf('"', eq + 2);
      if (end < 0) break;
      out[line.substring(start, eq).toLowerCase()] =
          line.substring(eq + 2, end);
      from = end + 1;
    }
    return out;
  }

  static bool _isKeyChar(int c) =>
      (c >= 0x61 && c <= 0x7A) || // a-z
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x30 && c <= 0x39) || // 0-9
      c == 0x5F || // _
      c == 0x2D; // -

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

  /// [fetchAndParse] on a background isolate. The list comes back through
  /// `Isolate.exit`, so it is handed over, not copied, and the download
  /// buffers and line parsing never touch the UI isolate's memory. A huge
  /// IPTV Editor M3U (user report, 2026-11-04: "not enough memory") used to
  /// do all of it on the main isolate.
  ///
  /// The whole-list passes run there too ([Channel.withUniqueIds], the
  /// [favorites] / [epgOverrides] stamps, [M3uList]'s split): on the UI
  /// isolate they froze a 1.28M-entry list's box for ~11 s after the
  /// download, and again at each launch's cache restore (LOG-ELUGMN).
  ///
  /// [onProgress] gets the bytes received so far, about once a second.
  static Future<M3uList> fetchAndParseInBackground(String url,
      {required String playlistId,
      String? saveTo,
      Set<String> favorites = const {},
      Map<String, String> epgOverrides = const {},
      void Function(int bytes)? onProgress}) async {
    final progress = ReceivePort();
    progress.listen((bytes) => onProgress?.call(bytes as int));
    try {
      return await _runInIsolate(
          url, playlistId, saveTo, progress.sendPort, favorites, epgOverrides);
    } catch (e) {
      throw friendlyError(e);
    } finally {
      progress.close();
    }
  }

  /// A background load's failure in the user's words. Translated on the
  /// UI isolate: the background one has no language loaded.
  static Object friendlyError(Object e) => switch (e) {
        M3uHttpError() => Exception(tr(
            'Failed to load playlist from {host} (HTTP {code})',
            {'host': e.host, 'code': e.code})),
        M3uStalledError() => Exception(tr(
            'The server stopped sending the playlist after {mb} MB. Try again later.',
            {'mb': e.bytes >> 20})),
        M3uNoAnswerError() => Exception(tr(
            'The server did not answer within {s} seconds.',
            {'s': firstByteLimit.inSeconds})),
        // Its text ends with the full link, password included.
        http.ClientException() when e.message.contains('before full header') =>
          Exception(tr('The server closed the connection without answering.')),
        http.ClientException() => Exception(e.message),
        _ => e,
      };

  /// Its own function so the isolate's closure only captures what it is
  /// given (a closure made in [fetchAndParseInBackground] would carry that
  /// scope's [onProgress], which can't be sent to another isolate).
  static Future<M3uList> _runInIsolate(
          String url,
          String playlistId,
          String? saveTo,
          SendPort progress,
          Set<String> favorites,
          Map<String, String> epgOverrides) =>
      Isolate.run(() async {
        final channels = Channel.withUniqueIds(await fetchAndParse(url,
            playlistId: playlistId, saveTo: saveTo, onBytes: progress.send));
        for (final c in channels) {
          c.isFavorite = favorites.contains(c.id);
          c.epgIdOverride = epgOverrides[c.rawId];
        }
        return M3uList(channels);
      });

  /// How long the server may take to start answering: a provider builds a
  /// big `get.php` list before it sends the first byte.
  static const firstByteLimit = Duration(seconds: 60);

  /// How long the download may go without any data. There is no limit on
  /// the whole download: a 5-minute one cut a ~350k-entry list that was
  /// still arriving (LOG-HKVWLU, 2026-11-06).
  static const stallLimit = Duration(seconds: 60);

  /// Streams the response line-by-line rather than buffering the whole body
  /// into one String — Xtream `get.php` playlists with tens of thousands of
  /// entries can be well over 100MB of text, and materializing that as a
  /// single contiguous allocation is what triggers an OutOfMemoryError on
  /// phones with a capped per-app heap (Android's default ~256MB ceiling).
  ///
  /// [saveTo]: also writes the raw bytes there as they arrive (the M3U
  /// cache, re-parsed on the next start), via `<saveTo>.part` so a failed
  /// load leaves the previous cache in place.
  ///
  /// [onBytes] gets the bytes received so far, at most once a second.
  /// [stall] is [stallLimit] except in tests.
  ///
  /// [onEntry]: gets each entry as it is read, instead of a returned list
  /// ([M3uImport] stores a 1.28M-entry list without holding it); a future
  /// it returns pauses the read until it completes.
  static Future<List<Channel>> fetchAndParse(String url,
      {required String playlistId,
      String? saveTo,
      void Function(int bytes)? onBytes,
      Duration stall = stallLimit,
      Future<void>? Function(Channel entry)? onEntry}) async {
    final part = saveTo == null ? null : File('$saveTo.part');
    final sink = part?.openWrite();
    Future<List<Channel>> parse(Stream<List<int>> bytes) async {
      final state = _ParseState(playlistId: playlistId, keep: onEntry == null);
      var received = 0;
      final sinceReport = Stopwatch()..start();
      final lines = bytes
          .timeout(stall, onTimeout: (events) {
            events.addError(M3uStalledError(received));
            events.close();
          })
          .map((chunk) {
            sink?.add(chunk);
            received += chunk.length;
            if (onBytes != null && sinceReport.elapsedMilliseconds >= 1000) {
              sinceReport.reset();
              onBytes(received);
            }
            return chunk;
          })
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());
      await for (final line in lines) {
        final entry = state.consumeLine(line);
        if (entry == null || onEntry == null) continue;
        final pending = onEntry(entry);
        if (pending != null) await pending;
      }
      if (sink != null) {
        await sink.close();
        await part!.rename(saveTo!);
      }
      return state.channels;
    }

    final client = http.Client();
    try {
      if (Uri.tryParse(url)?.scheme == 'file') {
        return await parse(File.fromUri(Uri.parse(url)).openRead());
      }
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client
          .send(request)
          .timeout(firstByteLimit, onTimeout: () => throw M3uNoAnswerError());

      if (streamedResponse.statusCode != 200) {
        throw M3uHttpError(Uri.parse(url).host, streamedResponse.statusCode);
      }
      return await parse(streamedResponse.stream);
    } catch (_) {
      if (sink != null) {
        await sink.close().catchError((_) {});
        if (await part!.exists()) await part.delete();
      }
      rethrow;
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

/// A playlist server's non-200 answer, thrown by [M3uParser.fetchAndParse]
/// and turned into the translated message on the UI isolate.
class M3uHttpError implements Exception {
  const M3uHttpError(this.host, this.code);
  final String host;
  final int code;

  @override
  String toString() => 'Failed to load playlist from $host (HTTP $code)';
}

/// An M3U list split the way the app reads it: by group (in first-seen
/// order), by tab ([M3uParser.entryCategory], per entry) and each tab's
/// groups. One pass, so it can be built on the background isolate with the
/// parse.
class M3uList {
  M3uList(this.channels) {
    final byTitle = <String, String>{};
    for (final c in channels) {
      byGroup.putIfAbsent(c.group, () => []).add(c);
      final tab = M3uParser.xtreamOnDemandTab(c.url) ??
          (byTitle[c.group] ??= M3uParser.groupCategory(c.group));
      byTab[tab]!.add(c);
      groupsOf[tab]!.putIfAbsent(c.group, () => []).add(c);
    }
  }

  final List<Channel> channels;

  /// Every entry by group title, whatever its tab.
  final Map<String, List<Channel>> byGroup = {};
  final Map<String, List<Channel>> byTab = {'tv': [], 'vod': [], 'series': []};

  /// Each tab's groups. One title can be on two tabs: an Xtream live and
  /// movie category of the same name ("EN | KIDS") each keep their own
  /// entries.
  final Map<String, Map<String, List<Channel>>> groupsOf = {
    'tv': {},
    'vod': {},
    'series': {},
  };
}

/// No data for [M3uParser.stallLimit] in the middle of a download.
class M3uStalledError implements Exception {
  const M3uStalledError(this.bytes);
  final int bytes;

  @override
  String toString() => 'Playlist download stalled after $bytes bytes';
}

/// No answer within [M3uParser.firstByteLimit].
class M3uNoAnswerError implements Exception {
  @override
  String toString() => 'No answer from the playlist server';
}

/// Holds the mutable state needed to parse M3U one line at a time, so the
/// same logic can drive either a fully-buffered string ([M3uParser.parse])
/// or a live stream ([M3uParser.fetchAndParse]).
class _ParseState {
  _ParseState({required this.playlistId, this.keep = true});

  final String playlistId;

  /// Whether [channels] collects the entries ([consumeLine] returns each
  /// one either way).
  final bool keep;
  final List<Channel> channels = [];
  Map<String, String> _attrs = {};
  Map<String, String> _headerAttrs = const {};
  String? _pendingName;
  String? _pendingSubtitleUrl;
  int _autoId = 0;

  /// One String per distinct group title: every entry's title is its own
  /// substring of its line otherwise, repeated across tens of thousands of
  /// entries in a big playlist.
  final Map<String, String> _groupTitles = {};

  /// The entry this line completes, if any.
  Channel? consumeLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;

    if (line.startsWith('#EXTM3U')) {
      // Header-level attributes (catch-up defaults for every entry).
      _headerAttrs = M3uParser.attributesOf(line);
    } else if (line.startsWith('#EXTINF')) {
      _attrs = M3uParser.attributesOf(line);
      _pendingName = M3uParser.titleOf(line) ?? 'Unnamed Channel';
      _pendingSubtitleUrl = null;
    } else if (line.startsWith('#EXTVLCOPT:sub-file=')) {
      _pendingSubtitleUrl = line.split('=').skip(1).join('=').trim();
    } else if (line.startsWith('#EXTGRP:')) {
      _attrs['group-title'] = line.substring('#EXTGRP:'.length).trim();
    } else if (line.startsWith('#')) {
      // Unsupported directive (#EXTM3U, #EXT-X-*, ...) — ignore.
      return null;
    } else {
      // A bare, non-comment line is the stream URL that finishes the
      // pending #EXTINF entry.
      Channel? entry;
      if (_pendingName != null) {
        _autoId++;
        final tvgId = _attrs['tvg-id'];
        final rawId =
            (tvgId != null && tvgId.isNotEmpty) ? tvgId : 'ch_$_autoId';
        final groupTitle = _attrs['group-title'];
        final onDemand =
            M3uParser.entryCategory(line, groupTitle ?? '') != 'tv';
        final catchup = M3uParser.catchupOf(_attrs, _headerAttrs,
            url: line, onDemand: onDemand);
        entry = Channel(
            id: '$playlistId::$rawId',
            rawId: rawId,
            playlistId: playlistId,
            onDemand: onDemand,
            name: _pendingName!,
            group: (groupTitle != null && groupTitle.isNotEmpty)
                ? _groupTitles.putIfAbsent(groupTitle, () => groupTitle)
                : 'Uncategorized',
            url: line,
            logoUrl: _attrs['tvg-logo'],
            subtitleUrl: _pendingSubtitleUrl,
            catchupDays: catchup.days,
            catchupKind: catchup.kind,
            catchupSource: catchup.source);
        if (keep) channels.add(entry);
      }
      _pendingName = null;
      _attrs = {};
      _pendingSubtitleUrl = null;
      return entry;
    }
    return null;
  }
}
