part of 'vesper_tools.dart';

// `profiles` and `parental`: viewer profiles and kids-profile limits from
// Vesper AI. The AI gets the power the profile on screen already has in
// Settings, never more:
// - On a kids profile every change (switching away included) needs the
//   parental PIN typed on the TV's own pad, as the TV's Settings do.
// - Loosening a kids profile (allowing groups, deleting it, a new PIN) asks
//   for the PIN on the TV from any profile: a kid can talk to the AI too.
// - The PIN never passes through the AI: no tool takes or returns digits,
//   and there is no "remove the PIN" or "make this profile unrestricted".

VesperProfileControl _profileControl(VesperToolbox box) =>
    box.profiles ??
    (throw VesperToolError('Profiles are not available on this device.'));

/// The PIN on the TV, or an error saying nothing changed.
Future<void> _needPin(VesperProfileControl p) async {
  if (!p.pinSet) return;
  if (!await p.askPin()) {
    throw VesperToolError('The parental PIN was not entered on the TV, so '
        'nothing changed.');
  }
}

/// The profile named [said] (its id, then its name), or an error listing
/// them.
ViewerProfile _findProfile(VesperProfileControl p, String said) {
  if (said.isEmpty) throw VesperToolError('Say which profile.');
  final folded = TitleSearch.fold(said);
  for (final v in p.profiles) {
    if (v.id == said ||
        TitleSearch.fold(v.name) == folded ||
        TitleSearch.fold(v.displayName) == folded) {
      return v;
    }
  }
  final search = TitleSearch(said);
  final close = [
    for (final v in p.profiles)
      if (search.matches(v.name) || search.matches(v.displayName)) v
  ];
  if (close.length == 1) return close.single;
  throw VesperToolError('No profile called "$said". Profiles: '
      '${p.profiles.map((v) => v.displayName).join(', ')}.');
}

Map<String, Object?> _describeProfile(
        VesperProfileControl p, ViewerProfile v) =>
    {
      'id': v.id,
      'name': v.displayName,
      if (v.isRestricted) 'kids': true,
      if (v.isMain) 'main': true,
      if (v.id == p.active.id) 'active': true,
    };

