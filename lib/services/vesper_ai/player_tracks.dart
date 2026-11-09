part of 'vesper_tools.dart';

// The player tool's audio track and subtitle actions (owner, 2026-11-09:
// "let the AI change audio track and subtitles"; it had swapped a Media Hub
// stream to get English when the file had an English track). Same steps as
// the player's Audio / Subtitles buttons, including remembering the choice
// for the rest of the show (AudioTrackPreferences, rememberForSeries).

/// The language code [asked] means: a code ("en", "fre") or a name in
/// English or the language itself ("French", "Español"); null when unknown.
String? trackLanguageCode(String asked) {
  final text = asked.trim().toLowerCase();
  if (text.isEmpty) return null;
  if (RegExp(r'^[a-z]{2,3}([-_][a-z]{2,4})?$').hasMatch(text) &&
      languageName(text).toLowerCase() != text) {
    return text;
  }
  for (final code in trackLanguages) {
    if (languageName(code).toLowerCase() == text) return code;
  }
  final codes = streamLanguagesOf(text).codes;
  return codes.isEmpty ? null : codes.first;
}

/// A track that is a commentary or audio description: never picked for a
/// language when a plain one exists.
bool _isExtraAudio(String? label) =>
    RegExp(r'commentary|comment|descri|audio ?desc|\bad\b|visually',
            caseSensitive: false)
        .hasMatch(label ?? '');

/// The audio track to play for [language] (a code): the selected one when
/// it already is that language, else the first plain (not commentary) one,
/// else any; null when the file has none.
VideoAudioTrack? pickAudioTrack(List<VideoAudioTrack> tracks, String language) {
  final same =
      tracks.where((t) => sameTrackLanguage(t.language, language)).toList();
  return same.where((t) => t.isSelected).firstOrNull ??
      same.where((t) => !_isExtraAudio(t.label)).firstOrNull ??
      same.firstOrNull;
}

/// The subtitle track for [language]: full (not forced) first, never the
/// live closed-captions track unless asked for "cc".
SubtitleTrack? pickSubtitleTrack(List<SubtitleTrack> tracks, String language,
    {bool forced = false}) {
  if (language == 'cc') {
    return tracks.where((t) => t.closedCaptions).firstOrNull;
  }
  final same = tracks
      .where(
          (t) => !t.closedCaptions && sameTrackLanguage(t.language, language))
      .toList();
  return same.where((t) => t.forced == forced).firstOrNull ?? same.firstOrNull;
}

String _audioName(VideoAudioTrack t, int index) {
  final name = audioTrackName(t.label, t.language);
  return name.isEmpty ? 'Audio ${index + 1}' : name;
}

String _subtitleName(SubtitleTrack t, int index) {
  if (t.closedCaptions) return 'Closed captions (CC)';
  final label = t.label?.trim() ?? '';
  final name = languageName(t.language);
  final base = label.isNotEmpty
      ? label
      : name.isNotEmpty
          ? name
          : 'Track ${index + 1}';
  return t.forced && !base.toLowerCase().contains('forced')
      ? '$base (forced)'
      : base;
}

String? _languageOf(String? code) =>
    code == null || code.isEmpty || noTrackLanguage.contains(code.toLowerCase())
        ? null
        : code;

Future<Map<String, Object?>> _audioTracks(
    VesperToolbox box, VideoPlayerHdrController c) async {
  final tracks = await c.getAudioTracks();
  return {
    'tracks': [
      for (final (i, t) in tracks.indexed)
        {
          'track': i + 1,
          'name': _audioName(t, i),
          if (_languageOf(t.language) != null) 'language': t.language,
          if (DataPoolCard.codecName(t.codec) != null)
            'codec': DataPoolCard.codecName(t.codec),
          if (DataPoolCard.channelsName(t.channelCount) != null)
            'channels': DataPoolCard.channelsName(t.channelCount),
          if (t.isSelected) 'playing': true,
        },
    ],
  };
}

