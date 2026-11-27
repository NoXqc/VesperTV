import 'dart:math' as math;

import 'live_group_styles.dart' show liveStyleColor;

/// A live style's scene (engine 2, owner 2026-11-27: "scope the sprite-scene
/// engine", then "loop on focus, rest when out of focus, editor page now and
/// AI connector updated"): small pixel-art sprites, drawn in the style file
/// itself, moving across the group row on a timeline that loops while the
/// row moves and shows its [rest] moment while it is still.
///
/// Data only, like the particle layers: every placement comes from the
/// scene time alone ([at]), so a still row is one frame and a moving one
/// keeps no state. Drawn by `LiveStylePainter` (live_style_view.dart).
/// Format, limits and the editor: dev-notes/live-group-styles.md "Scenes",
/// vespertv.app/styles/make.html, vespertv.app/styles/editor.html.
class LiveStyleScene {
  const LiveStyleScene({
    required this.length,
    required this.rest,
    required this.grid,
    required this.sprites,
    required this.actors,
  });

  /// Seconds per loop.
  final double length;

  /// The moment shown while the row is still (seconds into the loop).
  final double rest;

  /// How many sprite pixels fit the row's height (22 = a 44 px row draws
  /// each sprite pixel 2 px square).
  final int grid;

  final Map<String, LiveSceneSprite> sprites;

  /// Drawn in list order (later ones in front).
  final List<LiveSceneActor> actors;

  // Limits: a scene stays small (a row is about 260 x 44 px).
  static const maxSprites = 12;
  static const maxSets = 6;
  static const maxFrames = 8;
  static const maxSide = 32;
  static const maxColors = 24;
  static const maxActors = 16;
  static const maxKeys = 48;
  static const maxLength = 60.0;

  /// Every sprite and actor drawn at [t] seconds into the loop, back to
  /// front. Hidden actors (outside their `show` windows) are left out.
  List<LiveScenePlacement> at(double t) {
    final time = length <= 0 ? 0.0 : t - (t / length).floorToDouble() * length;
    return [
      for (final actor in actors)
        if (actor.placementAt(time, sprites[actor.sprite]) case final p?) p,
    ];
  }

  /// Parses [json]; null when nothing drawable is left. [notes] gets a line
  /// for every part left out or cut to a limit (the AI tool reports them).
  static LiveStyleScene? fromJson(Object? json, {List<String>? notes}) {
    void note(String s) => notes?.add(s);
    if (json is! Map) {
      if (json != null) note('scene is not an object');
      return null;
    }
    final length = _num(json['length'], 8, 0.5, maxLength);
    final grid = _num(json['grid'], 22, 8, 64).round();
    final sprites = <String, LiveSceneSprite>{};
    final rawSprites = json['sprites'];
    if (rawSprites is Map) {
      for (final e in rawSprites.entries) {
        if (sprites.length >= maxSprites) {
          note('more than $maxSprites sprites: "${e.key}" and after left out');
          break;
        }
        final name = '${e.key}';
        final sprite = LiveSceneSprite.fromJson(e.value, name, note);
        if (sprite == null) {
          note('sprite "$name" has no frame to draw: left out');
        } else {
          sprites[name] = sprite;
        }
      }
    } else {
      note('scene has no "sprites" object');
    }
    final actors = <LiveSceneActor>[];
    for (final raw in (json['actors'] as List?) ?? const []) {
      if (actors.length >= maxActors) {
        note('more than $maxActors actors: the rest left out');
        break;
      }
      final actor = LiveSceneActor.fromJson(raw, sprites, length, note);
      if (actor != null) actors.add(actor);
    }
    if (actors.isEmpty) {
      note('scene has no actor to draw');
      return null;
    }
    return LiveStyleScene(
      length: length,
      rest: _num(json['rest'], length / 2, 0, length),
      grid: grid,
      sprites: sprites,
      actors: actors,
    );
  }

  /// What [fromJson] would leave out or cut of [json] (empty = all of it is
  /// drawn), for the AI tool's answer.
  static List<String> check(Object? json) {
    final notes = <String>[];
    fromJson(json, notes: notes);
    return notes;
  }
}

/// One sprite: frame sets (walk, jump, idle...) of equally sized pixel
/// frames. A pixel is an ARGB colour; 0 = clear.
class LiveSceneSprite {
  LiveSceneSprite({
    required this.width,
    required this.height,
    required this.sets,
    required this.fps,
  });

  final int width, height;

  /// Set name -> frames -> [width] x [height] pixels, row by row.
  final Map<String, List<List<int>>> sets;

  /// Frames a second within a set (0 = always the first frame).
  final double fps;

  String get firstSet => sets.keys.first;

