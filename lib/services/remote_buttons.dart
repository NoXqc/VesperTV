import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import 'storage_service.dart';

/// What a remote button can do (Settings > Backup & devices > Remote
/// buttons). [label] is an English UI string: tr() it where it shows,
/// except Sports Trak (a brand).
class RemoteAction {
  const RemoteAction(this.id, this.label, this.icon, this.group, {this.help});

  /// Stored; never rename one.
  final String id;
  final String label;
  final IconData icon;
  final RemoteActionGroup group;

  /// Where it works, when not everywhere (English UI string).
  final String? help;

  static const all = <RemoteAction>[
    RemoteAction('play_pause', 'Play / Pause', Icons.play_arrow_outlined,
        RemoteActionGroup.playback),
    RemoteAction('stop', 'Stop playback', Icons.stop_outlined,
        RemoteActionGroup.playback),
    RemoteAction('full_screen', 'Full screen on the playing channel',
        Icons.fullscreen, RemoteActionGroup.playback),
    RemoteAction('last_channel', 'Previous channel', Icons.history,
        RemoteActionGroup.playback),
    RemoteAction('channel_up', 'Channel up', Icons.keyboard_arrow_up,
        RemoteActionGroup.playback,
        help: 'In the full-screen player'),
    RemoteAction('channel_down', 'Channel down', Icons.keyboard_arrow_down,
        RemoteActionGroup.playback,
        help: 'In the full-screen player'),
    RemoteAction(
        'info', 'Channel info', Icons.info_outline, RemoteActionGroup.playback,
        help: 'In the full-screen player'),
    RemoteAction(
        'favourites', 'Favourites', Icons.star_outline, RemoteActionGroup.open),
    RemoteAction('guide', 'Live guide', Icons.view_list_outlined,
        RemoteActionGroup.open),
    RemoteAction(
        'multiview', 'Multiview', Icons.grid_view, RemoteActionGroup.open),
    RemoteAction('sports', AppConstants.sportsTabName,
        Icons.sports_score_outlined, RemoteActionGroup.open),
    RemoteAction('hub', 'Media Hub', Icons.video_library_outlined,
        RemoteActionGroup.open),
    RemoteAction('search', 'Search', Icons.search, RemoteActionGroup.open),
    RemoteAction(
        'vesper', 'Vesper AI', Icons.auto_awesome, RemoteActionGroup.open),
    RemoteAction('home', 'Home', Icons.home_outlined, RemoteActionGroup.open),
    RemoteAction('settings', 'Settings', Icons.settings_outlined,
        RemoteActionGroup.open),
    RemoteAction('audio_next', 'Next audio track', Icons.audiotrack_outlined,
        RemoteActionGroup.player),
    RemoteAction('subtitles', 'Subtitles on / off',
        Icons.closed_caption_outlined, RemoteActionGroup.player),
    RemoteAction(
        'picture', 'Picture mode', Icons.aspect_ratio, RemoteActionGroup.player,
        help: 'In the full-screen player'),
    RemoteAction('record', 'Record this channel',
        Icons.fiber_manual_record_outlined, RemoteActionGroup.player),
  ];

  static RemoteAction? byId(String? id) =>
      id == null ? null : all.where((a) => a.id == id).firstOrNull;
}

enum RemoteActionGroup {
  playback('Playback'),
  open('Open'),
  player('Player options');

  const RemoteActionGroup(this.label);

  /// English UI string.
  final String label;
}

/// One learned button: what a short press and a hold do (null = nothing).
@immutable
class RemoteBinding {
  const RemoteBinding({required this.keyId, this.short, this.hold});

  /// [LogicalKeyboardKey.keyId]; an Android key Flutter has no name for is
  /// 0x11 << 32 | keycode (the Homatics' YouTube / Netflix buttons).
  final int keyId;
  final String? short;
  final String? hold;

