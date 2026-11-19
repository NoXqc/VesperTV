import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/hub_collection.dart';
import 'storage_service.dart';

/// Media Hub stream badges (Settings > Playback > Stream badges): a badge
/// pack made for Nuvio / Fusion (their "Badge URLs" / "Fusion badge URLs"),
/// published by editors like Xperience or Badger. A pack is one JSON file:
/// `groups` (Resolution, Audio, Language…) and `filters`, each a Java-style
/// regex run on the stream's text plus a picture (`imageURL`, a data: URI or
/// a link) or a coloured text tag. Every enabled filter that matches puts its
/// badge on the source row, in group order.
///
/// Matching runs in a background isolate that is killed after
/// [_matchTimeout]: the patterns are third-party, and one that backtracks
/// forever must not freeze a weak box. Results are cached per stream text.
class StreamBadgeGroup {
  const StreamBadgeGroup({required this.id, required this.name});
  final String id;
  final String name;
}

class StreamBadge {
  StreamBadge({
    required this.id,
    required this.name,
    required this.groupId,
    required this.pattern,
    this.imageUrl,
    this.tagColor,
    this.textColor,
    this.borderColor,
  });

  final String id;
  final String name;
  final String groupId;

  /// As written in the pack (Java syntax); see [streamBadgeRegExp].
  final String pattern;

  /// http(s) link or data: URI; null = a text tag showing [name].
  final String? imageUrl;

  /// ARGB, null = transparent (packs write `#AARRGGBB` or `#RRGGBB`).
  final int? tagColor;
  final int? textColor;
  final int? borderColor;

  Uint8List? _bytes;
  bool _decoded = false;

  /// The picture of a data: URI [imageUrl], decoded once (one instance, so
  /// the image cache keys stay equal across rows).
  Uint8List? get imageBytes {
    if (_decoded) return _bytes;
    _decoded = true;
    final url = imageUrl;
    if (url == null || !url.startsWith('data:')) return null;
    final comma = url.indexOf(',');
    if (comma < 0 || !url.substring(0, comma).contains(';base64')) return null;
    try {
      _bytes = base64.decode(url.substring(comma + 1).trim());
    } on FormatException {
      _bytes = null;
    }
    return _bytes;
  }

  /// [imageUrl] when it is a web link.
  String? get networkImage {
    final url = imageUrl;
    return url != null &&
            (url.startsWith('https://') || url.startsWith('http://'))
        ? url
        : null;
  }
}

/// A pack group about the picture's quality, the kinds VesperTV's own gold
/// tags show: resolution, release (WEB-DL, Remux, BluRay), HDR / Dolby
/// Vision, codec. Not audio, channels, languages, services, cached... The
/// player's OK popup shows only these (owner, 2026-11-18: "just the
/// quality badges like the original tag").
bool streamBadgeQualityGroup(String name) => RegExp(
        r'resolution|release|source|visual|hdr|dynamic|video|encod|codec|quality',
        caseSensitive: false)
    .hasMatch(name);

class StreamBadgePack {
  StreamBadgePack({
    required this.groups,
    required this.badges,
    required this.skipped,
  });

  final List<StreamBadgeGroup> groups;

  /// Enabled badges whose pattern Dart can run, in display order (group
  /// order, then the pack's order inside a group).
  final List<StreamBadge> badges;

  /// Enabled filters left out (empty pattern, or one Dart's regex can't run).
  final int skipped;