final _profilesTool = VesperTool(
  name: 'profiles',
  description: 'The TV\'s viewer profiles (each with its own favourites, '
      'history and hidden groups): list them, switch to one, create one '
      '(kids: true = a kids profile that only sees allowed groups), rename '
      'or delete one. On a kids profile the parental PIN is asked on the '
      'TV. Read vesper_help topic "profiles" first.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'switch', 'create', 'rename', 'delete'],
      },
      'profile': {
        'type': 'string',
        'description': 'For switch / rename / delete: its name or id.',
      },
      'name': {
        'type': 'string',
        'description': 'For create / rename: the new name.',
      },
      'kids': {
        'type': 'boolean',
        'description': 'For create: a kids profile (fixed once created).',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final p = _profileControl(box);
    final action = _str(args, 'action');
    final onKids = p.active.isRestricted;
    switch (action) {
      case 'list':
        return {
          'profiles': [for (final v in p.profiles) _describeProfile(p, v)],
          'pin_set': p.pinSet,
        };
      case 'switch':
        final target = _findProfile(p, _str(args, 'profile'));
        if (target.id == p.active.id) {
          return {'active': target.displayName, 'note': 'Already on it.'};
        }
        await _confirmRemote(
            box,
            caller,
            'An AI app wants to switch to the profile {name}.',
            {'name': target.displayName});
        // Leaving a kids profile: the PIN, like the TV's own switcher.
        if (onKids) await _needPin(p);
        if (!await p.switchTo(target.id, unlocked: onKids)) {
          throw VesperToolError('The switch did not happen.');
        }
        return {'active': target.displayName};
      case 'create':
        final name = _str(args, 'name');
        if (name.isEmpty) throw VesperToolError('Say the new profile\'s name.');
        if (name.length > 40) throw VesperToolError('That name is too long.');
        if (p.profiles.length >= 12) {
          throw VesperToolError('This TV already has 12 profiles.');
        }
        final kids = args['kids'] == true;
        await _confirmRemote(
            box,
            caller,
            kids
                ? 'An AI app wants to create the kids profile {name}.'
                : 'An AI app wants to create the profile {name}.',
            {'name': name});
        if (onKids) await _needPin(p);
        // A kids profile needs a PIN to get out of it: set one on the TV.
        if (kids && !p.pinSet && !await p.newPin()) {
          throw VesperToolError('A kids profile needs a parental PIN, set '
              'on the TV. It was not set, so nothing was created.');
        }
        final made = await p.create(name,
            kid: kids, colour: p.profiles.length % kProfileColors.length);
        return {
          'created': _describeProfile(p, made),
          if (kids)
            'note': 'It sees no groups until some are allowed (parental '
                'allow_groups).',
        };
      case 'rename':
        final target = _findProfile(p, _str(args, 'profile'));
        final name = _str(args, 'name');
        if (name.isEmpty) throw VesperToolError('Say the new name.');
        if (name.length > 40) throw VesperToolError('That name is too long.');
        await _confirmRemote(
            box,
            caller,
            'An AI app wants to rename the profile {name} to {new}.',
            {'name': target.displayName, 'new': name});
        if (onKids) await _needPin(p);
        await p.rename(target.id, name);
        return {'renamed': name};
      case 'delete':
        final target = _findProfile(p, _str(args, 'profile'));
        if (target.isMain) {
          throw VesperToolError('The Main profile cannot be deleted.');
        }
        if (target.id == p.active.id) {
          throw VesperToolError('This profile is on screen; switch to '
              'another one first.');
        }
        // Always asked on the TV, from any caller: its favourites and
        // history go with it.
        if (!await box.host.confirm(
            'Delete the profile {name}? Its favourites and history are '
            'deleted too.',
            {'name': target.displayName})) {
          throw VesperToolError('The viewer said no on the TV.');
        }
        if (onKids || target.isRestricted) await _needPin(p);
        if (!await p.delete(target.id)) {
          throw VesperToolError('It could not be deleted.');
        }
        return {'deleted': target.displayName};
    }
    throw VesperToolError('Unknown action $action.');
  },
);

/// Groups (every tab, or one) whose names hold [words], per playlist.
List<(String, String)> _groupsNamed(
    VesperToolbox box, String words, String tab) {
  final search = TitleSearch(words);
  final playlists = {for (final p in box.playlist.profiles) p.id};
  final lists = switch (tab) {
    'tv' => [box.playlist.tvGroups],
    'movies' => [box.playlist.vodGroups],
    'series' => [box.playlist.seriesGroups],
    _ => [
        box.playlist.tvGroups,
        box.playlist.vodGroups,
        box.playlist.seriesGroups
      ],
  };
  final seen = <String>{};
  return [
    for (final list in lists)
      for (final g in list)
        if (playlists.contains(g.playlistId) &&
            search.matches(g.title) &&
            seen.add('${g.playlistId}\u0000${g.title}'))
          (g.playlistId, g.title)
  ];
}

