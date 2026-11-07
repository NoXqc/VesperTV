part of 'vesper_tools.dart';

// The playlist editor for Vesper and AI apps: the same layer the editor
// page writes ([PlaylistEdits]: rules, hidden channels, renames, fallbacks),
// never the provider's playlist. Every change goes in [AiEditLog] so it can
// be undone without touching anything changed since. The manual for the
// model is `vesper_help` topic `playlist_editor` (vesper_help.dart).
// See dev-notes/vesper-ai.md (Playlist editor tool).

const _editorChangeActions = {
  'hide_no_guide',
  'hide_dead',
  'hide_channels',
  'show_channels',
  'add_rule',
  'remove_rule',
  'rename',
  'rename_group',
  'add_fallback',
  'remove_fallback',
  'set_option',
};

/// The playlists an action works on: [name] (id or name), or every enabled
/// playlist when empty and [allowAll], else the only one.
List<PlaylistSession> _editorSessions(VesperToolbox box, String name,
    {bool allowAll = true}) {
  final all = [
    for (final p in box.playlist.profiles)
      if (box.playlist.editorSession(p.id) case final s?) s
  ];
  if (name.isEmpty) {
    final enabled = all.where((s) => s.profile.enabled).toList();
    if (enabled.isEmpty) throw VesperToolError('No playlist is enabled.');
    if (enabled.length == 1 || allowAll) return enabled;
    throw VesperToolError('Say which playlist: '
        '${enabled.map((s) => s.profile.name).join(', ')}.');
  }
  for (final s in all) {
    if (s.profile.id == name) return [s];
  }
  final folded = TitleSearch.fold(name);
  final exact = [
    for (final s in all)
      if (TitleSearch.fold(s.profile.name) == folded) s
  ];
  if (exact.isNotEmpty) return exact.take(1).toList();
  final search = TitleSearch(name);
  final near = [
    for (final s in all)
      if (search.matches(s.profile.name)) s
  ];
  if (near.length == 1) return near;
  throw VesperToolError('No single playlist matches "$name". Playlists: '
      '${all.map((s) => s.profile.name).join(', ')}.');
}

/// A live channel from a `find_channels` id (`playlistId::rawId`) or a
/// search ref ("l12").
(PlaylistSession, Channel) _editorChannel(VesperToolbox box, String id) {
  var key = id.trim();
  if (!key.contains('::')) {
    final item = box.lookup(key);
    if (item is Channel && item.isLive) key = item.id;
  }
  final i = key.indexOf('::');
  if (i <= 0) {
    throw VesperToolError(
        'Use a channel id from playlist_editor find_channels ("$id" is not one).');
  }
  final s = box.playlist.editorSession(key.substring(0, i));
  if (s != null) {
    final raw = key.substring(i + 2);
    for (final c in s.allLiveChannels) {
      if (c.rawId == raw) return (s, c);
    }
  }
  throw VesperToolError('No live channel with id "$id".');
}

List<String> _strList(Map<String, Object?> args, String key) {
  final v = args[key];
  if (v is List) {
    return [
      for (final x in v)
        if ('$x'.trim().isNotEmpty) '$x'.trim()
    ];
  }
  final s = _str(args, key);
  return s.isEmpty ? const [] : [s];
}

