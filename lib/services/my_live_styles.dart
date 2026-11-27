import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'live_group_styles.dart';
import 'storage_service.dart';

/// Why an import brought nothing in ([MyLiveStyles.import]).
enum MyStylesProblem {
  /// Neither a link nor style text.
  notStyles,

  /// Style text, but no style in it this app can draw.
  nothingUsable,

  /// The link didn't answer with a file ([MyStylesError.detail]).
  download,

  /// The file or text is over [MyLiveStyles.maxBytes].
  tooBig,
}

class MyStylesError implements Exception {
  const MyStylesError(this.problem, [this.detail]);
  final MyStylesProblem problem;
  final String? detail;

  @override
  String toString() =>
      'MyStylesError(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// What an import did.
class MyStylesImport {
  const MyStylesImport(
      {required this.ids, required this.replaced, required this.skipped});

  /// The imported styles' ids (with [MyLiveStyles.idPrefix]), in file order.
  final List<String> ids;

  /// How many of [ids] replaced a style of the same id.
  final int replaced;

  /// Entries left out (not a style, nothing to draw, a newer engine).
  final int skipped;
}

/// Live styles the viewer makes (owner, 2026-11-27: "import custom live
/// groups so if users want to build their own they could import it into
/// Vesper"). Same format as the bank (`docs/styles/group-styles.json`, how-to
/// at vespertv.app/styles/make.html): a pack `{"styles": [...]}`, a list, or
/// one style. Brought in as a link (fetched again once a run when the
/// gallery opens, so its maker can update it) or as the text itself (From
/// phone, a computer's paste, an AI app through the `live_styles` tool).
///
/// Saved in [AppConstants.keyMyLiveStyles] for the whole household (synced
/// like the group colours that name them). Ids get [idPrefix] so they never
/// clash with the bank's; an import with an id already here replaces that
/// style. Shown first in the gallery as "Your styles".
class MyLiveStyles {
  MyLiveStyles._();
  static final instance = MyLiveStyles._();

  static const idPrefix = 'my-';

  /// Styles kept at most (the oldest go first).
  static const maxStyles = 60;

  /// A pasted text or a downloaded file, at most.
  static const maxBytes = 200 * 1024;

  @visibleForTesting
  static http.Client? debugClient;

  StorageService? _storage;
  List<_Source> _sources = const [];
  Future<void>? _refreshing;
  bool _refreshed = false;

  /// Reads the saved styles (a small preference; most viewers have none).
  void attach(StorageService storage) {
    _storage = storage;
    _sources = _decode(storage.getMyLiveStyles());
    _refreshed = false;
    _publish();
  }

  /// The viewer's styles, newest import first.
  List<LiveGroupStyle> get styles => [
        for (final source in _sources)
          for (final raw in source.styles)
            if (LiveGroupStyle.fromJson(raw) case final style?) style,
      ];

  /// The link [id] came from; null for a style brought in as text.
  String? linkOf(String id) {
    for (final source in _sources) {
      if (source.styles.any((s) => s['id'] == id)) return source.url;
    }
    return null;
  }

  /// How many styles came from [link].
  int countFrom(String link) => _sources
      .where((s) => s.url == link)
      .fold(0, (n, s) => n + s.styles.length);

  /// [input] is a link (http / https) or style text.
  Future<MyStylesImport> import(String input) async {
    final text = input.trim();
    if (text.isEmpty) throw const MyStylesError(MyStylesProblem.notStyles);
    final uri = Uri.tryParse(text);
    final isLink = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        !text.contains(RegExp(r'\s'));
    if (isLink) {
      final body = await _download(uri);
      final (styles, skipped) = _entries(body);
      return _add(_Source(text, styles), skipped);
    }
    if (utf8.encode(text).length > maxBytes) {
      throw const MyStylesError(MyStylesProblem.tooBig);
    }
    final (styles, skipped) = _entries(text);
    return _add(_Source(null, styles), skipped);
  }

  /// [json] already decoded (an AI app's `live_styles` tool).
  Future<MyStylesImport> importJson(Object? json) {
    final (styles, skipped) = _entriesOfJson(json);
    return _add(_Source(null, styles), skipped);
  }

  /// Removes style [id]; one that came from a link takes the whole link
  /// with it (the link would bring it back).
  Future<void> remove(String id) async {
    final link = linkOf(id);
    final next = link != null
        ? [
            for (final s in _sources)
              if (s.url != link) s
          ]
        : [
            for (final s in _sources)
              _Source(s.url, [
                for (final style in s.styles)
                  if (style['id'] != id) style
              ])
          ];
    await _save(next..removeWhere((s) => s.styles.isEmpty));
  }

  /// The gallery: every link fetched again, once a run (a failed one keeps
  /// its styles).
  Future<void> refreshLinks() {
    if (_refreshed) return Future.value();
    return _refreshing ??= _refreshLinks().whenComplete(() {
      _refreshing = null;
      _refreshed = true;
    });
  }

  Future<void> _refreshLinks() async {
    var next = _sources;
    var changed = false;
    for (final source in _sources) {
      final link = source.url;
      if (link == null) continue;
      try {
        final (styles, _) = _entries(await _download(Uri.parse(link)));
        if (jsonEncode(styles) == jsonEncode(source.styles)) continue;
        next = [
          for (final s in next)
            if (s.url == link) _Source(link, styles) else s
        ];
        changed = true;
      } catch (e) {
        debugPrint('MyLiveStyles: $link not refreshed: $e');
      }
    }
    if (changed) await _save(next);
  }

