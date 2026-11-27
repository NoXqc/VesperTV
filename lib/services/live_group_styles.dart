import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../l10n/l10n.dart';
import 'live_style_scene.dart';

/// Live styles for TV groups (owner, 2026-11-26: "a bank of live group[s]
/// that users could download ... a Christmas theme one with snowflakes
/// that starts to move on focus ... shooting stars Vesper style ... a few
/// sports ones"). Hold OK on a group > Colour… > Live styles…: a style is
/// saved where a group colour is (`vesper_group_colors_*`) as
/// `style:<id>`, so it follows renames, sync and backups like a colour; an
/// older app reads an unknown id as no colour.
///
/// A style is data, not code: a fade behind the row plus particle layers
/// (shape + motion) that `LiveStylePainter` draws. The bank is one JSON file
/// on the site ([bankUrl], `docs/styles/group-styles.json` in the repo), so
/// a new style needs no app update as long as it uses shapes and motions
/// this version knows (`engine`); a layer with an unknown shape or motion
/// is skipped, a style needing a newer engine is left out.
class LiveGroupStyle {
  const LiveGroupStyle({
    required this.id,
    required this.names,
    required this.category,
    required this.fade,
    required this.layers,
    this.pulse = 0,
    this.scene,
  });

  final String id;

  /// Language code -> name ('en' always there).
  final Map<String, String> names;

  /// seasonal / vesper / sports / fun (anything else shows under More);
  /// [LiveGroupStyles.mineCategory] for the viewer's own (`MyLiveStyles`).
  final String category;

  bool get isMine => category == LiveGroupStyles.mineCategory;

  /// The fade behind the row, left to right, evenly spaced (alpha
  /// included: the bank ends them transparent so the count stays readable).
  final List<Color> fade;

  /// Cycles a second the fade breathes (0 = steady).
  final double pulse;
  final List<LiveStyleLayer> layers;

  /// Sprites on a timeline (engine 2, [LiveStyleScene]); null = particles
  /// only.
  final LiveStyleScene? scene;

  String get name => names[L10n.code] ?? names['en'] ?? id;

  /// One colour for the style (Select more groups' dot, the menu).
  Color get swatch =>
      fade.isEmpty ? const Color(0xFFFFFFFF) : fade.first.withValues(alpha: 1);

  String get colorId => '${LiveGroupStyles.prefix}$id';

  static LiveGroupStyle? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || !RegExp(r'^[a-z0-9][a-z0-9-]{0,44}$').hasMatch(id)) {
      return null;
    }
    final engine = json['engine'];
    if (engine is num && engine > LiveGroupStyles.engine) return null;
    final names = <String, String>{};
    final rawNames = json['name'];
    if (rawNames is String) names['en'] = rawNames;
    if (rawNames is Map) {
      rawNames.forEach((k, v) {
        if (k is String && v is String && v.trim().isNotEmpty) {
          names[k] = v.trim();
        }
      });
    }
    if (names['en'] == null) return null;
    final fade = [
      for (final c in (json['fade'] as List?) ?? const [])
        if (liveStyleColor(c) case final color?) color,
    ];
    final layers = [
      for (final l in (json['layers'] as List?) ?? const [])
        if (LiveStyleLayer.fromJson(l) case final layer?) layer,
    ];
    final scene = LiveStyleScene.fromJson(json['scene']);
    if (fade.isEmpty && layers.isEmpty && scene == null) return null;
    return LiveGroupStyle(
      id: id,
      names: names,
      category: (json['category'] as String?) ?? '',
      fade: fade,
      pulse: _num(json['pulse'], 0, 0, 4),
      layers: layers,
      scene: scene,
    );
  }
}

/// One set of particles: a [shape] moving the [motion] way.
class LiveStyleLayer {
  const LiveStyleLayer({
    required this.shape,
    required this.motion,
    this.count = 10,
    this.minSize = 4,
    this.maxSize = 8,
    this.speed = 10,
    this.colors = const [Color(0xFFFFFFFF)],
    this.minOpacity = 0.6,
    this.maxOpacity = 1,
    this.spin = 0,
    this.sway = 0,
    this.tilt = 0,
    this.gap = 1,
    this.glow = false,
    this.fadeOut = false,
    this.xBand = const (0, 1),
    this.yBand = const (0, 1),
    this.chars = '',
  });

