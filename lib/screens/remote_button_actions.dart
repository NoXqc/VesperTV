import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/app_preferences.dart';
import '../services/epg_service.dart';
import '../services/guide_key.dart';
import '../services/playback_service.dart';
import '../services/recording_service.dart';
import '../services/remote_buttons.dart';
import '../services/vesper_ai/vesper_tools.dart';
import 'multiview_screen.dart';
import 'player_screen.dart';

/// What each [RemoteAction] does (Settings > Backup & devices > Remote
/// buttons). Player-only actions go to the open full-screen player
/// ([RemoteButtons.player]); the rest reuse the TV home's openers
/// ([GuideKey.openSection]) and Vesper AI's tools, so a button does exactly
/// what the same voice command does.
class RemoteButtonActions {
  RemoteButtonActions({
    required this.navigatorKey,
    required this.playback,
    required this.prefs,
    required this.epg,
    required this.toolbox,
    required this.openVesper,
    required this.toast,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final PlaybackService playback;
  final AppPreferences prefs;
  final EpgService epg;
  final VesperToolbox? Function() toolbox;
  final VoidCallback openVesper;
  final void Function(String message) toast;

  RemotePlayerTarget? get _player => RemoteButtons.instance.player;

  Future<void> run(String action) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    if (_player == null &&
        (action == 'play_pause' || action == 'stop') &&
        (RemoteButtons.instance.home?.call(action) ?? false)) {
      return;
    }
    switch (action) {
      case 'play_pause':
        await playback.togglePlayPause();
      case 'stop':
        _player?.close();
        await playback.stop();
      case 'full_screen':
        await _fullScreen(nav);
      case 'last_channel':
        final player = _player;
        if (player != null) {
          player.lastChannel();
          return;
        }
        final current = playback.liveChannel;
        final target = playback.recentlyPlayed
            .where((c) => c.isLive && c.id != current?.id)
            .firstOrNull;
        if (target != null) await _play(nav, target);
      case 'channel_up':
        _player?.zap(-1);
      case 'channel_down':
        _player?.zap(1);
      case 'fast_forward':
        final player = _player;
        if (player != null) {
          player.skip(1);
        } else {
          _sendMediaKey(LogicalKeyboardKey.mediaFastForward,
              PhysicalKeyboardKey.mediaFastForward);
        }
      case 'rewind':
        final player = _player;
        if (player != null) {
          player.skip(-1);
        } else {
          _sendMediaKey(
              LogicalKeyboardKey.mediaRewind, PhysicalKeyboardKey.mediaRewind);
        }
      case 'info':
        _player?.showInfo();
      case 'favourites' ||
            'guide' ||
            'sports' ||
            'hub' ||
            'search' ||
            'home' ||
            'settings':
        // The TV home's openers close what is above it (the player too).
        final opened = await _openSection(nav, action);
        if (!opened) toast(tr('Not available here'));
      case 'multiview':
        await _multiview(nav);
      case 'vesper':
        openVesper();
      case 'audio_next':
        await _nextAudio();
      case 'subtitles':
        await _toggleSubtitles();
      case 'picture':
        _player?.cycleFit();
      case 'record':
        await _record();
    }
  }

  /// Outside the player, a button set to Fast forward / Rewind does what
  /// the remote's own FF / RW keys do there (10-row jumps in the groups and
  /// channel lists, schedule pages): the key goes up the focus tree from
  /// the focused widget, like a real key press. The button itself was taken
  /// before the focus tree, so nothing else sees it.
  static void _sendMediaKey(
      LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    final event = KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp:
            Duration(microseconds: DateTime.now().microsecondsSinceEpoch));
    for (FocusNode? node = FocusManager.instance.primaryFocus;
        node != null;
        node = node.parent) {
      final result = node.onKeyEvent?.call(node, event);
      if (result == KeyEventResult.handled ||
          result == KeyEventResult.skipRemainingHandlers) {
        return;
      }
    }
  }

  Future<bool> _openSection(NavigatorState nav, String section) async {
    final box = toolbox();
    if (box != null) {
      return box.host.openSection(section);
    }
    return GuideKey.openSection(nav, section) ?? false;
  }