bool? _bool(Map<String, Object?> args, String key) {
  final v = args[key];
  if (v is bool) return v;
  if (v is String) {
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return null;
}

PlaylistEdits _copyEdits(PlaylistEdits e) => PlaylistEdits.fromJson(e.toJson());

/// The rawIds [edits] would hide in [s] (restores the saved layer after).
Set<String> _editorHiddenBy(PlaylistSession s, PlaylistEdits edits) {
  try {
    return edits.apply(s.allLiveChannels);
  } finally {
    s.applyEdits();
  }
}

/// What saving [next] would change on the TV in [s], with a few examples.
Map<String, Object?> _editorEffect(PlaylistSession s, PlaylistEdits next) {
  final live = s.allLiveChannels.toList();
  final beforeHidden = {...s.editHidden};
  final beforeNames = {for (final c in live) c.rawId: c.name};
  final Set<String> hidden;
  final Map<String, String> afterNames;
  try {
    hidden = next.apply(live);
    afterNames = {for (final c in live) c.rawId: c.name};
  } finally {
    s.applyEdits();
  }
  final byId = {for (final c in live) c.rawId: c};
  final newlyHidden = hidden.difference(beforeHidden);
  final shownAgain = beforeHidden.difference(hidden);
  final renamed = [
    for (final c in live)
      if (beforeNames[c.rawId] != afterNames[c.rawId]) c.rawId
  ];
  List<String> names(Iterable<String> ids) => [
        for (final id in ids.take(8))
          if (byId[id] case final c?) beforeNames[c.rawId] ?? c.sourceName
      ];
  return {
    'hidden': newlyHidden.length,
    'shown_again': shownAgain.length,
    'renamed': renamed.length,
    if (newlyHidden.isNotEmpty) 'hidden_examples': names(newlyHidden),
    if (shownAgain.isNotEmpty) 'shown_examples': names(shownAgain),
    if (renamed.isNotEmpty)
      'rename_examples': [
        for (final id in renamed.take(8))
          '${beforeNames[id]} -> ${afterNames[id]}'
      ],
  };
}

/// The localized words for the TV's confirm question.
String _editorWhat(int hidden, int shown, int renamed, Iterable<EditsDiff> d) {
  final parts = <String>[
    if (hidden > 0) tr('{n} channels hidden', {'n': hidden}),
    if (shown > 0) tr('{n} channels shown again', {'n': shown}),
    if (renamed > 0) tr('{n} channels renamed', {'n': renamed}),
    if (d.any((x) => x.fallbacks.isNotEmpty)) tr('fallback channels changed'),
  ];
  if (parts.isEmpty) {
    parts.add(d.any((x) => x.rulesAdded.isNotEmpty || x.rulesRemoved.isNotEmpty)
        ? tr('rules changed')
        : tr('settings changed'));
  }
  return parts.join(', ');
}

AiEditLog _editorLog(VesperToolbox box) =>
    AiEditLog.decode(box.storage.getAiEditorUndo());

Future<void> _saveEditorLog(VesperToolbox box, AiEditLog log) async {
  var json = log.encode();
  // A hide of thousands of channels is a big diff: keep the log small.
  while (json.length > 1500000 && log.changes.length > 1) {
    log.changes.removeAt(0);
    json = log.encode();
  }
  await box.storage.setAiEditorUndo(json);
}

/// Plans with [plan] (null = nothing to change in that playlist), shows
/// or applies the result. [plan] runs again after the TV's confirm, on the
/// edits as they are then (the viewer may have used the editor page).
Future<Map<String, Object?>> _editorCommit(
  VesperToolbox box,
  VesperCaller caller,
  List<PlaylistSession> sessions, {
  required String summary,
  required bool preview,
  required PlaylistEdits? Function(PlaylistSession s, PlaylistEdits current)
      plan,
  List<String> notes = const [],
  String question = 'An AI app wants to edit your playlist: {what}.',
  bool Function(PlaylistSession s, Map<String, Object?> effect)? refuse,
  bool record = true,
}) async {
  final planned = <PlaylistSession, PlaylistEdits>{};
  for (final s in sessions) {
    final next = plan(s, s.edits);
    if (next == null) continue;
    if (EditsDiff.between(s.edits, next).isEmpty) continue;
    planned[s] = next;
  }
  if (planned.isEmpty) {
    return {
      'changed': false,
      'note': ['Nothing to change.', ...notes].join(' '),
    };
  }
  var hidden = 0, shown = 0, renamed = 0;
  final report = <Map<String, Object?>>[];
  for (final e in planned.entries) {
    final effect = _editorEffect(e.key, e.value);
    if (refuse?.call(e.key, effect) ?? false) {
      throw VesperToolError('That would hide every channel of '
          '${e.key.profile.name}; nothing was changed.');
    }
    hidden += effect['hidden'] as int;
    shown += effect['shown_again'] as int;
    renamed += effect['renamed'] as int;
    report.add({'playlist': e.key.profile.name, ...effect});
  }
  final result = <String, Object?>{
    'playlists': report,
    if (notes.isNotEmpty) 'note': notes.join(' '),
  };
  if (preview) {
    return {
      'preview': true,
      ...result,
      'next': 'Nothing changed yet. Run the same action without preview to '
          'apply it.',
    };
  }
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot edit playlists.');
  }
  await _confirmRemote(box, caller, question, {
    'what': _editorWhat(hidden, shown, renamed, [
      for (final e in planned.entries) EditsDiff.between(e.key.edits, e.value)
    ]),
  });
  final diffs = <String, EditsDiff>{};
  for (final s in planned.keys) {
    final next = plan(s, s.edits);
    if (next == null) continue;
    final diff = EditsDiff.between(s.edits, next);
    if (diff.isEmpty) continue;
    await s.saveEdits(next);
    diffs[s.profile.id] = diff;
  }
  if (diffs.isEmpty) return {'changed': false, 'note': 'Nothing to change.'};
  if (!record) return {'changed': true, ...result};
  final log = _editorLog(box);
  final change = log.add(summary, diffs);
  await _saveEditorLog(box, log);
  return {
    'changed': true,
    'change_id': change.id,
    ...result,
    'undo': 'playlist_editor action "undo" with change_id "${change.id}".',
  };
}