  /// Drawn shapes this version knows; `glyph:<name>` = a [liveStyleGlyphs]
  /// icon.
  static const shapes = {
    'dot', 'snowflake', 'star4', 'star5', 'heart', 'spark', 'bubble', //
    'confetti', 'balloon', 'puck', 'dash', 'vline', 'hline', 'char', 'band',
  };
  static const motions = {
    'fall', 'rise', 'drift', 'drift-left', 'twinkle', 'chase', 'streak', //
    'bounce', 'roll', 'slide', 'arc', 'burst', 'still', 'wave',
  };

  final String shape;
  final String motion;
  final int count;
  final double minSize, maxSize;

  /// Pixels a second (fall, rise, drift, streak, slide, roll, bounce, arc),
  /// or cycles a second (twinkle, chase, burst, wave).
  final double speed;
  final List<Color> colors;
  final double minOpacity, maxOpacity;

  /// Turns a second (0 = no spin).
  final double spin;

  /// Side-to-side swing in pixels (fall / rise / drift), or a wave's height.
  final double sway;

  /// Pixels sideways per pixel down (slanted rain).
  final double tilt;

  /// Seconds between passes (streak, slide, arc, burst).
  final double gap;
  final bool glow;

  /// Fades away along its way (embers).
  final bool fadeOut;

  /// The part of the row (fractions) the layer keeps to.
  final (double, double) xBand, yBand;

  /// For the char shape: the characters it picks from.
  final String chars;

  static LiveStyleLayer? fromJson(Object? json) {
    if (json is! Map) return null;
    final shape = json['shape'];
    final motion = json['motion'];
    if (shape is! String || motion is! String) return null;
    final known = shapes.contains(shape) ||
        (shape.startsWith('glyph:') &&
            liveStyleGlyphs.containsKey(shape.substring(6)));
    if (!known || !motions.contains(motion)) return null;
    final size = _pair(json['size'], 4, 8, 0.5, 60);
    final opacity = _pair(json['opacity'], 0.6, 1, 0, 1);
    final colors = [
      for (final c in switch (json['color']) {
        final List l => l,
        final Object o => [o],
        null => const [],
      })
        if (liveStyleColor(c) case final color?) color,
    ];
    return LiveStyleLayer(
      shape: shape,
      motion: motion,
      count: _num(json['count'], 10, 1, 40).round(),
      minSize: size.$1,
      maxSize: size.$2,
      speed: _num(json['speed'], 10, 0, 600),
      colors: colors.isEmpty ? const [Color(0xFFFFFFFF)] : colors,
      minOpacity: opacity.$1,
      maxOpacity: opacity.$2,
      spin: _num(json['spin'], 0, -4, 4),
      sway: _num(json['sway'], 0, 0, 60),
      tilt: _num(json['tilt'], 0, -3, 3),
      gap: _num(json['gap'], 1, 0, 30),
      glow: json['glow'] == true,
      fadeOut: json['fadeOut'] == true,
      xBand: _pair(json['x'], 0, 1, 0, 1),
      yBand: _pair(json['y'], 0, 1, 0, 1),
      chars: (json['chars'] as String?) ?? '01',
    );
  }
}

