part of 'vesper_tools.dart';

// now_playing and player on a computer (owner, 2026-11-10: Windows up to
// par with Android). The player there is media_kit, reached through
// [DesktopPlayerControl] (full screen, else the mini player); the answers
// have the same shape as Android's.

Future<Map<String, Object?>> _desktopNowPlaying(
    VesperToolbox box, Map<String, Object?> args) async {
  final p = DesktopPlayerControl.current;
  if (p == null) return {'playing': null};
  final c = p.channel;
  final state = p.player.state;
  final out = <String, Object?>{
    ...box.describeChannel(c, withNow: false),
    'paused': !state.playing,
    if (p.inCatchup) 'catch_up': true,
    if (!p.fullScreen) 'mini_player': true,
  };
  if (c.isLive) {
    final now = box.epg.getCurrentProgram(c.epgId);
    final next = box.epg.getNextProgram(c.epgId);
    if (now != null) out['on_now'] = _programme(now);
    if (next != null) out['next'] = _programme(next);
  } else if (state.duration > Duration.zero) {
    out['position_min'] = state.position.inMinutes;
    out['length_min'] = state.duration.inMinutes;
  }
  final hubStream = p.sources?.current(p.playingId);
  if (hubStream != null) {
    out['stream'] = _describeStream(
        box, HubStream(hubStream, channelId: p.playingId),
        playing: true);
  }
  if (args['quality'] == true) {
    final quality = await _desktopQuality(p);
    if (quality.isNotEmpty) out['quality'] = quality;
  }
  return out;
}

/// The Data pool's numbers from mpv: picture, HDR, audio, bitrate, buffer,
/// dropped frames over ~1.5 s.
Future<Map<String, Object?>> _desktopQuality(DesktopPlayerControl p) async {
  final player = p.player;
  final first = await DesktopStreamStats.read(player);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  if (DesktopPlayerControl.current?.player != player) return const {};
  final last = await DesktopStreamStats.read(player);
  final out = <String, Object?>{};
  final w = last.integer('video-params/w'), h = last.integer('video-params/h');
  final fps = last.decimal('container-fps') ?? last.decimal('estimated-vf-fps');
  final video = [
    if (w != null && h != null) '${w}x$h',
    if (fps != null && fps > 0) '${fps.toStringAsFixed(2)} fps',
    if (DataPoolCard.codecName(last['video-format']) case final codec?) codec,
  ];
  if (video.isNotEmpty) out['video'] = video.join(' · ');
  final gamma = last['video-params/gamma'].toLowerCase();
  if (gamma.isNotEmpty) {
    out['hdr'] = gamma == 'pq'
        ? 'HDR10'
        : gamma == 'hlg'
            ? 'HLG'
            : 'SDR';
  }
  final audio = [
    if (DataPoolCard.codecName(last['audio-codec-name']) case final codec?)
      codec,
    if (DataPoolCard.channelsName(last.integer('audio-params/channel-count'))
        case final layout?)
      layout,
  ];
  if (audio.isNotEmpty) out['audio'] = audio.join(' · ');
  final bits = (last.decimal('video-bitrate') ?? 0) +
      (last.decimal('audio-bitrate') ?? 0);
  if (bits > 0) out['bitrate_mbps'] = (bits / 1e5).round() / 10;
  if (last.decimal('demuxer-cache-duration') case final s?) {
    out['buffered_s'] = (s * 10).round() / 10;
  }
  final d0 = first.integer('frame-drop-count'),
      d1 = last.integer('frame-drop-count');
  if (d0 != null && d1 != null) out['dropped_frames_now'] = d1 - d0;
  if (last.integer('file-size') case final size? when size > 0) {
    out['file_size_gb'] = (size / 1e8).round() / 10;
  }
  final hw = last['hwdec-current'];
  out['decoder'] = hw.isEmpty || hw == 'no' ? 'software' : 'hardware ($hw)';
  out['buffering'] = player.state.buffering;
  return out;
}

