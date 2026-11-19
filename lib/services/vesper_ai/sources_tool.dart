part of 'vesper_tools.dart';

// The full-screen player's Sources (owner, 2026-11-18): the live channel
// playing now and its other streams, the same list the drawer shows
// ([liveSourceRows]: quality copies, playlist editor fallbacks, the same
// channel in other playlists, a Dispatcharr channel's streams). list shows
// them; play switches the channel to one, for this viewer only. Adding a
// source = playlist_editor add_fallback (undoable); the Dispatcharr order
// is the settings key dispatcharr_sources.

final _sourcesTool = VesperTool(
  name: 'sources',
  description: 'The Sources of the live channel playing full screen on the '
      'TV (the same list as the player\'s Sources drawer): its quality '
      'copies, playlist fallbacks, the same channel in other playlists and, '
      'for a Dispatcharr channel, the streams Dispatcharr merged into it. '
      'action list: every source with an index, playlist, quality and which '
      'one plays now. action play index: switch the channel to that source '
      '(one OK on the TV). To add a source for good use playlist_editor '
      'add_fallback; settings key dispatcharr_sources sets which Dispatcharr '
      'streams are listed. Android TVs only.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'play'],
      },
      'index': {
        'type': 'integer',
        'description': 'For play: the index from list.',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    if (isDesktop) {
      throw VesperToolError('Sources is in the Android TV player only.');
    }
    final playing = box.playback.currentChannel;
    if (playing == null || !playing.isLive) {
      throw VesperToolError('No live channel is playing on the TV.');
    }
    final (:rows, :canAdd) = await liveSourceRows(box.playlist, playing);
    switch ('${args['action'] ?? ''}') {
      case 'list':
        return {
          'channel': playing.name,
          'sources': [
            for (final (i, (c, e)) in rows.indexed)
              {
                'index': i,
                'name': c.sourceName,
                if (e.playlist.isNotEmpty) 'playlist': e.playlist,
                if ((e.quality ?? liveSourceQuality(c)) case final q?)
                  'quality': q,
                if (e.current) 'playing': true,
              }
          ],
          if (rows.length < 2)
            'note': 'No other source for this channel. playlist_editor '
                'add_fallback adds one.',
        };
      case 'play':
        final i = args['index'];
        if (i is! num || i < 0 || i >= rows.length) {
          throw VesperToolError('Give index: one from action list.');
        }
        final (c, e) = rows[i.toInt()];
        if (e.current) return {'note': '${c.sourceName} is already playing.'};
        await _confirmRemote(box, caller, 'An AI app wants to play {title}.',
            {'title': c.sourceName});
        final switched =
            await playPickedLiveSource(playing, c, box.playback.playLiveSource);
        return {
          'playing': c.sourceName,
          'channel': playing.name,
          if (switched != null)
            'note': 'Dispatcharr switched the channel itself, for everyone '
                'watching it on that server.',
        };
      default:
        throw VesperToolError('action must be list or play.');
    }
  },
);