Map<String, Object?> _ruleJson(int n, EditRule r) => {
      'n': n,
      ...r.toJson(),
    };

Map<String, Object?> _editorList(VesperToolbox box, String playlist) {
  final sessions = _editorSessions(box, playlist);
  String channelName(String id) {
    try {
      return _editorChannel(box, id).$2.name;
    } catch (_) {
      return id;
    }
  }

  final log = _editorLog(box);
  return {
    'playlists': [
      for (final s in sessions)
        {
          'playlist': s.profile.name,
          'id': s.profile.id,
          'enabled': s.profile.enabled,
          'live_channels': s.allLiveChannels.length,
          'hidden_by_editor_now': s.editHidden.length,
          'hidden_on_tv': s.hiddenChannels.length,
          'hidden_by_hand': s.edits.hidden.length,
          'always_shown': s.edits.shown.length,
          'renamed_by_hand': s.edits.names.length,
          'group_renames': {
            for (final e in s.edits.groupNames.entries.take(50)) e.key: e.value,
          },
          'rules': [
            for (final (i, r) in s.edits.rules.indexed) _ruleJson(i + 1, r)
          ],
          'fallbacks': [
            for (final e in s.edits.fallbacks.entries.take(30))
              {
                'channel_id': '${s.profile.id}::${e.key}',
                'channel': channelName('${s.profile.id}::${e.key}'),
                'fallbacks': [for (final f in e.value) channelName(f)],
              }
          ],
          'hide_lower_copies': s.edits.hideLowerCopies,
          'hide_separators': s.edits.hideSeparators,
          'measured_dead':
              s.edits.probes.values.where((p) => !p.ok && !p.isStale).length,
        }
    ],
    'ai_changes': [
      for (final c in log.changes.reversed.take(10))
        {
          'change_id': c.id,
          'when': '${_day(c.at)} ${_clock(c.at)}',
          'what': c.summary,
        }
    ],
  };
}

Map<String, Object?> _editorFind(
    VesperToolbox box, String playlist, String query, String only) {
  final search = TitleSearch(query);
  if (search.isEmpty && only.isEmpty) {
    throw VesperToolError('Say what to look for (query), or only.');
  }
  final guideReady = box.epg.lastUpdated != null && !box.epg.isLoading;
  final out = <Map<String, Object?>>[];
  var total = 0;
  for (final s in _editorSessions(box, playlist)) {
    for (final c in s.allLiveChannels) {
      if (!search.isEmpty &&
          !search.matches(c.name) &&
          !search.matches(c.sourceName)) {
        continue;
      }
      final hidden = s.isLiveHidden(c.rawId);
      final noGuide = guideReady && !box.epg.hasPrograms(c.epgId);
      final probe = s.edits.probes[c.rawId];
      final dead = probe != null && !probe.ok && !probe.isStale;
      final keep = switch (only) {
        'hidden' => hidden,
        'visible' => !hidden,
        'no_guide' => noGuide && !hidden,
        'dead' => dead,
        _ => true,
      };
      if (!keep) continue;
      total++;
      if (out.length >= 30) continue;
      out.add({
        'id': c.id,
        'name': c.name,
        if (c.name != c.sourceName) 'provider_name': c.sourceName,
        if (c.group.isNotEmpty) 'group': s.edits.groupTitle(c.group),
        if (box._manyPlaylists) 'playlist': s.profile.name,
        if (hidden)
          'hidden_by': s.hiddenChannels.contains(c.rawId)
              ? 'tv'
              : s.editHidden.contains(c.rawId)
                  ? 'editor'
                  : 'combine_playlists',
        if (guideReady) 'has_guide': !noGuide,
        if (probe != null && !probe.isStale) 'test': probe.label,
        if (s.edits.fallbacks[c.rawId] case final f?) 'fallbacks': f.length,
      });
    }
  }
  return {
    'channels': out,
    if (total > out.length) 'note': '$total channels match; first 30 shown.',
  };
}