  /// Reads a pack; throws [FormatException] when [body] isn't one.
  static StreamBadgePack parse(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const FormatException('not JSON');
    }
    final Map<String, dynamic> root;
    if (json is Map<String, dynamic>) {
      root = json;
    } else if (json is List) {
      root = {'filters': json};
    } else {
      throw const FormatException('no filters');
    }
    final rawFilters = root['filters'] ?? root['badges'];
    if (rawFilters is! List) throw const FormatException('no filters');
    final groups = <StreamBadgeGroup>[
      for (final g in (root['groups'] is List ? root['groups'] as List : []))
        if (g is Map && g['id'] != null)
          StreamBadgeGroup(
            id: '${g['id']}',
            name: '${g['name'] ?? g['id']}'.trim(),
          ),
    ];
    final order = {for (var i = 0; i < groups.length; i++) groups[i].id: i};
    final badges = <(int, int, StreamBadge)>[];
    var skipped = 0;
    for (var i = 0; i < rawFilters.length; i++) {
      final f = rawFilters[i];
      if (f is! Map) continue;
      if (f['isEnabled'] == false || f['enabled'] == false) continue;
      final pattern = '${f['pattern'] ?? ''}'.trim();
      if (pattern.isEmpty || streamBadgeRegExp(pattern) == null) {
        skipped++;
        continue;
      }
      final image =
          '${f['imageURL'] ?? f['imageUrl'] ?? f['image'] ?? ''}'.trim();
      final groupId = '${f['groupId'] ?? ''}';
      badges.add((
        order[groupId] ?? groups.length,
        i,
        StreamBadge(
          id: '${f['id'] ?? i}',
          name: '${f['name'] ?? ''}'.trim(),
          groupId: groupId,
          pattern: pattern,
          imageUrl: image.isEmpty ? null : image,
          tagColor: parseBadgeColor(f['tagColor']),
          textColor: parseBadgeColor(f['textColor']),
          borderColor: parseBadgeColor(f['borderColor']),
        ),
      ));
    }
    if (badges.isEmpty) throw const FormatException('no usable filters');
    badges.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return StreamBadgePack(
      groups: groups,
      badges: [for (final b in badges) b.$3],
      skipped: skipped,
    );
  }
}

/// `#AARRGGBB` (Android order, as Nuvio and Badger write it), `#RRGGBB` or
/// `#RGB` as ARGB; null when missing, unreadable or fully transparent.
int? parseBadgeColor(Object? value) {
  if (value is! String) return null;
  var hex = value.trim();
  if (!hex.startsWith('#')) return null;
  hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final argb = int.tryParse(hex, radix: 16);
  if (argb == null || argb >> 24 == 0) return null;
  return argb;
}

final _leadingFlags = RegExp(r'^\(\?([a-zA-Z]+)\)');

/// A pack pattern (Java regex) as a Dart [RegExp], or null when it can't run.
/// Dart has no inline flags: a leading `(?i)` becomes case-insensitive
/// matching (as Badger and Nuvio's own previews read it), and a later `(?i)`
/// or `(?i:` makes the whole pattern case-insensitive.
RegExp? streamBadgeRegExp(String pattern) {
  var p = pattern.trim();
  var ignoreCase = false, dotAll = false, multiLine = false;
  final lead = _leadingFlags.firstMatch(p);
  if (lead != null) {
    final flags = lead.group(1)!.toLowerCase();
    if (flags.contains('x')) return null; // comments mode: no Dart equivalent
    ignoreCase = flags.contains('i');
    dotAll = flags.contains('s');
    multiLine = flags.contains('m');
    p = p.substring(lead.end);
  }
  if (p.contains('(?i)') || p.contains('(?i:')) {
    ignoreCase = true;
    p = p.replaceAll('(?i)', '').replaceAll('(?i:', '(?:');
  }
  if (p.isEmpty) return null;
  RegExp? build(bool unicode) {
    try {
      return RegExp(
        p,
        caseSensitive: !ignoreCase,
        dotAll: dotAll,
        multiLine: multiLine,
        unicode: unicode,
      );
    } on FormatException {
      return null;
    }
  }

  // \p{L} is a class only in unicode mode (literally "p{L}" otherwise).
  final classes = p.contains(r'\p{') || p.contains(r'\P{');
  return (classes ? build(true) : null) ?? build(false);
}

/// The text a pack's patterns read: the stream's name, title and file name on
/// one line (the patterns' `.` doesn't cross a line break). Hidden marker
/// characters some add-on formatters add for badge packs are kept.
String streamBadgeText({String? name, String? title, String? fileName}) {
  final parts = [
    name,
    title,
    if (fileName != null && !(title ?? '').contains(fileName)) fileName,
  ].whereType<String>().where((s) => s.trim().isNotEmpty);
  return parts.join(' ').replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
}

/// Runs in the matching isolate: for each text, the indexes of the patterns
/// that match it.
List<List<int>> matchStreamBadges(List<String> patterns, List<String> texts) {
  final regs = [for (final p in patterns) streamBadgeRegExp(p)];
  return [
    for (final text in texts)
      [
        for (var i = 0; i < regs.length; i++)
          if (regs[i]?.hasMatch(text) ?? false) i,
      ],
  ];
}

void _matchEntry(List<Object> args) {
  final port = args[0] as SendPort;
  port.send(
    matchStreamBadges(
      (args[1] as List).cast<String>(),
      (args[2] as List).cast<String>(),
    ),
  );
}