final _parentalTool = VesperTool(
  name: 'parental',
  description: 'Parental controls for kids profiles: status (PIN set, what '
      'each kids profile may see), allow_groups / block_groups (a kids '
      'profile only sees the groups allowed to it), change_pin (typed on '
      'the TV, never by you). Allowing groups asks for the PIN on the TV. '
      'Read vesper_help topic "profiles" first.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['status', 'allow_groups', 'block_groups', 'change_pin'],
      },
      'profile': {
        'type': 'string',
        'description': 'The kids profile (name or id).',
      },
      'contains': {
        'type': 'string',
        'description': 'For allow / block: words the group names contain '
            '("Disney", "Kids").',
      },
      'tab': {
        'type': 'string',
        'enum': ['all', 'tv', 'movies', 'series'],
        'description': 'Groups of one tab only (default all).',
      },
      'preview': {
        'type': 'boolean',
        'description': 'For allow / block: list the groups, change nothing.',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    final p = _profileControl(box);
    final action = _str(args, 'action');
    switch (action) {
      case 'status':
        return {
          'pin_set': p.pinSet,
          'kids_profiles': [
            for (final v in p.profiles.where((v) => v.isRestricted))
              {
                ..._describeProfile(p, v),
                'allowed_groups': [
                  for (final pl in box.playlist.profiles)
                    for (final g in box.storage.getShownGroupsFor(v.id, pl.id))
                      box._manyPlaylists ? '$g (${pl.name})' : g
                ].take(80).toList(),
              }
          ],
          if (!p.profiles.any((v) => v.isRestricted))
            'note': 'No kids profile yet (profiles action create, kids: '
                'true).',
        };
      case 'allow_groups':
      case 'block_groups':
        final allow = action == 'allow_groups';
        final target = _findProfile(p, _str(args, 'profile'));
        if (!target.isRestricted) {
          throw VesperToolError('${target.displayName} is not a kids '
              'profile: it sees every group it does not hide (the groups '
              'tool hides them on the profile on screen).');
        }
        final words = _str(args, 'contains');
        if (words.isEmpty) throw VesperToolError('Say which groups.');
        await box.playlist.ensureLiveChannelsLoaded();
        final found = _groupsNamed(box, words, _str(args, 'tab').toLowerCase());
        final changes = [
          for (final (pl, title) in found)
            if (box.storage.getShownGroupsFor(target.id, pl).contains(title) !=
                allow)
              (pl, title)
        ];
        final names = [for (final (_, t) in changes) t];
        if (found.isEmpty) {
          throw VesperToolError('No group matches "$words".');
        }
        if (changes.isEmpty) {
          return {
            'changed': 0,
            'note': allow
                ? 'Those groups are already allowed.'
                : 'Those groups are already blocked.',
          };
        }
        if (changes.length > 300) {
          throw VesperToolError('${changes.length} groups match "$words"; '
              'use more precise words.');
        }
        if (args['preview'] == true) {
          return {
            'preview': true,
            'would_change': names.length,
            'groups': names.take(60).toList(),
          };
        }
        await _confirmRemote(
            box,
            caller,
            allow
                ? 'An AI app wants to let {name} see {count} groups ({words}).'
                : 'An AI app wants to block {count} groups ({words}) for {name}.',
            {
              'name': target.displayName,
              'count': changes.length,
              'words': words
            });
        // Loosening, from any profile; tightening, only from the kid's own.
        if (allow || p.active.isRestricted) await _needPin(p);
        final byPlaylist = <String, List<String>>{};
        for (final (pl, title) in changes) {
          (byPlaylist[pl] ??= []).add(title);
        }
        for (final e in byPlaylist.entries) {
          final shown = box.storage.getShownGroupsFor(target.id, e.key);
          allow ? shown.addAll(e.value) : shown.removeAll(e.value);
          await box.storage.setShownGroupsFor(target.id, e.key, shown);
        }
        // The kid on screen sees it now; another profile's at its switch.
        if (target.id == p.active.id) box.playlist.applyActiveViewer();
        return {
          allow ? 'allowed' : 'blocked': names.take(60).toList(),
          'changed': names.length,
        };
      case 'change_pin':
        await _confirmRemote(box, caller,
            'An AI app wants to change the parental PIN.', const {});
        await _needPin(p);
        if (!await p.newPin()) {
          throw VesperToolError('No new PIN was set on the TV.');
        }
        return {'pin_changed': true, 'note': 'Typed on the TV only.'};
    }
    throw VesperToolError('Unknown action $action.');
  },
);
