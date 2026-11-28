import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../utils/desktop_platform.dart';
import '../models/channel.dart';
import '../services/app_preferences.dart';
import '../services/apple_tv_comeback.dart';
import '../services/epg_service.dart';
import '../services/multiview_sports.dart';
import '../services/playlist_manager.dart';
import '../services/storage_service.dart';
import '../widgets/auto_hide_overlay.dart';
import '../widgets/game_channel_chooser.dart';
import '../l10n/l10n.dart';
import '../services/desktop_stream_setup.dart';
import '../services/desktop_live_recovery.dart';
import '../widgets/glass_menu.dart';
import '../widgets/tv_dialog_option.dart';
import '../widgets/tv_text_field_gate.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/roll_down_menu.dart';
import '../widgets/sports_mode_live_panel.dart';
import 'multiview_screen.dart'
    show
        swapRotation,
        multiviewSlotRects,
        multiviewHeaderButtonStyle,
        showMultiviewTips,
        MultiviewCellTile,
        MultiviewSwapModeBadge,
        MultiviewSwapModePill;

/// Windows-only: a grid of simultaneously-playing live channels —
/// requested directly, citing TiviMate's own multiview (proven to run
/// fine even on a Fire Stick) and that a Windows PC has far more headroom
/// than any box this app otherwise targets. Each cell owns a completely
/// independent `media_kit` `Player`/`VideoController` — safe to run
/// several at once the same way `DesktopMiniPlayer`'s preview box already
/// is (see its own doc comment): `media_kit`'s texture-based rendering
/// supports many simultaneous `Video` widgets, unlike `video_player_hdr`'s
/// platform views, which is exactly why this exists only here and not on
/// mobile/TV. Deliberately standalone, same "doesn't touch
/// PlaybackService" shape as `DesktopPlayerScreen` — see that screen's own
/// doc comment for the fuller reasoning this one shares.
///
/// Only one cell's audio plays at a time (every other `Player` is muted,
/// not paused — all four keep decoding/rendering their video live) —
/// tapping a filled cell makes it the audio-focused one, mirroring
/// TiviMate's own "tap to swap audio" multiview behavior rather than
/// trying to invent a different convention.
///
/// With a TV remote (Apple TV) the screens are the focus stops: the first
/// one has focus on open (a gold-white frame), OK on an empty one opens the
/// channel picker, on a playing one gives it the sound, and on the one with
/// the sound opens Change channel / Reload / Remove (the hover buttons on
/// each screen are for a mouse only).
class DesktopMultiviewScreen extends StatefulWidget {
  const DesktopMultiviewScreen(
      {super.key, this.initialChannel, this.initialChannels = const []});

  /// Plays on the first screen when Multiview opens: the player bar's
  /// Multiview button brings the channel it was playing. Back returns the
  /// channel with the sound ([Navigator.pop] result) so the player can go
  /// on with it.
  final Channel? initialChannel;

  /// Sports Trak's "Play in Multiview": one screen per checked live game
  /// (up to 4, after [initialChannel] if both are given), in order, the
  /// first with the sound ([desktopMultiviewOpening] picks the layout).
  final List<Channel> initialChannels;

  @override
  State<DesktopMultiviewScreen> createState() => _DesktopMultiviewScreenState();
}

class _MultiviewCell {
  Channel? channel;
  Player? player;
  VideoController? controller;

  /// See `DesktopPlayerScreen`'s identical field's doc comment — mpv's
  /// native reconnect config doesn't reliably catch every way a live
  /// stream can end up reporting `completed` on its own, so this forces
  /// a fresh re-open whenever that happens instead.
  StreamSubscription<bool>? completedSubscription;
}

/// Requested directly: a smaller, 2-channel layout alongside the
/// original 4-channel grid — fewer simultaneous decode sessions when you
/// only actually want to watch two things, and each cell gets twice the
/// width to show it. [DesktopMultiviewScreen] always keeps 4 `_cells`
/// allocated regardless of which is active; only [dual]'s own two extra
/// cells get disposed when switching down to it (see [_setLayout]) to
/// actually free their connections rather than just hiding them.
///
/// [main] = 1 + 3: one big screen and three small ones beside it, where
/// Swap mode rotates the playing screens through the big one (Android's,
/// owner 2026-10-29). Remembered with the Android keys
/// (`getMultiviewMain` / `getMultiviewQuad`).
enum DesktopMultiviewLayout { dual, quad, main }

/// How Multiview opens with [channels] channels handed to it (Sports Trak's
/// Play in Multiview, the player bar's Multiview button): equal screens,
/// one per channel, like Android's `MultiviewScreen.initialChannels`.
/// [slots] = the screens on show.
///
/// A remote (Apple TV, Android's model): 1-4 channels = that many equal
/// screens (2 side by side, 3-4 in the 2 x 2 grid); none = one screen, or
/// 1 + 3 when it was chosen last ([remembered]).
///
/// A mouse: 2 channels = the 2-screen layout, 3-4 = the 4-screen grid;
/// none or one keeps the layout chosen last. Never remembered itself.
({DesktopMultiviewLayout layout, int slots}) desktopMultiviewOpening(
    int channels,
    {required bool remote,
    required DesktopMultiviewLayout remembered}) {
  final n = channels.clamp(0, 4);
  if (remote) {
    return n == 0 && remembered == DesktopMultiviewLayout.main
        ? (layout: DesktopMultiviewLayout.main, slots: 4)
        : (layout: DesktopMultiviewLayout.quad, slots: math.max(1, n));
  }
  final layout = n >= 3
      ? DesktopMultiviewLayout.quad
      : n == 2
          ? DesktopMultiviewLayout.dual
          : remembered;
  return (layout: layout, slots: layout == DesktopMultiviewLayout.dual ? 2 : 4);
}

class _DesktopMultiviewScreenState extends State<DesktopMultiviewScreen> {
  static const _cellCount = 4;
  final List<_MultiviewCell> _cells =
      List.generate(_cellCount, (_) => _MultiviewCell());
  int _activeCell = 0;
  DesktopMultiviewLayout _layout = DesktopMultiviewLayout.quad;