class StreamBadges {
  StreamBadges._();
  static final instance = StreamBadges._();

  static const _fileName = 'stream_badges.json';
  static const _matchTimeout = Duration(seconds: 8);
  static const _refreshAfter = Duration(hours: 24);
  static const _maxBytes = 12 * 1024 * 1024;

  /// The pack in use; null while off, loading or unreadable.
  final pack = ValueNotifier<StreamBadgePack?>(null);

  /// Bumps when match results arrive (rows waiting for theirs rebuild).
  final matched = ValueNotifier<int>(0);

  StorageService? _storage;
  Future<void>? _loading;
  bool _failed = false;

  /// A pattern ran past [_matchTimeout]: this pack is off until it changes.
  bool _stalled = false;
  int _generation = 0;
  final Map<String, List<StreamBadge>> _results = {};
  final Set<String> _pending = {};
  bool _running = false;
  Timer? _batch;

  void attach(StorageService storage) => _storage ??= storage;

  String get url => _storage?.getStreamBadgesUrl() ?? '';

  /// The viewer's switch (Media Hub sources > Stream badges): off keeps
  /// the pack, sources show VesperTV's own tags meanwhile.
  bool get on => _storage?.getStreamBadgesOn() ?? true;

  /// A pack is saved, switched on and usable (rows show it once loaded).
  bool get enabled => url.isNotEmpty && on && !_failed && !_stalled;

  Future<void> setOn(bool value) async {
    await _storage?.setStreamBadgesOn(value);
    // Rows go to the built-in tags or load the pack (ensureLoaded).
    matched.value++;
  }

  /// Starts loading the saved pack the first time a row needs it (never at
  /// startup: the splash stays as it was). [switchedOff]: Settings shows a
  /// switched-off pack's badges too.
  void ensureLoaded({bool switchedOff = false}) {
    if (pack.value != null || _loading != null) return;
    if (!(enabled || (switchedOff && url.isNotEmpty && !_failed))) return;
    _loading = _loadSaved().whenComplete(() => _loading = null);
  }

  Future<void> _loadSaved() async {
    final address = url;
    String? body;
    if (!kIsWeb) {
      try {
        final file = await _file();
        if (await file.exists()) body = await file.readAsString();
      } catch (e) {
        debugPrint('StreamBadges: cache read failed: $e');
      }
    }
    if (body == null) {
      try {
        body = await _download(address);
        await _store(address, body);
      } catch (e) {
        debugPrint('StreamBadges: download failed: $e');
        _loadFailed();
        return;
      }
    }
    final parsed = await _parse(body);
    if (address != url) return; // changed meanwhile
    if (parsed == null) {
      debugPrint('StreamBadges: saved pack unreadable');
      _loadFailed();
      return;
    }
    _setPack(parsed);
    debugPrint(
      'StreamBadges: ${parsed.badges.length} badges '
      '(${parsed.skipped} skipped)',
    );
    final fetched = _storage?.getStreamBadgesFetched() ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - fetched;
    // Packs are edited after publishing (Xperience saves as you go).
    if (age > _refreshAfter.inMilliseconds) unawaited(_refresh(address));
  }

  /// Rows waiting for the pack go back to the built-in tags (until Settings
  /// saves a pack again).
  void _loadFailed() {
    _failed = true;
    matched.value++;
  }

  Future<void> _refresh(String address) async {
    try {
      final body = await _download(address);
      final parsed = await _parse(body);
      if (parsed == null || address != url) return;
      await _store(address, body);
      _setPack(parsed);
    } catch (e) {
      debugPrint('StreamBadges: refresh failed: $e');
    }
  }