  static LiveSceneSprite? fromJson(
      Object? json, String name, void Function(String) note) {
    if (json is! Map) return null;
    final palette = <String, int>{};
    final rawPalette = json['palette'];
    if (rawPalette is Map) {
      for (final e in rawPalette.entries) {
        final key = '${e.key}';
        if (key.length != 1) {
          note('sprite "$name": palette key "$key" is not one character');
          continue;
        }
        if (palette.length >= LiveStyleScene.maxColors) {
          note('sprite "$name": more than ${LiveStyleScene.maxColors} '
              'colours, "$key" left out');
          continue;
        }
        final color =
            e.value == null || e.value == '' ? null : liveStyleColor(e.value);
        if (color == null && e.value != null && e.value != '') {
          note('sprite "$name": colour "${e.value}" for "$key" not '
              'understood (use #RRGGBB or #AARRGGBB)');
        }
        palette[key] = color?.toARGB32() ?? 0;
      }
    }
    // frames: a list of frames (one set, "default") or {set: [frames]}.
    final rawFrames = json['frames'];
    final rawSets = <String, List>{
      if (rawFrames is List) 'default': rawFrames,
      if (rawFrames is Map)
        for (final e in rawFrames.entries)
          if (e.value is List) '${e.key}': e.value as List,
    };
    final grids = <String, List<List<String>>>{};
    var width = 0, height = 0;
    for (final e in rawSets.entries) {
      if (grids.length >= LiveStyleScene.maxSets) {
        note('sprite "$name": more than ${LiveStyleScene.maxSets} frame '
            'sets, "${e.key}" left out');
        break;
      }
      final frames = <List<String>>[];
      for (final f in e.value) {
        if (frames.length >= LiveStyleScene.maxFrames) {
          note('sprite "$name" set "${e.key}": more than '
              '${LiveStyleScene.maxFrames} frames, the rest left out');
          break;
        }
        final rows = switch (f) {
          final String s => s.split('\n'),
          final List l => [for (final r in l) '$r'],
          _ => const <String>[],
        };
        if (rows.isEmpty) continue;
        final cut = rows.length > LiveStyleScene.maxSide ||
            rows.any((r) => r.length > LiveStyleScene.maxSide);
        if (cut) {
          note('sprite "$name": a frame is over '
              '${LiveStyleScene.maxSide} x ${LiveStyleScene.maxSide}, cut');
        }
        final kept = [
          for (final r in rows.take(LiveStyleScene.maxSide))
            r.length > LiveStyleScene.maxSide
                ? r.substring(0, LiveStyleScene.maxSide)
                : r
        ];
        height = math.max(height, kept.length);
        for (final r in kept) {
          width = math.max(width, r.length);
        }
        frames.add(kept);
      }
      if (frames.isNotEmpty) grids[e.key] = frames;
    }
    if (grids.isEmpty || width == 0 || height == 0) return null;
    final unknown = <String>{};
    final sets = <String, List<List<int>>>{
      for (final e in grids.entries)
        e.key: [
          for (final rows in e.value)
            [
              for (var y = 0; y < height; y++)
                for (var x = 0; x < width; x++)
                  () {
                    final row = y < rows.length ? rows[y] : '';
                    if (x >= row.length) return 0;
                    final ch = row[x];
                    if (ch == '.' || ch == ' ') return 0;
                    final c = palette[ch];
                    if (c == null) unknown.add(ch);
                    return c ?? 0;
                  }(),
            ]
        ],
    };
    if (unknown.isNotEmpty) {
      note('sprite "$name": ${unknown.map((c) => '"$c"').join(', ')} not in '
          'its palette, drawn clear');
    }
    return LiveSceneSprite(
      width: width,
      height: height,
      sets: sets,
      fps: _num(json['fps'], 6, 0, 24),
    );
  }
}

/// A point of an actor's path. Everything but [t], [x] and [y] holds from
/// this point to the next one.
class LiveSceneKey {
  const LiveSceneKey({
    required this.t,
    required this.x,
    required this.y,
    this.play,
    this.arc = 0,
    this.ease = 'linear',
    this.flip,
  });

  final double t;

  /// Across the row: 0 left, 1 right (the sprite's middle).
  final double x;

  /// Down the row: 0 top, 1 bottom (the sprite's feet).
  final double y;

  /// The frame set from here on.
  final String? play;

  /// A hop to the next point, its height in rows (0.3 = a third of the row).
  final double arc;

  /// linear, in, out or inout, to the next point.
  final String ease;

  /// Faces left from here on (true) or right (false).
  final bool? flip;
}

class LiveSceneActor {
  const LiveSceneActor({
    required this.sprite,
    required this.keys,
    required this.show,
    this.play,
  });

  final String sprite;

  /// Sorted by time; one point = it stays there.
  final List<LiveSceneKey> keys;

  /// When it shows (seconds into the loop); empty = always.
  final List<(double, double)> show;

  /// The frame set before any point names one.
  final String? play;