Future<Map<String, Object?>> _desktopPlayer(
    VesperToolbox box, Map<String, Object?> args) async {
  final action = _str(args, 'action');
  final p = DesktopPlayerControl.current;
  if (p == null) {
    if (action == 'stop') return {'done': 'stopped'};
    throw VesperToolError('Nothing is playing.');
  }
  final state = p.player.state;
  switch (action) {
    case 'pause':
      await p.pause();
      return {'done': 'paused'};
    case 'resume':
      await p.resume();
      return {'done': 'playing'};
    case 'stop':
      await p.stop();
      return {'done': 'stopped'};
    case 'back_to_live':
      if (!p.inCatchup) return {'done': 'already live'};
      await p.backToLive();
      return {'done': 'live'};
    case 'seek':
      final seconds = _int(args, 'seconds', -30, min: -7200, max: 7200);
      final ch = p.channel;
      if (ch.isLive && !p.inCatchup) {
        if (seconds < 0 && ch.hasCatchup) {
          if (!p.fullScreen) {
            throw VesperToolError('Catch-up plays full screen: open the '
                'channel full screen first.');
          }
          if (await p.catchupFrom(
              DateTime.now().add(Duration(seconds: seconds)))) {
            return {'done': 'catch-up from ${-seconds} s ago'};
          }
        }
        throw VesperToolError('This live channel cannot be rewound.');
      }
      await p.seekBy(Duration(seconds: seconds));
      if (p.inCatchup) {
        return {'done': '${seconds < 0 ? 'back' : 'forward'} ${seconds.abs()} s'};
      }
      final target = state.position + Duration(seconds: seconds);
      final clamped = target < Duration.zero
          ? Duration.zero
          : (state.duration > Duration.zero && target > state.duration
              ? state.duration
              : target);
      return {'done': 'at ${clamped.inMinutes} min'};
    case 'audio_tracks':
      return _desktopAudioTracks(p);
    case 'audio_track':
      return _desktopSetAudioTrack(box, p, args);
    case 'subtitles':
      return _desktopSubtitles(box, p);
    case 'subtitle':
      return _desktopSetSubtitles(box, p, args);
    case 'next_episode':
    case 'previous_episode':
      final episode =
          action == 'next_episode' ? p.nextEpisode : p.previousEpisode;
      if (episode == null) {
        throw VesperToolError(action == 'next_episode'
            ? 'No next episode: this is the last one, or not a show.'
            : 'No previous episode: this is the first one, or not a show.');
      }
      await p.playOther(episode);
      return {'playing': episode.name};
    case 'channel_up':
    case 'channel_down':
      final ch = p.channel;
      // "Next" during a show means its next episode.
      final episode =
          action == 'channel_up' ? p.nextEpisode : p.previousEpisode;
      if (!ch.isLive && episode != null) {
        await p.playOther(episode);
        return {'playing': episode.name};
      }
      if (!ch.isLive) throw VesperToolError('No live channel is playing.');
      final list = box.playlist
          .visibleChannels(category: 'tv')
          .where((x) => x.group == ch.group)
          .toList();
      final i = list.indexWhere((x) => x.id == ch.id);
      if (i < 0 || list.length < 2) {
        throw VesperToolError('No other channel in this list.');
      }
      final step = action == 'channel_up' ? 1 : -1;
      final next = list[(i + step) % list.length];
      await p.playOther(next);
      return {'playing': next.name};
  }
  throw VesperToolError('Unknown player action $action.');
}

String _desktopAudioName(mk.AudioTrack t, int index) {
  final name = audioTrackName(t.title, t.language);
  return name.isEmpty ? 'Audio ${index + 1}' : name;
}

/// [pickAudioTrack]'s rules for mpv's tracks.
mk.AudioTrack? _desktopPickAudio(
    List<mk.AudioTrack> tracks, String language, String selectedId) {
  final same =
      tracks.where((t) => sameTrackLanguage(t.language, language)).toList();
  return same.where((t) => t.id == selectedId).firstOrNull ??
      same.where((t) => !_isExtraAudio(t.title)).firstOrNull ??
      same.firstOrNull;
}