  /// Downloads and reads a pack for Settings; throws [StreamBadgeError].
  /// A GitHub page link is read as its raw file.
  Future<(StreamBadgePack, String)> fetch(String address) async {
    final link = HubCollection.rawLink(address);
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      throw const StreamBadgeError.notAPack();
    }
    final String body;
    try {
      body = await _download(link);
    } catch (e) {
      throw StreamBadgeError.download('$e');
    }
    final parsed = await _parse(body);
    if (parsed == null) throw const StreamBadgeError.notAPack();
    return (parsed, body);
  }

  /// Saves [address] and its downloaded [body] as the pack in use.
  Future<void> use(String address, StreamBadgePack parsed, String body) async {
    await _store(HubCollection.rawLink(address), body);
    await _storage?.setStreamBadgesOn(true);
    _failed = false;
    _setPack(parsed);
  }

  /// A badge pack pasted where Media Hub links go (sources, collections:
  /// Nuvio users paste it next to their add-ons) becomes the pack in use.
  /// Its badge count; null when [address] isn't a pack or won't download.
  Future<int?> useIfPack(String address) async {
    try {
      final (parsed, body) = await fetch(address);
      await use(address, parsed, body);
      return parsed.badges.length;
    } on StreamBadgeError {
      return null;
    }
  }

  /// Forgets the pack (the switch keeps it instead).
  Future<void> remove() async {
    await _storage?.setStreamBadgesUrl('');
    if (!kIsWeb) {
      try {
        final file = await _file();
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _failed = false;
    _setPack(null);
  }

  void _setPack(StreamBadgePack? value) {
    _generation++;
    _stalled = false;
    _results.clear();
    _pending.clear();
    pack.value = value;
    matched.value++;
  }

  /// The badges of a stream [text] (from [streamBadgeText]); null while not
  /// matched yet (it is queued, [matched] fires when done) or when off.
  List<StreamBadge>? badgesFor(String text) {
    final current = pack.value;
    if (current == null || _stalled) return null;
    final hit = _results[text];
    if (hit != null) return hit;
    if (_pending.add(text)) {
      // One isolate run for all the rows built in this frame.
      _batch ??= Timer(const Duration(milliseconds: 16), _run);
    }
    return null;
  }

  Future<void> _run() async {
    _batch = null;
    final current = pack.value;
    if (_running || current == null || _pending.isEmpty) return;
    _running = true;
    final generation = _generation;
    final texts = _pending.toList();
    final patterns = [for (final b in current.badges) b.pattern];
    try {
      final hits = await _match(patterns, texts);
      if (generation != _generation) return;
      if (hits == null) {
        _stalled = true;
        debugPrint(
          'StreamBadges: matching took over '
          '${_matchTimeout.inSeconds} s; pack off until it changes',
        );
        _pending.clear();
        return;
      }
      if (_results.length > 4000) _results.clear();
      for (var i = 0; i < texts.length; i++) {
        _results[texts[i]] = [for (final j in hits[i]) current.badges[j]];
        _pending.remove(texts[i]);
      }
    } finally {
      _running = false;
      if (generation == _generation) matched.value++;
      if (_pending.isNotEmpty) {
        _batch ??= Timer(const Duration(milliseconds: 16), _run);
      }
    }
  }

  /// Null when the isolate had to be killed.
  static Future<List<List<int>>?> _match(
    List<String> patterns,
    List<String> texts,
  ) async {
    if (kIsWeb) return matchStreamBadges(patterns, texts);
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
      _matchEntry,
      [port.sendPort, patterns, texts],
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    try {
      final reply = await port.first.timeout(_matchTimeout);
      if (reply is List<List<int>>) return reply;
      // onError sends [message, stack]; onExit sends null.
      debugPrint('StreamBadges: matching failed: $reply');
      return [for (final _ in texts) <int>[]];
    } on TimeoutException {
      isolate.kill(priority: Isolate.immediate);
      return null;
    } finally {
      port.close();
    }
  }

  static Future<StreamBadgePack?> _parse(String body) async {
    StreamBadgePack? read(String b) {
      try {
        return StreamBadgePack.parse(b);
      } on FormatException {
        return null;
      }
    }

    if (kIsWeb) return read(body);
    // A pack with pictures inside is over a megabyte of JSON.
    return Isolate.run(() => read(body));
  }

  static Future<String> _download(String address) async {
    final response = await http.get(Uri.parse(address), headers: const {
      'Accept': 'application/json'
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw 'HTTP ${response.statusCode}';
    if (response.bodyBytes.length > _maxBytes) throw 'too big';
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  Future<void> _store(String address, String body) async {
    if (!kIsWeb) {
      final file = await _file();
      await file.writeAsString(body, flush: true);
    }
    await _storage?.setStreamBadgesUrl(address);
    await _storage?.setStreamBadgesFetched(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');
}

class StreamBadgeError implements Exception {
  const StreamBadgeError.notAPack() : detail = null;
  const StreamBadgeError.download(String this.detail);

  /// Download failure detail; null = the address isn't a badge pack.
  final String? detail;

  @override
  String toString() => detail ?? 'not a badge pack';
}