  RemoteBinding copyWith(
          {String? short,
          String? hold,
          bool clearShort = false,
          bool clearHold = false}) =>
      RemoteBinding(
          keyId: keyId,
          short: clearShort ? null : (short ?? this.short),
          hold: clearHold ? null : (hold ?? this.hold));

  bool get isEmpty => short == null && hold == null;

  Map<String, Object?> toJson() => {
        if (short != null) 's': short,
        if (hold != null) 'h': hold,
      };

  static RemoteBinding? fromJson(String key, Object? json) {
    final id = int.tryParse(key);
    if (id == null || json is! Map) return null;
    String? action(Object? v) =>
        v is String && RemoteAction.byId(v) != null ? v : null;
    final b = RemoteBinding(
        keyId: id, short: action(json['s']), hold: action(json['h']));
    return b.isEmpty ? null : b;
  }
}

/// The full-screen player's arrows on a live channel with nothing on
/// screen (owner, 2026-11-11: some want the side drawer on Right).
enum PlayerArrow {
  left('Left', 'panel'),
  right('Right', 'last'),
  up('Up', 'channel_up'),
  down('Down', 'channel_down');

  const PlayerArrow(this.label, this.defaultAction);

  /// English UI string.
  final String label;
  final String defaultAction;

  /// The choices, in order: id + English UI label.
  static const actions = <(String, String)>[
    ('panel', 'Side drawer'),
    ('last', 'Last channel'),
    ('channel_up', 'Channel up'),
    ('channel_down', 'Channel down'),
    ('bar', 'Player bar'),
    ('none', 'Nothing'),
  ];
}

/// The full-screen player while it is open ([RemoteButtons.player]): the
/// actions that only make sense there go to its own handlers.
abstract interface class RemotePlayerTarget {
  void lastChannel();
  void zap(int step);
  void showInfo();
  void cycleFit();
  void openMultiview();
  void close();
}

/// Runs an action (the app root's, it knows the navigator and players).
typedef RemoteActionRunner = Future<void> Function(String action);

/// Remote buttons the viewer assigned to VesperTV actions, while the app is
/// open (no accessibility service: nothing outside the app). Learn mode:
/// Settings waits for a button ([learning]); a button that never reaches
/// the app is kept by the device.
///
/// A HardwareKeyboard handler can't stop the focused widget from also
/// getting the key (Flutter hands it to both), so this is a
/// [FocusManager.addEarlyKeyEventHandler]: called before the focus tree,
/// and a handled key never reaches it. A button set here does only what it
/// was set to (the player's own CH+ zap doesn't run on top of it). OK,
/// Back and the arrows are never taken.
///
/// A short press fires on the key going down when the button has no hold
/// action; with one, it fires on release unless a key repeat (the remote
/// held, like [HoldToActivate]) fired the hold action first.
class RemoteButtons {
  RemoteButtons._();

  static final instance = RemoteButtons._();

  StorageService? _storage;
  RemoteActionRunner? runner;

  /// False while the splash or Who's watching shows: keys pass through.
  bool Function() isActive = () => true;

  /// Set by Settings while it waits for "press your remote's button": key
  /// downs that aren't navigation come here first and are taken.
  void Function(KeyDownEvent event)? learning;

  /// Set while a full-screen player is open (the newest one).
  final _players = <RemotePlayerTarget>[];
  RemotePlayerTarget? get player => _players.lastOrNull;
  void registerPlayer(RemotePlayerTarget p) => _players.add(p);
  void unregisterPlayer(RemotePlayerTarget p) => _players.remove(p);

  /// Set by Home while its mini player is shown: gets Play/Pause and Stop
  /// actions first (the remote's own Play/Pause turns the mini player off
  /// there, it doesn't pause it). Returns true when it handled the action.
  bool Function(String action)? home;

  /// Bumped on every save (Settings rebuilds from it).
  final changes = ValueNotifier<int>(0);

  bool _installed = false;

  void attach(StorageService storage) => _storage = storage;

