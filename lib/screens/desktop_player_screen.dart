import '../utils/refined_finish.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../services/archive_playback_sources.dart';
import '../services/live_sources.dart';
import '../widgets/live_source_drawer.dart';
import '../widgets/archive_source_drawer.dart';
import '../widgets/channel_schedule_panel.dart';
import '../utils/playback_modal_back_guard.dart';
import '../services/app_preferences.dart';
import '../services/desktop_mini_player.dart';
import '../services/desktop_vod_progress.dart';
import '../services/epg_service.dart';
import '../services/playback_service.dart';
import '../services/playlist_manager.dart';
import '../services/real_4k_channels.dart';
import '../services/storage_service.dart';
import '../services/archive_ready_watch.dart';
import '../services/watch_tracker.dart';
import '../l10n/l10n.dart';
import '../widgets/media_file_info_overlay.dart';
import '../widgets/player_clock_pill.dart';
import '../widgets/player_side_panel.dart';
import '../widgets/desktop_audio_button.dart';
import '../services/desktop_catchup.dart';
import '../utils/time_format.dart';
import '../widgets/desktop_data_pool_card.dart';
import '../widgets/desktop_quality_badges.dart';
import '../widgets/desktop_subtitles.dart';
import '../services/desktop_audio.dart';
import '../widgets/player_bar_title.dart';
import '../utils/channel_name_matching.dart';
import '../widgets/player_controls.dart';
import '../widgets/player_overlays.dart';
import '../widgets/desktop_video_status.dart';
import '../utils/scrub_steps.dart';
import '../widgets/live_channel_info_card.dart';
import '../widgets/audio_delay_adjuster.dart';
import '../widgets/data_pool_card.dart';
import '../services/catchup_session.dart';
import '../services/subtitle_tracks.dart' show languageName;
import 'search_screen.dart';
import '../widgets/gold_tag.dart';
import '../services/desktop_stream_setup.dart';
import '../services/desktop_live_recovery.dart';
import '../widgets/desktop_reconnecting_badge.dart';
import '../widgets/skip_segment_button.dart';
import '../widgets/watch_game_button.dart';
import '../services/watch_game_offer.dart';
import '../services/desktop_player_control.dart';
import '../services/skip_segments.dart';
import '../widgets/glass_menu.dart';
import '../services/ios_pip.dart';
import '../utils/desktop_platform.dart';
import '../utils/video_fit.dart';
import 'desktop_multiview_screen.dart';
import '../services/ci_tour.dart';

/// A deliberately standalone, Windows-only playback screen — see
/// `pubspec.yaml`'s media_kit comment for why this exists at all:
/// `video_player_hdr` (every other platform's player, completely
/// untouched by this file) has no Windows implementation whatsoever, and
/// `PlaybackService`/`PlayerScreen`/`PlayerControls`/`mini_player_bar.dart`
/// are all built directly around that package's own controller/value
/// shape (buffering state, captions, backup-server retry, Up Next,
/// position-save timers, the shared-controller-across-presentation-widgets
/// architecture...). Threading a platform-agnostic abstraction through all
/// of that is a real, separate project of its own — this screen
/// deliberately does NOT attempt it. It's a self-contained player: its own
/// `Player`, its own controls (favorite, reload, recall, skip ±10s,
/// previous/next episode), no shared state with `PlaybackService` at all.
/// VOD progress is saved separately through DesktopVodProgress using the same
/// storage/history as Android. Recall's [_DesktopLiveHistory] remains a local
/// live-channel list. This screen never calls PlaybackService.play().
///
/// Leaving a *live* channel via the back button doesn't stop it — same
/// "keeps playing in the background" idea as `PlaybackService` already
/// has for mobile — it hands the running `Player`/`VideoController` off to
/// [DesktopMiniPlayer] instead of disposing them (see [_handleBack]), and
/// `DesktopLiveResumeHint` (mounted globally in main.dart) shows a small
/// clickable pill until it's resumed. A movie or episode has no such
/// handoff — same as mobile, those just stop on exit.
class DesktopPlayerScreen extends StatefulWidget {
  const DesktopPlayerScreen({
    super.key,
    required this.channel,
    this.queue,
    this.sources,
    this.resolveQueued,
    this.existingPlayer,
    this.existingController,
    this.catchupAt,
    this.turnSideways = true,
  });

  final Channel channel;

  /// Opens [channel] (a live channel) as catch-up from this time instead
  /// of live: OK on a past programme in the guide ([DesktopCatchup]).
  final ArchivePlaybackSources? sources;

  /// Every episode of the series this channel belongs to, in order — only
  /// meaningful (and only ever passed) for a TV show episode, same concept
  /// as `PlaybackService.setUpNextQueue`. Drives the Previous/Next episode
  /// buttons; null/empty for a movie or live channel, which have no such
  /// queue.
  final List<Channel>? queue;

  /// Gives a [queue] episode that has no URL yet (Archive) its stream —
  /// same role as `PlaybackService.setUpNextQueue`'s `resolve`.
  final Future<Channel?> Function(Channel)? resolveQueued;

  /// Set together, only by `DesktopLiveResumeHint` when resuming a
  /// minimized live channel — reuses the session already playing in the
  /// background instead of this screen creating (and restarting the
  /// stream with) a new `Player`. Null for every other caller, which
  /// always starts a fresh session.
  final Player? existingPlayer;
  final VideoController? existingController;
  final DateTime? catchupAt;

  /// iPhone: the player turns the phone's screen sideways when it opens.
  /// False for the launch's resume, which nobody tapped (owner, 2026-11-19:
  /// the app went landscape by itself); Rotate still turns it.
  final bool turnSideways;

  @override
  State<DesktopPlayerScreen> createState() => _DesktopPlayerScreenState();
}

/// Recall's backing history — see [DesktopPlayerScreen]'s doc comment for
/// why this is separate from `PlaybackService.recentlyPlayed` rather than
/// reusing it. A plain static list (not persisted): good enough for "go
/// back to the live channel I was just on" within one run of the app.
class _DesktopLiveHistory {
  static final List<Channel> _recent = [];

  static void record(Channel channel) {
    _recent.removeWhere((c) => c.id == channel.id);
    _recent.insert(0, channel);
    if (_recent.length > 6) _recent.removeRange(6, _recent.length);
  }

  static List<Channel> recentExcluding(String id) =>
      _recent.where((c) => c.id != id).take(4).toList();
}