Future<Map<String, Object?>> _runPlaylistEditor(
    VesperToolbox box, Map<String, Object?> args, VesperCaller caller) async {
  final action = _str(args, 'action');
  final playlist = _str(args, 'playlist');
  final preview = _bool(args, 'preview') ?? false;
  await box.playlist.ensureLiveChannelsLoaded();
  if (action == 'list') return _editorList(box, playlist);
  if (action == 'find_channels') {
    return _editorFind(box, playlist, _str(args, 'query'), _str(args, 'only'));
  }
  if (action == 'undo') return _editorUndo(box, args, caller, preview);
  if (!_editorChangeActions.contains(action)) {
    throw VesperToolError('Unknown action "$action". Call vesper_help with '
        'topic "playlist_editor".');
  }
  if (box.restrictedViewer && !preview) {
    throw VesperToolError('This profile cannot edit playlists.');
  }
  switch (action) {
    case 'hide_no_guide':
      if (box.epg.isLoading) {
        throw VesperToolError(
            'The TV guide is updating right now; try again when it is done.');
      }
      if (box.epg.lastUpdated == null) {
        throw VesperToolError('No TV guide is loaded on this TV yet, so every '
            'channel would look like it has none. Nothing was changed.');
      }
      final notes = <String>[];
      final sessions = _editorSessions(box, playlist);
      final targets = <PlaylistSession, Set<String>>{};
      for (final s in sessions) {
        final live = s.allLiveChannels.toList();
        if (!live.any((c) => box.epg.hasPrograms(c.epgId))) {
          notes.add('${s.profile.name}: skipped, none of its channels has '
              'guide data (its guide is probably not loaded).');
          continue;
        }
        targets[s] = {
          for (final c in live)
            if (!s.isLiveHidden(c.rawId) && !box.epg.hasPrograms(c.epgId))
              c.rawId
        };
      }
      notes.add('This hides the channels without guide data now; channels '
          'added later are not hidden automatically.');
      return _editorCommit(box, caller, targets.keys.toList(),
          summary: 'hide channels without guide data',
          preview: preview,
          notes: notes,
          plan: (s, cur) => _copyEdits(cur)
            ..hidden.addAll(targets[s]!)
            ..shown.removeAll(targets[s]!));
    case 'hide_dead':
      final sessions = _editorSessions(box, playlist);
      Set<String> dead(PlaylistSession s) => {
            for (final e in s.edits.probes.entries)
              if (!e.value.ok && !e.value.isStale && !s.isLiveHidden(e.key))
                e.key
          };
      return _editorCommit(box, caller, sessions,
          summary: 'hide channels measured dead',
          preview: preview,
          notes: const [
            'Only channels a stream test (Playlist editor page > Test) or '
                'real playback measured dead in the last 30 days count.'
          ], plan: (s, cur) {
        final ids = dead(s);
        return _copyEdits(cur)
          ..hidden.addAll(ids)
          ..shown.removeAll(ids);
      });
    case 'hide_channels':
    case 'show_channels':
      final hide = action == 'hide_channels';
      final ids = _strList(args, 'channel_ids');
      if (ids.isEmpty) throw VesperToolError('Give channel_ids.');
      if (ids.length > 2000) {
        throw VesperToolError('At most 2000 channels at once; use a rule.');
      }
      final bySession = <PlaylistSession, Set<String>>{};
      for (final id in ids) {
        final (s, c) = _editorChannel(box, id);
        (bySession[s] ??= {}).add(c.rawId);
      }
      return _editorCommit(box, caller, bySession.keys.toList(),
          summary: '${hide ? 'hide' : 'show'} ${ids.length} channel(s)',
          preview: preview,
          notes: [
            if (!hide)
              'Channels hidden on the TV itself (hold OK > Hide channel) '
                  'stay hidden; the viewer shows those in Settings.'
          ], plan: (s, cur) {
        final raw = bySession[s]!;
        final next = _copyEdits(cur);
        if (hide) {
          return next
            ..hidden.addAll(raw)
            ..shown.removeAll(raw);
        }
        next.hidden.removeAll(raw);
        // Still hidden by a rule / Collapse copies: "always show" them.
        final still = _editorHiddenBy(s, next);
        next.shown.addAll(raw.where(still.contains));
        return next;
      });
    case 'add_rule':
      final type = _str(args, 'rule_type');
      final find = _str(args, 'find');
      final replace =
          args['replace'] is String ? args['replace'] as String : '';
      final regex = _bool(args, 'regex') ?? false;
      final field = _str(args, 'field') == 'group' ? 'group' : 'name';
      if (type != 'hide' && type != 'replace') {
        throw VesperToolError('rule_type is "hide" or "replace".');
      }
      if (find.isEmpty || find.length > 300) {
        throw VesperToolError('find is 1 to 300 characters.');
      }
      if (type == 'replace' && field == 'group') {
        throw VesperToolError('Replace rules work on channel names only; '
            'rename groups with rename_group.');
      }
      if (regex) {
        try {
          RegExp(find, unicode: true);
        } on FormatException catch (e) {
          throw VesperToolError('Bad regex: ${e.message}');
        }
      }
      final rule = EditRule(
          type: type, find: find, replace: replace, regex: regex, field: field);
      return _editorCommit(box, caller, _editorSessions(box, playlist),
          summary: type == 'hide'
              ? 'add rule: hide ${field == 'group' ? 'groups' : 'names'} '
                  'matching "$find"'
              : 'add rule: replace "$find" with "$replace" in names',
          preview: preview,
          refuse: type == 'hide'
              ? (s, effect) {
                  final visible = s.allLiveChannels
                      .where((c) => !s.isLiveHidden(c.rawId))
                      .length;
                  return visible > 0 && (effect['hidden'] as int) >= visible;
                }
              : null,
          notes: const ['Rules run again on every content update.'],
          plan: (s, cur) {
        final key = jsonEncode(rule.toJson());
        if (cur.rules.any((r) => jsonEncode(r.toJson()) == key)) {
          return null;
        }
        if (cur.rules.length >= 100) {
          throw VesperToolError('${s.profile.name} has 100 rules already.');
        }
        return _copyEdits(cur)..rules.add(rule);
      });
    case 'remove_rule':
      final index = _int(args, 'rule_index', 0, min: 0, max: 100);
      final find = _str(args, 'find');
      if (index == 0 && find.isEmpty) {
        throw VesperToolError('Give rule_index (from list) or find.');
      }
      final sessions = _editorSessions(box, playlist, allowAll: index == 0);
      return _editorCommit(box, caller, sessions,
          summary: index > 0 ? 'remove rule $index' : 'remove rule "$find"',
          preview: preview, plan: (s, cur) {
        final next = _copyEdits(cur);
        if (index > 0) {
          if (index > next.rules.length) {
            throw VesperToolError(
                '${s.profile.name} has ${next.rules.length} rule(s).');
          }
          next.rules.removeAt(index - 1);
        } else {
          next.rules
              .removeWhere((r) => r.find.toLowerCase() == find.toLowerCase());
        }
        return next;
      });
    case 'rename':
      final renames = _renames(args, 'channel_id');
      final bySession = <PlaylistSession, Map<String, String>>{};
      for (final (id, name) in renames) {
        final (s, c) = _editorChannel(box, id);
        (bySession[s] ??= {})[c.rawId] = name;
      }
      return _editorCommit(box, caller, bySession.keys.toList(),
          summary: 'rename ${renames.length} channel(s)',
          preview: preview, plan: (s, cur) {
        final next = _copyEdits(cur);
        for (final e in bySession[s]!.entries) {
          if (e.value.isEmpty) {
            next.names.remove(e.key);
          } else {
            next.names[e.key] = e.value;
          }
        }
        return next;
      });
    case 'rename_group':
      final renames = _renames(args, 'group');
      final sessions = _editorSessions(box, playlist);
      final unknown = <String>[];
      final bySession = <PlaylistSession, Map<String, String>>{};
      for (final (group, name) in renames) {
        var found = false;
        for (final s in sessions) {
          final titles = {for (final c in s.allLiveChannels) c.group};
          final folded = TitleSearch.fold(group);
          String? provider;
          for (final t in titles) {
            if (TitleSearch.fold(t) == folded ||
                TitleSearch.fold(s.edits.groupTitle(t)) == folded) {
              provider = t;
              break;
            }
          }
          if (provider == null) continue;
          found = true;
          (bySession[s] ??= {})[provider] = name;
        }
        if (!found) unknown.add(group);
      }
      if (bySession.isEmpty) {
        throw VesperToolError('No live group named ${unknown.join(', ')}.');
      }
      return _editorCommit(box, caller, bySession.keys.toList(),
          summary: 'rename ${renames.length} group(s)',
          preview: preview,
          notes: [
            if (unknown.isNotEmpty) 'Not found: ${unknown.join(', ')}.',
            'Groups given the same name are merged into one.',
          ], plan: (s, cur) {
        final next = _copyEdits(cur);
        for (final e in bySession[s]!.entries) {
          if (e.value.isEmpty || e.value == e.key) {
            next.groupNames.remove(e.key);
          } else {
            next.groupNames[e.key] = e.value;
          }
        }
        return next;
      });
    case 'add_fallback':
    case 'remove_fallback':
      final add = action == 'add_fallback';
      final (s, target) = _editorChannel(box, _str(args, 'channel_id'));
      final fallbackArg = _str(args, 'fallback_id');
      Channel? fallback;
      if (fallbackArg.isNotEmpty) {
        fallback = _editorChannel(box, fallbackArg).$2;
      } else if (add) {
        throw VesperToolError('Give fallback_id: the channel to try instead.');
      }
      if (fallback != null && fallback.id == target.id) {
        throw VesperToolError('A channel cannot be its own fallback.');
      }
      return _editorCommit(box, caller, [s],
          summary: add
              ? 'add ${fallback!.name} as fallback for ${target.name}'
              : fallback == null
                  ? 'remove every fallback of ${target.name}'
                  : 'remove fallback ${fallback.name} from ${target.name}',
          preview: preview,
          notes: [
            if (add)
              'Fallbacks are tried in order when the channel fails, before '
                  'its automatic copies.'
          ], plan: (_, cur) {
        final next = _copyEdits(cur);
        final list = [...?next.fallbacks[target.rawId]];
        if (add) {
          if (list.contains(fallback!.id)) return null;
          if (list.length >= 10) {
            throw VesperToolError('${target.name} has 10 fallbacks already.');
          }
          list.add(fallback.id);
        } else if (fallback == null) {
          list.clear();
        } else {
          list.remove(fallback.id);
        }
        if (list.isEmpty) {
          next.fallbacks.remove(target.rawId);
        } else {
          next.fallbacks[target.rawId] = list;
        }
        return next;
      });
    case 'set_option':
      final option = _str(args, 'option');
      final value = _bool(args, 'value');
      if (value == null) throw VesperToolError('Give value true or false.');
      if (option != 'hide_lower_copies' && option != 'hide_separators') {
        throw VesperToolError(
            'option is "hide_lower_copies" or "hide_separators".');
      }
      return _editorCommit(box, caller, _editorSessions(box, playlist),
          summary: '${value ? 'turn on' : 'turn off'} $option',
          preview: preview, plan: (s, cur) {
        final next = _copyEdits(cur);
        if (option == 'hide_lower_copies') {
          next.hideLowerCopies = value;
        } else {
          next.hideSeparators = value;
        }
        return next;
      });
  }
  throw VesperToolError('Unknown action "$action".');
}

