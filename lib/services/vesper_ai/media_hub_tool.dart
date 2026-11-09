part of 'vesper_tools.dart';

// Media Hub for AI apps (Discord request, 2026-11-09): find a title, list
// the streams its sources offer (provider, quality, audio, size; never the
// links, which can carry debrid keys), play it with the best or a chosen
// stream, and swap the playing stream the way the player's source drawer
// does. How the playing stream is doing is in now_playing (quality).

/// Media Hub as the media_hub tool sees it (AppVesperHub on the app's
/// ArchiveService and navigator).
abstract interface class VesperHub {
  /// Titles matching [query], best first; never titles kept under Other.
  Future<List<HubTitle>> search(String query,
      {ArchiveType? type, int limit = 8});

  /// [title] with its full details (a show's episodes); null when its
  /// source is gone.
  Future<HubTitle?> details(HubTitle title);

  /// Every stream [title]'s sources offer (a show: its [episode]'s).
  Future<List<ArchiveStreamOption>> streams(HubTitle title,
      {ArchiveVideo? episode});

  /// Full screen, like Play on its page: [option] plays that stream, null
  /// = the app's own choice (the stream picked last time, Auto-play, or
  /// the list on the TV). Returns the id the player will play it under.
  Future<String> play(HubTitle title,
      {ArchiveVideo? episode, ArchiveStreamOption? option});

  /// The show's page, for the viewer to pick an episode.
  Future<void> openShow(HubTitle show);
}

/// One stream handed out by the sources action: of a title (and episode),
/// or of what is playing ([channelId]).
class HubStream {
  const HubStream(this.option, {this.title, this.episode, this.channelId});
  final ArchiveStreamOption option;
  final HubTitle? title;
  final ArchiveVideo? episode;
  final String? channelId;

  String get id => '${option.source.key}|${option.stream.identity}';
  String get key => 'o:${title?.key ?? channelId}|${episode?.id ?? ''}|$id';
}

/// How long play waits for the stream to start before answering (tests: 0).
Duration mediaHubStartWait = const Duration(seconds: 20);

const _hubStreamCap = 25;

/// True: the stream says it's ready (debrid cached: ⚡ or `+]`); false: the
/// provider is still downloading it (its link plays a short "being
/// downloaded" clip, see ArchiveReadyWatch); null: it doesn't say.
bool? hubStreamReady(ArchiveStreamOption o) {
  final label = '${o.stream.name ?? ''} ${o.stream.title ?? ''}';
  if (label.toLowerCase().contains('download') || label.contains('⏳')) {
    return false;
  }
  if (label.contains('⚡') || label.contains('+]')) return true;
  return null;
}

