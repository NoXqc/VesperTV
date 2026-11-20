part of 'vesper_tools.dart';

// `my_groups`: the viewer's own live groups for an AI (owner, 2026-11-09:
// "create a sports group and add all the sports channels from my favorites
// in it"). The same groups as hold OK > Move to group… on the TV
// (`UserGroups` through PlaylistManager): a channel moved in leaves its
// provider group and shows only there; it stays a favourite. Also orders
// channels in any group, like hold OK > Move Up / Down.

/// The live channels behind [refs] (from favorites, search, groups), and
/// the refs that aren't one.
(List<Channel>, List<String>) _liveChannelsOf(VesperToolbox box, Object? refs) {
  if (refs is! List || refs.isEmpty) {
    throw VesperToolError('Give refs: channel refs from favorites, search or '
        'groups.');
  }
  final channels = <Channel>[];
  final unknown = <String>[];
  for (final r in refs) {
    final c = box.lookup('$r');
    if (c is Channel && c.isLive && !channels.any((x) => x.id == c.id)) {
      channels.add(c);
    } else if (c is! Channel || !c.isLive) {
      unknown.add('$r');
    }
  }
  return (channels, unknown);
}

/// [shown]'s index for a move [to] top / bottom / up / down (by [steps]) /
/// a position (1 = first), from [from].
int _moveTarget(String to, int from, int length, int steps) {
  final index = switch (to.toLowerCase()) {
    'top' || 'first' => 0,
    'bottom' || 'last' => length - 1,
    'up' || 'higher' => from - steps,
    'down' || 'lower' => from + steps,
    final n => (int.tryParse(n) ??
            (throw VesperToolError(
                'to: top, bottom, up, down or a position number.'))) -
        1,
  };
  return index.clamp(0, length - 1);
}