/// `renames`: [{key: ..., new_name: ...}], or one [key] + `new_name`.
List<(String, String)> _renames(Map<String, Object?> args, String key) {
  String clean(String s) => s.length > 120 ? s.substring(0, 120) : s;
  final out = <(String, String)>[];
  final list = args['renames'];
  if (list is List) {
    for (final r in list) {
      if (r is! Map) continue;
      final k = '${r[key] ?? ''}'.trim();
      if (k.isEmpty) continue;
      out.add((k, clean('${r['new_name'] ?? ''}'.trim())));
    }
  }
  final single = _str(args, key);
  if (single.isNotEmpty) out.add((single, clean(_str(args, 'new_name'))));
  if (out.isEmpty) {
    throw VesperToolError('Give $key and new_name (or renames).');
  }
  if (out.length > 500) throw VesperToolError('At most 500 renames at once.');
  return out;
}

Future<Map<String, Object?>> _editorUndo(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  final log = _editorLog(box);
  final id = _str(args, 'change_id');
  final change = log.find(id);
  if (change == null) {
    throw VesperToolError(log.changes.isEmpty
        ? 'There is no AI playlist change to undo.'
        : 'No change "$id". Recent ones: '
            '${log.changes.reversed.take(10).map((c) => '${c.id} (${c.summary})').join(', ')}.');
  }
  final sessions = [
    for (final pid in change.diffs.keys)
      if (box.playlist.editorSession(pid) case final s?) s
  ];
  final skipped = <String, int>{};
  final result = await _editorCommit(box, caller, sessions,
      summary: 'undo ${change.id}',
      preview: preview,
      record: false,
      question: 'An AI app wants to undo its playlist change: {what}.',
      plan: (s, cur) {
    final (next, left) = change.diffs[s.profile.id]!.revert(cur);
    skipped[s.profile.id] = left;
    return next;
  });
  if (preview) return {...result, 'undoes': change.summary};
  // Undone, or nothing left to undo: out of the log either way.
  final fresh = _editorLog(box);
  fresh.changes.removeWhere((c) => c.id == change.id);
  await _saveEditorLog(box, fresh);
  final kept = skipped.values.fold<int>(0, (a, b) => a + b);
  return {
    ...result,
    'undid': '${change.id}: ${change.summary}',
    if (kept > 0)
      'kept': '$kept part(s) were changed again since and were left as '
          'they are now.',
  };
}