/// The audio a stream's labels advertise ("E-AC-3 5.1 Atmos"); never
/// guessed, null when they say nothing.
String? hubStreamAudio(ArchiveStreamOption o) {
  final text =
      archiveStreamLabel('${o.stream.name ?? ''} ${o.stream.title ?? ''}');
  bool has(String pattern) =>
      RegExp(pattern, caseSensitive: false).hasMatch(text);
  final codec = has(r'\btrue[ ._-]?hd\b')
      ? 'TrueHD'
      : has(r'\bdts[ ._-]?(hd|x|ma)\b|\bdts:x\b')
          ? 'DTS-HD'
          : has(r'\bdts\b')
              ? 'DTS'
              : has(r'\bddp|\bdd\+|\be-?ac-?3\b')
                  ? 'E-AC-3'
                  : has(r'\b(dd|ac-?3)\b|\bdolby digital\b')
                      ? 'AC-3'
                      : has(r'\baac')
                          ? 'AAC'
                          : null;
  // "DDP5.1", "Atmos.7.1" (release names use dots between words).
  final layout = RegExp(r'(?<!\d)([257])[.]([01])(?!\d)').firstMatch(text)?[0];
  final parts = [
    if (codec != null) codec,
    if (layout != null) layout,
    if (has(r'\batmos\b')) 'Atmos',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

/// The viewer's Media Hub playback order (Settings > Media Hub > Playback:
/// preferred source, highest quality within their limit, language, or the
/// largest file), skipping links still downloading and trailers.
ArchiveStreamOption? hubBestStream(
    StorageService storage, List<ArchiveStreamOption> options) {
  final playable = [
    for (final o in options)
      if (o.stream.ytId == null && hubStreamReady(o) != false) o
  ];
  final prefs = ArchivePlaybackPreferences.read(storage);
  final ranked = prefs.ranked(playable);
  // Nothing within the viewer's limits: still the best language first.
  final fallback = prefs.ranked(playable, strict: false).firstOrNull;
  if (storage.getArchiveAutoLargest()) {
    return largestArchiveStream(prefs.bestLanguage(ranked)) ??
        ranked.firstOrNull ??
        fallback;
  }
  return ranked.firstOrNull ?? fallback;
}

/// The stream after [current] in [options] (wrapping; -1 = unknown, from
/// the first), skipping links still downloading and trailers; null when
/// there's no other.
ArchiveStreamOption? hubNextStream(
    List<ArchiveStreamOption> options, int current) {
  for (var step = 1; step <= options.length; step++) {
    final i = (current + step) % options.length;
    if (i == current) continue;
    final o = options[i];
    if (o.stream.ytId == null && hubStreamReady(o) != false) return o;
  }
  return null;
}

Map<String, Object?> _describeStream(VesperToolbox box, HubStream s,
    {bool playing = false}) {
  final o = s.option;
  final name = archiveStreamLabel(o.stream.name ?? '');
  var details = archiveStreamLabel(o.stream.title ?? '');
  if (details.length > 160) details = '${details.substring(0, 160)}…';
  final formats = archiveStreamFormats(o);
  final audio = hubStreamAudio(o);
  // The audio languages its label names; none = not said (an untagged
  // release is usually English).
  final languages = streamLanguagesOf(
      archiveStreamLabel('${o.stream.name ?? ''} ${o.stream.title ?? ''}'));
  final bytes = archiveStreamBytes(o);
  final ready = hubStreamReady(o);
  return {
    'ref': box.refFor(s),
    'source': o.source.name,
    if (name.isNotEmpty) 'name': name,
    if (details.isNotEmpty) 'details': details,
    if (formats.isNotEmpty) 'video': formats.join(' '),
    if (audio != null) 'audio': audio,
    if (languages.codes.isNotEmpty)
      'languages': (languages.codes.toList()..sort()),
    if (languages.multi) 'multi_audio': true,
    if (bytes > 0) 'size_gb': (bytes / 1e8).round() / 10,
    if (ready != null) 'ready': ready,
    if (o.stream.ytId != null) 'youtube': true,
    if (playing) 'playing': true,
  };
}

String _episodeLabel(ArchiveVideo v) =>
    'S${v.season.toString().padLeft(2, '0')}'
    'E${v.episode.toString().padLeft(2, '0')}'
    '${v.title.isEmpty ? '' : ' - ${v.title}'}';

Map<String, Object?> _describeHubTitle(VesperToolbox box, HubTitle t) => {
      'ref': box.refFor(t),
      'title': t.meta.name,
      'kind': t.meta.type == ArchiveType.series ? 'series' : 'movie',
      if (t.meta.year != null) 'year': t.meta.year,
    };

bool _aired(ArchiveVideo v) {
  final date = DateTime.tryParse(v.released ?? '');
  return date == null || !date.isAfter(DateTime.now());
}

/// The title of a ref (or the best match for query); with [args]' season
/// and episode for a show, that episode (from its full details).
Future<(HubTitle, ArchiveVideo?)> _hubTarget(
    VesperToolbox box, VesperHub hub, Map<String, Object?> args) async {
  final ref = _str(args, 'ref');
  final query = _str(args, 'query');
  var title = ref.isEmpty ? null : box.lookup(ref);
  if (title is! HubTitle && query.isNotEmpty) {
    title = (await hub.search(query, limit: 1)).firstOrNull;
    if (title == null) {
      throw VesperToolError('Nothing called "$query" in Media Hub.');
    }
  }
  if (title is! HubTitle) {
    throw VesperToolError('Give a title ref from media_hub search.');
  }
  if (title.meta.type != ArchiveType.series ||
      args['season'] == null ||
      args['episode'] == null) {
    return (title, null);
  }
  final season = _int(args, 'season', 1, min: 0, max: 200);
  final number = _int(args, 'episode', 1, min: 0, max: 5000);
  final full = await hub.details(title);
  if (full == null) {
    throw VesperToolError("This title's Media Hub source is not available.");
  }
  final video = full.meta.videos
      .where((v) => v.season == season && v.episode == number)
      .firstOrNull;
  if (video == null) {
    throw VesperToolError('${full.meta.name} has no season $season episode '
        '$number. The episodes action lists them.');
  }
  return (full, video);
}

/// What is playing, with its Media Hub streams; throws when it isn't from
/// Media Hub.
Future<(Channel, ArchivePlaybackSources, List<ArchiveStreamOption>)>
    _playingHub(VesperToolbox box) async {
  if (isDesktop) throw VesperToolError('Not available on Windows yet.');
  final playing = box.playback.currentChannel;
  final sources = box.playback.hubSources;
  if (playing == null) throw VesperToolError('Nothing is playing.');
  final options = sources == null
      ? const <ArchiveStreamOption>[]
      : await sources.load(playing.id);
  if (sources == null ||
      (options.isEmpty && sources.current(playing.id) == null)) {
    throw VesperToolError('What is playing is not from Media Hub. Give a '
        'title ref instead.');
  }
  return (playing, sources, options);
}

/// Waits (up to [mediaHubStartWait]) for [id] to play in a new player (not
/// [before], the one playing when asked); a short answer for the model.
Future<Map<String, Object?>> _awaitStart(
    VesperToolbox box, String id, Object? before) async {
  if (isDesktop) return const {};
  final until = DateTime.now().add(mediaHubStartWait);
  while (DateTime.now().isBefore(until)) {
    final playback = box.playback;
    if (playback.currentChannel?.id == id && playback.controller != before) {
      if (playback.error != null) return {'error_on_tv': playback.error};
      if (playback.controller?.value.isInitialized ?? false) {
        return {'started': true};
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return {
    'started': false,
    'note': 'Not playing yet: the TV may be asking the viewer to pick a '
        'stream, or the stream is slow to start. now_playing tells later.',
  };
}

final _mediaHubTool = VesperTool(
  name: 'media_hub',
  description: 'Media Hub: the viewer\'s add-ons and media servers (not the '
      'IPTV playlists). search: movies and shows by name (title refs). '
      'episodes: a show\'s episodes. sources: the streams offered for a '
      'title (ref; a show also needs season and episode), or with no ref '
      'for what is playing now: source, video quality, audio, languages '
      'its label names (none = not said; untagged releases are usually '
      'English; a multi-audio file can start in another language unless '
      'the viewer set a preferred audio language), size, ready (false = the provider is '
      'still downloading it: it will not play yet), which one is playing, '
      'and best (the viewer\'s Media Hub playback settings and language). '
      'play: a title ref (best true starts the best '
      'stream; otherwise the app picks as usual or asks on the TV), a '
      'stream ref from sources, or a show with season and episode (a show '
      'without them opens its page). switch: the playing title to another '
      'stream at the same position (a stream ref, "next" or "best"), e.g. '
      'when it buffers or fails; now_playing shows how it plays.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['search', 'episodes', 'sources', 'play', 'switch'],
      },
      'query': {
        'type': 'string',
        'description': 'For search (or instead of a ref): title words only.',
      },
      'kind': {
        'type': 'string',
        'enum': ['all', 'movie', 'series'],
        'description': 'For search (default all).',
      },
      'limit': {'type': 'integer', 'description': 'For search, 1-20.'},
      'ref': {
        'type': 'string',
        'description': 'A title ref (h…) or stream ref (o…); for switch '
            'also "next" or "best".',
      },
      'season': {'type': 'integer'},
      'episode': {'type': 'integer'},
      'best': {
        'type': 'boolean',
        'description': 'For play: start the best stream without asking.',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final hub = box.hub;
    if (hub == null || box.prefs.hideArchive) {
      throw VesperToolError('Media Hub is hidden or not set up on this TV.');
    }
    final action = _str(args, 'action');
    switch (action) {
      case 'search':
        final query = _str(args, 'query');
        if (query.isEmpty) throw VesperToolError('Say what to search for.');
        final type = switch (_str(args, 'kind')) {
          'movie' => ArchiveType.movie,
          'series' => ArchiveType.series,
          _ => null,
        };
        final found = await hub.search(query,
            type: type, limit: _int(args, 'limit', 8, max: 20));
        return {
          'titles': [for (final t in found) _describeHubTitle(box, t)],
          if (found.isEmpty) 'note': 'Nothing called "$query" in Media Hub.',
        };
      case 'episodes':
        final (title, _) = await _hubTarget(
            box, hub, {...args, 'season': null, 'episode': null});
        if (title.meta.type != ArchiveType.series) {
          throw VesperToolError('${title.meta.name} is a movie.');
        }
        final full = await hub.details(title);
        if (full == null) {
          throw VesperToolError(
              "This title's Media Hub source is not available.");
        }
        final videos = full.meta.videos;
        final season = args['season'] == null
            ? null
            : _int(args, 'season', 1, min: 0, max: 200);
        final seasons = {for (final v in videos) v.season}.toList()..sort();
        return {
          'title': full.meta.name,
          'seasons': seasons,
          'episodes': [
            for (final v in videos)
              if (season == null
                  ? v.season == seasons.lastOrNull
                  : v.season == season)
                {
                  'season': v.season,
                  'episode': v.episode,
                  if (v.title.isNotEmpty) 'title': v.title,
                  if (v.released != null) 'released': v.released,
                  if (!_aired(v)) 'aired': false,
                }
          ],
          if (season == null && seasons.length > 1)
            'note': 'The last season is listed; give season for another.',
        };
      case 'sources':
        if (_str(args, 'ref').isEmpty && _str(args, 'query').isEmpty) {
          final (playing, sources, options) = await _playingHub(box);
          final current =
              archiveCurrentStreamIndex(options, sources.current(playing.id));
          final best = hubBestStream(box.storage, options);
          HubStream wrap(ArchiveStreamOption o) =>
              HubStream(o, channelId: playing.id);
          return {
            'title': playing.group.isNotEmpty ? playing.group : playing.name,
            if (playing.group.isNotEmpty) 'episode_or_title': playing.name,
            'sources': [
              for (var i = 0; i < options.length && i < _hubStreamCap; i++)
                _describeStream(box, wrap(options[i]), playing: i == current),
            ],
            if (best != null) 'best': box.refFor(wrap(best)),
            if (options.length > _hubStreamCap)
              'note': '${options.length} streams; the first $_hubStreamCap '
                  'are listed.',
          };
        }
        final (title, episode) = await _hubTarget(box, hub, args);
        if (title.meta.type == ArchiveType.series && episode == null) {
          throw VesperToolError('Which episode? Give season and episode '
              '(the episodes action lists them).');
        }
        final options = await hub.streams(title, episode: episode);
        final best = hubBestStream(box.storage, options);
        HubStream wrap(ArchiveStreamOption o) =>
            HubStream(o, title: title, episode: episode);
        return {
          'title': title.meta.name,
          if (episode != null) 'episode': _episodeLabel(episode),
          'sources': [
            for (final o in options.take(_hubStreamCap))
              _describeStream(box, wrap(o)),
          ],
          if (best != null) 'best': box.refFor(wrap(best)),
          if (options.isEmpty)
            'note': 'No source offers a playable stream for this right now.',
          if (options.length > _hubStreamCap)
            'note': '${options.length} streams; the first $_hubStreamCap '
                'are listed.',
        };
      case 'play':
        final picked = box.lookup(_str(args, 'ref'));
        if (picked is HubStream && picked.title == null) {
          // A stream of what is playing: that's a switch.
          return _switchStream(box, caller, picked.id);
        }
        if (picked is HubStream) {
          final title = picked.title!;
          final name = picked.episode == null
              ? title.meta.name
              : '${title.meta.name} ${_episodeLabel(picked.episode!)}';
          await _confirmRemote(
              box, caller, 'An AI app wants to play {title}.', {'title': name});
          final before = box.playback.controller;
          final id = await hub.play(title,
              episode: picked.episode, option: picked.option);
          return {
            'playing': name,
            'stream': _describeStream(box, picked),
            ...await _awaitStart(box, id, before),
          };
        }
        final (title, episode) = await _hubTarget(box, hub, args);
        if (title.meta.type == ArchiveType.series && episode == null) {
          await _confirmRemote(box, caller, 'An AI app wants to open {title}.',
              {'title': title.meta.name});
          await hub.openShow(title);
          return {
            'opened': title.meta.name,
            'kind': 'series',
            'note': 'The show page is open on the TV. Give season and '
                'episode to play one.',
          };
        }
        final name = episode == null
            ? title.meta.name
            : '${title.meta.name} ${_episodeLabel(episode)}';
        ArchiveStreamOption? option;
        if (args['best'] == true) {
          option = hubBestStream(
              box.storage, await hub.streams(title, episode: episode));
          if (option == null) {
            throw VesperToolError(
                'No source offers a playable stream for $name right now.');
          }
        }
        await _confirmRemote(
            box, caller, 'An AI app wants to play {title}.', {'title': name});
        final before = box.playback.controller;
        final id = await hub.play(title, episode: episode, option: option);
        return {
          'playing': name,
          if (option != null)
            'stream': _describeStream(
                box, HubStream(option, title: title, episode: episode)),
          ...await _awaitStart(box, id, before),
        };
      case 'switch':
        return _switchStream(box, caller, _str(args, 'ref'));
    }
    throw VesperToolError('Unknown media_hub action $action.');
  },
);

/// The playing Media Hub title to another of its streams (a stream ref's
/// id, "next" or "best"), at the same position, like the source drawer.
Future<Map<String, Object?>> _switchStream(
    VesperToolbox box, VesperCaller caller, String which) async {
  final (playing, sources, options) = await _playingHub(box);
  if (options.isEmpty) {
    throw VesperToolError('No other stream is offered for this right now.');
  }
  final current =
      archiveCurrentStreamIndex(options, sources.current(playing.id));
  ArchiveStreamOption? target;
  if (which.isEmpty || which == 'next') {
    target = hubNextStream(options, current);
  } else if (which == 'best') {
    target = hubBestStream(box.storage, [
      for (var i = 0; i < options.length; i++)
        if (i != current) options[i]
    ]);
  } else {
    final picked = box.lookup(which);
    final id = picked is HubStream ? picked.id : which;
    target = options
        .where((o) => '${o.source.key}|${o.stream.identity}' == id)
        .firstOrNull;
    if (target == null) {
      throw VesperToolError('That stream is not offered for what is playing. '
          'Call sources again.');
    }
  }
  if (target == null) {
    throw VesperToolError('No other stream is ready for this right now.');
  }
  if (current >= 0 && identical(options[current], target)) {
    return {'note': 'That stream is already playing.'};
  }
  if (target.stream.ytId != null) {
    throw VesperToolError('That is a trailer, not the title.');
  }
  await _confirmRemote(
      box, caller, 'An AI app wants to play {title}.', {'title': playing.name});
  final replacement = await sources.select(playing.id, target);
  if (replacement == null || box.playback.currentChannel?.id != playing.id) {
    throw VesperToolError('Could not switch stream. Try another source.');
  }
  await sources.remember(playing.id, target);
  await box.playback.replaceStream(replacement);
  return {
    'switched': true,
    'stream': _describeStream(box, HubStream(target, channelId: playing.id),
        playing: true),
  };
}

const _hubStats = MethodChannel('vespertv/stats');

/// How the playing stream is doing, like the Data pool: picture, HDR,
/// audio, downloaded bitrate over ~1.5 s, buffer and dropped frames.
Future<Map<String, Object?>> _playingQuality(VesperToolbox box) async {
  final c = box.playback.controller;
  if (c == null || !c.value.isInitialized) return const {};
  Future<Map<Object?, Object?>?> sample() async {
    try {
      return await _hubStats.invokeMapMethod<Object?, Object?>(
          'getStats', {'playerId': SubtitleTracks.playerIdOf(c)});
    } catch (_) {
      return null;
    }
  }

  final first = await sample();
  final out = <String, Object?>{};
  try {
    if (c.isVideoTrackSupportAvailable()) {
      final v =
          (await c.getVideoTracks()).where((t) => t.isSelected).firstOrNull;
      final size = c.value.size;
      final parts = [
        if (v?.width != null && v?.height != null)
          '${v!.width}x${v.height}'
        else if (size.width > 0)
          '${size.width.round()}x${size.height.round()}',
        if (v?.frameRate != null) '${v!.frameRate!.toStringAsFixed(2)} fps',
        if (DataPoolCard.codecName(v?.codec) case final codec?) codec,
      ];
      if (parts.isNotEmpty) out['video'] = parts.join(' · ');
    }
    if (c.isAudioTrackSupportAvailable()) {
      final a =
          (await c.getAudioTracks()).where((t) => t.isSelected).firstOrNull;
      final language = a?.language;
      final parts = [
        if (DataPoolCard.codecName(a?.codec) case final codec?) codec,
        if (DataPoolCard.channelsName(a?.channelCount) case final layout?)
          layout,
        if (language != null && language.isNotEmpty && language != 'und')
          language.toUpperCase(),
      ];
      if (parts.isNotEmpty) out['audio'] = parts.join(' · ');
    }
  } catch (_) {
    // Not every stream reports its tracks.
  }
  if (first != null) {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final last = await sample() ?? first;
    if (last['hdr'] is String) out['hdr'] = VideoHdrReport.label(last);
    final bytes0 = first['bytes'], bytes1 = last['bytes'];
    final t0 = first['nowMs'], t1 = last['nowMs'];
    if (bytes0 is num && bytes1 is num && t0 is num && t1 is num && t1 > t0) {
      final mbps = (bytes1 - bytes0) * 8 / ((t1 - t0) / 1000) / 1e6;
      out['bitrate_mbps'] = (mbps * 10).round() / 10;
    }
    if (last['bufferedMs'] case final num ms) {
      out['buffered_s'] = (ms / 100).round() / 10;
    }
    final d0 = first['dropped'], d1 = last['dropped'];
    if (d0 is num && d1 is num) out['dropped_frames_now'] = d1 - d0;
    if (last['fileSizeBytes'] case final num size when size > 0) {
      out['file_size_gb'] = (size / 1e8).round() / 10;
    }
  }
  out['buffering'] = c.value.isBuffering;
  return out;
}