class _DesktopPlayerScreenState extends State<DesktopPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  late Channel _currentChannel;
  bool _controlsVisible = true;

  /// iPhone / iPad: the touch layout ([_touchControls]), landscape on a
  /// phone, controls that hide by themselves.
  bool get _touch => isIosTarget;

  /// iOS picture-in-picture is on: mpv is stopped and Apple's player has
  /// the stream (see [_startPip]).
  bool _inPip = false;
  bool _pipStarting = false;

  /// The movie's length when PiP started (mpv's is gone once stopped).
  Duration _pipDuration = Duration.zero;
  Timer? _touchHide;

  /// The picture mode's name over the video right after the touch bar's
  /// picture button ([_cycleFit]); [_fitPill] keeps it while it fades out.
  bool _fitPillVisible = false;
  VideoFit _fitPill = VideoFit.fit;
  Timer? _fitPillTimer;

  /// Touch seek bar: where the thumb is while a finger drags it (the seek
  /// happens on release, not on every move).
  double? _dragMs;
  final _fileInfoRequests = ValueNotifier<int>(0);

  /// [PlayerSidePanel] (Last channels / My Teams / Live now) on a live
  /// channel: the left-edge tab or the Left key opens it, Esc / a click on
  /// the video closes it — Windows has no remote Left (owner, 2026-10-18).
  bool _panelOpen = false;

  /// Settings > Playback > Data pool: the card is open (the bar's Data
  /// pool button or the I key).
  bool _dataPoolOpen = false;

  /// Apple TV remote: the Android TV player's flow and look (owner,
  /// 2026-11-20: "I don't know how we would make two TV apps that don't
  /// look the same" - he guides Apple TV users from his Android box). A zap
  /// shows the live info bar alone ([_tvZapInfo], nothing focused); OK
  /// shows the bar with its buttons ([_controlsVisible]: [LiveInfoBar] on a
  /// live channel, the transport bar on a movie / episode / catch-up); Down
  /// from it, the options row ([_tvOptions], [PlayerOptionsPill]). Up or
  /// Back there = the bar again; Back on the bar = the picture.
  bool _tvOptions = false;
  bool _tvZapInfo = false;
  final FocusScopeNode _tvBarScope =
      FocusScopeNode(debugLabel: 'desktop-player-bar');
  final FocusScopeNode _tvOptionsScope =
      FocusScopeNode(debugLabel: 'desktop-player-options');

  /// The bar button that had focus when the options row opened.
  FocusNode? _tvFocusBeforeOptions;

  /// Catch-up on a remote: the channel card's Channel schedule above the
  /// bar (Up from the bar), like Android's.
  final FocusNode _scheduleChipFocus =
      FocusNode(debugLabel: 'desktop-player-schedule-chip');

  /// Stream info from the options row: the Data pool card for 10 s.
  Timer? _dataPoolTimer;

  /// Remote Fast forward / Rewind (and Left on a movie), Android's: each
  /// press moves a target ([SkipCue] in the middle; a held key's steps
  /// grow), one seek 700 ms after the last press. Live with catch-up:
  /// Rewind = minutes back ([_skipLive]).
  Duration? _skipTarget;
  bool _skipLive = false;
  int _skipSteps = 0;
  final _scrubSteps = ScrubSteps();
  Timer? _skipCommit;

  /// Remote, movie / episode: Android's error screen when the stream fails
  /// before it plays (the friendly text + the technical details, links
  /// left out). Live has DesktopLiveRecovery's reconnects instead.
  String? _tvError;
  StreamSubscription<String>? _errorSubscription;
  Timer? _errorCheck;

  /// Remote: Android's Up Next (Settings > Playback > Up Next): the card
  /// in the last 45 s ([UpNextBubble]) and, on "early", the next episode
  /// 30 s before the end. [_upNextDismissed] = the episode whose card was
  /// closed; [_upNextFrom] = the one that already started its next.
  String? _upNextDismissed;
  String? _upNextFrom;
  StreamSubscription<Duration>? _upNextSubscription;

  /// When the current stream was opened (the card's "Playing for").
  DateTime _openedAt = DateTime.now();

  /// Catch-up of the live channel ([DesktopCatchup]); made on first use.
  DesktopCatchup? _catchupPlayer;

  /// On the app's services, not this screen's context: Back hands it to
  /// the guide's preview ([DesktopMiniPlayer]) with the player.
  DesktopCatchup get _catchupCtl =>
      _catchupPlayer ??= DesktopCatchup.forApp(_player,
          playlists: context.read<PlaylistManager>(),
          epg: context.read<EpgService>(),
          storage: context.read<StorageService>(),
          onLive: _playLiveAgain);

  /// Playing a catch-up programme of [_currentChannel] (still the live
  /// channel, so history / favourites / rows stay on it).
  bool get _inCatchup => _catchupPlayer?.active ?? false;

  /// When the live channel was paused: Play after more than 90 s resumes
  /// from there as catch-up (timeshift, like Android).
  DateTime? _livePausedAt;

  /// Holds the keys while the picture has them; never an arrow's target
  /// (requestFocus still works). Screen-sized, its centre was nearer than
  /// the next button: Left from Stop landed here instead of on Multiview
  /// (Apple TV tour, +915), the bar stayed up with nothing focused.
  final FocusNode _rootFocus =
      FocusNode(debugLabel: 'desktop-player-root', skipTraversal: true);

  /// Enter on a live channel focuses Play / Pause: the keyboard's way into
  /// the bar, since Up / Down on the picture change channel.
  final FocusNode _playPauseFocus =
      FocusNode(debugLabel: 'desktop-player-play-pause');

  /// Keys that change a live channel from the picture: Up / Page Up / CH+ =
  /// the channel above in the list, Down / Page Down / CH- = below (same
  /// directions as Android's player and the guide).
  static final Map<LogicalKeyboardKey, int> _zapKeys = {
    LogicalKeyboardKey.arrowUp: -1,
    LogicalKeyboardKey.pageUp: -1,
    LogicalKeyboardKey.channelUp: -1,
    LogicalKeyboardKey.arrowDown: 1,
    LogicalKeyboardKey.pageDown: 1,
    LogicalKeyboardKey.channelDown: 1,
  };

  /// Up / Down on a live channel (a Windows keyboard viewer, 2026-11-14):
  /// the previous / next channel of the list it was opened from
  /// ([PlaybackService.zapList], set by the guide), else its own group;
  /// wraps at either end and skips copies with the same id, like Android's
  /// `PlayerScreen._zapChannel`. From catch-up it steps from the live
  /// channel and leaves catch-up.
  void _zapChannel(int step) {
    final current = _currentChannel;
    if (!current.isLive) return;
    int indexIn(List<Channel> l) {
      final exact = l.indexWhere((c) => identical(c, current));
      return exact >= 0 ? exact : l.indexWhere((c) => c.id == current.id);
    }

    var list = context.read<PlaybackService>().zapList ?? const <Channel>[];
    var i = indexIn(list);
    if (i < 0) {
      list = context.read<PlaylistManager>().visibleChannels(
          playlistId: current.playlistId,
          groupTitle: current.group,
          category: 'tv');
      i = indexIn(list);
    }
    if (i < 0) return;
    for (var n = 1; n < list.length; n++) {
      final c = list[(i + step * n) % list.length];
      if (c.id == current.id) continue;
      _flashControls();
      unawaited(_switchTo(c));
      return;
    }
  }

  /// Shows the bar (the new channel's name and programme) for 3 s after a
  /// zap when it was hidden; a bar the viewer opened stays as it was.
  Timer? _zapHud;
  void _flashControls() {
    if (_touch) return;
    // Remote, live: the info bar alone, nothing in it focused (Android's
    // zap); a bar or options row the viewer opened stays as it is.
    if (_tvRemote && _isLive && !_inCatchup) {
      if (_controlsVisible || _tvOptions) return;
      _zapHud?.cancel();
      setState(() => _tvZapInfo = true);
      // The CI tour's screenshot comes a few seconds after the key.
      _zapHud = Timer(const Duration(seconds: CiTour.enabled ? 12 : 3), () {
        _zapHud = null;
        if (mounted) setState(() => _tvZapInfo = false);
      });
      return;
    }
    final flashing = _zapHud != null;
    if (_controlsVisible && !flashing) return;
    _zapHud?.cancel();
    setState(() => _controlsVisible = true);
    _zapHud = Timer(const Duration(seconds: 3), () {
      _zapHud = null;
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _stopZapHud() {
    _zapHud?.cancel();
    _zapHud = null;
    _tvZapInfo = false;
  }

  /// A TV remote (Apple TV), not a mouse and keyboard: the bar hides when
  /// nothing on it has focus, OK opens it on Play / Pause, and it hides
  /// again by itself ([_armTvBarIdle]). A computer's bar shows from the
  /// start and stays. Discord (Apple TV, 2026-11-20): the bar was on screen
  /// with the picture holding the remote, so every arrow changed channel
  /// or opened the side panel instead of moving along it.
  bool get _tv => context.read<AppPreferences>().isTelevision;

  /// A TV remote's layout (Apple TV): Android TV's bars, see [_tvOptions].
  bool get _tvRemote => _tv && !_touch;

  /// Remote, live: the info bar shows (a zap, or OK).
  bool get _tvInfoBarShown =>
      _tvRemote && _isLive && !_inCatchup && (_controlsVisible || _tvZapInfo);

  /// Remote: something sits at the bottom (the bar, the info bar, the
  /// options row).
  bool get _tvChromeShown => _controlsVisible || _tvZapInfo || _tvOptions;

  /// OK on the picture: the bar with Play / Pause focused (the keyboard's
  /// and the remote's way into it).
  void _showBarFocused() {
    _stopZapHud();
    setState(() {
      _controlsVisible = true;
      _tvOptions = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _playPauseFocus.context != null) {
        _playPauseFocus.requestFocus();
      }
    });
    _armTvBarIdle();
  }

  /// Remote: the bar hides 6 s after the last key while it has focus (not
  /// while a menu from it is open or nothing plays), and the picture takes
  /// the arrows again.
  Timer? _tvBarIdle;
  void _armTvBarIdle() {
    if (!_tv) return;
    _tvBarIdle?.cancel();
    _tvBarIdle = Timer(const Duration(seconds: 6), () {
      _tvBarIdle = null;
      if (!mounted) return;
      if (ModalRoute.isCurrentOf(context) == false || !_player.state.playing) {
        _armTvBarIdle();
        return;
      }
      final inBar = _rootFocus.hasFocus && !_rootFocus.hasPrimaryFocus;
      if (!(_controlsVisible || _tvOptions) || !inBar) return;
      setState(() {
        _controlsVisible = false;
        _tvOptions = false;
      });
      _rootFocus.requestFocus();
    });
  }

  void _openPanel() {
    if (!_isLive) return;
    _stopZapHud();
    setState(() {
      _panelOpen = true;
      _controlsVisible = false;
      _tvOptions = false;
    });
  }

  void _closePanel() {
    if (!_panelOpen) return;
    setState(() => _panelOpen = false);
    _rootFocus.requestFocus();
  }

  /// Remote: Down from the bar = the options row, on its first tile.
  void _openTvOptions() {
    _tvFocusBeforeOptions = FocusManager.instance.primaryFocus;
    _stopZapHud();
    _dataPoolTimer?.cancel();
    setState(() {
      _tvOptions = true;
      _controlsVisible = false;
      // It would sit over the row; Stream info reopens it.
      _dataPoolOpen = false;
    });
    _armTvBarIdle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tvOptions) return;
      _tvOptionsScope.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_tvOptions) return;
        if (FocusManager.instance.primaryFocus == _tvOptionsScope) {
          _tvOptionsScope.nextFocus();
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  /// Remote: Up / Back in the options row = the bar, on the button it left.
  void _closeTvOptions() {
    if (!_tvOptions) return;
    setState(() {
      _tvOptions = false;
      _controlsVisible = true;
    });
    _armTvBarIdle();
    final previous = _tvFocusBeforeOptions;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previous != null && previous.context != null) {
        previous.requestFocus();
      } else if (_playPauseFocus.context != null) {
        _playPauseFocus.requestFocus();
      }
    });
  }

  /// An Up / Down that stays inside the bar (a move that left it is undone).
  bool _tryTvBarMove(TraversalDirection direction) {
    final previous = FocusManager.instance.primaryFocus;
    final moved = previous?.focusInDirection(direction) ?? false;
    if (moved && _tvBarScope.hasFocus) return true;
    if (moved) previous?.requestFocus();
    return false;
  }

  /// Remote Right on a live channel: the channel watched before it.
  void _lastChannel() {
    final previous = _DesktopLiveHistory.recentExcluding(_currentChannel.id);
    if (previous.isEmpty) return;
    _flashControls();
    unawaited(_switchTo(previous.first));
  }

  /// Options row > Stream info: the Data pool card for 10 s (Android's).
  void _showTvDataPool() {
    _dataPoolTimer?.cancel();
    setState(() {
      _tvOptions = false;
      _controlsVisible = false;
      _dataPoolOpen = true;
    });
    _rootFocus.requestFocus();
    _dataPoolTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _dataPoolOpen = false);
    });
  }

  /// Options row > Search: Back first (a live channel goes on playing in
  /// the guide's preview), then Search over the guide. Over this player, a
  /// channel picked in Search would open a second player and a second
  /// stream on top of this one.
  void _openTvSearch() {
    final navigator = Navigator.of(context);
    final id = _currentChannel.id;
    final scope = id.startsWith('xt_vod_')
        ? 'Movies'
        : id.startsWith('xt_ep_')
            ? 'TV Shows'
            : 'TV';
    _handleBack();
    unawaited(navigator.push(
        MaterialPageRoute(builder: (_) => SearchScreen(initialScope: scope))));
  }

  /// Options row > Start over: the programme on now, from its start.
  void _startOver() {
    final now =
        context.read<EpgService>().getCurrentProgram(_currentChannel.epgId);
    if (now != null) unawaited(_startCatchup(now.start));
  }

  /// Catch-up's previous (-1) programme, the one playing from its start
  /// (0), the next one (1); no later programme known = live.
  void _catchupJump(int step) {
    _armTvBarIdle();
    final at = _catchupCtl.playhead;
    if (at == null) return;
    final list = context.read<EpgService>().getPrograms(_currentChannel.epgId);
    final target = step < 0
        ? CatchupSession.programmeBefore(list, at)
        : step == 0
            ? CatchupSession.programmeAt(list, at)
            : CatchupSession.programmeAfter(list, at);
    if (target == null) {
      if (step > 0) unawaited(_catchupCtl.backToLive());
      return;
    }
    unawaited(_startCatchup(target.start));
  }

  /// The catch-up card's Channel schedule (remote): OK opens the schedule,
  /// Down / Back go back to the bar.
  KeyEventResult _onScheduleChipKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _openSchedule();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) _playPauseFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// iPhone: the live channel's schedule over the video (Android's info
  /// card "Channel schedule"): past programmes replay through catch-up,
  /// the one on now goes back to live, a later one opens its actions.
  bool _scheduleOpen = false;

  void _openSchedule() {
    if (!_isLive) return;
    _stopZapHud();
    setState(() {
      _scheduleOpen = true;
      _panelOpen = false;
      _controlsVisible = false;
      _tvOptions = false;
    });
  }

  void _closeSchedule() {
    if (!_scheduleOpen) return;
    setState(() => _scheduleOpen = false);
    _rootFocus.requestFocus();
  }

  late final _sourceBackGuard = PlaybackModalBackGuard(onChanged: () {
    if (mounted) setState(() {});
  });
  bool get _sourceDrawerOpen => _sourceBackGuard.isOpen;

  Future<void> _openSources() async {
    final sources = widget.sources;
    if (sources == null || _sourceDrawerOpen) return;
    final channelId = _currentChannel.id;
    _sourceBackGuard.opened();
    setState(() {
      _controlsVisible = false;
      _tvOptions = false;
    });
    try {
      final selection = await showArchiveSourceDrawer(context,
          sources: sources, channelId: channelId);
      if (!mounted || selection == null || _currentChannel.id != channelId) {
        return;
      }
      final position = _player.state.position;
      final playing = _player.state.playing;
      await sources.remember(channelId, selection.option);
      if (!mounted || _currentChannel.id != channelId) return;
      await _switchTo(selection.channel, start: position, play: playing);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Could not switch stream. Try another source.'))));
      }
    } finally {
      if (mounted) {
        _sourceBackGuard.closed();
        _rootFocus.requestFocus();
      }
    }
  }

  /// Live: the playing channel's other sources (quality copies, playlist
  /// editor fallbacks, the same channel in other playlists, the streams of
  /// a Dispatcharr channel), as Android's player lists them
  /// ([liveSourceRows]). This player (iPhone / iPad, Windows, macOS, Linux)
  /// had none (owner, 2026-11-18: iOS needs the Dispatcharr Sources too).
  /// The last row adds another source, like Android's (owner, 2026-11-20:
  /// the Apple TV drawers must have everything Android TV's have).
  Future<void> _openLiveSources() async {
    if (!_isLive || _inCatchup || _sourceDrawerOpen) return;
    final manager = context.read<PlaylistManager>();
    final id = _currentChannel.id;
    _sourceBackGuard.opened();
    setState(() {
      _controlsVisible = false;
      _tvOptions = false;
    });
    try {
      // Android's drawer: the last row adds a source (a playlist editor
      // fallback found by search), then the list opens again with it.
      while (mounted && _currentChannel.id == id) {
        final playing = _currentChannel;
        final (:rows, :canAdd) = await liveSourceRows(manager, playing);
        if (!mounted || _currentChannel.id != id) return;
        final sources = [for (final r in rows) r.$1];
        final picked = await showLiveSourceDrawer(context,
            canAdd: canAdd, entries: [for (final r in rows) r.$2]);
        if (!mounted || picked == null || _currentChannel.id != id) return;
        if (picked != liveSourceAdd) {
          final note = await playPickedLiveSource(
              playing, sources[picked], _playLiveSource);
          if (note != null && mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(note)));
          }
          return;
        }
        await manager.ensureLiveChannelsLoaded();
        if (!mounted) return;
        final fallback = await showLiveSourceSearch(context,
            title: tr('Another source for {channel}',
                {'channel': sources.first.name}),
            channels: manager.visibleChannels(category: 'tv'),
            suggest: channelCopyProbe(channelCopyKey(sources.first.name)),
            skipUrls: {for (final s in sources) s.url},
            describe: (c) => [
                  manager.playlistNameFor(c.playlistId).trim(),
                  c.group,
                ].where((s) => s.isNotEmpty).join(' · '));
        if (!mounted || fallback == null) continue;
        final added = await manager.addLiveFallback(sources.first, fallback);
        if (!mounted) return;
        if (!added) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('That source is already on the list.'))));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Could not switch stream. Try another source.'))));
      }
    } finally {
      if (mounted) {
        _sourceBackGuard.closed();
        _rootFocus.requestFocus();
      }
    }
  }

  /// The playing live channel from another source (same channel, same
  /// history and favourite: only the stream changes, like Android's
  /// `PlaybackService.playLiveSource`).
  Future<void> _playLiveSource(Channel source) async {
    final channel = _currentChannel.copyWith(
        url: source.url, httpHeaders: source.httpHeaders);
    if (channel.url == _currentChannel.url) return;
    debugPrint('DesktopPlayer: source picked -> ${source.name}');
    setState(() => _currentChannel = channel);
    await _openMedia(channel);
  }

  /// True once [_handleBack] has handed the live session to
  /// [DesktopMiniPlayer] — [dispose] must not also dispose it in that
  /// case, even though this screen did create it.
  bool _handedOffToMiniPlayer = false;

  /// Forces a fresh re-open whenever a *live* channel's player reports
  /// `completed` on its own. mpv's native reconnect config (see the
  /// `demuxer-lavf-o` property set in [initState]) doesn't reliably catch
  /// every way a live stream can end up here — confirmed directly: a
  /// clean `lavf: EOF reached` with no reconnect attempt logged
  /// afterward at all, despite `reconnect_at_eof=1` being set. A live
  /// channel should never just "complete," so reacting to it here is a
  /// recovery path this app fully controls, regardless of the exact
  /// low-level ffmpeg cause.
  StreamSubscription<bool>? _completedSubscription;

  /// The live list's 4K tag ([Real4kChannels]): mpv reports the decoded
  /// size whenever it changes, channel switches included.
  StreamSubscription<int?>? _heightSubscription;

  late final DesktopVodProgress _progress;
  late final PlaybackService _history;
  Timer? _progressTimer;
  bool _progressReady = false;
  int _openGeneration = 0;

  bool get _isLive => _currentChannel.isLive;
  List<Channel> get _queue => widget.queue ?? const [];
  int get _currentIndex => _queue.indexWhere((c) => c.id == _currentChannel.id);
  Channel? get _previousEpisode =>
      !_isLive && _currentIndex > 0 ? _queue[_currentIndex - 1] : null;
  Channel? get _nextEpisode =>
      !_isLive && _currentIndex >= 0 && _currentIndex < _queue.length - 1
          ? _queue[_currentIndex + 1]
          : null;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    if (_tv) {
      // Remote: the bar shows the channel for 3 s, then the picture.
      _controlsVisible = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flashControls();
      });
    }
    DesktopPlayerControl.register(_control);
    WatchGameOffer.current.addListener(_onWatchOfferChanged);
    _armWatchTimer();
    _progress = DesktopVodProgress(context.read<StorageService>());
    _history = context.read<PlaybackService>();
    if (widget.existingPlayer != null && widget.existingController != null) {
      _player = widget.existingPlayer!;
      _videoController = widget.existingController!;
      // Ours now: DesktopMiniPlayer.take emptied the holder, so dispose
      // tears it down unless Back hands it back. (It was skipped for a
      // taken player: Stop left the stream playing as sound only, one more
      // per channel picked after it. Windows user, +798, 2026-11-14.)
      // A catch-up from the guide's preview comes with its session.
      final catchup = DesktopMiniPlayer.instance.claimCatchup(_player);
      if (catchup != null) {
        catchup.onLive = _playLiveAgain;
        _catchupPlayer = catchup;
        DesktopLiveRecovery.of(_player).stop();
      } else {
        DesktopLiveRecovery.of(_player).watch(widget.channel);
      }
    } else {
      _player = newDesktopPlayer(bigCache: true);
      // Best-effort mpv/ffmpeg-level reconnect tuning for a live,
      // non-seekable TS stream — reconnect_streamed=1 is necessary for
      // mpv to even attempt recovering a genuinely dropped/reset read
      // (confirmed via log as `ffmpeg: tcp: ffurl_read returned -138` on
      // one specific provider), and rw_timeout bounds any single blocked
      // read/write (including a Range-reconnect attempt hanging forever
      // on a server that doesn't support it — the *original* bug this
      // property set replaces a plain reconnect_streamed=0 workaround
      // for) to a fixed ceiling instead of hanging indefinitely.
      //
      // This alone isn't fully reliable, though — confirmed directly: a
      // clean `lavf: EOF reached` with no reconnect attempt logged
      // afterward at all, despite reconnect_at_eof=1 being set, meaning
      // mpv doesn't catch every way a live stream can end up here. The
      // real safety net is _completedSubscription below, which reacts at
      // the app level instead of depending on mpv's own reconnect logic.
      configureDesktopStreamPlayer(_player, 'player');
      _videoController = desktopVideoController(_player);
      // The volume / mute set last time (a handed-over mini player
      // session already has it).
      final storage = context.read<StorageService>();
      unawaited(_player.setVolume(
          storage.getDesktopMuted() ? 0 : storage.getDesktopVolume()));
      if (widget.catchupAt case final at? when _currentChannel.isLive) {
        unawaited(_startCatchup(at));
      } else {
        unawaited(_openMedia(_currentChannel));
      }
      _applySeriesSubtitles();
    }
    if (_isLive) _DesktopLiveHistory.record(_currentChannel);
    // Trakt/Simkl, for Media Hub titles (a no-op otherwise).
    if (!_currentChannel.transientPlayback) {
      unawaited(WatchTracker.instance.started(_currentChannel.id));
    }
    // DesktopPlayerScreen deliberately never calls PlaybackService.play()
    // (see this class's own doc comment) — meaning nothing on Windows
    // ever recorded a "last channel" at all, since StorageService
    // .setLastChannelId is otherwise only ever called from inside
    // PlaybackService. Confirmed directly: main.dart's own Windows
    // auto-resume-last-channel (added for exactly this) silently never
    // found anything to resume into, because this was always null. Only
    // live channels are recorded, matching main.dart's own "scoped to
    // live channels only" resume logic — a movie/episode has no "resume
    // where I left off on launch" concept to begin with.
    if (_isLive) {
      context.read<StorageService>().setLastChannelId(_currentChannel.id);
      // Feeds the TV home's "History" group (live channels only, so
      // Continue Watching is unaffected).
      context.read<PlaybackService>().recordWatched(_currentChannel);
    }
    _progressTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _heightSubscription = _player.stream.height.listen((height) {
      // A picture: whatever failed before it is over.
      if (height != null && _tvError != null && mounted) {
        setState(() => _tvError = null);
      }
      if (!_isLive || height == null) return;
      Real4kChannels.record(
          _currentChannel.id, _player.state.width ?? 0, height);
    });
    // Live: DesktopLiveRecovery (waits, retries, copies). A movie or
    // episode that ends early was a cut stream: continue at the position.
    _completedSubscription = _player.stream.completed.listen((completed) {
      // mpv is stopped on purpose while Apple's player has the stream.
      if (completed && mounted && !_isLive && !_inPip) _resumeAfterCut();
    });
    _errorSubscription = _player.stream.error.listen(_onPlayerError);
    _upNextSubscription = _player.stream.position.listen(_checkUpNext);
    if (_touch) {
      IosPip.onStopped = _onPipStopped;
      // Full screen: no status bar. A phone turns sideways, also with its
      // rotation lock on (owner's iPhone 8: the player stayed portrait);
      // Rotate in the top bar goes back. Released in dispose.
      unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || MediaQuery.sizeOf(context).shortestSide >= 600) return;
        if (!widget.turnSideways) return;
        unawaited(SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]));
      });
      _armTouchHide();
    }
  }

  /// iOS picture-in-picture. iOS only floats Apple's own player, so the
  /// stream moves there: mpv stops first (one provider connection), then
  /// [IosPip] opens the same link in an AVPlayer and floats it. MKV and
  /// raw TS can't go there ([IosPip.urlFor] is null): a message instead.
  /// If Apple's player can't open it, mpv comes back at the same spot.
  Future<void> _startPip() async {
    if (_inPip || _pipStarting) return;
    final channel = _currentChannel;
    final url = IosPip.urlFor(channel);
    if (url == null) {
      _pipMessage(tr(
          "Picture-in-picture isn't available for this stream. It works with live channels from Xtream playlists and MP4 files."));
      return;
    }
    final live = _isLive;
    final position = live ? Duration.zero : _player.state.position;
    _pipDuration = _player.state.duration;
    _saveProgress();
    setState(() {
      _pipStarting = true;
      _controlsVisible = false;
    });
    // No reconnects, no progress saves at 0 while mpv is stopped.
    ++_openGeneration;
    _progressReady = false;
    DesktopLiveRecovery.of(_player).stop();
    await _player.stop();
    final error = await IosPip.start(
      url: url,
      live: live,
      position: position.inMilliseconds / 1000,
      // A source's own headers (Media Hub) win over our User-Agent.
      headers: {'User-Agent': kDesktopStreamUserAgent, ...channel.httpHeaders},
    );
    if (!mounted) return;
    if (error == null) {
      debugPrint('IosPip: started (${live ? 'live' : 'vod'})');
      setState(() {
        _pipStarting = false;
        _inPip = true;
      });
      return;
    }
    debugPrint('IosPip: start failed: $error');
    setState(() => _pipStarting = false);
    _pipMessage(tr("Picture-in-picture couldn't open this stream."));
    unawaited(_openMedia(channel, start: live ? null : position));
  }

  /// The PiP window closed. Restore (its "back to the app" button): mpv
  /// takes over again where Apple's player got to. X: stop watching.
  void _onPipStopped(bool restore, double seconds) {
    if (!mounted || !_inPip) return;
    setState(() => _inPip = false);
    final at =
        _isLive ? null : Duration(milliseconds: (seconds * 1000).round());
    debugPrint('IosPip: stopped (${restore ? 'restore' : 'closed'})');
    if (restore) {
      unawaited(_openMedia(_currentChannel, start: at));
      _armTouchHide();
      return;
    }
    if (at != null && _pipDuration > Duration.zero) {
      unawaited(_progress.save(_currentChannel, at, _pipDuration));
    }
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  /// "Watch here" on the player while PiP floats: back to mpv.
  Future<void> _endPip() async {
    if (!_inPip) return;
    final seconds = await IosPip.stop();
    if (!mounted || !_inPip) return;
    _onPipStopped(true, seconds);
  }

  void _pipMessage(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  /// What the player shows while PiP has the stream.
  Widget _pipNotice() {
    return Stack(children: [
      Positioned(
        top: 0,
        left: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              tooltip: tr('Back'),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _handleBack,
            ),
          ),
        ),
      ),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_in_picture_alt,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              _pipStarting
                  ? tr('Opening picture-in-picture…')
                  : tr('Playing in picture-in-picture'),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (_inPip) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _endPip,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(tr('Watch here')),
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  /// Touch: the controls hide 4 s after the last touch while playing.
  void _armTouchHide() {
    _touchHide?.cancel();
    if (!_touch || !_controlsVisible) return;
    _touchHide = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_player.state.playing || _sourceDrawerOpen) return;
      if (_dragMs != null) return;
      setState(() => _controlsVisible = false);
    });
  }

  /// Touch: the next picture mode (Fit, Stretched, Crop, Fit height, Fit
  /// width, Slight zoom, Cinema zoom: Android's button and setting), named
  /// over the video for a moment.
  void _cycleFit() {
    final prefs = context.read<AppPreferences>();
    final fit = prefs.videoFit.next;
    prefs.setVideoFit(fit);
    _armTouchHide();
    _fitPillTimer?.cancel();
    setState(() {
      _fitPill = fit;
      _fitPillVisible = true;
    });
    _fitPillTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _fitPillVisible = false);
    });
  }

  /// The picture sized for the picture mode like Android's VideoPlayerPane
  /// ([VideoFit.sizeIn]): the screen edge crops what overflows. Subtitles
  /// are drawn over the screen, not the picture's box, so Crop or a zoom
  /// never pushes them off the bottom. The same widgets in every mode, so
  /// a new mode never recreates the video view.
  Widget _video(AppPreferences prefs) {
    final fit = prefs.videoFit;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: LayoutBuilder(
            builder: (context, c) => ValueListenableBuilder<Rect?>(
              valueListenable: _videoController.rect,
              builder: (context, rect, _) {
                final pane = c.biggest;
                // Size unknown yet (no frame): the whole screen, fitted.
                final known = rect != null &&
                    rect.width > 1 &&
                    rect.height > 1 &&
                    pane.width.isFinite &&
                    pane.height.isFinite &&
                    pane.height > 0;
                final box =
                    known ? fit.sizeIn(pane, rect.width / rect.height) : pane;
                _logPictureFit(fit, rect, pane, box);
                return OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: SizedBox.fromSize(
                    size: box,
                    child: Video(
                        controller: _videoController,
                        controls: NoVideoControls,
                        fit: known ? BoxFit.fill : BoxFit.contain,
                        pauseUponEnteringBackgroundMode:
                            mediaKitPausesInBackground,
                        subtitleViewConfiguration:
                            const SubtitleViewConfiguration(visible: false)),
                  ),
                );
              },
            ),
          ),
        ),
        // Settings: the player's Subtitles menu > size.
        SubtitleView(
            controller: _videoController,
            configuration: SubtitleViewConfiguration(
                textScaler: TextScaler.linear(prefs.subtitleScale))),
      ],
    );
  }

  String? _pictureFitLogged;

  /// Send log: the sizes behind the picture, once per change (an iPhone
  /// user, 2026-11-19: full screen "too wide", not 16:9, in every picture
  /// mode). `video` is what media_kit reports (mpv's aspect-corrected
  /// size), `decoded` the stream's own pixels, `box` what's drawn.
  void _logPictureFit(VideoFit fit, Rect? rect, Size pane, Size box) {
    if (!pane.isFinite || !box.isFinite) return;
    String s(double w, double h) => '${w.round()}x${h.round()}';
    final state = _player.state;
    final line = 'PictureFit: ${fit.name} video '
        '${rect == null ? 'none' : s(rect.width, rect.height)} decoded '
        '${state.width ?? 0}x${state.height ?? 0} pane '
        '${s(pane.width, pane.height)} box ${s(box.width, box.height)}';
    if (line == _pictureFitLogged) return;
    _pictureFitLogged = line;
    debugPrint(line);
  }

  /// Touch: landscape <-> portrait, whatever the rotation lock says (the
  /// Android phone player's Rotate button).
  Future<void> _toggleRotation() async {
    final toLandscape =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    await SystemChrome.setPreferredOrientations(toLandscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  int _cutRetries = 0;

  /// Skip intro / recap / credits (IntroDB), same watcher as Android.
  final _segments = SkipSegmentWatcher();

  // --- Watch game pill (Settings > Sports Trak > Watch game button) ------
  // Android's rules: a reminded game started; shown 10 s when it arrives,
  // then only while the player bar shows; a click switches, it never
  // switches by itself.
  final _watchFocus = FocusNode(debugLabel: 'desktop-watch-game');
  DateTime? _watchShownUntil;
  Timer? _watchTimer;

  WatchGameOffer? get _watchOffer {
    final offer = WatchGameOffer.current.value;
    if (offer == null || offer.expired) return null;
    if (offer.channel.id == _currentChannel.id) return null;
    final fresh =
        _watchShownUntil != null && DateTime.now().isBefore(_watchShownUntil!);
    return fresh || _controlsVisible ? offer : null;
  }

  void _onWatchOfferChanged() {
    if (!mounted) return;
    _armWatchTimer();
    setState(() {});
  }

  /// Once per game: 10 s on screen when the offer arrives.
  void _armWatchTimer() {
    _watchTimer?.cancel();
    final offer = WatchGameOffer.current.value;
    if (offer != null && !offer.announced) {
      offer.announced = true;
      const shown = Duration(seconds: 10);
      _watchShownUntil = DateTime.now().add(shown);
      _watchTimer = Timer(shown, () {
        if (mounted) setState(() {});
      });
    }
  }

  /// What Vesper AI drives while this screen is open.
  late final _control = _ScreenControl(this);

  /// Vesper AI's "stop" and the bar's Stop: closes the player without
  /// handing a live channel to the mini player.
  void _stopAndClose() {
    if (!mounted) return;
    _catchupPlayer?.dispose();
    Navigator.of(context).pop();
  }

  void _watchGame(WatchGameOffer offer) {
    WatchGameOffer.current.value = null;
    debugPrint('DesktopPlayer: Watch game -> ${offer.channel.name}');
    unawaited(_switchTo(offer.channel));
  }

  void _skipSegment(SkipSegment segment) {
    final next = _nextEpisode;
    _segments.skip(segment,
        playNext: next == null ? null : () => _switchTo(next));
  }

  /// The real end of a movie or episode: Settings > Playback > Up Next.
  /// Android's 30-seconds-early countdown has no Windows version, so
  /// "early" also starts the next episode at the end here.
  void _onEpisodeEnded() {
    final next = _nextEpisode;
    if (next == null) return;
    if (context.read<StorageService>().getUpNextMode() == 'off') return;
    // Remote: its Up Next card was closed (Android: no next episode then).
    if (_tvRemote && _upNextDismissed == _currentChannel.id) return;
    if (_upNextFrom == _currentChannel.id) return;
    debugPrint('DesktopPlayer: episode ended, Up next');
    unawaited(_switchTo(next));
  }

  /// Android's 1.0.53 fix on Windows: a stream that ends well before its
  /// length reconnects at the position instead of stopping there.
  void _resumeAfterCut() {
    final position = _player.state.position;
    final duration = _player.state.duration;
    if (duration <= Duration.zero ||
        duration - position < const Duration(seconds: 60) ||
        _cutRetries >= 3) {
      _onEpisodeEnded();
      return;
    }
    _cutRetries++;
    debugPrint('DesktopPlayer: stream cut at ${position.inSeconds} s of '
        '${duration.inSeconds} s, resuming (try $_cutRetries)');
    final channel = _currentChannel;
    unawaited(Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted || _currentChannel.id != channel.id) return;
      unawaited(_openMedia(channel, start: position));
    }));
  }

  /// Open at the saved time without briefly playing the beginning first.
  /// Explicit start is used when switching source files within one title.
  Future<void> _openMedia(Channel channel,
      {Duration? start, bool play = true}) async {
    final generation = ++_openGeneration;
    _progressReady = false;
    bool current() =>
        mounted &&
        generation == _openGeneration &&
        _currentChannel.id == channel.id;
    _openedAt = DateTime.now();
    _errorCheck?.cancel();
    if (_tvError != null) setState(() => _tvError = null);
    try {
      final resume = start ?? _progress.resumePosition(channel);
      if (start == null) _cutRetries = 0;
      await openDesktopStream(_player, channel, start: resume, play: play);
      if (!current()) return;
      DesktopLiveRecovery.of(_player).watch(channel);
      if (resume == null) {
        // Trakt/Simkl may only know a fraction until the stream opens.
        final duration = _player.state.duration > Duration.zero
            ? _player.state.duration
            : await _player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 30));
        if (!current() || !_progress.accepts(channel)) return;
        final target = _progress.resumePosition(channel, duration: duration);
        if (target != null) await _player.seek(target);
        if (!current() || !_progress.accepts(channel)) return;
        await _progress.storage.clearResumeFraction(channel.id);
      }
      if (!current() || (!channel.isLive && !_progress.accepts(channel))) {
        return;
      }
      // Restart and explicit source-switch positions supersede a tracker fraction.
      if (_progress.isFraction(channel)) {
        await _progress.storage.clearResumeFraction(channel.id);
      }
      if (!current()) return;
      _progressReady = true;
      if (_progress.accepts(channel)) {
        unawaited(_history.recordWatched(channel));
      }
    } catch (e) {
      // Transport URLs can contain credentials; log only the failure type.
      debugPrint('Desktop playback open failed: ${e.runtimeType}');
    }
  }

  void _saveProgress() {
    if (!_progressReady) return;
    unawaited(_progress.save(
        _currentChannel, _player.state.position, _player.state.duration));
  }

  /// Trakt/Simkl: report mpv's exact position independently of saved progress.
  void _reportStopped() {
    if (_currentChannel.transientPlayback) return;
    final state = _player.state;
    // A Media Hub source's "being downloaded" clip isn't the title.
    if (ArchiveReadyWatch.instance.ended(_currentChannel.id, state.duration)) {
      return;
    }
    unawaited(WatchTracker.instance
        .stopped(_currentChannel.id, state.position, state.duration));
  }

  @override
  void dispose() {
    _touchHide?.cancel();
    _fitPillTimer?.cancel();
    if (_touch) {
      if (_inPip || _pipStarting) unawaited(IosPip.stop());
      if (IosPip.onStopped == _onPipStopped) IosPip.onStopped = null;
      // The rest of the app turns freely again (with the lock on: portrait).
      unawaited(SystemChrome.setPreferredOrientations([]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _sourceBackGuard.dispose();
    _fileInfoRequests.dispose();
    _progressTimer?.cancel();
    ++_openGeneration;
    if (!_handedOffToMiniPlayer) {
      _saveProgress();
      _reportStopped();
    }
    _completedSubscription?.cancel();
    _heightSubscription?.cancel();
    _catchupPlayer?.dispose();
    _segments.dispose();
    DesktopPlayerControl.unregister(_control);
    WatchGameOffer.current.removeListener(_onWatchOfferChanged);
    _watchTimer?.cancel();
    _watchFocus.dispose();
    _zapHud?.cancel();
    _tvBarIdle?.cancel();
    _playPauseFocus.dispose();
    _skipCommit?.cancel();
    _errorCheck?.cancel();
    unawaited(_errorSubscription?.cancel());
    unawaited(_upNextSubscription?.cancel());
    _tvBarScope.dispose();
    _tvOptionsScope.dispose();
    _scheduleChipFocus.dispose();
    _dataPoolTimer?.cancel();
    _rootFocus.dispose();
    if (!_handedOffToMiniPlayer) DesktopLiveRecovery.of(_player).stop();
    if (!_handedOffToMiniPlayer) DesktopLiveRecovery.disposePlayer(_player);
    super.dispose();
  }

  /// A live channel keeps playing in the background instead of stopping —
  /// see the class doc comment. A movie or episode just pops normally;
  /// [dispose] tears its `Player` down the same way it always has.
  void _handleBack() {
    if (_sourceBackGuard.blocksBack) return;
    // Apple's player has the stream: mpv is stopped, nothing to hand to
    // the mini player. Closing the screen ends PiP (dispose).
    if (_inPip || _pipStarting) {
      Navigator.of(context).pop();
      return;
    }
    // Catch-up goes on in the guide's preview, like Android's (the
    // preview's OK takes it back full screen).
    if (_inCatchup) {
      DesktopMiniPlayer.instance.minimize(
          _currentChannel, _player, _videoController,
          catchup: _catchupPlayer);
      _catchupPlayer = null;
      _handedOffToMiniPlayer = true;
      Navigator.of(context).pop();
      return;
    }
    if (_isLive) {
      DesktopMiniPlayer.instance
          .minimize(_currentChannel, _player, _videoController);
      _handedOffToMiniPlayer = true;
    }
    Navigator.of(context).pop();
  }

  Future<void> _switchTo(Channel channel,
      {Duration? start, bool play = true}) async {
    if (channel.url.isEmpty) {
      final resolve = widget.resolveQueued;
      Channel? resolved;
      try {
        resolved = resolve == null ? null : await resolve(channel);
      } catch (_) {
        resolved = null;
      }
      if (!mounted) return;
      if (resolved == null || resolved.url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('No playable stream for this title.')),
          backgroundColor: Colors.red.shade900,
        ));
        return;
      }
      channel = resolved;
    }
    _saveProgress();
    _progressReady = false;
    _reportStopped();
    _catchupPlayer?.dispose();
    _livePausedAt = null;
    setState(() => _currentChannel = channel);
    await _openMedia(channel, start: start, play: play);
    if (!mounted) return;
    unawaited(WatchTracker.instance.started(channel.id));
    _applySeriesSubtitles();
    if (_isLive) _DesktopLiveHistory.record(channel);
    // See initState's identical call for why — keeps it current across a
    // channel switch too, not just the one this screen opened with.
    if (_isLive) {
      context.read<StorageService>().setLastChannelId(channel.id);
      context.read<PlaybackService>().recordWatched(channel);
    }
  }

  /// An episode gets the subtitles chosen earlier in its series (same
  /// memory as Android's, see DesktopSubtitles.applyForSeries), and a
  /// movie / episode the audio track picked last time or the preferred
  /// audio language (DesktopAudio.applyRemembered).
  void _applySeriesSubtitles() {
    if (_isLive) return;
    final playing = _currentChannel;
    unawaited(DesktopAudio.applyRemembered(
            context.read<StorageService>(), playing, _player,
            isCurrent: () => mounted && _currentChannel == playing)
        .catchError((Object _) {}));
    final channel = _currentChannel;
    unawaited(DesktopSubtitles.applyForSeries(
            context.read<StorageService>(), channel, _player,
            isCurrent: () => mounted && _currentChannel == channel)
        .catchError((Object _) => false));
  }

  /// Manual reconnect for a stalled live stream — this screen has none of
  /// `PlaybackService`'s automatic backup-server retry, so a simple
  /// re-open is the only recovery available.
  void _reload() {
    final channel = _currentChannel;
    unawaited(openDesktopStream(_player, channel).then((_) {
      if (mounted && _currentChannel.id == channel.id) {
        DesktopLiveRecovery.of(_player).watch(channel);
      }
    }));
  }

  /// The bar's Multiview (Android's player has it, Apple TV didn't:
  /// Discord, 2026-11-20): the playing channel becomes Multiview's first
  /// screen. This player lets go of the stream first (one provider
  /// connection per screen, CLAUDE.md), and plays the screen that has the
  /// sound when Multiview closes.
  Future<void> _openMultiview() async {
    if (!_isLive || _inCatchup) return;
    final channel = _currentChannel;
    _stopZapHud();
    _tvBarIdle?.cancel();
    setState(() {
      _controlsVisible = false;
      _tvOptions = false;
    });
    ++_openGeneration;
    DesktopLiveRecovery.of(_player).stop();
    await _player.stop();
    if (!mounted) return;
    final back = await Navigator.of(context).push<Channel>(MaterialPageRoute(
        builder: (_) => DesktopMultiviewScreen(initialChannel: channel)));
    if (!mounted) return;
    _rootFocus.requestFocus();
    await _switchTo(back ?? channel);
    if (mounted) _flashControls();
  }

  /// Catch-up from [at] on the same player. Live recovery stops first:
  /// it would take the finite archive stream for a dead live one.
  Future<void> _startCatchup(DateTime at, {bool toProgrammeEnd = true}) async {
    DesktopLiveRecovery.of(_player).stop();
    _livePausedAt = null;
    final started = await _catchupCtl.play(_currentChannel, at,
        toProgrammeEnd: toProgrammeEnd);
    if (mounted) setState(() {});
    if (started) {
      debugPrint('DesktopPlayer: catch-up of ${_currentChannel.name}');
    }
  }

  /// Catch-up handed back to the live channel.
  Future<void> _playLiveAgain(Channel live) async {
    if (!mounted) return;
    setState(() {});
    await _openMedia(live);
  }

  static final _mediaKeys = {
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
  };

  void _togglePlay(bool playing) {
    if (playing) {
      if (_isLive && !_inCatchup) _livePausedAt = DateTime.now();
      _player.pause();
      return;
    }
    final pausedAt = _livePausedAt;
    _livePausedAt = null;
    if (_inCatchup) {
      _catchupCtl.resume();
      return;
    }
    if (pausedAt != null &&
        _currentChannel.hasCatchup &&
        DateTime.now().difference(pausedAt) > const Duration(seconds: 90)) {
      unawaited(_startCatchup(pausedAt));
      return;
    }
    _player.play();
  }

  void _toggleDataPool() {
    setState(() => _dataPoolOpen = !_dataPoolOpen);
    if (_dataPoolOpen) {
      debugPrint('DesktopDataPool: opened on ${_currentChannel.name}');
    }
  }

  void _skip(Duration amount) {
    if (_inCatchup) {
      unawaited(_catchupCtl.seekBy(amount));
      return;
    }
    final current = _player.state.position;
    var target = current + amount;
    if (target < Duration.zero) target = Duration.zero;
    final duration = _player.state.duration;
    if (duration > Duration.zero && target > duration) target = duration;
    _player.seek(target);
  }

  Future<void> _openRecallPicker() async {
    final history = _DesktopLiveHistory.recentExcluding(_currentChannel.id);
    final chosen = await showModalBottomSheet<Channel>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: RefinedFinish.decorate(
              context,
              BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              )),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  tr('Recall — recently watched'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr('No other live channels watched yet this session.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )
              else
                ...history.map((c) => GlassFocusFrame(
                        child: ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.tv, color: Colors.white54, size: 20),
                      title: Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      onTap: () => Navigator.of(sheetContext).pop(c),
                    ))),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) _switchTo(chosen);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// The player bar, one row like the Android player's (1.0.18): title on
  /// the left, buttons centred (scaled down to fit, never more than 60 % of
  /// the width), time on the right; a slim seek bar above it for VOD. Live
  /// shows what's left of the programme instead of a seek bar — never from
  /// the stream's own duration (a DVR window looked like a ~30 s file).
  /// Catch-up's scrub bar: the programme at the playhead in clock times
  /// (its start .. end), else the request's own length. Seeking past what
  /// the stream holds asks a new request (DesktopCatchup.seekTo).
  Widget _catchupBar() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, _) {
        final ctl = _catchupCtl;
        final s = ctl.session, at = ctl.playhead;
        if (s == null || at == null) return const SizedBox(height: 24);
        final programme = ctl.programme;
        final start = programme?.start ?? s.requestStart;
        final end = programme?.stop ??
            s.requestStart.add(_player.state.duration > Duration.zero
                ? _player.state.duration
                : const Duration(hours: 1));
        final total = end.difference(start).inSeconds.clamp(1, 1 << 30);
        final value = at.difference(start).inSeconds.clamp(0, total);
        final clock = TimeFormat.hm;
        return Row(
          children: [
            Text(clock.format(start.toLocal()),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Expanded(
              child: SizedBox(
                height: 24,
                child: Slider(
                  value: value.toDouble(),
                  max: total.toDouble(),
                  onChanged: (v) => unawaited(
                      ctl.seekTo(start.add(Duration(seconds: v.round())))),
                ),
              ),
            ),
            Text(clock.format(end.toLocal()),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildBar(PlaylistManager playlist) {
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      initialData: _player.state.playing,
      builder: (context, playingSnapshot) {
        final playing = playingSnapshot.data ?? false;
        final width = MediaQuery.sizeOf(context).width;
        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recall goes furthest left: it means *backward*.
            if (_isLive && !_inCatchup)
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: tr('Recall — go back to a recent channel'),
                onPressed: _openRecallPicker,
              ),
            IconButton(
              icon: Icon(
                _currentChannel.isFavorite ? Icons.star : Icons.star_border,
                color: _currentChannel.isFavorite ? Colors.amber : Colors.white,
              ),
              tooltip: _currentChannel.isFavorite
                  ? tr('Remove from favorites')
                  : tr('Add to favorites'),
              onPressed: () {
                playlist.toggleFavorite(_currentChannel);
                setState(() {});
              },
            ),
            if (_inCatchup)
              TextButton.icon(
                icon: const Icon(Icons.fiber_manual_record,
                    color: Colors.redAccent, size: 14),
                label: Text(tr('LIVE'),
                    style: const TextStyle(color: Colors.white)),
                onPressed: () => unawaited(_catchupCtl.backToLive()),
              ),
            if (_isLive && !_inCatchup)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: tr('Reload channel'),
                onPressed: _reload,
              ),
            if (_isLive && !_inCatchup)
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: tr('Sources'),
                onPressed: _openLiveSources,
              ),
            if (_isLive && !_inCatchup)
              IconButton(
                icon: const Icon(Icons.grid_view, color: Colors.white),
                tooltip: tr('Multiview'),
                onPressed: _openMultiview,
              ),
            // Back keeps a live channel playing in the guide's preview;
            // Stop ends it (Windows user, 2026-11-14).
            if (_isLive)
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white),
                tooltip: tr('Stop playback'),
                onPressed: _stopAndClose,
              ),
            if (_previousEpisode != null)
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                tooltip: tr('Previous episode'),
                onPressed: () => _switchTo(_previousEpisode!),
              ),
            if (!_isLive || _inCatchup)
              IconButton(
                tooltip: tr('Back 10 seconds'),
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () => _skip(const Duration(seconds: -10)),
              ),
            IconButton(
              focusNode: _playPauseFocus,
              tooltip: playing ? tr('Pause') : tr('Play'),
              iconSize: 40,
              color: Colors.white,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => _togglePlay(playing),
            ),
            if (!_isLive || _inCatchup)
              IconButton(
                tooltip: tr('Forward 10 seconds'),
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () => _skip(const Duration(seconds: 10)),
              ),
            if (_nextEpisode != null)
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                tooltip: tr('Next episode'),
                onPressed: () => _switchTo(_nextEpisode!),
              ),
            if (context.watch<AppPreferences>().dataPool)
              IconButton(
                icon: Icon(Icons.analytics_outlined,
                    color: _dataPoolOpen ? Colors.amber : Colors.white),
                tooltip: tr('Data pool'),
                onPressed: _toggleDataPool,
              ),
            DesktopAudioButton(
                // A new stream is a new track list.
                key: ValueKey('audio-${_currentChannel.id}'),
                player: _player,
                channel: _currentChannel),
            // Live too: a channel's closed captions (CC) go on and off here
            // (an Apple TV viewer had them on with no way to turn them off).
            DesktopSubtitleButton(
                // A new episode is a new file: fresh track list.
                key: ValueKey(_currentChannel.id),
                player: _player,
                channel: _currentChannel),
            // The TV's own remote sets the volume; the slider would also
            // keep Left / Right for itself.
            if (!_tv) _DesktopVolume(player: _player),
          ],
        );
        final ring = Theme.of(context).colorScheme.primary;
        // A ring in the theme's colour on the focused button: the default
        // focus tint was a faint grey circle, invisible over a picture
        // from the couch.
        ButtonStyle focusRing(ButtonStyle? base) =>
            (base ?? const ButtonStyle()).copyWith(
              side: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.focused)
                      ? BorderSide(color: ring, width: 2)
                      : null),
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.focused) ? Colors.black54 : null),
            );
        final ringed = IconButtonTheme(
          data: IconButtonThemeData(
              style: focusRing(IconButtonTheme.of(context).style)),
          child: TextButtonTheme(
            data: TextButtonThemeData(
                style: focusRing(TextButtonTheme.of(context).style)),
            child: buttons,
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_inCatchup) _catchupBar(),
            if (!_isLive)
              StreamBuilder<Duration>(
                stream: _player.stream.position,
                initialData: _player.state.position,
                builder: (context, posSnapshot) {
                  final position = posSnapshot.data ?? Duration.zero;
                  final duration = _player.state.duration;
                  final sliderMax = duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0;
                  return SizedBox(
                    height: 24,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: position.inMilliseconds
                            .clamp(0, sliderMax.toInt())
                            .toDouble(),
                        max: sliderMax,
                        onChanged: duration.inMilliseconds > 0
                            ? (v) =>
                                _player.seek(Duration(milliseconds: v.round()))
                            : null,
                      ),
                    ),
                  );
                },
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayerBarTitle(
                        title: _currentChannel.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: DesktopQualityBadges(
                            key: ValueKey('badges-${_currentChannel.id}'),
                            player: _player),
                      ),
                      if (_isLive &&
                          playlist
                              .playlistNameFor(_currentChannel.playlistId)
                              .trim()
                              .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GoldTag(
                              label: playlist
                                  .playlistNameFor(_currentChannel.playlistId)
                                  .trim()),
                        ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * 0.6),
                  child: FittedBox(fit: BoxFit.scaleDown, child: ringed),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _inCatchup
                        ? StreamBuilder<Duration>(
                            stream: _player.stream.position,
                            builder: (context, _) => Text(
                              _catchupCtl.playhead == null
                                  ? ''
                                  : TimeFormat.hm
                                      .format(_catchupCtl.playhead!.toLocal()),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          )
                        : _isLive
                            ? _LiveRemainingLabel(
                                channelId: _currentChannel.epgId)
                            : StreamBuilder<Duration>(
                                stream: _player.stream.position,
                                initialData: _player.state.position,
                                builder: (context, posSnapshot) => Text(
                                  '${_formatDuration(posSnapshot.data ?? Duration.zero)}'
                                  ' / ${_formatDuration(_player.state.duration)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Remote (Apple TV): Android TV's bottom bars, see [_tvOptions].
  List<Widget> _tvChrome(PlaylistManager playlist) {
    final liveBar = _isLive && !_inCatchup;
    final barShown = _controlsVisible || (liveBar && _tvZapInfo);
    return [
      // Catch-up: the channel card above the bar (Channel schedule), like
      // Android's.
      if (_inCatchup && _controlsVisible)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 48,
          left: 0,
          right: 0,
          child: Center(
            child: LiveChannelInfoCard(
              channel: _currentChannel,
              at: _catchupCtl.playhead,
              scheduleFocus: _scheduleChipFocus,
              onScheduleKey: _onScheduleChipKey,
              onSchedule: _openSchedule,
            ),
          ),
        ),
      if (barShown && !_tvOptions)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // A zap: display only, Up / Down keep changing channel.
          child: ExcludeFocus(
            excluding: !_controlsVisible,
            child: FocusTraversalGroup(
              child: FocusScope(
                node: _tvBarScope,
                child:
                    liveBar ? _tvInfoBar(playlist) : _tvTransportBar(playlist),
              ),
            ),
          ),
        ),
      if (_tvOptions)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FocusTraversalGroup(
            child: FocusScope(
              node: _tvOptionsScope,
              child: _tvOptionsRow(playlist),
            ),
          ),
        ),
    ];
  }

  /// Remote, live: Android's one bottom bar ([LiveInfoBar]).
  Widget _tvInfoBar(PlaylistManager playlist) => LiveInfoBar(
        title: _currentChannel.name,
        epgId: _currentChannel.epgId,
        channel: _currentChannel,
        buttons: _controlsVisible,
        isFavorite: _currentChannel.isFavorite,
        onToggleFavorite: () {
          playlist.toggleFavorite(_currentChannel);
          setState(() {});
        },
        onSchedule: _openSchedule,
        onActivity: _armTvBarIdle,
        badges: [
          DesktopQualityBadges(
              key: ValueKey('tv-badges-${_currentChannel.id}'),
              player: _player,
              gold: true),
        ],
        timeline: _TvLiveProgress(epgId: _currentChannel.epgId),
        playPause: StreamBuilder<bool>(
          stream: _player.stream.playing,
          initialData: _player.state.playing,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return LiveInfoBar.playPauseButton(
              playing: playing,
              focusNode: _playPauseFocus,
              onPressed: () {
                _armTvBarIdle();
                _togglePlay(playing);
              },
            );
          },
        ),
      );

  /// Remote, movie / episode / catch-up: Android's TV bar (title left,
  /// transport centred, badges and time right; the progress line above).
  Widget _tvTransportBar(PlaylistManager playlist) {
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      initialData: _player.state.playing,
      builder: (context, playingSnapshot) {
        final playing = playingSnapshot.data ?? false;
        final width = MediaQuery.sizeOf(context).width;
        final seekable = !_isLive || _inCatchup;
        var title = _currentChannel.name;
        if (_inCatchup) {
          final at = _catchupCtl.playhead;
          final on = at == null
              ? null
              : CatchupSession.programmeAt(
                  context.read<EpgService>().getPrograms(_currentChannel.epgId),
                  at);
          if (on != null) title = '${on.title} · $title';
        }
        final favourite = _currentChannel.isFavorite;
        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RingIconButton(
              icon: favourite ? Icons.star : Icons.star_border,
              color: favourite ? Colors.amber : Colors.white,
              tooltip: favourite
                  ? tr('Remove from favorites')
                  : tr('Add to favorites'),
              onPressed: () {
                playlist.toggleFavorite(_currentChannel);
                setState(() {});
              },
            ),
            if (_previousEpisode != null)
              RingIconButton(
                icon: Icons.skip_previous,
                tooltip: tr('Previous episode'),
                onPressed: () => _switchTo(_previousEpisode!),
              ),
            if (_inCatchup) ...[
              RingIconButton(
                icon: Icons.skip_previous,
                tooltip: tr('Previous programme'),
                onPressed: () => _catchupJump(-1),
              ),
              RingIconButton(
                icon: Icons.restart_alt,
                tooltip: tr('Watch from the start'),
                onPressed: () => _catchupJump(0),
              ),
            ],
            if (seekable)
              SkipHoldButton(
                icon: Icons.replay_10,
                onSeek: (amount) {
                  _armTvBarIdle();
                  _skip(-amount);
                },
              ),
            RingIconButton(
              focusNode: _playPauseFocus,
              icon: playing ? Icons.pause : Icons.play_arrow,
              tooltip: playing ? tr('Pause') : tr('Play'),
              onPressed: () => _togglePlay(playing),
            ),
            if (seekable)
              SkipHoldButton(
                icon: Icons.forward_10,
                onSeek: (amount) {
                  _armTvBarIdle();
                  _skip(amount);
                },
              ),
            if (_nextEpisode != null)
              RingIconButton(
                icon: Icons.skip_next,
                tooltip: tr('Next episode'),
                onPressed: () => _switchTo(_nextEpisode!),
              ),
            if (_inCatchup) ...[
              RingIconButton(
                icon: Icons.skip_next,
                tooltip: tr('Next programme'),
                onPressed: () => _catchupJump(1),
              ),
              BackToLiveButton(
                  onPressed: () => unawaited(_catchupCtl.backToLive())),
            ],
          ],
        );
        final titleCell = Expanded(
          child: _inCatchup
              ? Row(children: [
                  GoldTag(
                      label: tr('Catch-up').toUpperCase(),
                      margin: const EdgeInsets.only(right: 6)),
                  Expanded(child: PlayerBarTitle(title: title)),
                ])
              : PlayerBarTitle(title: title),
        );
        const timeStyle = TextStyle(color: Colors.white70, fontSize: 12);
        final side = Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DesktopQualityBadges(
                  key: ValueKey('tv-badges-${_currentChannel.id}'),
                  player: _player),
              const SizedBox(width: 8),
              Flexible(
                child: StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: _player.state.position,
                  builder: (context, snapshot) {
                    final String text;
                    if (_inCatchup) {
                      final at = _catchupCtl.playhead;
                      if (at == null) return const SizedBox.shrink();
                      final behind = DateTime.now().difference(at);
                      final h = behind.inHours;
                      final m = behind.inMinutes % 60;
                      final lag = h > 0
                          ? '$h:${m.toString().padLeft(2, '0')}'
                          : '$m min';
                      text = '${TimeFormat.hm.format(at.toLocal())} · '
                          '${tr('{time} behind live', {'time': lag})}';
                    } else {
                      text =
                          '${_formatDuration(snapshot.data ?? Duration.zero)}'
                          ' / ${_formatDuration(_player.state.duration)}';
                    }
                    return Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: timeStyle);
                  },
                ),
              ),
            ],
          ),
        );
        return Container(
          color: RefinedFinish.surface(context, Colors.black54),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Android's scrub bar: Up from the buttons, Left / Right move
              // a target, one seek.
              if (!_isLive || _inCatchup) _tvScrubBar(),
              Row(children: [
                titleCell,
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * 0.6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(visualDensity: VisualDensity.compact),
                      child: buttons,
                    ),
                  ),
                ),
                side,
              ]),
            ],
          ),
        );
      },
    );
  }

  /// What the remote seeks in: a movie / episode's own length, or the
  /// catch-up programme at the playhead ([start] = its clock time).
  ({Duration position, Duration duration, DateTime? start})? get _seekRange {
    if (_inCatchup) {
      final ctl = _catchupCtl;
      final s = ctl.session, at = ctl.playhead;
      if (s == null || at == null) return null;
      final programme = ctl.programme;
      final start = programme?.start ?? s.requestStart;
      final end = programme?.stop ??
          s.requestStart.add(_player.state.duration > Duration.zero
              ? _player.state.duration
              : const Duration(hours: 1));
      return (
        position: at.difference(start),
        duration: end.difference(start),
        start: start
      );
    }
    if (_isLive) return null;
    final duration = _player.state.duration;
    if (duration <= Duration.zero) return null;
    return (position: _player.state.position, duration: duration, start: null);
  }

  /// A seek inside [_seekRange]: catch-up asks the programme's time.
  void _seekTo(Duration to) {
    final range = _seekRange;
    if (range == null) return;
    if (range.start case final start?) {
      unawaited(_catchupCtl.seekTo(start.add(to)));
    } else {
      unawaited(_player.seek(to));
    }
  }

  /// Remote, movie / episode / catch-up: Android's scrub bar ([ScrubBar]).
  Widget _tvScrubBar() => StreamBuilder<Duration>(
        stream: _player.stream.position,
        initialData: _player.state.position,
        builder: (context, _) {
          final range = _seekRange;
          if (range == null) return const SizedBox(height: 24);
          return ScrubBar(
            onSeek: _seekTo,
            position: range.position,
            duration: range.duration,
            onActivity: _armTvBarIdle,
          );
        },
      );

  /// Live rewind: past catch-up's 90 s live edge from the first press.
  static int _liveStepMinutes(int steps) => steps == 0
      ? 2
      : steps < 4
          ? 1
          : steps < 8
              ? 5
              : 15;

  /// See [_skipTarget].
  void _tvSkipKey(int sign, {bool repeat = false}) {
    if (_panelOpen || _scheduleOpen) return;
    final range = _seekRange;
    if (range != null) {
      if (_skipLive) _skipTarget = null;
      _skipLive = false;
      final step = _scrubSteps.next(repeat: repeat);
      if (step == null) return;
      final next = (_skipTarget ?? range.position) + step * sign;
      _skipTarget = next < Duration.zero
          ? Duration.zero
          : next > range.duration
              ? range.duration
              : next;
    } else {
      final live = _currentChannel;
      if (sign > 0 || !live.isLive || !live.hasCatchup) return;
      if (!_skipLive) _skipTarget = null;
      _skipLive = true;
      final back = (_skipTarget ?? Duration.zero) +
          Duration(minutes: _liveStepMinutes(_skipSteps++));
      final most = Duration(days: live.catchupDays);
      _skipTarget = back > most ? most : back;
    }
    setState(() {});
    _skipCommit?.cancel();
    _skipCommit = Timer(const Duration(milliseconds: 700), _commitTvSkip);
  }

  void _commitTvSkip() {
    _skipCommit?.cancel();
    final target = _skipTarget;
    final live = _skipLive;
    _skipTarget = null;
    _skipSteps = 0;
    _scrubSteps.reset();
    if (mounted) setState(() {});
    if (target == null || !mounted) return;
    if (live) {
      unawaited(_startCatchup(DateTime.now().subtract(target),
          toProgrammeEnd: false));
      return;
    }
    _seekTo(target);
  }

  /// See [_tvError]. mpv reports errors it gets past by itself too: only
  /// one that leaves the movie without a picture 4 s later counts.
  void _onPlayerError(String message) {
    if (!_tvRemote || _isLive || !mounted) return;
    final at = _player.state.position;
    _errorCheck?.cancel();
    _errorCheck = Timer(const Duration(seconds: 4), () {
      if (!mounted || _isLive) return;
      final state = _player.state;
      if (state.width != null || state.position > at) return;
      setState(() => _tvError = _withoutLinks(message));
    });
  }

  /// Error text without the stream's links (they can hold the viewer's
  /// user name and password, and users post photos of the screen).
  static String _withoutLinks(String raw) => raw.replaceAllMapped(
          RegExp(r'[a-z][a-z0-9+.-]*://\S+', caseSensitive: false), (m) {
        final host = Uri.tryParse(m[0]!)?.host ?? '';
        return host.isEmpty ? '<link>' : '<$host>';
      });

  /// Android's error screen (VideoPlayerPane): what went wrong, then the
  /// technical details for a photo.
  Widget _tvErrorView(String error) => Positioned.fill(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyPlaybackError(error),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                Text(tr('Technical details'),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );

  /// Remote, "early" Up Next: the next episode 30 s before the end, like
  /// Android's PlaybackService.
  void _checkUpNext(Duration position) {
    if (!mounted || !_tvRemote || _isLive) return;
    final next = _nextEpisode;
    final id = _currentChannel.id;
    if (next == null || _upNextDismissed == id || _upNextFrom == id) return;
    if (context.read<StorageService>().getUpNextMode() != 'early') return;
    final duration = _player.state.duration;
    if (duration <= Duration.zero) return;
    final remaining = duration - position;
    if (remaining > const Duration(seconds: 30) || remaining.isNegative) {
      return;
    }
    _upNextFrom = id;
    debugPrint('DesktopPlayer: Up next, 30 s before the end');
    unawaited(_switchTo(next));
  }

  /// Remote: Android's options row ([PlayerOptionsPill]), same tiles in the
  /// same order where this player has them (no Buffer: Android's player
  /// only).
  Widget _tvOptionsRow(PlaylistManager playlist) {
    final prefs = context.watch<AppPreferences>();
    final epg = context.watch<EpgService>();
    final live = _isLive && !_inCatchup;
    String? programme;
    if (_inCatchup) {
      final at = _catchupCtl.playhead;
      programme = at == null
          ? null
          : CatchupSession.programmeAt(
                  epg.getPrograms(_currentChannel.epgId), at)
              ?.title;
    } else if (_isLive) {
      programme = epg.getCurrentProgram(_currentChannel.epgId)?.title;
    }
    Widget tile(IconData icon, String label, VoidCallback onPressed,
            {String? shortLabel, String? detail}) =>
        LabeledIconButton(
          icon: icon,
          label: label,
          shortLabel: shortLabel,
          detail: detail,
          onPressed: () {
            _armTvBarIdle();
            onPressed();
          },
        );
    final delay = prefs.audioDelayMs;
    final link = playlist.channelLinkFor(_currentChannel);
    final linked = link == null ? null : playlist.resolveChannelLink(link);
    return PlayerOptionsPill(
      live: live,
      catchup: _inCatchup,
      title: OptionsTitleText(name: _currentChannel.name, programme: programme),
      sound: _TvSoundSummary(
          key: ValueKey('tv-sound-${_currentChannel.id}'), player: _player),
      tiles: [
        if (_isLive) tile(Icons.list, tr('Channels'), _openPanel),
        if (live) tile(Icons.swap_horiz, tr('Sources'), _openLiveSources),
        if (prefs.dataPool)
          tile(Icons.analytics_outlined, tr('Stream info'), _showTvDataPool),
        if (live)
          tile(Icons.history, tr('Recall — go back to a recent channel'),
              _openRecallPicker,
              shortLabel: tr('Recent')),
        if (live && _currentChannel.hasCatchup)
          tile(Icons.restart_alt, tr('Watch from the start'), _startOver,
              shortLabel: tr('Start over')),
        if (live)
          tile(Icons.refresh, tr('Reload channel'), _reload,
              shortLabel: tr('Reload')),
        DesktopAudioButton(
            key: ValueKey('tv-audio-${_currentChannel.id}'),
            player: _player,
            channel: _currentChannel,
            tile: (open) => tile(
                Icons.multitrack_audio, tr('Audio track'), open,
                shortLabel: tr('Audio'))),
        DesktopSubtitleButton(
            key: ValueKey('tv-subs-${_currentChannel.id}'),
            player: _player,
            channel: _currentChannel,
            tile: (open) => tile(Icons.subtitles, tr('Subtitles'), open)),
        tile(Icons.av_timer, tr('Audio sync'),
            () => showAudioDelayAdjuster(context),
            detail: delay == 0
                ? null
                : '${delay > 0 ? '+' : '-'}${delay.abs()} ms'),
        if (linked != null)
          tile(
              Icons.swap_horiz,
              tr('Switch to {playlistName}: {name}', {
                'playlistName': playlist.playlistNameFor(linked.playlistId),
                'name': linked.name
              }),
              () => _switchTo(linked),
              shortLabel: playlist.playlistNameFor(linked.playlistId)),
        if (live && !prefs.hideMultiview)
          tile(Icons.grid_view, tr('Open in Multiview'), _openMultiview,
              shortLabel: tr('Multiview')),
        if (widget.sources != null)
          tile(Icons.swap_horiz, tr('Sources'), _openSources),
        tile(prefs.videoFit.icon, tr(prefs.videoFit.label), _cycleFit),
        tile(Icons.search, tr('Search'), _openTvSearch),
      ],
    );
  }

  /// iPhone / iPad. The computer bar squeezed into a portrait phone was a
  /// strip of tiny overlapping buttons (owner's iPhone 8, 2026-11-09), and
  /// Sources only opened with the Right key. Touch gets a phone layout:
  /// back, title, Sources and Rotate on top; big play/pause and +-10 s in
  /// the middle; seek bar, badges and the other buttons at full touch size
  /// along the bottom. No volume slider: the phone has its own buttons.
  List<Widget> _touchControls(PlaylistManager playlist) {
    final seekable = !_isLive || _inCatchup;
    final prefs = context.watch<AppPreferences>();
    final playlistName = _isLive
        ? playlist.playlistNameFor(_currentChannel.playlistId).trim()
        : '';
    // Any touch on the controls keeps them up another 4 s.
    Widget keepUp(Widget child) =>
        Listener(onPointerDown: (_) => _armTouchHide(), child: child);
    final info = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DesktopQualityBadges(
            key: ValueKey('badges-${_currentChannel.id}'), player: _player),
        if (playlistName.isNotEmpty) GoldTag(label: playlistName),
        // Its Align would take a whole line of the Wrap.
        if (_isLive && !_inCatchup)
          IntrinsicWidth(
              child: _LiveRemainingLabel(channelId: _currentChannel.epgId)),
      ],
    );
    final buttons = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
          mainAxisSize: MainAxisSize.min, children: _touchButtons(playlist)),
    );
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: keepUp(Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: tr('Back'),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBack,
                ),
                Expanded(
                  child: PlayerBarTitle(
                    title: _currentChannel.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.sources != null)
                  IconButton(
                    tooltip: tr('Sources'),
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    onPressed: _openSources,
                  )
                else if (_isLive && !_inCatchup)
                  IconButton(
                    tooltip: tr('Sources'),
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    onPressed: _openLiveSources,
                  ),
                if (IosPip.available && !_inCatchup)
                  IconButton(
                    tooltip: tr('Picture-in-picture'),
                    icon: const Icon(Icons.picture_in_picture_alt,
                        color: Colors.white),
                    onPressed: _startPip,
                  ),
                IconButton(
                  tooltip: tr(prefs.videoFit.label),
                  icon: Icon(prefs.videoFit.icon, color: Colors.white),
                  onPressed: _cycleFit,
                ),
                IconButton(
                  tooltip: tr('Rotate'),
                  icon: const Icon(Icons.screen_rotation, color: Colors.white),
                  onPressed: _toggleRotation,
                ),
              ],
            ),
          ),
        )),
      ),
      Center(
        child: keepUp(StreamBuilder<bool>(
          stream: _player.stream.playing,
          initialData: _player.state.playing,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seekable) ...[
                  _TouchRoundButton(
                    icon: Icons.replay_10,
                    size: 32,
                    tooltip: tr('Back 10 seconds'),
                    onPressed: () => _skip(const Duration(seconds: -10)),
                  ),
                  const SizedBox(width: 40),
                ],
                _TouchRoundButton(
                  icon: playing ? Icons.pause : Icons.play_arrow,
                  size: 48,
                  tooltip: playing ? tr('Pause') : tr('Play'),
                  onPressed: () => _togglePlay(playing),
                ),
                if (seekable) ...[
                  const SizedBox(width: 40),
                  _TouchRoundButton(
                    icon: Icons.forward_10,
                    size: 32,
                    tooltip: tr('Forward 10 seconds'),
                    onPressed: () => _skip(const Duration(seconds: 10)),
                  ),
                ],
              ],
            );
          },
        )),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: keepUp(Container(
          padding: const EdgeInsets.fromLTRB(12, 32, 8, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_inCatchup) _catchupBar(),
                if (!_isLive) _touchSeekBar(),
                LayoutBuilder(
                  // Landscape: badges and buttons share a row. Portrait:
                  // the buttons get their own row.
                  builder: (context, box) => box.maxWidth >= 560
                      ? Row(children: [
                          Expanded(child: info),
                          Flexible(child: buttons),
                        ])
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            info,
                            Align(
                                alignment: Alignment.centerRight,
                                child: buttons),
                          ],
                        ),
                ),
              ],
            ),
          ),
        )),
      ),
      if (_isLive && !_inCatchup && !_panelOpen)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Center(child: PlayerSidePanelTab(onTap: _openPanel)),
        ),
    ];
  }

  /// Touch: the bottom row's buttons (play/pause and +-10 s are in the
  /// middle of the screen).
  List<Widget> _touchButtons(PlaylistManager playlist) => [
        if (_isLive && !_inCatchup)
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: tr('Recall — go back to a recent channel'),
            onPressed: _openRecallPicker,
          ),
        IconButton(
          icon: Icon(
            _currentChannel.isFavorite ? Icons.star : Icons.star_border,
            color: _currentChannel.isFavorite ? Colors.amber : Colors.white,
          ),
          tooltip: _currentChannel.isFavorite
              ? tr('Remove from favorites')
              : tr('Add to favorites'),
          onPressed: () {
            playlist.toggleFavorite(_currentChannel);
            setState(() {});
          },
        ),
        if (_isLive)
          IconButton(
            icon: const Icon(Icons.event_note, color: Colors.white),
            tooltip: tr('Channel schedule'),
            onPressed: _openSchedule,
          ),
        if (_inCatchup)
          TextButton.icon(
            icon: const Icon(Icons.fiber_manual_record,
                color: Colors.redAccent, size: 14),
            label:
                Text(tr('LIVE'), style: const TextStyle(color: Colors.white)),
            onPressed: () => unawaited(_catchupCtl.backToLive()),
          ),
        if (_isLive && !_inCatchup)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: tr('Reload channel'),
            onPressed: _reload,
          ),
        if (_previousEpisode != null)
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            tooltip: tr('Previous episode'),
            onPressed: () => _switchTo(_previousEpisode!),
          ),
        if (_nextEpisode != null)
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            tooltip: tr('Next episode'),
            onPressed: () => _switchTo(_nextEpisode!),
          ),
        if (context.watch<AppPreferences>().dataPool)
          IconButton(
            icon: Icon(Icons.analytics_outlined,
                color: _dataPoolOpen ? Colors.amber : Colors.white),
            tooltip: tr('Data pool'),
            onPressed: _toggleDataPool,
          ),
        DesktopAudioButton(
            key: ValueKey('audio-${_currentChannel.id}'),
            player: _player,
            channel: _currentChannel),
        // Live too: closed captions (CC) on / off.
        DesktopSubtitleButton(
            key: ValueKey(_currentChannel.id),
            player: _player,
            channel: _currentChannel),
      ];

  /// Touch: elapsed | seek bar | length. Dragging moves the thumb; the
  /// seek happens on release (one seek, not one per finger move).
  Widget _touchSeekBar() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      initialData: _player.state.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;
        final known = duration.inMilliseconds > 0;
        final max = known ? duration.inMilliseconds.toDouble() : 1.0;
        final value = (_dragMs ?? position.inMilliseconds.toDouble())
            .clamp(0.0, max)
            .toDouble();
        const time = TextStyle(color: Colors.white70, fontSize: 13);
        return Row(
          children: [
            Text(_formatDuration(Duration(milliseconds: value.round())),
                style: time),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: value,
                  max: max,
                  onChanged: known ? (v) => setState(() => _dragMs = v) : null,
                  onChangeEnd: known
                      ? (v) {
                          setState(() => _dragMs = null);
                          unawaited(
                              _player.seek(Duration(milliseconds: v.round())));
                          _armTouchHide();
                        }
                      : null,
                ),
              ),
            ),
            Text(_formatDuration(duration), style: time),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistManager>();
    final playerClock =
        context.select<AppPreferences, bool>((p) => p.playerClock);
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      // Every Back (Esc / Backspace via DesktopBackKey, the system's) goes
      // through _handleBack, so a live channel is handed to the mini player
      // like the top-left arrow does: a plain pop stopped it. The side
      // panel and the schedule close first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _sourceBackGuard.blocksBack) return;
        if (_scheduleOpen) {
          _closeSchedule();
        } else if (_panelOpen) {
          _closePanel();
        } else if (_tvRemote && _tvOptions) {
          _closeTvOptions();
        } else if (_tvRemote && _scheduleChipFocus.hasFocus) {
          _playPauseFocus.requestFocus();
        } else if (!_touch &&
            _rootFocus.hasFocus &&
            !_rootFocus.hasPrimaryFocus) {
          // Arrowing along the bar (Enter put focus there): Back first
          // returns to the picture, where Up / Down change channel.
          _stopZapHud();
          setState(() => _controlsVisible = false);
          _rootFocus.requestFocus();
        } else {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: (_, event) {
            // Remote: any key while the bar has focus keeps it up.
            if (_tv && event is KeyDownEvent && !_rootFocus.hasPrimaryFocus) {
              _armTvBarIdle();
            }
            // Remote, Up / Down in the bar or the options row (Android's
            // flow): Down from the bar = the options row, Up there = the
            // bar; catch-up: Up from the bar = the card's Channel schedule.
            if (_tvRemote &&
                event is! KeyUpEvent &&
                !_rootFocus.hasPrimaryFocus &&
                (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.logicalKey == LogicalKeyboardKey.arrowDown)) {
              final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
              final press = event is KeyDownEvent;
              if (_tvOptionsScope.hasFocus) {
                if (press && up) _closeTvOptions();
                return KeyEventResult.handled;
              }
              if (_tvBarScope.hasFocus) {
                if (press &&
                    !_tryTvBarMove(
                        up ? TraversalDirection.up : TraversalDirection.down)) {
                  if (!up) {
                    _openTvOptions();
                  } else if (_inCatchup && _scheduleChipFocus.context != null) {
                    _scheduleChipFocus.requestFocus();
                  }
                }
                return KeyEventResult.handled;
              }
            }
            if (event is KeyDownEvent &&
                _rootFocus.hasPrimaryFocus &&
                _currentChannel.mediaFileInfo != null &&
                [
                  LogicalKeyboardKey.select,
                  LogicalKeyboardKey.enter,
                  LogicalKeyboardKey.numpadEnter
                ].contains(event.logicalKey)) {
              _fileInfoRequests.value++;
              // A remote has no other way into the bar: OK opens it too
              // (below).
              if (!_tv) return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowRight &&
                _rootFocus.hasPrimaryFocus &&
                widget.sources != null) {
              _openSources();
              return KeyEventResult.handled;
            }
            // Remote, live: Right = the channel watched before (Android's
            // default for Right).
            if (_tvRemote &&
                event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowRight &&
                _rootFocus.hasPrimaryFocus &&
                _isLive &&
                !_inCatchup &&
                !_panelOpen &&
                !_scheduleOpen) {
              _lastChannel();
              return KeyEventResult.handled;
            }
            // I = Data pool (when it's on in Settings > Playback).
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyI &&
                context.read<AppPreferences>().dataPool) {
              _toggleDataPool();
              return KeyEventResult.handled;
            }
            // M = mute / unmute, like most desktop players.
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyM) {
              _DesktopVolume.toggleMute(context, _player);
              return KeyEventResult.handled;
            }
            // Space and the keyboard's media keys: play / pause, like most
            // desktop players (owner, 2026-11-14). Space on a focused bar
            // button still presses that button.
            if (event is KeyDownEvent &&
                (_mediaKeys.contains(event.logicalKey) ||
                    (event.logicalKey == LogicalKeyboardKey.space &&
                        _rootFocus.hasPrimaryFocus))) {
              final playing = _player.state.playing;
              final key = event.logicalKey;
              if (!(key == LogicalKeyboardKey.mediaPlay && playing) &&
                  !(key == LogicalKeyboardKey.mediaPause && !playing)) {
                _togglePlay(playing);
                _flashControls();
              }
              return KeyEventResult.handled;
            }
            // Fast forward / Rewind. A remote (Apple TV): Android's, a target
            // in the middle and one seek ([_tvSkipKey]). A keyboard: 10 s,
            // like the bar's buttons (movies, episodes, catch-up).
            if (event is! KeyUpEvent &&
                (event.logicalKey == LogicalKeyboardKey.mediaFastForward ||
                    event.logicalKey == LogicalKeyboardKey.mediaRewind)) {
              final sign =
                  event.logicalKey == LogicalKeyboardKey.mediaFastForward
                      ? 1
                      : -1;
              if (_tvRemote) {
                _tvSkipKey(sign, repeat: event is KeyRepeatEvent);
              } else if (!_isLive || _inCatchup) {
                _skip(Duration(seconds: 10 * sign));
                _flashControls();
              }
              return KeyEventResult.handled;
            }
            // Remote, on the picture (Android's arrows): a movie / episode
            // = Left goes back like Rewind (the Siri Remote has none; owner,
            // 2026-11-20), Right = its sources (above) or nothing; catch-up
            // = Left the side panel, Right the last channel; Up / Down on a
            // movie open the bar like OK.
            if (_tv &&
                event is! KeyUpEvent &&
                _rootFocus.hasPrimaryFocus &&
                !_panelOpen &&
                !_scheduleOpen) {
              final key = event.logicalKey;
              final press = event is KeyDownEvent;
              if (!_isLive && key == LogicalKeyboardKey.arrowLeft) {
                _tvSkipKey(-1, repeat: event is KeyRepeatEvent);
                return KeyEventResult.handled;
              }
              if (!_isLive && key == LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.handled;
              }
              if (_inCatchup && key == LogicalKeyboardKey.arrowLeft) {
                if (press) _openPanel();
                return KeyEventResult.handled;
              }
              if (_inCatchup && key == LogicalKeyboardKey.arrowRight) {
                if (press) _lastChannel();
                return KeyEventResult.handled;
              }
              if (!_isLive &&
                  (key == LogicalKeyboardKey.arrowUp ||
                      key == LogicalKeyboardKey.arrowDown)) {
                if (event is KeyDownEvent) _showBarFocused();
                return KeyEventResult.handled;
              }
            }
            final zap = _zapKeys[event.logicalKey];
            if (zap != null &&
                event is! KeyUpEvent &&
                // Not while arrowing along the player bar's buttons.
                _rootFocus.hasPrimaryFocus &&
                _isLive &&
                !_panelOpen &&
                !_scheduleOpen &&
                !_inPip &&
                !_pipStarting) {
              // One channel per press: a held key's repeats would open a
              // stream per repeat.
              if (event is KeyDownEvent) _zapChannel(zap);
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                !_touch &&
                (_isLive || _tv) &&
                _rootFocus.hasPrimaryFocus &&
                !_panelOpen &&
                !_scheduleOpen &&
                [
                  LogicalKeyboardKey.select,
                  LogicalKeyboardKey.enter,
                  LogicalKeyboardKey.numpadEnter
                ].contains(event.logicalKey)) {
              _showBarFocused();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                // Not while arrowing along the player bar's buttons.
                _rootFocus.hasPrimaryFocus &&
                _isLive &&
                !_inCatchup &&
                !_panelOpen) {
              _openPanel();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              if (_panelOpen) {
                _closePanel();
                return;
              }
              if (_currentChannel.mediaFileInfo != null) {
                _fileInfoRequests.value++;
              }
              _stopZapHud();
              setState(() => _controlsVisible = !_controlsVisible);
              _armTouchHide();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // NoVideoControls — Video defaults to its own built-in
                // AdaptiveVideoControls overlay (play/pause, seek bar, and
                // its own fullscreen toggle). Left on, that showed up as a
                // second player bar stacked on top of this screen's own,
                // and its fullscreen button entered real native-window
                // fullscreen with no way back to this screen's back
                // button (which isn't part of that overlay at all) short of
                // closing the app. This screen's own overlay below is the
                // only controls surface.
                _video(context.watch<AppPreferences>()),
                if (!_inPip && !_pipStarting)
                  Positioned(
                    top: 64,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _fitPillVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(child: _FitPill(fit: _fitPill)),
                      ),
                    ),
                  ),
                DesktopReconnectingBadge(
                    recovery: DesktopLiveRecovery.of(_player)),
                if (_inPip || _pipStarting) _pipNotice(),
                Builder(builder: (context) {
                  final storage = context.read<StorageService>();
                  _segments.attachDesktop(_player, _currentChannel.id,
                      enabled: storage.getSkipSegments(),
                      episodeCandidate:
                          !_isLive && !_currentChannel.transientPlayback,
                      tmdbKey: storage.getTmdbApiKey());
                  return SkipSegmentButton(
                    watcher: _segments,
                    controlsVisible: _controlsVisible,
                    hasNext: _nextEpisode != null,
                    hint: SkipHint.none,
                    onSkip: _skipSegment,
                  );
                }),
                if (!_inPip && !_pipStarting)
                  WatchGameButton(
                    offer: _watchOffer,
                    // Above the player bar while it shows (the touch
                    // layout's bottom bar is taller).
                    bottom: _tvRemote
                        ? (_tvChromeShown
                            ? PlayerControls.liveInfoBarHeight + 8
                            : 28)
                        : _controlsVisible
                            ? (_touch ? 150 : 120)
                            : 28,
                    showUpHint: false,
                    onWatch: _watchGame,
                    focusNode: _watchFocus,
                  ),
                // While PiP has the stream, mpv is stopped: its controls
                // would do nothing ([_pipNotice] has Back and Watch here).
                if (_controlsVisible && _touch && !_inPip && !_pipStarting)
                  ..._touchControls(playlist),
                if (_controlsVisible && !_touch && !_tvRemote) ...[
                  // Not on a TV: the remote's Back (Menu) does it, and
                  // Up from the bar landed on it.
                  if (!_tv)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: tr('Back'),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: _handleBack,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: _buildBar(playlist),
                    ),
                  ),
                  if (_isLive && !_inCatchup && !_panelOpen)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      // A remote opens the panel with Left on the picture;
                      // the tab is a picture of that, not a focus stop.
                      child: Center(
                        child: ExcludeFocus(
                            excluding: _tv,
                            child: PlayerSidePanelTab(onTap: _openPanel)),
                      ),
                    ),
                ],
                if (_tvRemote && !_inPip) ...[
                  if (_tvError case final error?)
                    _tvErrorView(error)
                  else
                    DesktopBufferingSpinner(player: _player),
                  if (!_isLive)
                    UpNextBubble(
                      mode: context.read<StorageService>().getUpNextMode(),
                      progress: () => (
                        position: _player.state.position,
                        duration: _player.state.duration
                      ),
                      nextChannel: _upNextDismissed == _currentChannel.id
                          ? null
                          : _nextEpisode,
                      onPlayNow: () {
                        final next = _nextEpisode;
                        if (next == null) return;
                        _upNextFrom = _currentChannel.id;
                        unawaited(_switchTo(next));
                      },
                      onDismiss: () =>
                          setState(() => _upNextDismissed = _currentChannel.id),
                    ),
                ],
                if (_tvRemote) ..._tvChrome(playlist),
                if (_tvRemote && _skipTarget != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: SkipCue(
                          target: _skipTarget!,
                          live: _skipLive,
                          position: _seekRange?.position ?? Duration.zero,
                          duration: _seekRange?.duration ?? Duration.zero,
                        ),
                      ),
                    ),
                  ),
                if (_dataPoolOpen && context.watch<AppPreferences>().dataPool)
                  Positioned(
                    left: 16,
                    right: 16,
                    // Above the player bar while it shows.
                    bottom: _tvRemote
                        ? (_tvChromeShown
                            ? PlayerControls.liveInfoBarHeight + 8
                            : 16)
                        : _controlsVisible
                            ? (_touch ? 170 : 120)
                            : 16,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: GestureDetector(
                          // A click on the card mustn't hide the bar.
                          onTap: () {},
                          child: DesktopDataPoolCard(
                              key: ValueKey('pool-${_currentChannel.id}'),
                              player: _player,
                              channel: _currentChannel,
                              since: _openedAt),
                        ),
                      ),
                    ),
                  ),
                // Touch: hidden under the top bar's Sources / Rotate.
                if (playerClock && !_inPip && !_pipStarting)
                  PlayerClockPill(
                      top: 6,
                      // The info bar starts with its own clock.
                      visible:
                          !(_touch && _controlsVisible) && !_tvInfoBarShown),
                if (_currentChannel.mediaFileInfo case final info?)
                  MediaFileInfoOverlay(
                      key: ValueKey('file-info-${_currentChannel.id}'),
                      info: info,
                      requests: _fileInfoRequests,
                      // Touch: below the top bar's Sources / Rotate.
                      top: (_touch ? 64 : 16) +
                          (playerClock && !_touch
                              ? PlayerClockPill.height
                              : 0)),
                // Touch: the top bar already names the title.
                if (_currentChannel.mediaFileInfo != null && !_touch)
                  MediaTitleCue.forChannel(
                      key: ValueKey('title-cue-${_currentChannel.id}'),
                      seriesName: _currentChannel.seriesName,
                      name: _currentChannel.name,
                      requests: _fileInfoRequests),
                if (_panelOpen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: math.min(PlayerSidePanel.width, size.width * 0.88),
                    child: GestureDetector(
                      // Clicks on the panel's empty space mustn't reach the
                      // video's click-to-close.
                      onTap: () {},
                      child: PlayerSidePanel(
                        current: _currentChannel,
                        onClose: _closePanel,
                        onPlay: _switchTo,
                      ),
                    ),
                  ),
                if (_scheduleOpen)
                  Positioned.fill(
                    child: ChannelSchedulePanel(
                      channel: _currentChannel,
                      at: _inCatchup ? _catchupCtl.playhead : null,
                      onClose: _closeSchedule,
                      onCatchup: (start) => unawaited(_startCatchup(start)),
                      onLive: () {
                        if (_inCatchup) unawaited(_catchupCtl.backToLive());
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The live-only replacement for the seek bar — same widget/logic as
/// `PlayerControls`' private `_LiveRemainingLabel` on mobile: how long is
/// left in whatever's currently airing, from EPG data, not the video
/// controller's own (untrustworthy, for a live stream) duration.
class _LiveRemainingLabel extends StatelessWidget {
  const _LiveRemainingLabel({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();
    final programme = epg.getCurrentProgram(channelId);
    if (programme == null) return const SizedBox.shrink();
    final remaining = programme.stop.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final minutes = remaining.inMinutes;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        minutes < 1
            ? tr('Ending now')
            : tr('{minutes} min left', {'minutes': minutes}),
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

/// Mute button + volume slider at the end of the player bar (Windows user
/// request, 2026-10-20). Volume and mute are remembered on this PC; mute
/// is volume 0 on the player, so the slider shows 0 while muted and
/// unmuting goes back to the saved level.
class _DesktopVolume extends StatelessWidget {
  const _DesktopVolume({required this.player});

  final Player player;

  static void toggleMute(BuildContext context, Player player) {
    final storage = context.read<StorageService>();
    final muted = !storage.getDesktopMuted();
    storage.setDesktopMuted(muted);
    player.setVolume(muted ? 0 : storage.getDesktopVolume());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snapshot) {
        final volume = (snapshot.data ?? 100).clamp(0.0, 100.0);
        final storage = context.read<StorageService>();
        final muted = storage.getDesktopMuted() || volume == 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                  muted
                      ? Icons.volume_off
                      : volume < 50
                          ? Icons.volume_down
                          : Icons.volume_up,
                  color: Colors.white),
              tooltip: muted ? tr('Unmute') : tr('Mute'),
              onPressed: () {
                if (!storage.getDesktopMuted() && volume == 0) {
                  // Slid down to 0: the button brings the sound back.
                  storage.setDesktopVolume(50);
                  player.setVolume(50);
                  return;
                }
                toggleMute(context, player);
              },
            ),
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: muted ? 0 : volume,
                  max: 100,
                  onChanged: (v) {
                    storage.setDesktopMuted(false);
                    storage.setDesktopVolume(v);
                    player.setVolume(v);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The picture mode's name over the video after the picture button (the
/// look of PlayerScreen's: a round icon and the name, like Nuvio).
class _FitPill extends StatelessWidget {
  const _FitPill({required this.fit});

  final VideoFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child: Icon(fit.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            tr(fit.label),
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Touch: a big round button in the middle of the video (play/pause,
/// +-10 s), on a dark disc so it reads on bright pictures.
class _TouchRoundButton extends StatelessWidget {
  const _TouchRoundButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        iconSize: size,
        padding: EdgeInsets.all(size * 0.3),
        color: Colors.white,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

/// [DesktopPlayerControl] for the full-screen player: the same steps as its
/// own buttons (pause keeps the live timeshift rule, seek and Back to live
/// work inside catch-up, a stream switch keeps the position).
class _ScreenControl extends DesktopPlayerControl {
  _ScreenControl(this.s);
  final _DesktopPlayerScreenState s;

  @override
  Channel get channel => s._currentChannel;
  @override
  Player get player => s._player;
  @override
  bool get fullScreen => true;
  @override
  bool get inCatchup => s._inCatchup;
  @override
  Channel? get nextEpisode => s._nextEpisode;
  @override
  Channel? get previousEpisode => s._previousEpisode;
  @override
  ArchivePlaybackSources? get sources => s.widget.sources;

  @override
  Future<void> pause() async {
    if (s._player.state.playing) s._togglePlay(true);
  }

  @override
  Future<void> resume() async {
    if (!s._player.state.playing) s._togglePlay(false);
  }

  @override
  Future<void> stop() async => s._stopAndClose();

  @override
  Future<void> seekBy(Duration amount) async => s._skip(amount);

  @override
  Future<bool> catchupFrom(DateTime at) async {
    if (!s.mounted || !s._currentChannel.hasCatchup) return false;
    await s._startCatchup(at);
    return s._inCatchup;
  }

  @override
  Future<void> backToLive() async {
    if (s._inCatchup) await s._catchupCtl.backToLive();
  }

  @override
  Future<void> playOther(Channel channel) => s._switchTo(channel);

  @override
  Future<void> replaceStream(Channel replacement) {
    final state = s._player.state;
    return s._switchTo(replacement, start: state.position, play: state.playing);
  }
}

/// Line 2 of the Apple TV live info bar: the programme's start, how far
/// it is, its end (Android's live timeline at rest; going back into
/// catch-up from it is Android's only for now: Start over and Channel
/// schedule do it here).
class _TvLiveProgress extends StatefulWidget {
  const _TvLiveProgress({required this.epgId});

  final String epgId;

  @override
  State<_TvLiveProgress> createState() => _TvLiveProgressState();
}

class _TvLiveProgressState extends State<_TvLiveProgress> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programme =
        context.watch<EpgService>().getCurrentProgram(widget.epgId);
    if (programme == null) return const SizedBox.shrink();
    final span = programme.stop.difference(programme.start).inSeconds;
    if (span <= 0) return const SizedBox.shrink();
    final at = (DateTime.now().difference(programme.start).inSeconds / span)
        .clamp(0.0, 1.0);
    final accent = Theme.of(context).colorScheme.primary;
    const style = LiveInfoBar.timeStyle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Text(TimeFormat.hm.format(programme.start), style: style),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                      height: 3,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3))),
                  Container(
                      width: box.maxWidth * at,
                      height: 3,
                      decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(3))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(TimeFormat.hm.format(programme.stop), style: style),
      ]),
    );
  }
}

/// The Apple TV options row's sound ("English • 5.1"), Android's status
/// line: the playing track's language (placeholders left out) and its
/// channel layout.
class _TvSoundSummary extends StatefulWidget {
  const _TvSoundSummary({super.key, required this.player});

  final Player player;

  @override
  State<_TvSoundSummary> createState() => _TvSoundSummaryState();
}

class _TvSoundSummaryState extends State<_TvSoundSummary> {
  static const _noLanguage = {'mis', 'mul', 'und', 'zxx', 'qaa'};
  StreamSubscription<AudioParams>? _params;
  StreamSubscription<Track>? _track;

  @override
  void initState() {
    super.initState();
    _params = widget.player.stream.audioParams.listen((_) => _changed());
    _track = widget.player.stream.track.listen((_) => _changed());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _params?.cancel();
    _track?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = DesktopAudio.tracksOf(widget.player);
    final selected = widget.player.state.track.audio;
    final track = tracks.where((t) => t.id == selected.id).firstOrNull ??
        (tracks.length == 1 ? tracks.first : null);
    final language = (track?.language ?? '').toLowerCase();
    final text = [
      if (language.isNotEmpty && !_noLanguage.contains(language))
        languageName(language),
      DataPoolCard.channelsName(widget.player.state.audioParams.channelCount),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: const TextStyle(color: Colors.white, fontSize: 12));
  }
}