  /// 1 + 3 Swap mode: arrows (or a click on a small screen) move the
  /// playing screens through the big one; only the big one has sound. The
  /// players themselves move, so nothing reconnects.
  bool _swapMode = false;

  /// Bumped on every swap: the big screen flashes gold once.
  int _swapCount = 0;

  /// Swap mode's arrows. Not a focus stop itself: a focusable wrapper the
  /// size of the screen left a remote nowhere to go (every screen lies
  /// inside it, so no arrow found a neighbour) and OK on it did nothing:
  /// "clicking on the + does nothing" on Apple TV (Discord, 2026-11-20).
  /// Its key handler sees the keys of whatever has focus inside.
  final _keys = FocusNode(
      debugLabel: 'desktop-multiview',
      canRequestFocus: false,
      skipTraversal: true);

  /// One focus stop per screen, kept by place (a swap moves the players,
  /// not the stops). The first screen has focus when Multiview opens.
  final List<FocusNode> _cellFocus = List.generate(
      _cellCount, (i) => FocusNode(debugLabel: 'desktop-multiview-cell-$i'));
  int? _focusedCell;

  /// A remote, not a mouse: Apple TV. Computers keep the click layout.
  bool get _tv => context.read<AppPreferences?>()?.isTelevision ?? false;

  // ---- A remote (Apple TV): Android's Multiview, its look and its keys
  // (owner, 2026-11-20: both TV apps must look the same). Same model as
  // MultiviewScreen: [_slots] screens on show (Add screen / Remove screen),
  // equal screens or 1 + 3 ([_layout] main), Hold OK enlarges, OK = the
  // screen's menu, the sound follows the focused screen, the header slides
  // down on Up from the top row, the live guide picks channels.
  static const _anim = Duration(milliseconds: 280);
  int _slots = 1;
  int? _enlarged;
  int? _fullscreen;
  List<Rect?> _rects = List.filled(4, null);
  bool _headerShown = true;
  Timer? _headerTimer;
  final _headerScope = FocusScopeNode(debugLabel: 'desktop-multiview-header');
  final _headerFirst = FocusNode(debugLabel: 'desktop-multiview-header-first');
  int? _panelFor;
  Completer<Channel?>? _panelPick;
  final _panelKey = GlobalKey<SportsModeLivePanelState>();
  bool _menuOpen = false;

  bool get _main => _layout == DesktopMultiviewLayout.main;