double _num(Object? v, double fallback, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;

/// `[a, b]` or one number (both ends).
(double, double) _pair(Object? v, double a, double b, double min, double max) {
  if (v is num) {
    final n = _num(v, a, min, max);
    return (n, n);
  }
  if (v is List && v.length == 2) {
    final x = _num(v[0], a, min, max);
    final y = _num(v[1], b, min, max);
    return x <= y ? (x, y) : (y, x);
  }
  return (a, b);
}

/// `#RRGGBB` or `#AARRGGBB` (Android order, like the badge packs).
Color? liveStyleColor(Object? v) {
  if (v is! String) return null;
  final hex = v.startsWith('#') ? v.substring(1) : v;
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return null;
  return switch (hex.length) {
    6 => Color(0xFF000000 | n),
    8 => Color(n),
    _ => null,
  };
}

/// The icons a style can draw (`glyph:<name>`). Kept here as constants so
/// the build keeps them in the icon font.
const liveStyleGlyphs = <String, IconData>{
  'sports_soccer': Icons.sports_soccer,
  'sports_hockey': Icons.sports_hockey,
  'sports_football': Icons.sports_football,
  'sports_basketball': Icons.sports_basketball,
  'sports_baseball': Icons.sports_baseball,
  'sports_tennis': Icons.sports_tennis,
  'sports_golf': Icons.sports_golf,
  'sports_motorsports': Icons.sports_motorsports,
  'sports_rugby': Icons.sports_rugby,
  'sports_volleyball': Icons.sports_volleyball,
  'sports_cricket': Icons.sports_cricket,
  'sports_mma': Icons.sports_mma,
  'emoji_events': Icons.emoji_events,
  'music_note': Icons.music_note,
  'movie': Icons.movie,
  'eco': Icons.eco,
  'local_florist': Icons.local_florist,
  'ac_unit': Icons.ac_unit,
  'favorite': Icons.favorite,
  'bolt': Icons.bolt,
  'pets': Icons.pets,
  'cake': Icons.cake,
  'rocket_launch': Icons.rocket_launch,
  'park': Icons.park,
  'nightlight': Icons.nightlight,
  'local_fire_department': Icons.local_fire_department,
  'celebration': Icons.celebration,
  'sports_esports': Icons.sports_esports,
};

/// The bank: downloaded from [bankUrl], kept in a file, refreshed after a
/// day. Read the first time a row or the picker needs it, never at
/// startup.
class LiveGroupStyles {
  LiveGroupStyles._();
  static final instance = LiveGroupStyles._();

  static const prefix = 'style:';

  /// The category of the viewer's own styles (`MyLiveStyles`), shown first
  /// as "Your styles".
  static const mineCategory = 'mine';

  /// Shapes / motions version this app draws (a style may ask for more).
  /// 2 = sprite scenes ([LiveStyleScene], 2026-11-27).
  static const engine = 2;

  /// A test build can point at a PC (`--dart-define=VESPER_STYLES_URL=...`).
  static const bankUrl = String.fromEnvironment('VESPER_STYLES_URL',
      defaultValue: 'https://vespertv.app/styles/group-styles.json');

  static const _fileName = 'live_group_styles.json';
  static const _refreshAfter = Duration(hours: 24);
  static const _maxBytes = 1024 * 1024;

  @visibleForTesting
  static http.Client? debugClient;

  /// Tests: where the bank file goes (null = app support).
  @visibleForTesting
  static String? debugFolder;

  static bool isStyleId(String? colorId) =>
      colorId != null && colorId.startsWith(prefix);

  /// The viewer's own styles, then the bank's in bank order; empty until
  /// read.
  final styles = ValueNotifier<List<LiveGroupStyle>>(const []);
  Map<String, LiveGroupStyle> _byId = const {};
  List<LiveGroupStyle> _bank = const [];
  List<LiveGroupStyle> _mine = const [];

  Future<void>? _reading;
  Future<List<LiveGroupStyle>>? _downloading;
  bool _read = false;
  bool _downloaded = false;
  DateTime? _savedAt;

  /// The style a saved colour id names; null for a colour, an unknown style
  /// or a bank not read yet ([ensureLoaded] reads it).
  LiveGroupStyle? styleOf(String? colorId) =>
      isStyleId(colorId) ? _byId[colorId!.substring(prefix.length)] : null;

  /// Reads the saved bank once; downloads it when it's a day old, or once a
  /// run when [wanted] (a saved id, synced from another device, say) isn't
  /// in it.
  void ensureLoaded({String? wanted}) {
    if (!_read) {
      _reading ??= _readSaved().whenComplete(() {
        _reading = null;
        _read = true;
        _refreshIfDue(wanted);
      });
      return;
    }
    _refreshIfDue(wanted);
  }

  void _refreshIfDue(String? wanted) {
    if (_downloaded || _downloading != null) return;
    final missing = wanted != null && styleOf(wanted) == null;
    final old = _savedAt == null ||
        DateTime.now().difference(_savedAt!) > _refreshAfter;
    if (missing || old) unawaited(download().catchError((_) => styles.value));
  }

  /// The picker: the viewer's own styles + the bank fresh from the site
  /// (once a run), else the saved one; throws when there is none of them.
  Future<List<LiveGroupStyle>> load() async {
    if (!_read) {
      _reading ??= _readSaved().whenComplete(() {
        _reading = null;
        _read = true;
      });
      await _reading;
    }
    if (_downloaded && _bank.isNotEmpty) return styles.value;
    try {
      await download();
      return styles.value;
    } catch (e) {
      if (styles.value.isNotEmpty) return styles.value;
      rethrow;
    }
  }

  /// The viewer's own styles (`MyLiveStyles`), shown before the bank's.
  void useMine(List<LiveGroupStyle> mine) {
    _mine = List.unmodifiable(mine);
    _publish();
  }

  /// Downloads and saves the bank (one at a time).
  Future<List<LiveGroupStyle>> download() =>
      _downloading ??= _download().whenComplete(() => _downloading = null);

  Future<List<LiveGroupStyle>> _download() async {
    final client = debugClient ?? http.Client();
    try {
      final response = await client.get(Uri.parse(bankUrl), headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw 'HTTP ${response.statusCode}';
      if (response.bodyBytes.length > _maxBytes) throw 'too big';
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final parsed = parse(body);
      if (parsed.isEmpty) throw 'no styles';
      _downloaded = true;
      _use(parsed);
      _savedAt = DateTime.now();
      try {
        final file = await _file();
        if (file != null) await file.writeAsString(body, flush: true);
      } catch (e) {
        debugPrint('LiveStyles: save failed: $e');
      }
      debugPrint('LiveStyles: ${parsed.length} styles downloaded');
      return parsed;
    } catch (e) {
      debugPrint('LiveStyles: download failed: $e');
      rethrow;
    } finally {
      if (debugClient == null) client.close();
    }
  }

  Future<void> _readSaved() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return;
      _savedAt = await file.lastModified();
      final parsed = parse(await file.readAsString());
      if (parsed.isNotEmpty) _use(parsed);
    } catch (e) {
      debugPrint('LiveStyles: saved bank unreadable: $e');
    }
  }

  void _use(List<LiveGroupStyle> list) {
    _bank = list;
    _publish();
  }

  void _publish() {
    final all = [..._mine, ..._bank];
    _byId = {for (final s in all) s.id: s};
    styles.value = List.unmodifiable(all);
  }

  /// The bank file's styles (bad entries left out).
  static List<LiveGroupStyle> parse(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return const [];
    }
    final list = entriesOf(json);
    final seen = <String>{};
    return [
      for (final s in list)
        if (LiveGroupStyle.fromJson(s) case final style?)
          if (seen.add(style.id)) style,
    ];
  }

  /// The style entries of a decoded file: a pack (`{"styles": [...]}`), a
  /// list of styles, or one style.
  static List<Object?> entriesOf(Object? json) => switch (json) {
        {'styles': final List l} => l,
        final List l => l,
        {'id': _} => [json],
        _ => const [],
      };

  static Future<File?> _file() async {
    if (kIsWeb) return null;
    final folder = debugFolder ?? (await getApplicationSupportDirectory()).path;
    return File('$folder/$_fileName');
  }

  @visibleForTesting
  void debugReset() {
    _byId = const {};
    _bank = const [];
    _mine = const [];
    styles.value = const [];
    _read = false;
    _downloaded = false;
    _savedAt = null;
    _reading = null;
    _downloading = null;
  }

  /// Tests: use [list] as the bank without a file or a download.
  @visibleForTesting
  void debugUse(List<LiveGroupStyle> list) {
    _read = true;
    _downloaded = true;
    _savedAt = DateTime.now();
    _use(list);
  }
}