  /// Once, at the app root.
  void install() {
    if (_installed) return;
    _installed = true;
    FocusManager.instance.addEarlyKeyEventHandler((event) =>
        handle(event) ? KeyEventResult.handled : KeyEventResult.ignored);
  }

  // ------------------------------------------------------------- storage

  int _cacheGen = -1;
  Map<int, RemoteBinding> _bindings = const {};
  Map<PlayerArrow, String> _arrows = const {};

  void _load() {
    final storage = _storage;
    if (storage == null) return;
    if (_cacheGen == storage.viewerGeneration) return;
    _cacheGen = storage.viewerGeneration;
    _bindings = decodeBindings(storage.getRemoteButtons());
    _arrows = decodeArrows(storage.getPlayerArrows());
  }

  static Map<int, RemoteBinding> decodeBindings(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final map = jsonDecode(json);
      if (map is! Map) return const {};
      return {
        for (final e in map.entries)
          if (RemoteBinding.fromJson('${e.key}', e.value) case final b?)
            b.keyId: b,
      };
    } catch (_) {
      return const {};
    }
  }

  static Map<PlayerArrow, String> decodeArrows(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final map = jsonDecode(json);
      if (map is! Map) return const {};
      final ids = {for (final a in PlayerArrow.actions) a.$1};
      return {
        for (final arrow in PlayerArrow.values)
          if (map[arrow.name] case final String v when ids.contains(v))
            arrow: v,
      };
    } catch (_) {
      return const {};
    }
  }

  /// The current viewer's buttons, in the order they were learned.
  List<RemoteBinding> get bindings {
    _load();
    return _bindings.values.toList();
  }

  RemoteBinding? bindingFor(int keyId) {
    _load();
    return _bindings[keyId];
  }

  Future<void> saveBinding(RemoteBinding binding) async {
    _load();
    final next = Map<int, RemoteBinding>.of(_bindings);
    if (binding.isEmpty) {
      next.remove(binding.keyId);
    } else {
      next[binding.keyId] = binding;
    }
    await _saveBindings(next);
  }

  Future<void> forget(int keyId) async {
    _load();
    final next = Map<int, RemoteBinding>.of(_bindings)..remove(keyId);
    await _saveBindings(next);
  }

  Future<void> _saveBindings(Map<int, RemoteBinding> next) async {
    _bindings = next;
    await _storage?.setRemoteButtons(next.isEmpty
        ? null
        : jsonEncode({for (final b in next.values) '${b.keyId}': b.toJson()}));
    changes.value++;
  }

  /// What [arrow] does in the full-screen player on a live channel.
  String arrowAction(PlayerArrow arrow) {
    _load();
    return _arrows[arrow] ?? arrow.defaultAction;
  }

  Future<void> setArrow(PlayerArrow arrow, String action) async {
    _load();
    final next = Map<PlayerArrow, String>.of(_arrows);
    if (action == arrow.defaultAction) {
      next.remove(arrow);
    } else {
      next[arrow] = action;
    }
    _arrows = next;
    await _storage?.setPlayerArrows(next.isEmpty
        ? null
        : jsonEncode({for (final e in next.entries) e.key.name: e.value}));
    changes.value++;
  }

  bool get isCustomised {
    _load();
    return _bindings.isNotEmpty || _arrows.isNotEmpty;
  }

  Future<void> reset() async {
    _bindings = const {};
    _arrows = const {};
    await _storage?.setRemoteButtons(null);
    await _storage?.setPlayerArrows(null);
    changes.value++;
  }

  // ---------------------------------------------------------------- keys

  /// Keys that only move around / go back: never learned or taken.
  static bool isNavigation(KeyEvent event) {
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonA ||
        k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.browserBack;
  }

  /// Names for the usual remote keys (English UI strings; [describe]).
  static final _names = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.channelUp: 'CH+',
    LogicalKeyboardKey.channelDown: 'CH-',
    LogicalKeyboardKey.mediaPlayPause: 'Play / Pause',
    LogicalKeyboardKey.mediaPlay: 'Play',
    LogicalKeyboardKey.mediaPause: 'Pause',
    LogicalKeyboardKey.mediaStop: 'Stop',
    LogicalKeyboardKey.mediaRecord: 'Record',
    LogicalKeyboardKey.mediaFastForward: 'Fast forward',
    LogicalKeyboardKey.mediaRewind: 'Rewind',
    LogicalKeyboardKey.mediaTrackNext: 'Next',
    LogicalKeyboardKey.mediaTrackPrevious: 'Previous',
    LogicalKeyboardKey.mediaLast: 'Last',
    LogicalKeyboardKey.guide: 'Guide',
    LogicalKeyboardKey.info: 'Info',
    LogicalKeyboardKey.browserFavorites: 'Bookmark',
    LogicalKeyboardKey.browserSearch: 'Search',
    LogicalKeyboardKey.launchAssistant: 'Assistant',
    LogicalKeyboardKey.colorF0Red: 'Red',
    LogicalKeyboardKey.colorF1Green: 'Green',
    LogicalKeyboardKey.colorF2Yellow: 'Yellow',
    LogicalKeyboardKey.colorF3Blue: 'Blue',
    LogicalKeyboardKey.closedCaptionToggle: 'Subtitles',
    LogicalKeyboardKey.tvInput: 'Input',
    LogicalKeyboardKey.settings: 'Settings',
    LogicalKeyboardKey.dvr: 'DVR',
  };

  /// A button's name in Settings: (English UI string to tr(), or null)
  /// and the text to show when there's none (a key label, "Button 172").
  static (String?, String) describe(int keyId) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key != null) {
      final name = _names[key];
      if (name != null) return (name, name);
      final label = key.keyLabel.trim();
      if (label.isNotEmpty) return (null, label);
    }
    // Android keys Flutter has no name for: 0x11 << 32 | keycode.
    if (keyId >> 32 == 0x11) return (null, '#${keyId & 0xffffffff}');
    return (null, '#0x${keyId.toRadixString(16)}');
  }

  /// True when a learned button takes [event] (the Guide / voice keys'
  /// own handlers leave it alone then).
  bool owns(KeyEvent event) {
    if (!isActive() || isNavigation(event)) return false;
    return bindingFor(event.logicalKey.keyId) != null;
  }

  /// Physical keys held now that this took on the way down: their repeats
  /// and release are taken too. Value = the binding (null = learned /
  /// swallowed), and whether the hold already fired.
  final _held = <PhysicalKeyboardKey, _Held>{};

  /// Visible for tests: true = taken (the focused widget never sees it).
  @visibleForTesting
  bool handle(KeyEvent event) {
    final physical = event.physicalKey;
    if (event is KeyUpEvent) {
      final held = _held.remove(physical);
      if (held == null) return false;
      final b = held.binding;
      if (b != null && !held.fired && b.hold != null && b.short != null) {
        _run(b.short!);
      }
      return true;
    }
    if (event is KeyRepeatEvent) {
      final held = _held[physical];
      if (held == null) return false;
      final b = held.binding;
      if (b != null && !held.fired && b.hold != null) {
        held.fired = true;
        _run(b.hold!);
      }
      return true;
    }
    if (event is! KeyDownEvent || isNavigation(event)) return false;
    final learn = learning;
    if (learn != null) {
      _held[physical] = _Held(null)..fired = true;
      learn(event);
      return true;
    }
    if (!isActive()) return false;
    final b = bindingFor(event.logicalKey.keyId);
    if (b == null || _typing) return false;
    final held = _Held(b);
    _held[physical] = held;
    if (b.hold == null) {
      held.fired = true;
      _run(b.short!);
    }
    return true;
  }

  /// A text field has the cursor: a keyboard's keys stay letters.
  static bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;

  void _run(String action) {
    final run = runner;
    debugPrint('RemoteButtons: $action');
    if (run != null) unawaited(run(action));
  }
}

class _Held {
  _Held(this.binding);
  final RemoteBinding? binding;
  bool fired = false;
}