  Future<MyStylesImport> _add(_Source source, int skipped) async {
    if (source.styles.isEmpty) {
      throw const MyStylesError(MyStylesProblem.nothingUsable);
    }
    final ids = [for (final s in source.styles) s['id'] as String];
    final have = {
      for (final s in _sources)
        for (final style in s.styles) style['id'] as String
    };
    final replaced = ids.where(have.contains).length;
    // The same link again replaces itself; any import replaces its ids.
    final rest = <_Source>[
      for (final s in _sources)
        if (source.url == null || s.url != source.url)
          _Source(s.url, [
            for (final style in s.styles)
              if (!ids.contains(style['id'])) style
          ]),
    ]..removeWhere((s) => s.styles.isEmpty);
    var next = [source, ...rest];
    // The oldest go past maxStyles.
    var count = 0;
    next = [
      for (final s in next)
        if (count < maxStyles)
          _Source(s.url, [
            for (final style in s.styles)
              if (count++ < maxStyles) style
          ]),
    ]..removeWhere((s) => s.styles.isEmpty);
    await _save(next);
    debugPrint('MyLiveStyles: imported ${ids.length} '
        '(${source.url == null ? 'text' : 'link'}), $skipped left out');
    return MyStylesImport(ids: ids, replaced: replaced, skipped: skipped);
  }

  Future<String> _download(Uri uri) async {
    final client = debugClient ?? http.Client();
    try {
      final response = await client.get(uri, headers: const {
        'Accept': 'application/json, text/plain, */*'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw MyStylesError(
            MyStylesProblem.download, 'HTTP ${response.statusCode}');
      }
      if (response.bodyBytes.length > maxBytes) {
        throw const MyStylesError(MyStylesProblem.tooBig);
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } on MyStylesError {
      rethrow;
    } on TimeoutException {
      throw const MyStylesError(MyStylesProblem.download, 'timeout');
    } catch (e) {
      throw MyStylesError(MyStylesProblem.download, e.runtimeType.toString());
    } finally {
      if (debugClient == null) client.close();
    }
  }

  /// The usable styles in [text] (ids made ours, category "mine") and how
  /// many entries were left out.
  static (List<Map<String, Object?>>, int) _entries(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const MyStylesError(MyStylesProblem.notStyles);
    }
    return _entriesOfJson(json);
  }

  static (List<Map<String, Object?>>, int) _entriesOfJson(Object? json) {
    final entries = LiveGroupStyles.entriesOf(json);
    if (entries.isEmpty) throw const MyStylesError(MyStylesProblem.notStyles);
    final out = <Map<String, Object?>>[];
    final seen = <String>{};
    var skipped = 0;
    for (final entry in entries) {
      final style = _ours(entry);
      if (style == null || !seen.add(style['id'] as String)) {
        skipped++;
        continue;
      }
      out.add(style);
    }
    return (out, skipped);
  }

  /// [entry] as one of the viewer's styles: id lower-cased, made of a-z 0-9
  /// and dashes, with [idPrefix]; a name in any language (or the id) as the
  /// English one; category "mine". Null when the app can't draw it.
  @visibleForTesting
  static Map<String, Object?>? ours(Object? entry) => _ours(entry);

  static Map<String, Object?>? _ours(Object? entry) {
    if (entry is! Map) return null;
    final style = <String, Object?>{
      for (final e in entry.entries)
        if (e.key is String) e.key as String: e.value
    };
    var id = (style['id'] is String ? style['id'] as String : '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (id.startsWith(idPrefix)) id = id.substring(idPrefix.length);
    if (id.isEmpty) return null;
    if (id.length > 40) id = id.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
    id = '$idPrefix$id';
    style['id'] = id;
    final name = style['name'];
    if (name is Map) {
      final names = <String, String>{
        for (final e in name.entries)
          if (e.key is String && e.value is String && '${e.value}'.trim() != '')
            e.key as String: (e.value as String).trim()
      };
      if (names.isNotEmpty) names.putIfAbsent('en', () => names.values.first);
      style['name'] = names.isEmpty ? id.substring(idPrefix.length) : names;
    } else if (name is! String || name.trim().isEmpty) {
      style['name'] = id.substring(idPrefix.length);
    }
    style['category'] = LiveGroupStyles.mineCategory;
    // A scene needs engine 2: an older app leaves the style out instead of
    // drawing it without its sprites.
    final engine = style['engine'];
    if (style['scene'] != null && (engine is! num || engine < 2)) {
      style['engine'] = 2;
    }
    return LiveGroupStyle.fromJson(style) == null ? null : style;
  }

  Future<void> _save(List<_Source> next) async {
    _sources = next;
    _publish();
    await _storage?.setMyLiveStyles(next.isEmpty
        ? ''
        : jsonEncode([
            for (final s in next) {'url': s.url, 'styles': s.styles}
          ]));
  }

  void _publish() => LiveGroupStyles.instance.useMine(styles);

  static List<_Source> _decode(String saved) {
    if (saved.isEmpty) return const [];
    try {
      final json = jsonDecode(saved);
      if (json is! List) return const [];
      return [
        for (final s in json)
          if (s is Map && s['styles'] is List)
            _Source(
              s['url'] is String ? s['url'] as String : null,
              [
                for (final style in s['styles'] as List)
                  if (style is Map)
                    {
                      for (final e in style.entries)
                        if (e.key is String) e.key as String: e.value
                    }
              ],
            ),
      ]..removeWhere((s) => s.styles.isEmpty);
    } catch (e) {
      debugPrint('MyLiveStyles: saved styles unreadable: $e');
      return const [];
    }
  }

  @visibleForTesting
  void debugReset() {
    _storage = null;
    _sources = const [];
    _refreshed = false;
    _refreshing = null;
    LiveGroupStyles.instance.useMine(const []);
  }
}

/// One import: a link, or text (null [url]).
class _Source {
  const _Source(this.url, this.styles);
  final String? url;
  final List<Map<String, Object?>> styles;
}