Map<String, Object?> _desktopAudioTracks(DesktopPlayerControl p) {
  final tracks = DesktopAudio.tracksOf(p.player);
  final selected = p.player.state.track.audio.id;
  return {
    'tracks': [
      for (final (i, t) in tracks.indexed)
        {
          'track': i + 1,
          'name': _desktopAudioName(t, i),
          if (_languageOf(t.language) != null) 'language': t.language,
          if (DataPoolCard.codecName(t.codec) != null)
            'codec': DataPoolCard.codecName(t.codec),
          if (DataPoolCard.channelsName(t.channelscount) != null)
            'channels': DataPoolCard.channelsName(t.channelscount),
          if (t.id == selected) 'playing': true,
        },
    ],
  };
}

Future<Map<String, Object?>> _desktopSetAudioTrack(VesperToolbox box,
    DesktopPlayerControl p, Map<String, Object?> args) async {
  final channel = p.channel;
  final tracks = DesktopAudio.tracksOf(p.player);
  if (tracks.isEmpty) {
    throw VesperToolError('This stream has no audio tracks to choose from.');
  }
  final selected = p.player.state.track.audio.id;
  mk.AudioTrack? picked;
  if (args['track'] != null) {
    final n = _int(args, 'track', 0);
    if (n < 1 || n > tracks.length) {
      throw VesperToolError('Track $n does not exist: there are '
          '${tracks.length} (audio_tracks lists them).');
    }
    picked = tracks[n - 1];
  } else {
    final code = trackLanguageCode(_str(args, 'language'));
    if (code == null) throw VesperToolError('Which language or track?');
    picked = _desktopPickAudio(tracks, code, selected);
    if (picked == null) {
      final have = {
        for (final t in tracks)
          if (_languageOf(t.language) != null) languageName(t.language)
      };
      throw VesperToolError('No ${languageName(code)} audio in this stream'
          '${have.isEmpty ? '' : ' (it has ${have.join(', ')})'}.');
    }
  }
  final viewer = box.storage.getActiveViewerId();
  if (picked.id != selected) await p.player.setAudioTrack(picked);
  // Remembered like a pick in the player's Audio button.
  if (box.storage.getActiveViewerId() == viewer &&
      DesktopPlayerControl.current?.player == p.player &&
      p.channel.id == channel.id) {
    await DesktopAudio.remember(box.storage, channel, picked);
  }
  return {'done': 'audio: ${_desktopAudioName(picked, tracks.indexOf(picked))}'};
}

bool _desktopForced(mk.SubtitleTrack t) =>
    (t.title ?? '').toLowerCase().contains('forced');

String _desktopSubtitleName(mk.SubtitleTrack t, int index) {
  final label = t.title?.trim() ?? '';
  final name = languageName(t.language);
  return label.isNotEmpty
      ? label
      : name.isNotEmpty
          ? name
          : 'Track ${index + 1}';
}

Map<String, Object?> _desktopSubtitles(
    VesperToolbox box, DesktopPlayerControl p) {
  final tracks = DesktopSubtitles.embedded(p.player);
  final current = p.player.state.track.subtitle;
  final online = DesktopSubtitles.onlineLang(p.player);
  final showing = online == null
      ? tracks.where((t) => t.id == current.id).firstOrNull
      : null;
  return {
    'tracks': [
      for (final (i, t) in tracks.indexed)
        {
          'track': i + 1,
          'name': _desktopSubtitleName(t, i),
          if (_languageOf(t.language) != null) 'language': t.language,
          if (_desktopForced(t)) 'forced': true,
          if (identical(t, showing)) 'showing': true,
        },
    ],
    if (online != null) 'showing_online': DesktopSubtitles.langLabel(online),
    if (online == null && showing == null) 'off': true,
    'online_available': _onlineSubtitles(box, p.channel),
  };
}