const _playlistEditorTool = VesperTool(
  name: 'playlist_editor',
  description:
      'Edit the viewer\'s live TV playlists on this TV (the Playlist editor '
      'layer: the provider\'s playlist is never changed). Hide channels '
      'without guide data or measured dead, hide / show channels, add hide '
      'or find-and-replace rules (e.g. strip a "CA: " prefix), rename '
      'channels and groups, set fallback channels, collapse lower-quality '
      'copies. Every change returns a change_id and can be undone. Call '
      'vesper_help topic "playlist_editor" first for the rules and examples; '
      'use preview: true to see the effect before changing anything.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': [
          'list',
          'find_channels',
          ..._editorChangeActions,
          'undo',
        ],
      },
      'playlist': {
        'type': 'string',
        'description': 'Playlist name or id. Omitted = every enabled '
            'playlist (or the one channel_id belongs to).',
      },
      'preview': {
        'type': 'boolean',
        'description': 'true = only report what would change.',
      },
      'query': {
        'type': 'string',
        'description': 'find_channels: words in the channel name.',
      },
      'only': {
        'type': 'string',
        'enum': ['hidden', 'visible', 'no_guide', 'dead'],
        'description': 'find_channels: filter.',
      },
      'channel_ids': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'hide_channels / show_channels: ids from find_channels.',
      },
      'channel_id': {
        'type': 'string',
        'description': 'rename / add_fallback / remove_fallback: the channel.',
      },
      'fallback_id': {
        'type': 'string',
        'description': 'add_fallback / remove_fallback: the channel to try '
            'when channel_id fails.',
      },
      'new_name': {'type': 'string'},
      'group': {
        'type': 'string',
        'description': 'rename_group: the group\'s name.',
      },
      'renames': {
        'type': 'array',
        'description': 'rename / rename_group, several at once: '
            '[{"channel_id" or "group": ..., "new_name": ...}]. Empty '
            'new_name = back to the provider\'s name.',
        'items': {'type': 'object'},
      },
      'rule_type': {
        'type': 'string',
        'enum': ['hide', 'replace'],
      },
      'find': {
        'type': 'string',
        'description': 'add_rule: text (or regex) to find, case-insensitive. '
            'remove_rule: the rule\'s find text.',
      },
      'replace': {
        'type': 'string',
        'description': 'add_rule replace: the new text ("" removes it).',
      },
      'regex': {'type': 'boolean'},
      'field': {
        'type': 'string',
        'enum': ['name', 'group'],
        'description': 'add_rule hide: match the channel name (default) or '
            'its group.',
      },
      'rule_index': {
        'type': 'integer',
        'description': 'remove_rule: the rule\'s n from list.',
      },
      'option': {
        'type': 'string',
        'enum': ['hide_lower_copies', 'hide_separators'],
      },
      'value': {'type': 'boolean'},
      'change_id': {
        'type': 'string',
        'description': 'undo: the change to take back (default: the latest).',
      },
    },
    'required': ['action'],
  },
  run: _runPlaylistEditor,
);
