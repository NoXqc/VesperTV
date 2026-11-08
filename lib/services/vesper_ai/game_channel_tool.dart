part of 'vesper_tools.dart';

// Matching Sports Trak games to channels from an AI app: `groups` action
// channels lists a group's channels with their guide (every "NBA League
// Pass" feed at once), and `game_channel` saves the channel a game card
// plays, exactly like the viewer's hold OK > channel pick on the card
// (SportsChannelPicks.pickForGame, per viewer, kept 7 days).

/// The live channels of the group best named by [name], with now / next.
Future<Map<String, Object?>> _groupChannels(
    VesperToolbox box, String name) async {
  if (name.isEmpty) throw VesperToolError('Say which group.');
  await box.playlist.ensureLiveChannelsLoaded();
  final title = box.findLiveGroup(name);
  if (title == null) {
    throw VesperToolError('No live group called "$name". groups action list '
        'shows them.');
  }
  final channels = [
    for (final c in box.playlist.visibleChannels(category: 'tv'))
      if (box.playlist.liveGroupOf(c) == title) c
  ];
  final similar = rankByName({
    for (final g in box.playlist.tvGroups)
      if (!g.isHidden &&
          !box.playlist.hiddenGroupsFor(g.playlistId).contains(g.title))
        g.title
  }, name, (t) => t, limit: 6)
      .where((t) => t != title)
      .toList();
  Map<String, Object?>? slot(EpgProgram? p) => p == null
      ? null
      : {
          'title': p.title,
          'day': _day(p.start),
          'start': _clock(p.start),
          'end': _clock(p.stop),
        };
  return {
    'group': title,
    'channels': [
      for (final c in channels.take(_groupChannelCap))
        {
          ...box.describeChannel(c, withNow: false),
          if (slot(box.epg.getCurrentProgram(c.epgId)) case final now?)
            'now': now,
          if (slot(box.epg.getNextProgram(c.epgId)) case final next?)
            'next': next,
        }
    ],
    if (channels.length > _groupChannelCap)
      'note': '${channels.length} channels in this group; the first '
          '$_groupChannelCap are listed. search finds others by name.',
    if (channels.isEmpty) 'note': 'Every channel of this group is hidden.',
    if (similar.isNotEmpty) 'similar_groups': similar,
  };
}

const _groupChannelCap = 120;

final _gameChannelTool = VesperTool(
  name: 'game_channel',
  description: 'Save which live channel a Sports Trak game card plays, the '
      'same as the viewer picking it on the card. picks: one {game, '
      'channel} per game, refs from sports_today (game) and search / groups '
      'channels / play_game (channel). Only pick a channel whose name, group '
      'or guide names that game, or the network the league lists; never '
      'guess between unnamed feeds. One OK on the TV for the whole list. '
      'Read vesper_help topic "sports" first.',
  schema: {
    'type': 'object',
    'properties': {
      'picks': {
        'type': 'array',
        'description': 'At most 40, one per game.',
        'items': {
          'type': 'object',
          'properties': {
            'game': {
              'type': 'string',
              'description': 'Game ref from sports_today ("g4").',
            },
            'channel': {
              'type': 'string',
              'description': 'Live channel ref ("l12").',
            },
          },
          'required': ['game', 'channel'],
        },
      },
    },
    'required': ['picks'],
  },
  run: (box, args, caller) async {
    final raw = args['picks'];
    if (raw is! List || raw.isEmpty) {
      throw VesperToolError('Give picks: a list of {game, channel} refs.');
    }
    if (raw.length > 40) throw VesperToolError('At most 40 games per call.');
    await box.playlist.ensureLiveChannelsLoaded();
    final visible = {
      for (final c in box.playlist.visibleChannels(category: 'tv')) c.id
    };
    // By game: the last pick for a game given twice wins.
    final todo = <String, (SportsGame, Channel)>{};
    final problems = <Map<String, Object?>>[];
    for (final entry in raw) {
      final p = entry is Map ? entry : const {};
      final gameRef = '${p['game'] ?? ''}'.trim();
      final channelRef = '${p['channel'] ?? ''}'.trim();
      void problem(String why) =>
          problems.add({'game': gameRef, 'channel': channelRef, 'error': why});
      switch ((box.lookup(gameRef), box.lookup(channelRef))) {
        case (final SportsGame g, final Channel c) when c.isLive:
          if (visible.contains(c.id)) {
            todo[SportsChannelPicks.eventKey(g)] = (g, c);
          } else {
            problem('${c.name} is hidden on this TV.');
          }
        case (SportsGame _, _):
          problem('Unknown live channel ref "$channelRef": search again.');
        default:
          problem('Unknown game ref "$gameRef": call sports_today again.');
      }
    }
    if (todo.isEmpty) {
      return {'error': 'Nothing saved.', 'problems': problems};
    }
    final first = todo.values.first;
    await _confirmRemote(
        box,
        caller,
        todo.length == 1
            ? 'An AI app wants {game} to play on {channel} in {tab}.'
            : 'An AI app wants to set the channels of {count} games in {tab}.',
        {
          'game': first.$1.title,
          'channel': first.$2.name,
          'count': todo.length,
          'tab': AppConstants.sportsTabName,
        });
    final picks = SportsChannelPicks.load(box.storage);
    for (final (g, c) in todo.values) {
      await picks.pickForGame(g, c.id);
    }
    return {
      'saved': [
        for (final (g, c) in todo.values) {'game': g.title, 'channel': c.name}
      ],
      if (problems.isNotEmpty) 'problems': problems,
      'note': 'The cards show these channels the next time Sports Trak '
          'refreshes or opens. The viewer can change them on the card.',
    };
  },
);