Future<Map<String, Object?>> _desktopSetSubtitles(VesperToolbox box,
    DesktopPlayerControl p, Map<String, Object?> args) async {
  final channel = p.channel;
  final storage = box.storage;
  final player = p.player;
  final asked = _str(args, 'language').toLowerCase();
  final tracks = DesktopSubtitles.embedded(player);

  Future<Map<String, Object?>> embedded(mk.SubtitleTrack? track) async {
    // Same as the player's Subtitles button: an episode's choice carries on
    // to the rest of the series; Off is remembered.
    await SubtitleTracks.rememberForSeries(storage, channel,
        kind: track == null ? null : 'embedded',
        lang: track?.language,
        label: track?.title);
    await setDesktopSubtitle(player, track);
    return {
      'done': track == null
          ? 'subtitles off'
          : 'subtitles: ${_desktopSubtitleName(track, tracks.indexOf(track))}'
    };
  }

  if (const {'off', 'none', 'no', 'disable', 'disabled'}.contains(asked)) {
    return embedded(null);
  }
  if (args['track'] != null) {
    final n = _int(args, 'track', 0);
    if (n < 1 || n > tracks.length) {
      throw VesperToolError(tracks.isEmpty
          ? 'This file has no subtitle tracks; ask for a language to get '
              'one from the add-ons.'
          : 'Track $n does not exist: there are ${tracks.length} '
              '(subtitles lists them).');
    }
    return embedded(tracks[n - 1]);
  }
  if (asked == 'cc' || asked.contains('closed caption')) {
    throw VesperToolError('Closed captions are not available on Windows.');
  }
  final code = trackLanguageCode(asked);
  if (code == null) throw VesperToolError('Which language, or off?');
  final forced = args['forced'] == true;
  final same =
      tracks.where((t) => sameTrackLanguage(t.language, code)).toList();
  final track = same.where((t) => _desktopForced(t) == forced).firstOrNull ??
      same.firstOrNull;
  if (track != null) return embedded(track);

  // Not in the file: the first match from the viewer's subtitle add-ons.
  if (!_onlineSubtitles(box, channel)) {
    throw VesperToolError('No ${languageName(code)} subtitles in this file'
        '${AddonService.supports(channel) ? ', and no subtitle add-on is '
            'on (Settings > Playlists & sources > Online subtitles)' : ''}.');
  }
  final match = (await AddonService(storage).search(channel))
      .where((s) => sameTrackLanguage(s.lang, code))
      .firstOrNull;
  if (match == null) {
    throw VesperToolError(
        'No ${languageName(code)} subtitles for this title, in the file or '
        'from the add-ons.');
  }
  final text = await AddonService.download(match);
  if (DesktopPlayerControl.current?.player != player) {
    throw VesperToolError('The stream changed meanwhile.');
  }
  await DesktopSubtitles.useOnline(player, text, match.lang);
  await storage.addOnlineSubtitleLang(match.lang);
  await SubtitleTracks.rememberForSeries(storage, channel,
      kind: 'online', lang: match.lang);
  return {
    'done': 'subtitles: ${DesktopSubtitles.langLabel(match.lang)} '
        '(online, ${match.addonName})'
  };
}

/// Media Hub's "what is playing" on a computer: its sources and streams.
Future<(Channel, ArchivePlaybackSources, List<ArchiveStreamOption>)>
    _desktopPlayingHub() async {
  final p = DesktopPlayerControl.current;
  if (p == null) throw VesperToolError('Nothing is playing.');
  final sources = p.sources;
  final options = sources == null
      ? const <ArchiveStreamOption>[]
      : await sources.load(p.playingId);
  if (sources == null ||
      (options.isEmpty && sources.current(p.playingId) == null)) {
    throw VesperToolError('What is playing is not from Media Hub. Give a '
        'title ref instead.');
  }
  return (p.channel, sources, options);
}

/// [_awaitStart] on a computer: [id] plays in a player with a length (or
/// playing) within [mediaHubStartWait].
Future<Map<String, Object?>> _desktopAwaitStart(String id) async {
  final until = DateTime.now().add(mediaHubStartWait);
  while (DateTime.now().isBefore(until)) {
    final p = DesktopPlayerControl.current;
    if (p != null && p.playingId == id) {
      final state = p.player.state;
      if (state.playing || state.duration > Duration.zero) {
        return {'started': true};
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return {
    'started': false,
    'note': 'Not playing yet: the computer may be asking the viewer to pick '
        'a stream, or the stream is slow to start. now_playing tells later.',
  };
}