  @override
  void initState() {
    super.initState();
    _comeback = AppleTvComeback.listen(_onBackOnScreen);
    final storage = context.read<StorageService>();
    _layout = storage.getMultiviewMain()
        ? DesktopMultiviewLayout.main
        : storage.getMultiviewQuad()
            ? DesktopMultiviewLayout.quad
            : DesktopMultiviewLayout.dual;
    final initial = [
      if (widget.initialChannel case final c?) c,
      ...widget.initialChannels,
    ].take(_cellCount).toList();
    // From the player or Sports Trak: equal screens, one per channel
    // (Android's); else the layout chosen last.
    final opening = desktopMultiviewOpening(initial.length,
        remote: _tv, remembered: _layout);
    _layout = opening.layout;
    if (_tv) {
      _slots = opening.slots;
      _headerScope.addListener(_onHeaderFocus);
      _hideHeaderSoon(const Duration(seconds: 4));
    }
    // The connections tip (one per screen) first, Android's popup, until
    // "Don't show this again" (Settings' "Show the Multiview tip" brings it
    // back). A remote: screen 1 has focus under it and again after it; OK
    // is focused in it, Up reaches the check box.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final tv = _tv;
      if (tv) _cellFocus[0].requestFocus();
      await showMultiviewTips(context);
      if (mounted && tv) _cellFocus[0].requestFocus();
    });
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openInitial(initial));
      });
    }
  }

  /// The longest a screen of [DesktopMultiviewScreen.initialChannels] waits
  /// for the one before it to show a picture ([_openInitial]).
  static const _openGap = Duration(seconds: 4);

  /// The channels Multiview opened with, one screen each in order, one at a
  /// time like Android's: the next screen connects once the one before
  /// shows a picture (at most [_openGap]), as a 1-connection account or a
  /// weak device chokes on several streams opening together. A screen the
  /// viewer filled meanwhile, or that is no longer on show, is skipped.
  Future<void> _openInitial(List<Channel> channels) async {
    for (final (i, channel) in channels.indexed) {
      if (!mounted) return;
      if (i > 0 && (_cells[i].channel != null || i >= _screensOnShow)) {
        continue;
      }
      final player = _assign(i, channel);
      if (i < channels.length - 1) await _firstPicture(player);
    }
  }

  /// Screens the layout shows now (cells from 0).
  int get _screensOnShow => _tv
      ? (_main ? _cellCount : _slots)
      : (_layout == DesktopMultiviewLayout.dual ? 2 : _cellCount);

  static Future<void> _firstPicture(Player player) async {
    if ((player.state.width ?? 0) > 0) return;
    try {
      await player.stream.width
          .firstWhere((w) => (w ?? 0) > 0)
          .timeout(_openGap);
    } catch (_) {
      // No picture in time, or the screen closed: the next one connects.
    }
  }

  void _revealHeader({bool focus = false}) {
    _headerTimer?.cancel();
    if (!_headerShown) setState(() => _headerShown = true);
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _headerFirst.requestFocus();
      });
    } else {
      _hideHeaderSoon(const Duration(seconds: 4));
    }
  }

  void _hideHeaderSoon([Duration after = const Duration(milliseconds: 1500)]) {
    _headerTimer?.cancel();
    _headerTimer = Timer(after, () {
      if (mounted && !_headerScope.hasFocus && _headerShown) {
        setState(() => _headerShown = false);
      }
    });
  }

  void _onHeaderFocus() {
    if (_headerScope.hasFocus) {
      _headerTimer?.cancel();
    } else {
      _hideHeaderSoon();
    }
  }

  /// Equal screens <-> 1 + 3 (remembered). Back to equal screens, the
  /// playing screens move to the front (nothing reconnects).
  void _tvToggleMain() {
    final main = !_main;
    setState(() {
      _swapMode = false;
      _enlarged = null;
      if (main) {
        _layout = DesktopMultiviewLayout.main;
        _slots = _cellCount;
      } else {
        _layout = DesktopMultiviewLayout.quad;
        final active = _cells[_activeCell];
        final order = [
          for (final c in _cells)
            if (c.channel != null) c,
          for (final c in _cells)
            if (c.channel == null) c,
        ];
        for (var i = 0; i < _cellCount; i++) {
          _cells[i] = order[i];
        }
        _slots = math.max(1, _cells.where((c) => c.channel != null).length);
        final a = _cells.indexOf(active);
        _activeCell = a < 0 ? 0 : a;
      }
    });
    final storage = context.read<StorageService>();
    unawaited(storage.setMultiviewMain(main));
    unawaited(storage.setMultiviewQuad(false));
  }

  /// Add screen: a new empty screen, focused, with the live guide open.
  /// Backing out of the guide takes the empty screen away again.
  Future<void> _tvAddScreen() async {
    if (_slots >= _cellCount) return;
    final index = _slots;
    setState(() => _slots++);
    _cellFocus[index].requestFocus();
    await _tvOpenPicker(index);
    if (!mounted || _cells[index].channel != null) return;
    if (_slots == index + 1) setState(() => _slots--);
    _cellFocus[math.max(0, index - 1)].requestFocus();
  }

  /// Remove screen: closes it, the later screens move up one place (their
  /// streams keep playing).
  void _tvRemoveScreen(int index) {
    final removed = _cells[index];
    removed.completedSubscription?.cancel();
    DesktopLiveRecovery.disposePlayer(removed.player);
    if (_main) {
      setState(() {
        _cells[index] = _MultiviewCell();
        _swapMode = false;
        if (_fullscreen == index) _fullscreen = null;
      });
      return;
    }
    final wasActive = index == _activeCell;
    setState(() {
      for (var j = index; j < _slots - 1; j++) {
        _cells[j] = _cells[j + 1];
      }
      _cells[_slots - 1] = _MultiviewCell();
      if (_slots > 1) _slots--;
      if (_activeCell > index) _activeCell--;
      if (_activeCell >= _slots) _activeCell = _slots - 1;
      final e = _enlarged;
      _enlarged = e == null || e == index
          ? null
          : e > index
              ? e - 1
              : e;
      if (_fullscreen == index) _fullscreen = null;
      if (_slots < 2) _enlarged = null;
    });
    final focus = math.min(index, _slots - 1);
    _cellFocus[focus].requestFocus();
    if (wasActive) _setActive(focus);
  }

  void _tvToggleEnlarge(int index) {
    if (_slots < 2 || _fullscreen != null || _main) return;
    setState(() => _enlarged = _enlarged == index ? null : index);
  }

  void _tvEnterFullscreen(int index) {
    if (_cells[index].channel == null) return;
    _setActive(index);
    setState(() => _fullscreen = index);
    _hideHeaderSoon(Duration.zero);
  }

  void _tvExitFullscreen() {
    final index = _fullscreen;
    if (index == null) return;
    setState(() => _fullscreen = null);
    _cellFocus[index].requestFocus();
  }

  void _togglePause(int index) {
    final player = _cells[index].player;
    if (player == null) return;
    unawaited(player.state.playing ? player.pause() : player.play());
  }

  /// OK on an empty screen, Change channel, Add screen: the live guide over
  /// the left of the screens (they keep playing), Android's picker.
  Future<void> _tvOpenPicker(int index) async {
    if (_panelFor != null) return;
    final chosen = await _pickFromGuide(index);
    if (chosen == null || !mounted) return;
    _assign(index, chosen);
    // The sound follows the selected screen.
    if (_cellFocus[index].hasFocus) _setActive(index);
  }

  Future<Channel?> _pickFromGuide(int index) {
    _panelPick?.complete(null);
    final done = Completer<Channel?>();
    _panelPick = done;
    // The header goes with it (Add screen / Change channel from it): its
    // focus listener never heard the guide take the focus, and it stayed
    // over the guide's titles (Apple TV tour, +921).
    _headerTimer?.cancel();
    setState(() {
      _panelFor = index;
      _headerShown = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final panel = _panelKey.currentState;
      if (!mounted || panel == null) return;
      panel.focusGroups();
      panel.openGuide();
    });
    return done.future;
  }

  void _closePanel([Channel? picked]) {
    final index = _panelFor;
    final done = _panelPick;
    _panelPick = null;
    setState(() => _panelFor = null);
    if (done != null && !done.isCompleted) done.complete(picked);
    if (index != null) _cellFocus[index].requestFocus();
  }

  /// The live guide's game groups: Sports Trak's live games with a channel.
  Future<List<LivePanelGame>> _panelLiveGames() async {
    final games = await MultiviewSports.liveGames(
      storage: context.read<StorageService>(),
      playlist: context.read<PlaylistManager>(),
      epg: context.read<EpgService>(),
    );
    return [
      for (final g in games)
        (
          id: g.game.id,
          title: g.game.title,
          note: trSports(g.game.statusText),
          channels: [for (final m in g.matches) m.channel],
        ),
    ];
  }

  /// OK on a playing screen: Android's menu in the screen's top right.
  Future<void> _tvCellMenu(int index) async {
    final cell = _cells[index];
    if (cell.channel == null || _menuOpen) return;
    _menuOpen = true;
    try {
      final rect = rollDownAnchorOf(_cellFocus[index].context);
      const width = 280.0;
      final anchor = rect == null
          ? null
          : Rect.fromLTWH(math.max(rect.left + 8, rect.right - width - 8),
              rect.top, width, 0);
      final playing = cell.player?.state.playing ?? false;
      final full = _fullscreen == index;
      final action = await showRollDownMenu<String>(
        context,
        anchor: anchor,
        centered: false,
        width: width,
        title: cell.channel!.name,
        items: [
          if (_slots < _cellCount && !full)
            RollDownMenuItem(
                value: 'add',
                icon: Icons.add_box_outlined,
                label: tr('Add screen')),
          RollDownMenuItem(
              value: 'search', icon: Icons.search, label: tr('Search and add')),
          RollDownMenuItem(
              value: 'change',
              icon: Icons.swap_horiz,
              label: tr('Change channel')),
          RollDownMenuItem(
              value: 'pause',
              icon: playing ? Icons.pause : Icons.play_arrow,
              label: playing ? tr('Pause') : tr('Play')),
          if (_main && index != 0 && !full)
            RollDownMenuItem(
                value: 'main',
                icon: Icons.open_in_full,
                label: tr('Move to the big screen')),
          if (_canSwap && !_swapMode && !full)
            RollDownMenuItem(
                value: 'swapMode',
                icon: Icons.swap_vert,
                label: tr('Swap mode')),
          if (_slots >= 2 && !full && !_main)
            RollDownMenuItem(
                value: 'enlarge',
                icon: _enlarged == index ? Icons.grid_view : Icons.open_in_full,
                label: _enlarged == index
                    ? tr('Equal screens')
                    : tr('Enlarge screen')),
          RollDownMenuItem(
              value: 'full',
              icon: full ? Icons.fullscreen_exit : Icons.fullscreen,
              label: full ? tr('Exit full screen') : tr('Full screen')),
          RollDownMenuItem(
              value: 'reload', icon: Icons.refresh, label: tr('Reload')),
          RollDownMenuItem(
              value: 'remove', icon: Icons.close, label: tr('Remove screen')),
        ],
      );
      if (!mounted) return;
      switch (action) {
        case 'add':
          await _tvAddScreen();
        case 'search':
          await _openPicker(index);
        case 'change':
          await _tvOpenPicker(index);
        case 'pause':
          _togglePause(index);
        case 'main':
          _moveToMain(index);
          _cellFocus[0].requestFocus();
        case 'swapMode':
          _enterSwapMode();
        case 'enlarge':
          _tvToggleEnlarge(index);
        case 'full':
          full ? _tvExitFullscreen() : _tvEnterFullscreen(index);
        case 'reload':
          _reload(index);
        case 'remove':
          _tvRemoveScreen(index);
      }
    } finally {
      _menuOpen = false;
    }
  }

  /// Back: the channel with the sound goes back to the player that opened
  /// Multiview (null when no screen plays).
  void _leave() {
    final active = _cells[_activeCell].channel ??
        _cells.map((c) => c.channel).whereType<Channel>().firstOrNull;
    // Every screen lets go of its stream now, not after the closing
    // animation (dispose): the player that opened Multiview reconnects at
    // once, and many accounts allow one connection.
    for (final cell in _cells) {
      final player = cell.player;
      if (player == null) continue;
      DesktopLiveRecovery.of(player).stop();
      unawaited(player.stop());
    }
    Navigator.of(context).pop(active);
  }

  bool _playing(_MultiviewCell c) => c.channel != null && c.player != null;

  bool get _canSwap =>
      _layout == DesktopMultiviewLayout.main &&
      _cells.where(_playing).length >= 2;

  void _enterSwapMode() {
    if (!_canSwap) return;
    // A playing screen on the big one first.
    if (!_playing(_cells[0])) _moveToMain(_cells.indexWhere(_playing));
    setState(() => _swapMode = true);
    _setSwapAudio();
    _cellFocus[0].requestFocus();
    debugPrint('DesktopMultiview: swap mode on');
  }

  void _exitSwapMode() {
    if (_swapMode) setState(() => _swapMode = false);
  }

  /// [index]'s screen onto the big one (the big one's goes where it was).
  void _moveToMain(int index) {
    if (index <= 0 || index >= _cellCount) return;
    final big = _cells[0];
    _cells[0] = _cells[index];
    _cells[index] = big;
    setState(() => _swapCount++);
    _setSwapAudio();
  }

  /// Every playing screen [step] places through the big one; empty slots
  /// stay put.
  void _rotateSwap(int step) {
    final slots = [
      for (var i = 0; i < _cellCount; i++)
        if (_playing(_cells[i])) i
    ];
    if (slots.length < 2) return;
    final moved = [for (final from in swapRotation(slots, step)) _cells[from]];
    for (var k = 0; k < slots.length; k++) {
      _cells[slots[k]] = moved[k];
    }
    setState(() => _swapCount++);
    _setSwapAudio();
  }

  /// Swap mode / 1 + 3 after a move: only the big screen plays sound.
  void _setSwapAudio() {
    _activeCell = 0;
    for (var i = 0; i < _cellCount; i++) {
      _cells[i].player?.setVolume(i == 0 ? 100 : 0);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (_tv &&
        !_swapMode &&
        e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.arrowUp &&
        _fullscreen == null &&
        _panelFor == null) {
      final i = _cellFocus.indexWhere((n) => n.hasFocus);
      if (i < 0 || _rects[i] == null) return KeyEventResult.ignored;
      final top = _rects.whereType<Rect>().map((r) => r.top).reduce(math.min);
      if (_rects[i]!.top > top + 1) return KeyEventResult.ignored;
      _revealHeader(focus: true);
      return KeyEventResult.handled;
    }
    if (!_swapMode || e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowRight) {
      _rotateSwap(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      _rotateSwap(-1);
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.select)) {
      _exitSwapMode();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setLayout(DesktopMultiviewLayout layout) {
    if (layout == _layout) return;
    final storage = context.read<StorageService>();
    unawaited(storage.setMultiviewMain(layout == DesktopMultiviewLayout.main));
    if (layout != DesktopMultiviewLayout.main) {
      unawaited(
          storage.setMultiviewQuad(layout == DesktopMultiviewLayout.quad));
      _swapMode = false;
    }
    if (layout == DesktopMultiviewLayout.dual) {
      // Actually free cells 2/3's connections/decode sessions, not just
      // hide them — leaving them playing, muted, off-screen would still
      // hold a connection slot and a decoder for nothing visible.
      for (var i = 2; i < _cellCount; i++) {
        _cells[i].completedSubscription?.cancel();
        DesktopLiveRecovery.disposePlayer(_cells[i].player);
        _cells[i] = _MultiviewCell();
      }
      if (_activeCell >= 2) _activeCell = 0;
    }
    setState(() => _layout = layout);
  }

  /// Apple TV: back from the Home screen every screen opens again at live
  /// (media_kit paused them, tvOS cut their connections: [AppleTvComeback]).
  AppLifecycleListener? _comeback;

  void _onBackOnScreen(Duration away) {
    if (!mounted) return;
    debugPrint('AppleTvComeback: Multiview opened again after '
        '${away.inSeconds} s away');
    for (var i = 0; i < _cells.length; i++) {
      _reload(i);
    }
  }

  @override
  void dispose() {
    _comeback?.dispose();
    _headerTimer?.cancel();
    _headerScope.dispose();
    _headerFirst.dispose();
    _panelPick?.complete(null);
    _keys.dispose();
    for (final node in _cellFocus) {
      node.dispose();
    }
    for (final cell in _cells) {
      cell.completedSubscription?.cancel();
      DesktopLiveRecovery.disposePlayer(cell.player);
    }
    super.dispose();
  }

  /// [channel] on screen [index] (its old stream closes); the new player.
  Player _assign(int index, Channel channel) {
    final cell = _cells[index];
    cell.completedSubscription?.cancel();
    DesktopLiveRecovery.disposePlayer(cell.player);
    final player = newDesktopPlayer();
    // See DesktopPlayerScreen's identical fix for the full story —
    // reconnect_streamed=1 is necessary (not optional) to recover from a
    // genuine dropped read on a live/non-seekable stream, which is exactly
    // what reconnect_streamed governs; reconnect_on_network_error doesn't
    // cover it (that one's only for failures during the initial connect).
    // rw_timeout is what avoids reopening the *original* hang-forever bug
    // reconnect_streamed=0 was first added for: it bounds any single
    // blocked read/write (including a hanging Range-reconnect attempt on a
    // server that doesn't support it) to a fixed ceiling instead of
    // letting it hang forever, so ffmpeg's own reconnect loop can retry.
    configureDesktopStreamPlayer(player, 'multiview');
    final controller = desktopVideoController(player);
    unawaited(openDesktopStream(player, channel)
        .then((_) => DesktopLiveRecovery.of(player).watch(channel)));
    player.setVolume(index == _activeCell ? 100 : 0);
    // Reconnects: DesktopLiveRecovery (waits, retries, copies).
    setState(() {
      cell.channel = channel;
      cell.player = player;
      cell.controller = controller;
      cell.completedSubscription = null;
    });
    return player;
  }

  /// Same manual-relaunch idea as `DesktopPlayerScreen._reload`/
  /// `PlayerControls`' own Reload button — for a cell that's silently
  /// stalled (frozen frame, no error), requested directly for every
  /// multiview cell the same way.
  void _reload(int index) {
    final cell = _cells[index];
    final channel = cell.channel;
    if (channel == null) return;
    final player = cell.player;
    if (player == null) return;
    unawaited(openDesktopStream(player, channel)
        .then((_) => DesktopLiveRecovery.of(player).watch(channel)));
  }

  void _clear(int index) {
    _cells[index].completedSubscription?.cancel();
    DesktopLiveRecovery.disposePlayer(_cells[index].player);
    setState(() => _cells[index] = _MultiviewCell());
  }

  void _setActive(int index) {
    if (_cells[index].channel == null) return;
    setState(() => _activeCell = index);
    for (var i = 0; i < _cells.length; i++) {
      _cells[i].player?.setVolume(i == _activeCell ? 100 : 0);
    }
  }

  Future<void> _openPicker(int index) async {
    final playlist = context.read<PlaylistManager>();
    final channels = playlist.visibleChannels(category: 'tv');
    final chosen = await showDialog<Channel>(
      context: context,
      builder: (_) => _ChannelPickerDialog(channels: channels),
    );
    if (chosen != null) _assign(index, chosen);
    if (mounted && _tv) _cellFocus[index].requestFocus();
  }

  /// Remote: OK on the screen with the sound. The mouse has these as
  /// buttons on the screen itself.
  Future<void> _cellMenu(int index) async {
    final channel = _cells[index].channel;
    if (channel == null) return;
    final choice = await showGlassMenu<String>(
      context: context,
      builder: (context) => GlassMenuDialog(
        title: Text(channel.name),
        children: [
          TvDialogOption(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop('change'),
            child: Text(tr('Change channel')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('reload'),
            child: Text(tr('Reload')),
          ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop('remove'),
            child: Text(tr('Remove')),
          ),
          if (_canSwap && !_swapMode)
            TvDialogOption(
              onPressed: () => Navigator.of(context).pop('swap'),
              child: Text(tr('Swap mode')),
            ),
          TvDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'change':
        await _openPicker(index);
      case 'reload':
        _reload(index);
      case 'remove':
        _clear(index);
      case 'swap':
        _enterSwapMode();
    }
    if (mounted && choice != 'change' && choice != 'swap') {
      _cellFocus[index].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back in Swap mode ends it first; otherwise it leaves with the
      // channel that has the sound ([_leave]).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_swapMode) {
          _exitSwapMode();
        } else if (_tv && _panelFor != null) {
          if (!(_panelKey.currentState?.back() ?? false)) _closePanel();
        } else if (_tv && _fullscreen != null) {
          _tvExitFullscreen();
        } else {
          _leave();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _keys,
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: _tv
              ? SafeArea(child: _buildTv())
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: tr('Back'),
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: _leave,
                            ),
                            Text(tr('Multiview'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            PopupMenuButton<DesktopMultiviewLayout>(
                              tooltip: tr('Layout'),
                              icon: const Icon(Icons.grid_view,
                                  color: Colors.white),
                              onSelected: _setLayout,
                              itemBuilder: (context) => [
                                CheckedPopupMenuItem(
                                  value: DesktopMultiviewLayout.dual,
                                  checked:
                                      _layout == DesktopMultiviewLayout.dual,
                                  child: Text(tr('2 channels')),
                                ),
                                CheckedPopupMenuItem(
                                  value: DesktopMultiviewLayout.quad,
                                  checked:
                                      _layout == DesktopMultiviewLayout.quad,
                                  child: Text(tr('4 channels')),
                                ),
                                CheckedPopupMenuItem(
                                  value: DesktopMultiviewLayout.main,
                                  checked:
                                      _layout == DesktopMultiviewLayout.main,
                                  child: Text(tr('1 + 3 screens')),
                                ),
                              ],
                            ),
                            if (_layout == DesktopMultiviewLayout.main)
                              TextButton.icon(
                                icon: Icon(Icons.swap_vert,
                                    color: _swapMode
                                        ? Colors.amber
                                        : Colors.white),
                                label: Text(tr('Swap mode'),
                                    style: TextStyle(
                                        color: _swapMode
                                            ? Colors.amber
                                            : Colors.white)),
                                onPressed: _swapMode
                                    ? _exitSwapMode
                                    : _canSwap
                                        ? _enterSwapMode
                                        : null,
                              ),
                            const Spacer(),
                            if (_swapMode)
                              const _DesktopSwapPill()
                            else ...[
                              const Icon(Icons.volume_up,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(tr('= audio — click a channel to switch'),
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          // Stacked (Column), not side-by-side — requested
                          // directly: splitting a landscape screen into left/
                          // right halves squeezes each cell into a tall, narrow
                          // near-square, badly distorting a widescreen video's
                          // actual shape. Splitting top/bottom instead lets each
                          // cell span the full screen width, keeping something
                          // much closer to its real aspect ratio even though it's
                          // shorter.
                          // The cell *frame* (border/header/buttons) fills the
                          // whole row, same as a quad cell fills its quarter —
                          // constraining the whole frame to 16:9 (an earlier
                          // version of this fix) made dual cells look noticeably
                          // smaller than quad's. Only the video itself is aspect-
                          // constrained now (inside `_buildCell`), letterboxing
                          // within the full-size frame instead of shrinking the
                          // frame around it.
                          // Flex 13:7 instead of a flat 50/50 split when only one
                          // of the two cells actually has a channel in it — a
                          // plain even split made a single active stream look
                          // small (letterboxed within an exactly-half-height row),
                          // reported directly as needing to be "bigger by 30%".
                          // 13:7 gives the occupied row exactly 65% of the
                          // available height, i.e. 1.3x the even-split baseline —
                          // once both cells are filled they're back to equal flex
                          // (13:13) and split evenly like a normal multiview grid.
                          child: _layout == DesktopMultiviewLayout.main
                              ? Row(
                                  children: [
                                    Expanded(
                                        flex: 3,
                                        child: Padding(
                                            padding: const EdgeInsets.all(3),
                                            child: _DesktopSwapFlash(
                                                swaps: _swapCount,
                                                child: _buildCell(0)))),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          for (var i = 1; i < _cellCount; i++)
                                            Expanded(
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: _buildCell(i))),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : _layout == DesktopMultiviewLayout.dual
                                  ? Column(
                                      children: [
                                        Expanded(
                                            flex: _cells[0].channel != null
                                                ? 13
                                                : 7,
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                child: _buildCell(0))),
                                        Expanded(
                                            flex: _cells[1].channel != null
                                                ? 13
                                                : 7,
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                child: _buildCell(1))),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              3),
                                                      child: _buildCell(0))),
                                              Expanded(
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              3),
                                                      child: _buildCell(1))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              3),
                                                      child: _buildCell(2))),
                                              Expanded(
                                                  child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              3),
                                                      child: _buildCell(3))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// A remote: Android's Multiview (see [_slots]).
  Widget _buildTv() {
    final size = MediaQuery.sizeOf(context);
    final buttonStyle =
        multiviewHeaderButtonStyle(Theme.of(context).colorScheme.primary);
    final header = Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Focus(
        // Listen-only: Down from the header goes back to the first screen.
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.arrowDown) {
            _cellFocus[0].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            IconButton(
              tooltip: tr('Back'),
              style: buttonStyle,
              focusNode: _headerFirst,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _leave,
            ),
            Text(tr('Multiview'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            if (_fullscreen == null)
              TextButton.icon(
                style: buttonStyle,
                onPressed: _tvToggleMain,
                icon: Icon(_main ? Icons.view_quilt : Icons.grid_view,
                    color: Colors.white, size: 18),
                label: Text(_main ? tr('1 + 3 screens') : tr('Equal screens'),
                    style: const TextStyle(color: Colors.white)),
              ),
            if (_main && _canSwap && _fullscreen == null)
              TextButton.icon(
                style: buttonStyle,
                onPressed: _enterSwapMode,
                icon:
                    const Icon(Icons.swap_vert, color: Colors.white, size: 18),
                label: Text(tr('Swap mode'),
                    style: const TextStyle(color: Colors.white)),
              ),
            if (_slots < _cellCount && _fullscreen == null && !_main)
              TextButton.icon(
                style: buttonStyle,
                onPressed: _tvAddScreen,
                icon: const Icon(Icons.add_box_outlined,
                    color: Colors.white, size: 18),
                label: Text(tr('Add screen'),
                    style: const TextStyle(color: Colors.white)),
              ),
            const Spacer(),
            const Icon(Icons.volume_up, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                  tr('= audio follows the selected screen · OK for options · hold OK to enlarge'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(builder: (context, box) {
            _rects = multiviewSlotRects(box.biggest, _slots,
                enlarged: _enlarged, fullscreen: _fullscreen, main: _main);
            // The big / full-screen screen last, so it's painted on top.
            final top = _fullscreen ?? _enlarged;
            final order = [
              for (var i = 0; i < _cellCount; i++)
                if (i != top) i,
              if (top != null) top,
            ];
            return Stack(
              children: [
                for (final i in order)
                  if (_rects[i] != null)
                    AnimatedPositioned.fromRect(
                      key: ValueKey(i),
                      rect: _rects[i]!,
                      duration: _anim,
                      curve: Curves.easeInOutCubic,
                      child: _buildTvCell(i, full: i == _fullscreen),
                    ),
              ],
            );
          }),
        ),
        if (_swapMode && _rects[0] != null)
          Positioned(
            left: _rects[0]!.left,
            width: _rects[0]!.width,
            top: math.min(_rects[0]!.bottom + 8, size.height - 48),
            child: const Center(child: MultiviewSwapModePill()),
          ),
        if (_panelFor != null)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: FocusScope(
              child: SportsModeLivePanel(
                key: _panelKey,
                current: _cells[_panelFor!].channel,
                onPlay: (channel, _) async => _closePanel(channel),
                onRight: () => _panelKey.currentState?.focusGroups(),
                liveGames: _panelLiveGames,
              ),
            ),
          ),
        // The header is hidden on purpose: a small Up arrow says it's there.
        if (!_headerShown && _fullscreen == null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: const Icon(Icons.keyboard_arrow_up,
                      color: Colors.white70, size: 20),
                ),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_headerShown,
            child: AnimatedSlide(
              offset: _headerShown ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 220),
              child: ExcludeFocus(
                excluding: !_headerShown,
                child: FocusScope(node: _headerScope, child: header),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A remote: Android's screen tile ([MultiviewCellTile]). OK: an empty
  /// screen opens the live guide, a playing one takes the sound and opens
  /// its menu. Hold OK: enlarge (1 + 3: to the big screen; the big one or a
  /// single screen: full screen).
  Widget _buildTvCell(int index, {bool full = false}) {
    final cell = _cells[index];
    void onTap() {
      if (_swapMode) {
        if (index == 0) {
          _exitSwapMode();
        } else if (_playing(cell)) {
          _moveToMain(index);
        }
        return;
      }
      if (cell.channel == null) {
        unawaited(_tvOpenPicker(index));
        return;
      }
      _setActive(index);
      unawaited(_tvCellMenu(index));
    }

    void onHold() {
      if (cell.channel == null || _swapMode) return;
      if (_main) {
        if (index == 0) {
          full ? _tvExitFullscreen() : _tvEnterFullscreen(index);
        } else {
          _moveToMain(index);
          _cellFocus[0].requestFocus();
        }
        return;
      }
      if (_slots < 2) {
        full ? _tvExitFullscreen() : _tvEnterFullscreen(index);
      } else {
        _tvToggleEnlarge(index);
      }
    }

    final controller = cell.controller;
    return HoldToActivate(
      onTap: onTap,
      onHold: cell.channel == null ? null : onHold,
      child: MultiviewCellTile(
        focusNode: _cellFocus[index],
        channel: cell.channel,
        video: controller == null
            ? null
            : Video(
                // A swap moves the controller to another screen.
                key: ObjectKey(controller),
                controller: controller,
                controls: NoVideoControls,
                pauseUponEnteringBackgroundMode: mediaKitPausesInBackground),
        active: index == _activeCell && cell.channel != null,
        onTap: onTap,
        onLongPress: cell.channel == null ? null : onHold,
        // The sound follows the selected screen (TiviMate-style).
        onFocused: () => _setActive(index),
        widthBoost: 1,
        fill: true,
        bare: full,
        alignment: Alignment.center,
        badge: _swapMode && index == 0
            ? MultiviewSwapModeBadge(swaps: _swapCount)
            : null,
      ),
    );
  }

  Widget _buildCell(int index) {
    final cell = _cells[index];
    final active = index == _activeCell && cell.channel != null;
    // The frame shows the remote's place; a mouse needs none.
    final focused = _tv && _focusedCell == index;
    return InkWell(
      focusNode: _cellFocus[index],
      autofocus: index == 0,
      onFocusChange: (f) {
        if (f) {
          setState(() => _focusedCell = index);
        } else if (_focusedCell == index) {
          setState(() => _focusedCell = null);
        }
      },
      onTap: () {
        if (cell.channel == null) {
          _openPicker(index);
        } else if (_swapMode) {
          // A small screen moves up; the big one ends Swap mode.
          index == 0 ? _exitSwapMode() : _moveToMain(index);
        } else if (_tv && active) {
          _cellMenu(index);
        } else {
          _setActive(index);
        }
      },
      child: Container(
        // The remote's place: white, over the gold of the screen with the
        // sound (InkWell's own focus colour is drawn under the video).
        decoration: BoxDecoration(
          border: Border.all(
              color: focused
                  ? Colors.white
                  : active
                      ? Colors.amber
                      : Colors.white24,
              width: focused || active ? 3 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        // The name bar fades after a few seconds (it covered the score
        // bug); it's back on a new channel, when the sound moves here, and
        // while the mouse is over the tile (its buttons live there).
        child: AutoHideOverlay(
          flashKey: (cell.channel?.id, active),
          hidden: active ? const MultiviewAudioBadge() : null,
          video: cell.controller != null
              // AspectRatio wraps only the video, not the frame around it
              // — media_kit's Video widget has no fit/letterbox option of
              // its own and otherwise just stretches to fill whatever box
              // it's handed.
              ? Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(
                        // A swap moves the controller to another screen.
                        key: ObjectKey(cell.controller),
                        controller: cell.controller!,
                        controls: NoVideoControls,
                        pauseUponEnteringBackgroundMode:
                            mediaKitPausesInBackground),
                  ),
                )
              : const ColoredBox(
                  color: Color(0xFF1A1A1A),
                  child: Center(
                    child: Icon(Icons.add_circle_outline,
                        color: Colors.white38, size: 40),
                  ),
                ),
          overlay: cell.channel == null
              ? const SizedBox.shrink()
              : Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    // Was a 2-stop gradient fading to transparent almost
                    // immediately — reported directly as barely visible
                    // against a bright/busy video frame. A mid-bar stop
                    // keeps the whole header solidly dark (not just its
                    // very top edge) before fading out underneath it, and
                    // the text itself now carries its own shadow as a
                    // second, independent line of contrast — the same
                    // "readable over anything behind it" fix already used
                    // elsewhere in this app (e.g. PosterCard's progress
                    // label) rather than relying on the backdrop alone.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.6, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.92),
                          Colors.black.withValues(alpha: 0.92),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    // A remote never stops on these (they show on mouse
                    // hover): OK on the screen opens the same actions.
                    child: ExcludeFocus(
                      excluding: _tv,
                      child: Row(
                        children: [
                          if (active) ...[
                            const Icon(Icons.volume_up,
                                color: Colors.amber,
                                size: 15,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4)
                                ]),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              cell.channel!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4)
                                  ]),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: tr('Reload'),
                            onPressed: () => _reload(index),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz,
                                color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: tr('Change channel'),
                            onPressed: () => _openPicker(index),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: tr('Remove'),
                            onPressed: () => _clear(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A plain search-and-pick list — the live channel list this draws from
/// can run into the tens of thousands across every enabled playlist (see
/// `PlaylistManager.visibleChannels`), so a simple substring filter over
/// a lazily-built `ListView` is what keeps this responsive rather than
/// anything fancier.
class _ChannelPickerDialog extends StatefulWidget {
  const _ChannelPickerDialog({required this.channels});

  final List<Channel> channels;

  @override
  State<_ChannelPickerDialog> createState() => _ChannelPickerDialogState();
}

/// The picker's quick filters: every channel, games playing now (with
/// their matched channel) and sports channels — see [MultiviewSports].
enum _PickerFilter { all, live, sports }

class _ChannelPickerDialogState extends State<_ChannelPickerDialog> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'desktop-multiview-search');

  bool get _tv => context.read<AppPreferences?>()?.isTelevision ?? false;
  String _query = '';
  _PickerFilter _filter = _PickerFilter.all;

  /// Loaded the first time Live now is picked; null until then.
  List<LiveGameChannel>? _live;
  bool _liveLoading = false;

  Future<void> _loadLive() async {
    if (_live != null || _liveLoading) return;
    setState(() => _liveLoading = true);
    List<LiveGameChannel> live;
    try {
      live = await MultiviewSports.liveGames(
        storage: context.read<StorageService>(),
        playlist: context.read<PlaylistManager>(),
        epg: context.read<EpgService>(),
      );
    } catch (_) {
      live = const [];
    }
    if (!mounted) return;
    setState(() {
      _live = live;
      _liveLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live now: one row per game; search matches the game or its channels.
    final live = MultiviewSports.search(_live ?? const [], _query);
    final Iterable<Channel> base = switch (_filter) {
      _PickerFilter.all => widget.channels,
      _PickerFilter.live => [for (final l in live) l.channel],
      _PickerFilter.sports => widget.channels.where(MultiviewSports.isSports),
    };
    final q = _query.toLowerCase();
    final filtered = q.isEmpty || _filter == _PickerFilter.live
        ? base.toList()
        : base.where((c) => c.name.toLowerCase().contains(q)).toList();
    Widget chip(_PickerFilter f, String label, IconData icon) => ChoiceChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: _filter == f,
          onSelected: (_) {
            setState(() => _filter = f);
            if (f == _PickerFilter.live) _loadLive();
          },
        );
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SizedBox(
        width: 480,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              // On a computer it types at once (autofocus); with a remote
              // (Apple TV) the keyboard waits for OK and the arrows pass
              // over it, and the first channel has focus instead: a
              // focused field kept the arrows for its cursor.
              child: TvTextFieldGate(
                focusNode: _searchFocus,
                builder: (context, readOnly) => TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  readOnly: readOnly,
                  autofocus: !_tv,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: tr('Search channels...'),
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(spacing: 8, children: [
                chip(_PickerFilter.all, tr('All'), Icons.apps),
                chip(_PickerFilter.live, tr('Live now'), Icons.sports_score),
                chip(_PickerFilter.sports, tr('Sports'), Icons.sports),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: _filter == _PickerFilter.live && _live == null
                          ? const CircularProgressIndicator()
                          : Text(
                              _filter == _PickerFilter.live
                                  ? tr(
                                      'No live games on your channels right now')
                                  : tr('No channels found'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54)),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final row =
                            _filter == _PickerFilter.live && i < live.length
                                ? live[i]
                                : null;
                        // Remote: the list starts focused (see the search
                        // field above).
                        final first = i == 0 && _tv;
                        if (row != null) {
                          final n = row.matches.length;
                          return GlassFocusFrame(
                              child: ListTile(
                            autofocus: first,
                            leading: const Icon(Icons.sports_score,
                                color: Colors.white54),
                            title: Text(MultiviewSports.label(row.game),
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                                n > 1
                                    ? '${c.name} · ${tr('{n} channels', {
                                            'n': n
                                          })}'
                                    : c.name,
                                style: const TextStyle(color: Colors.white54)),
                            trailing: n > 1
                                ? const Icon(Icons.chevron_right,
                                    color: Colors.white54)
                                : null,
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              final picked =
                                  await chooseGameChannel(context, row);
                              if (picked != null && mounted) {
                                navigator.pop(picked);
                              }
                            },
                          ));
                        }
                        return GlassFocusFrame(
                            child: ListTile(
                          autofocus: first,
                          leading: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
                              ? Image.network(c.logoUrl!,
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.tv,
                                      color: Colors.white54))
                              : const Icon(Icons.tv, color: Colors.white54),
                          title: Text(c.name,
                              style: const TextStyle(color: Colors.white)),
                          onTap: () => Navigator.of(context).pop(c),
                        ));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swap mode in the header: blinks like Android's SWAP pill.
class _DesktopSwapPill extends StatefulWidget {
  const _DesktopSwapPill();

  @override
  State<_DesktopSwapPill> createState() => _DesktopSwapPillState();
}

class _DesktopSwapPillState extends State<_DesktopSwapPill>
    with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_blink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          border: Border.all(color: Colors.amber, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            Text(tr('SWAP'),
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(width: 10),
            Text(tr('Arrows or a click swap · Esc to finish'),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// A gold flash over the big screen on every swap ([swaps] changes).
class _DesktopSwapFlash extends StatefulWidget {
  const _DesktopSwapFlash({required this.swaps, required this.child});

  final int swaps;
  final Widget child;

  @override
  State<_DesktopSwapFlash> createState() => _DesktopSwapFlashState();
}

class _DesktopSwapFlashState extends State<_DesktopSwapFlash>
    with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450), value: 1);

  @override
  void didUpdateWidget(_DesktopSwapFlash old) {
    super.didUpdateWidget(old);
    if (old.swaps != widget.swaps) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.amber
                        .withValues(alpha: (1 - _flash.value) * 0.9),
                    width: 4),
                color:
                    Colors.amber.withValues(alpha: (1 - _flash.value) * 0.18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