final _myGroupsTool = VesperTool(
  name: 'my_groups',
  description:
      'The viewer\'s own live TV groups (top of the TV tab\'s groups, like '
      'hold OK > Move to group… on the TV, and the playlist editor\'s Move / '
      'Copy to group). list: each with its channels. create: a new empty '
      'group. add: channels (refs) into a group, made if new; they leave '
      'their provider group and show only in it (still favourites if they '
      'were). With playlist: into that playlist\'s own (provider) group '
      'instead, e.g. "put these channels in Sports of playlist B". With copy '
      'true: they stay where they are and also show in that group. remove: '
      'channels back to their own group, copies removed (with group: only '
      'their copy in that group). delete: a group (its channels go back). '
      'order: a group\'s channels, refs first in that order, the rest after. '
      'move: a group (no ref), or a channel (ref) inside the group it is in '
      '(own or provider; group names the group for a copy), to top, bottom, '
      'up / down (steps) or a position.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'create', 'add', 'remove', 'delete', 'order', 'move'],
      },
      'group': {
        'type': 'string',
        'description': 'The own group\'s name (for create: the new name); '
            'with playlist, that playlist\'s group.',
      },
      'playlist': {
        'type': 'string',
        'description': 'For add: put the channels in a group of this '
            'playlist (name or id) instead of an own group.',
      },
      'copy': {
        'type': 'boolean',
        'description': 'For add: copy (the channels also stay in their '
            'group) instead of move.',
      },
      'refs': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'For add / remove / order: live channel refs.',
      },
      'ref': {
        'type': 'string',
        'description': 'For move: a channel ref (else the group moves).',
      },
      'to': {
        'type': 'string',
        'description': 'For move: top, bottom, up, down or a position '
            '(1 = first).',
      },
      'steps': {
        'type': 'integer',
        'description': 'For move up / down: how many places (default 1).',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final action = _str(args, 'action');
    final playlist = box.playlist;
    await playlist.ensureLiveChannelsLoaded();
    List<Channel> channelsOf(String title) =>
        playlist.visibleChannels(groupTitle: title, category: 'tv');
    if (action == 'list') {
      return {
        'groups': [
          for (final g in playlist.userGroups)
            {
              'name': g,
              'channels': [
                for (final c in channelsOf(g).take(200))
                  {'ref': box.refFor(c), 'title': c.name}
              ],
            }
        ],
        if (playlist.userGroups.isEmpty)
          'note': 'No own groups yet: create or add makes one.',
      };
    }
    if (box.restrictedViewer) {
      throw VesperToolError('This profile cannot change groups.');
    }
    final name = _str(args, 'group');
    String ownGroup() {
      if (name.isEmpty) throw VesperToolError('Which group? Give group.');
      for (final g in playlist.userGroups) {
        if (g == name || TitleSearch.fold(g) == TitleSearch.fold(name)) {
          return g;
        }
      }
      throw VesperToolError('"$name" is not one of the viewer\'s own groups '
          '(list shows them).');
    }

    switch (action) {
      case 'create':
        if (name.isEmpty) throw VesperToolError('Give the group a name.');
        if (playlist.isUserGroup(name)) {
          return {'group': name, 'note': 'That group is already there.'};
        }
        return {'created': await playlist.createUserGroup(name)};
      case 'add':
        final (channels, unknown) = _liveChannelsOf(box, args['refs']);
        if (name.isEmpty) throw VesperToolError('Which group? Give group.');
        if (channels.isEmpty) {
          throw VesperToolError('None of these refs is a live channel.');
        }
        final copy = _bool(args, 'copy') ?? false;
        final GroupRef dest;
        final playlistName = _str(args, 'playlist');
        if (playlistName.isNotEmpty) {
          // A provider group of any enabled playlist (the editor's Move /
          // Copy to group), by the title the TV shows.
          final s = _editorSessions(box, playlistName, allowAll: false).single;
          if (!s.profile.enabled) {
            throw VesperToolError('${s.profile.name} is turned off.');
          }
          await s.ensureLiveChannelsLoaded();
          final titles = [for (final g in s.tvGroups) g.title];
          final title = titles.contains(name)
              ? name
              : titles.firstWhere(
                  (g) => TitleSearch.fold(g) == TitleSearch.fold(name),
                  orElse: () => throw VesperToolError(
                      '${s.profile.name} has no group "$name" (the groups '
                      'tool lists them).'));
          dest = GroupRef.provider(s.profile.id, title);
        } else {
          var title = playlist.userGroups.firstWhere(
              (g) => TitleSearch.fold(g) == TitleSearch.fold(name),
              orElse: () => '');
          // New: made unique against the provider groups (groups are
          // picked by title).
          if (title.isEmpty) title = await playlist.createUserGroup(name);
          dest = GroupRef.own(title);
        }
        final done = await playlist.placeChannels(channels, dest, copy: copy);
        return {
          'group': dest.isOwn ? dest.title : playlist.placementLabel(dest),
          copy ? 'copied' : 'moved': [for (final c in channels) c.name],
          if (done.skipped > 0) 'already_there': done.skipped,
          if (unknown.isNotEmpty) 'not_live_channels': unknown,
        };
      case 'remove':
        final (channels, unknown) = _liveChannelsOf(box, args['refs']);
        if (name.isNotEmpty) {
          // Only the copy in that group; the channel stays where it is.
          final copies = [
            for (final c in channels)
              if (playlist.isCopyIn(c, name)) c
          ];
          for (final c in copies) {
            await playlist.removeCopyFrom(c, name);
          }
          return {
            'copies_removed_from': name,
            'channels': [for (final c in copies) c.name],
            if (copies.length < channels.length)
              'note': 'The others have no copy in "$name".',
            if (unknown.isNotEmpty) 'not_live_channels': unknown,
          };
        }
        final back = [
          for (final c in channels)
            if (playlist.placementOf(c) != null) c
        ];
        await playlist.unplaceChannels(back);
        return {
          'back_to_their_groups': [
            // The group's name on the TV (renamed in the editor or not).
            for (final c in back) '${c.name} (${playlist.liveGroupOf(c)})'
          ],
          if (unknown.isNotEmpty) 'not_live_channels': unknown,
        };
      case 'delete':
        final title = ownGroup();
        await _confirmRemote(box, caller,
            'An AI app wants to delete your group {group}.', {'group': title});
        await playlist.deleteUserGroup(title);
        return {'deleted': title};
      case 'order':
        final title = ownGroup();
        final (channels, unknown) = _liveChannelsOf(box, args['refs']);
        final now = await playlist
            .orderUserGroupChannels(title, [for (final c in channels) c.id]);
        return {
          'group': title,
          'order': [
            for (final (i, c) in now.take(200).indexed) '${i + 1}. ${c.name}'
          ],
          if (unknown.isNotEmpty) 'not_live_channels': unknown,
        };
      case 'move':
        final steps = _int(args, 'steps', 1, min: 1, max: 10000);
        final to = _str(args, 'to');
        if (to.isEmpty) throw VesperToolError('Give to.');
        final ref = _str(args, 'ref');
        if (ref.isEmpty) {
          final title = ownGroup();
          final groups = playlist.userGroups;
          final from = groups.indexOf(title);
          final index = _moveTarget(to, from, groups.length, steps);
          final placed = await playlist.moveUserGroup(title, index - from);
          return {
            'group': title,
            'position': (placed ?? from) + 1,
            'of': groups.length,
          };
        }
        final c = box.lookup(ref);
        if (c is! Channel || !c.isLive) {
          throw VesperToolError('Give a live channel ref.');
        }
        // A copy is listed in a group that isn't its own: group names it.
        final group = name.isNotEmpty && playlist.isCopyIn(c, name)
            ? name
            : playlist.liveGroupOf(c);
        // An own group spans every playlist; a provider group's order is
        // its playlist's (PlaylistSession.moveChannel).
        var shown = playlist.isUserGroup(group)
            ? channelsOf(group)
            : playlist.visibleChannels(
                playlistId: c.playlistId, groupTitle: group, category: 'tv');
        // Moved or copied into another playlist's group: that one's list.
        for (final p in playlist.profiles) {
          if (shown.any((x) => x.id == c.id)) break;
          if (!p.enabled || p.id == c.playlistId) continue;
          shown = playlist.visibleChannels(
              playlistId: p.id, groupTitle: group, category: 'tv');
        }
        final from = shown.indexWhere((x) => x.id == c.id);
        if (from < 0) throw VesperToolError('${c.name} is not listed now.');
        final index = _moveTarget(to, from, shown.length, steps);
        final placed = index == from
            ? from
            : await playlist.moveChannel(c, index - from, inGroup: group);
        return {
          'moved': c.name,
          'group': group,
          'position': (placed ?? from) + 1,
          'of': shown.length,
        };
    }
    throw VesperToolError('Unknown my_groups action $action.');
  },
);