  static LiveSceneActor? fromJson(
      Object? json,
      Map<String, LiveSceneSprite> sprites,
      double length,
      void Function(String) note) {
    if (json is! Map) return null;
    final sprite = '${json['sprite'] ?? ''}';
    if (!sprites.containsKey(sprite)) {
      note('actor using sprite "$sprite": no such sprite, left out');
      return null;
    }
    final keys = <LiveSceneKey>[];
    final at = json['at'];
    if (at is List && at.length == 2) {
      keys.add(LiveSceneKey(
          t: 0,
          x: _num(at[0], 0.5, -1, 2),
          y: _num(at[1], 1, -1, 2),
          flip: json['flip'] == true ? true : null));
    }
    for (final raw in (json['path'] as List?) ?? const []) {
      if (keys.length >= LiveStyleScene.maxKeys) {
        note('actor "$sprite": more than ${LiveStyleScene.maxKeys} path '
            'points, the rest left out');
        break;
      }
      if (raw is! Map) continue;
      final ease = '${raw['ease'] ?? 'linear'}';
      keys.add(LiveSceneKey(
        t: _num(raw['t'], 0, 0, length),
        x: _num(raw['x'], 0.5, -1, 2),
        y: _num(raw['y'], 1, -1, 2),
        play: raw['play'] is String ? raw['play'] as String : null,
        arc: _num(raw['arc'], 0, -2, 2),
        ease: const {'linear', 'in', 'out', 'inout'}.contains(ease)
            ? ease
            : 'linear',
        flip: raw['flip'] is bool ? raw['flip'] as bool : null,
      ));
    }
    if (keys.isEmpty) {
      note('actor "$sprite": no "at" and no "path", left out');
      return null;
    }
    keys.sort((a, b) => a.t.compareTo(b.t));
    final s = sprites[sprite]!;
    for (final k in keys) {
      if (k.play != null && !s.sets.containsKey(k.play)) {
        note('actor "$sprite": frame set "${k.play}" not in the sprite');
      }
    }
    final show = <(double, double)>[];
    final rawShow = json['show'];
    final windows = rawShow is List && rawShow.isNotEmpty && rawShow[0] is num
        ? [rawShow]
        : (rawShow is List ? rawShow : const []);
    for (final w in windows) {
      if (w is List && w.length == 2 && w[0] is num && w[1] is num) {
        show.add(((w[0] as num).toDouble(), (w[1] as num).toDouble()));
      }
    }
    return LiveSceneActor(
      sprite: sprite,
      keys: keys,
      show: show,
      play: json['play'] is String ? json['play'] as String : null,
    );
  }

  bool shownAt(double t) {
    if (show.isEmpty) return true;
    for (final (a, b) in show) {
      if (a <= b ? (t >= a && t < b) : (t >= a || t < b)) return true;
    }
    return false;
  }

  LiveScenePlacement? placementAt(double t, LiveSceneSprite? s) {
    if (s == null || !shownAt(t)) return null;
    String? play = this.play;
    var flip = false;
    for (final k in keys) {
      if (k.t > t) break;
      if (k.play != null) play = k.play;
      if (k.flip != null) flip = k.flip!;
    }
    double x, y;
    if (t <= keys.first.t || keys.length == 1) {
      x = keys.first.x;
      y = keys.first.y;
    } else if (t >= keys.last.t) {
      x = keys.last.x;
      y = keys.last.y;
    } else {
      var i = 0;
      while (keys[i + 1].t <= t) {
        i++;
      }
      final a = keys[i], b = keys[i + 1];
      final span = b.t - a.t;
      final raw = span <= 0 ? 1.0 : (t - a.t) / span;
      final p = switch (a.ease) {
        'in' => raw * raw,
        'out' => 1 - (1 - raw) * (1 - raw),
        'inout' => raw * raw * (3 - 2 * raw),
        _ => raw,
      };
      x = a.x + (b.x - a.x) * p;
      // The hop follows the plain time, so it peaks halfway in time.
      y = a.y + (b.y - a.y) * p - a.arc * 4 * raw * (1 - raw);
    }
    final set = play != null && s.sets.containsKey(play) ? play : s.firstSet;
    final frames = s.sets[set]!;
    final frame = s.fps <= 0 || frames.length == 1
        ? 0
        : (t * s.fps).floor() % frames.length;
    return LiveScenePlacement(
        sprite: s, set: set, frame: frame, x: x, y: y, flip: flip);
  }
}

/// Where one sprite frame goes: [x] its middle, [y] its feet, as fractions
/// of the row.
class LiveScenePlacement {
  const LiveScenePlacement({
    required this.sprite,
    required this.set,
    required this.frame,
    required this.x,
    required this.y,
    required this.flip,
  });

  final LiveSceneSprite sprite;
  final String set;
  final int frame;
  final double x, y;
  final bool flip;
}

double _num(Object? v, double fallback, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;