  Future<void> _play(NavigatorState nav, Channel channel) async {
    final box = toolbox();
    if (box != null) return box.host.playChannel(channel);
  }

  /// The channel playing in a preview / the Home mini player, full screen
  /// on the same stream (PlayerScreen's play is a no-op on it).
  Future<void> _fullScreen(NavigatorState nav) async {
    if (_player != null) return;
    final channel = playback.currentChannel;
    if (channel == null || playback.controller == null) {
      toast(tr('Nothing is playing.'));
      return;
    }
    unawaited(nav
        .push(PlayerPageRoute(builder: (_) => PlayerScreen(channel: channel))));
  }

  Future<void> _multiview(NavigatorState nav) async {
    if (prefs.hideMultiview) {
      toast(tr('Not available here'));
      return;
    }
    final player = _player;
    if (player != null) {
      // The playing player becomes screen 1 (PlayerScreen's own button).
      player.openMultiview();
      return;
    }
    await playback.stop();
    nav.popUntil((r) => r.isFirst);
    unawaited(
        nav.push(MaterialPageRoute(builder: (_) => const MultiviewScreen())));
  }

  /// The next audio track of what's playing (wraps), remembered like a
  /// pick in the player.
  Future<void> _nextAudio() async {
    final box = toolbox();
    if (box == null) return;
    final list = await box.call('player', {'action': 'audio_tracks'});
    final tracks = (list['tracks'] as List?)?.cast<Map>() ?? const [];
    if (tracks.length < 2) {
      toast(list['error'] is String
          ? '${list['error']}'
          : tr('This stream has one audio track.'));
      return;
    }
    final playing = tracks.indexWhere((t) => t['playing'] == true);
    final next = tracks[(playing + 1) % tracks.length];
    final done = await box
        .call('player', {'action': 'audio_track', 'track': next['track']});
    toast(done['error'] is String
        ? '${done['error']}'
        : tr('Audio: {name}', {'name': '${next['name']}'}));
  }

  /// Subtitles off when any show; else the viewer's subtitle language when
  /// the file has it, otherwise its first track.
  Future<void> _toggleSubtitles() async {
    final box = toolbox();
    if (box == null) return;
    final state = await box.call('player', {'action': 'subtitles'});
    if (state['error'] is String) {
      toast('${state['error']}');
      return;
    }
    final tracks = (state['tracks'] as List?)?.cast<Map>() ?? const [];
    if (state['off'] != true) {
      await box.call('player', {'action': 'subtitle', 'language': 'off'});
      toast(tr('Subtitles off'));
      return;
    }
    final preferred = box.storage.getPreferredSubtitleLanguage();
    if (preferred.isNotEmpty && preferred != 'off') {
      final done = await box
          .call('player', {'action': 'subtitle', 'language': preferred});
      if (done['done'] is String) {
        toast(tr('Subtitles on'));
        return;
      }
    }
    if (tracks.isEmpty) {
      toast(tr('No subtitles in this stream'));
      return;
    }
    final pick =
        tracks.where((t) => t['forced'] != true).firstOrNull ?? tracks.first;
    await box.call('player', {'action': 'subtitle', 'track': pick['track']});
    toast(tr('Subtitles: {name}', {'name': '${pick['name']}'}));
  }

  /// Records the live channel playing until its programme ends (2 h
  /// without a guide), or stops that recording: the TV home's hold menu
  /// Record.
  Future<void> _record() async {
    final channel = playback.liveChannel;
    if (!RecordingService.supported || channel == null || !channel.isLive) {
      toast(tr('No live channel is playing.'));
      return;
    }
    final service = RecordingService.instance;
    await service.init();
    final running = service.recordingOf(channel);
    if (running != null) {
      await service.stop(running);
      toast(tr('Recording stopped'));
      return;
    }
    await service.askNotifications();
    if (!await service.hasRoom()) {
      toast(tr('Not enough free space to record'));
      return;
    }
    final now = epg.getCurrentProgram(channel.epgId);
    await service.handOver(
        channel,
        playback,
        () => service.recordChannel(channel,
            program: now?.title ?? '', until: now?.stop.toLocal()));
    toast(tr('Recording {title}', {'title': now?.title ?? channel.name}));
  }
}