Future<Map<String, Object?>> _setAudioTrack(VesperToolbox box,
    VideoPlayerHdrController c, Map<String, Object?> args) async {
  final playback = box.playback;
  final channel = playback.currentChannel;
  final tracks = await c.getAudioTracks();
  if (tracks.isEmpty) {
    throw VesperToolError('This stream has no audio tracks to choose from.');
  }
  final asked = _str(args, 'language');
  VideoAudioTrack? picked;
  if (args['track'] != null) {
    final n = _int(args, 'track', 0);
    if (n < 1 || n > tracks.length) {
      throw VesperToolError('Track $n does not exist: there are '
          '${tracks.length} (audio_tracks lists them).');
    }
    picked = tracks[n - 1];
  } else {
    final code = trackLanguageCode(asked);
    if (code == null) throw VesperToolError('Which language or track?');
    picked = pickAudioTrack(tracks, code);
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
  if (!picked.isSelected) await c.selectAudioTrack(picked.id);
  // Remembered like a pick in the player: the rest of the show, and this
  // movie when it resumes.
  if (channel != null &&
      box.storage.getActiveViewerId() == viewer &&
      playback.controller == c &&
      playback.currentChannel == channel) {
    await AudioTrackPreferences.remember(box.storage, channel, picked);
  }
  return {'done': 'audio: ${_audioName(picked, tracks.indexOf(picked))}'};
}

bool _onlineSubtitles(VesperToolbox box, Channel? channel) =>
    channel != null &&
    (channel.subtitles.isNotEmpty ||
        (AddonService.supports(channel) &&
            AddonService(box.storage).anyEnabled));

Future<Map<String, Object?>> _subtitles(
    VesperToolbox box, VideoPlayerHdrController c) async {
  final id = SubtitleTracks.playerIdOf(c);
  var tracks = const <SubtitleTrack>[];
  try {
    tracks = await SubtitleTracks.list(id);
  } catch (_) {}
  final external = SubtitleTracks.externalFor.value == id
      ? SubtitleTracks.externalLabel[id]
      : null;
  final on = external != null || tracks.any((t) => t.selected);
  return {
    'tracks': [
      for (final (i, t) in tracks.indexed)
        {
          'track': i + 1,
          'name': _subtitleName(t, i),
          if (_languageOf(t.language) != null) 'language': t.language,
          if (t.forced) 'forced': true,
          if (t.closedCaptions) 'closed_captions': true,
          if (external == null && t.selected) 'showing': true,
        },
    ],
    if (external != null) 'showing_online': external,
    if (!on) 'off': true,
    'online_available': _onlineSubtitles(box, box.playback.currentChannel),
  };
}

Future<Map<String, Object?>> _setSubtitles(VesperToolbox box,
    VideoPlayerHdrController c, Map<String, Object?> args) async {
  final channel = box.playback.currentChannel;
  final storage = box.storage;
  final id = SubtitleTracks.playerIdOf(c);
  final asked = _str(args, 'language').toLowerCase();
  var tracks = const <SubtitleTrack>[];
  try {
    tracks = await SubtitleTracks.list(id);
  } catch (_) {}

  Future<Map<String, Object?>> embedded(SubtitleTrack? track) async {
    // An episode: the choice carries on to the rest of the series; Off
    // forgets it (the player's Subtitles button does the same).
    await SubtitleTracks.rememberForSeries(storage, channel,
        kind: track == null ? null : 'embedded',
        lang: track?.language,
        label: track?.label,
        forced: track?.forced ?? false);
    await SubtitleTracks.clearExternal(c);
    await SubtitleTracks.select(id, track);
    return {
      'done': track == null
          ? 'subtitles off'
          : 'subtitles: ${_subtitleName(track, tracks.indexOf(track))}'
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
  final cc = asked == 'cc' || asked.contains('closed caption');
  final code = cc ? 'cc' : trackLanguageCode(asked);
  if (code == null) throw VesperToolError('Which language, or off?');
  final track = pickSubtitleTrack(tracks, code, forced: args['forced'] == true);
  if (track != null) return embedded(track);
  if (cc) throw VesperToolError('This channel has no closed captions.');

  // Not in the file: the first match from the viewer's subtitle add-ons
  // (or the stream's own subtitle files), like a language picked online.
  if (channel == null || !_onlineSubtitles(box, channel)) {
    throw VesperToolError('No ${languageName(code)} subtitles in this file'
        '${channel != null && AddonService.supports(channel) ? ', and no '
            'subtitle add-on is on (Settings > Add-ons)' : ''}.');
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
  if (box.playback.controller != c) {
    throw VesperToolError('The stream changed meanwhile.');
  }
  await SubtitleTracks.useExternal(c, text);
  SubtitleTracks.externalLabel[id] =
      languageName(match.lang).isEmpty ? match.lang : languageName(match.lang);
  await storage.addOnlineSubtitleLang(match.lang);
  await SubtitleTracks.rememberForSeries(storage, channel,
      kind: 'online', lang: match.lang);
  return {
    'done': 'subtitles: ${SubtitleTracks.externalLabel[id]} '
        '(online, ${match.addonName})'
  };
}
