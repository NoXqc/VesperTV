part of 'vesper_tools.dart';

// TV guide (EPG) matching for AI apps (owner, 2026-11-12: "paste an EPG
// link in my AI chat and say: fill in my missing EPG on playlist XYZ").
// Adds guides to a playlist (an XMLTV link, or another playlist's guide) as
// its Extra guides, suggests guide channels for the channels without guide
// data ([GuideMatcher]: prefixes, spacing, typos), and links them (the same
// per-channel EPG id override as Settings > EPG > channel matching and the
// editor page's Guide popup). Every change goes in [GuideLinkLog] for undo.
// The manual for the model is `vesper_help` topic `epg_matching`. See
// dev-notes/vesper-ai.md (EPG matching tool).

/// Guide addresses can carry a login (Xtream `xmltv.php?username=…`): the
/// AI only ever sees the host.
String _guideHost(String url) => Uri.tryParse(url)?.host ?? '';

GuideLinkLog _guideLog(VesperToolbox box) =>
    GuideLinkLog.decode(box.storage.getAiGuideUndo());

Future<void> _saveGuideLog(VesperToolbox box, GuideLinkLog log) =>
    box.storage.setAiGuideUndo(log.encode());

/// The one playlist an action is about ([name]: name or id).
PlaylistSession _guideSession(VesperToolbox box, String name) =>
    _editorSessions(box, name, allowAll: false).single;

/// A channel guide matching works on: shown in Live TV, not a divider row
/// or a dated event channel ("NBA 01: Nuggets @ 7 Nov 7:00 PM", its guide
/// comes from its name).
bool _guideChannel(VesperToolbox box, Channel c) =>
    box.isVisibleLive(c) &&
    !PlaylistEdits.isSeparator(c) &&
    !isEventChannelName(c.sourceName);

/// [s]'s channels without guide data now, filtered by [group] / [query].
List<Channel> _withoutGuide(VesperToolbox box, PlaylistSession s,
    {String group = '', String query = ''}) {
  final inGroup = TitleSearch(group);
  final named = TitleSearch(query);
  return [
    for (final c in s.allLiveChannels)
      // The cheap check first: big playlists have 100,000+ channels.
      if (!box.epg.hasPrograms(c.epgId) &&
          _guideChannel(box, c) &&
          (inGroup.isEmpty || inGroup.matches(s.liveGroupOf(c))) &&
          (named.isEmpty ||
              named.matches(c.name) ||
              named.matches(c.sourceName)))
        c
  ];
}

/// Every guide channel [s]'s channels can be linked to: its own guides'
/// channel lists, the names of its channels that have guide data, and with
/// [from] that playlist's guides and channels too.
List<GuideEntry> _guideEntries(
    VesperToolbox box, PlaylistSession s, PlaylistSession? from) {
  final byId = <String, GuideEntry>{};
  void addGuide(String url, String label) {
    for (final ch in box.epg.channelsFromSource(url)) {
      final id = normalizeEpgId(ch.id);
      if (id.isEmpty || byId.containsKey(id)) continue;
      byId[id] = GuideEntry(ch.id, ch.name,
          source: label,
          url: url,
          live: box.epg.currentProgramInCatalog(ch.id) != null);
    }
  }

  void addChannels(PlaylistSession p) {
    final label = '${p.profile.name} channels';
    final fallbackUrl = editorGuideUrls(p.profile).firstOrNull ?? '';
    for (final c in p.allLiveChannels) {
      if (!box.epg.hasPrograms(c.epgId) || !box.isVisibleLive(c)) continue;
      final id = normalizeEpgId(c.epgId);
      final entry = byId[id] ??= GuideEntry(c.epgId, c.name,
          source: label, url: fallbackUrl, live: true);
      if (entry.aliases.length < 8 && entry.name != c.name) {
        entry.aliases.add(c.name);
      }
    }
  }

  final own = editorGuideUrls(s.profile);
  final labels = editorGuideSources(s.profile);
  for (var i = 0; i < own.length; i++) {
    addGuide(own[i], labels[i]['name']!);
  }
  if (from != null) {
    final urls = editorGuideUrls(from.profile);
    for (var i = 0; i < urls.length; i++) {
      addGuide(
          urls[i],
          i == 0
              ? '${from.profile.name} guide'
              : '${from.profile.name} extra guide $i');
    }
  }
  addChannels(s);
  if (from != null) addChannels(from);
  return byId.values.toList();
}

/// One guide update after the AI's changes, 20 s after the last one (like
/// the editor page): the guide only keeps programmes for channel ids it
/// knows, so new links show data once it has run. Waits for an update
/// already running (it started before the change).
Timer? _guideReloadTimer;
void _reloadGuideSoon(VesperToolbox box) {
  _guideReloadTimer?.cancel();
  var tries = 0;
  void attempt() {
    if (box.epg.isLoading && tries++ < 60) {
      _guideReloadTimer = Timer(const Duration(seconds: 15), attempt);
      return;
    }
    unawaited(box.epg.refreshAll());
  }

  _guideReloadTimer = Timer(const Duration(seconds: 20), attempt);
}

/// Starts a guide update with the latest sources now and waits up to [wait]
/// for it (an AI request has about a minute in all). True = done.
Future<bool> _updateGuideNow(VesperToolbox box, Duration wait) async {
  _guideReloadTimer?.cancel();
  final deadline = DateTime.now().add(wait);
  while (box.epg.isLoading && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (box.epg.isLoading) {
    _reloadGuideSoon(box);
    return false;
  }
  final run = box.epg.refreshAll();
  final left = deadline.difference(DateTime.now());
  if (left <= Duration.zero) {
    unawaited(run);
    return false;
  }
  try {
    await run.timeout(left);
    return true;
  } on TimeoutException {
    return false;
  }
}

Map<String, Object?> _guideStatus(VesperToolbox box, String playlist) {
  final sessions = _editorSessions(box, playlist);
  final ready = box.epg.lastUpdated != null && !box.epg.isLoading;
  final log = _guideLog(box);
  return {
    'guide_updating': box.epg.isLoading,
    if (box.epg.lastUpdated case final t?)
      'guide_updated': '${_day(t)} ${_clock(t)}',
    'playlists': [
      for (final s in sessions)
        () {
          final urls = editorGuideUrls(s.profile);
          final labels = editorGuideSources(s.profile);
          final visible = [
            for (final c in s.allLiveChannels)
              if (_guideChannel(box, c)) c
          ];
          return {
            'playlist': s.profile.name,
            'id': s.profile.id,
            'enabled': s.profile.enabled,
            'guides': [
              for (var i = 0; i < urls.length; i++)
                {
                  'n': i + 1,
                  'name': labels[i]['name'],
                  'host': _guideHost(urls[i]),
                  // 0 = its channel list isn't loaded in this app run yet.
                  'channels': box.epg.channelsFromSource(urls[i]).length,
                }
            ],
            'live_channels': visible.length,
            if (ready)
              'without_guide':
                  visible.where((c) => !box.epg.hasPrograms(c.epgId)).length,
            'linked': s.epgIdOverrides.length,
            'linked_automatically': s.autoPairedEpgOverrides.length,
          };
        }()
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

/// Refuses work that needs a loaded guide.
void _needGuide(VesperToolbox box) {
  if (box.epg.isLoading) {
    throw VesperToolError('The TV guide is updating right now; call status '
        'and try again when guide_updating is false.');
  }
  if (box.epg.lastUpdated == null) {
    throw VesperToolError('No TV guide is loaded on this TV yet.');
  }
}

/// [entries] empty: the guides' channel lists aren't loaded in this app run.
void _needEntries(VesperToolbox box, List<GuideEntry> entries) {
  if (entries.isNotEmpty) return;
  _reloadGuideSoon(box);
  throw VesperToolError('The guide\'s channel list is not loaded yet (the '
      'TV loads it with each guide update; one starts in 20 s). Call status '
      'and try again when guide_updating is false. If the playlist has no '
      'guide, add one with add_guide.');
}

Future<Map<String, Object?>> _guideSuggest(
    VesperToolbox box, Map<String, Object?> args) async {
  _needGuide(box);
  final s = _guideSession(box, _str(args, 'playlist'));
  final fromName = _str(args, 'from_playlist');
  final from = fromName.isEmpty ? null : _guideSession(box, fromName);
  final entries = _guideEntries(box, s, identical(from, s) ? null : from);
  _needEntries(box, entries);
  final channels = _withoutGuide(box, s,
      group: _str(args, 'group'), query: _str(args, 'query'));
  final all = await suggestGuides(entries, [for (final c in channels) c.name]);
  final show = _str(args, 'show').isEmpty ? 'unsure' : _str(args, 'show');
  var sure = 0, unsure = 0, none = 0;
  final picked = <int>[];
  for (var i = 0; i < channels.length; i++) {
    final kind = all[i].isEmpty
        ? 'none'
        : isSure(all[i])
            ? 'sure'
            : 'unsure';
    switch (kind) {
      case 'sure':
        sure++;
      case 'unsure':
        unsure++;
      default:
        none++;
    }
    if (show == 'all' || show == kind) picked.add(i);
  }
  final offset = _int(args, 'offset', 0, min: 0, max: 100000);
  final limit = _int(args, 'limit', 30, max: 60);
  final page = picked.skip(offset).take(limit).toList();
  return {
    'playlist': s.profile.name,
    'without_guide': channels.length,
    'sure': sure,
    'unsure': unsure,
    'no_match': none,
    'showing': show,
    'channels': [
      for (final i in page)
        {
          'id': channels[i].id,
          'name': channels[i].name,
          if (s.liveGroupOf(channels[i]).isNotEmpty)
            'group': s.liveGroupOf(channels[i]),
          if (channels[i].epgIdOverride case final o?) 'linked_now': o,
          if (all[i].isNotEmpty) 'sure': isSure(all[i]),
          'suggestions': [
            for (final g in all[i])
              {
                'guide_id': g.entry.id,
                'name': g.entry.name,
                'guide': g.entry.source,
                'score': double.parse(g.score.toStringAsFixed(2)),
                if (box.epg.currentProgramInCatalog(g.entry.id) case final p?)
                  'now': p.title,
              }
          ],
        }
    ],
    if (offset + limit < picked.length) 'next_offset': offset + limit,
    'note': 'link with sure: true links the $sure sure ones at once. For the '
        'others pick a guide_id (check "now" against what the channel airs) '
        'and link them with links; find_guide searches the guide by words '
        '(abbreviations, other spellings). Leave a channel alone when no '
        'guide channel is really it.',
  };
}

Map<String, Object?> _guideFind(VesperToolbox box, Map<String, Object?> args) {
  final search = TitleSearch(_str(args, 'query'));
  if (search.isEmpty) throw VesperToolError('Say what to look for (query).');
  final s = _guideSession(box, _str(args, 'playlist'));
  final fromName = _str(args, 'from_playlist');
  final from = fromName.isEmpty ? null : _guideSession(box, fromName);
  final entries = _guideEntries(box, s, identical(from, s) ? null : from);
  _needEntries(box, entries);
  final out = <Map<String, Object?>>[];
  var total = 0;
  for (final e in entries) {
    if (!search.matches(e.name) &&
        !search.matches(e.id) &&
        !e.aliases.any(search.matches)) {
      continue;
    }
    total++;
    if (out.length >= 30) continue;
    out.add({
      'guide_id': e.id,
      'name': e.name,
      if (e.aliases.isNotEmpty) 'also': e.aliases.take(3).toList(),
      'guide': e.source,
      if (box.epg.currentProgramInCatalog(e.id) case final p?) 'now': p.title,
    });
  }
  return {
    'results': out,
    if (total > out.length) 'note': '$total match; first 30 shown.',
  };
}

Future<Map<String, Object?>> _guideAdd(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  final s = _guideSession(box, _str(args, 'playlist'));
  final url = _str(args, 'url');
  final fromName = _str(args, 'from_playlist');
  final adding = <String>[];
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw VesperToolError('url must be a full http(s):// link to an XMLTV '
          'guide (.xml or .xml.gz).');
    }
    adding.add(url);
  } else if (fromName.isNotEmpty) {
    final from = _guideSession(box, fromName);
    if (identical(from, s)) {
      throw VesperToolError('from_playlist is the same playlist.');
    }
    adding.addAll(editorGuideUrls(from.profile));
    if (adding.isEmpty) {
      throw VesperToolError('${from.profile.name} has no guide.');
    }
  } else {
    throw VesperToolError('Give url (an XMLTV link) or from_playlist.');
  }
  final before = List<String>.from(s.profile.extraEpgUrls);
  final after = [...before];
  for (final u in adding) {
    if (u == s.profile.epgUrl || after.contains(u)) continue;
    after.add(u);
  }
  if (after.length > 5) {
    throw VesperToolError('A playlist takes five extra guides at most; '
        '${s.profile.name} would have ${after.length}. Remove one first '
        '(remove_guide).');
  }
  if (after.length == before.length) {
    return {'changed': false, 'note': '${s.profile.name} already has it.'};
  }
  final count = after.length - before.length;
  if (preview) {
    return {
      'preview': true,
      'playlist': s.profile.name,
      'adds': count,
      'hosts': [for (final u in after.skip(before.length)) _guideHost(u)],
    };
  }
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change playlists.');
  }
  await _confirmRemote(
      box,
      caller,
      'An AI app wants to add a TV guide to {playlist}.',
      {'playlist': s.profile.name});
  await box.playlist.updatePlaylist(s.profile.copyWith(extraEpgUrls: after));
  final log = _guideLog(box);
  final change = log.add('add $count guide(s) to ${s.profile.name}',
      guides: {s.profile.id: (before, after)});
  await _saveGuideLog(box, log);
  final done = await _updateGuideNow(box, const Duration(seconds: 30));
  final loaded = [
    for (final u in after.skip(before.length))
      box.epg.channelsFromSource(u).length
  ];
  return {
    'changed': true,
    'change_id': change.id,
    'playlist': s.profile.name,
    'guide_updated': done,
    if (done) 'guide_channels': loaded,
    'note': done
        ? (loaded.every((n) => n == 0)
            ? 'The guide updated but the new guide gave no channels: check '
                'the link (it must be an XMLTV file).'
            : 'Done. Next: suggest for ${s.profile.name}.')
        : 'The guide is still downloading (big guides take a few minutes). '
            'Call status until guide_updating is false, then suggest.',
    'undo': 'epg_matching action "undo" with change_id "${change.id}".',
  };
}

Future<Map<String, Object?>> _guideRemove(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  final s = _guideSession(box, _str(args, 'playlist'));
  final urls = editorGuideUrls(s.profile);
  final n = _int(args, 'guide', 0, min: 0, max: 99);
  if (n < 1 || n > urls.length) {
    throw VesperToolError('guide is the n from status (1..${urls.length}).');
  }
  final url = urls[n - 1];
  if (url == s.profile.epgUrl) {
    throw VesperToolError('That is the playlist\'s own guide; only extra '
        'guides can be removed here.');
  }
  final before = List<String>.from(s.profile.extraEpgUrls);
  final after = [...before]..remove(url);
  if (preview) {
    return {
      'preview': true,
      'playlist': s.profile.name,
      'removes': _guideHost(url),
    };
  }
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change playlists.');
  }
  await _confirmRemote(
      box,
      caller,
      'An AI app wants to remove a TV guide from {playlist}.',
      {'playlist': s.profile.name});
  await box.playlist.updatePlaylist(s.profile.copyWith(extraEpgUrls: after));
  final log = _guideLog(box);
  final change = log.add(
      'remove guide ${_guideHost(url)} from '
      '${s.profile.name}',
      guides: {s.profile.id: (before, after)});
  await _saveGuideLog(box, log);
  _reloadGuideSoon(box);
  return {
    'changed': true,
    'change_id': change.id,
    'note': 'Channels linked to that guide lose their guide data at the next '
        'update unless another guide has the same ids.',
    'undo': 'epg_matching action "undo" with change_id "${change.id}".',
  };
}

Future<Map<String, Object?>> _guideLink(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  _needGuide(box);
  final fromName = _str(args, 'from_playlist');
  // playlist -> rawId -> guide entry.
  final plan = <PlaylistSession, Map<String, GuideEntry>>{};
  final names = <String, String>{};
  final skipped = <String>[];
  final entriesFor = <PlaylistSession, Map<String, GuideEntry>>{};
  Map<String, GuideEntry> entriesOf(PlaylistSession s) => entriesFor[s] ??= () {
        final from = fromName.isEmpty ? null : _guideSession(box, fromName);
        final list = _guideEntries(box, s, identical(from, s) ? null : from);
        _needEntries(box, list);
        return {for (final e in list) normalizeEpgId(e.id): e};
      }();

  if (args['sure'] == true) {
    final s = _guideSession(box, _str(args, 'playlist'));
    final entries = entriesOf(s).values.toList();
    final channels = _withoutGuide(box, s,
        group: _str(args, 'group'), query: _str(args, 'query'));
    final all =
        await suggestGuides(entries, [for (final c in channels) c.name]);
    for (var i = 0; i < channels.length; i++) {
      if (!isSure(all[i])) continue;
      (plan[s] ??= {})[channels[i].rawId] = all[i].first.entry;
      names[channels[i].rawId] = channels[i].name;
    }
  } else {
    final links = args['links'];
    if (links is! List || links.isEmpty) {
      throw VesperToolError('Give links: [{"channel_id", "guide_id"}], or '
          'sure: true.');
    }
    if (links.length > 3000) {
      throw VesperToolError('At most 3000 links per call.');
    }
    for (final l in links) {
      if (l is! Map) continue;
      final cid = '${l['channel_id'] ?? ''}'.trim();
      final gid = normalizeEpgId('${l['guide_id'] ?? ''}');
      final PlaylistSession s;
      final Channel c;
      try {
        (s, c) = _editorChannel(box, cid);
      } on VesperToolError {
        skipped.add('$cid (no such channel)');
        continue;
      }
      final entry = entriesOf(s)[gid];
      if (entry == null) {
        skipped.add('${c.name} (guide_id "${l['guide_id']}" is not in its '
            'guides; use one from suggest or find_guide)');
        continue;
      }
      (plan[s] ??= {})[c.rawId] = entry;
      names[c.rawId] = c.name;
    }
  }
  // Already linked that way: nothing to do.
  for (final e in plan.entries) {
    e.value.removeWhere((raw, g) =>
        normalizeEpgId(e.key.epgIdOverrides[raw] ?? '') ==
        normalizeEpgId(g.id));
  }
  plan.removeWhere((_, m) => m.isEmpty);
  final count = plan.values.fold(0, (n, m) => n + m.length);
  // Guides of another playlist the links need: added as extra guides.
  final guidesToAdd = <PlaylistSession, List<String>>{};
  for (final e in plan.entries) {
    final own = editorGuideUrls(e.key.profile);
    final need = {
      for (final g in e.value.values)
        if (g.url.isNotEmpty && !own.contains(g.url)) g.url
    }.toList();
    if (need.isEmpty) continue;
    if (e.key.profile.extraEpgUrls.length + need.length > 5) {
      throw VesperToolError('These links need ${need.length} more guide(s) on '
          '${e.key.profile.name}, which can take five extra guides at most. '
          'Remove one first (remove_guide), or add_guide it yourself.');
    }
    guidesToAdd[e.key] = need;
  }
  final examples = [
    for (final m in plan.values)
      for (final e in m.entries.take(10))
        '${names[e.key]} -> ${e.value.name} (${e.value.id})'
  ].take(10).toList();
  final result = <String, Object?>{
    'links': count,
    if (examples.isNotEmpty) 'examples': examples,
    if (guidesToAdd.isNotEmpty)
      'adds_guides': {
        for (final e in guidesToAdd.entries)
          e.key.profile.name: [for (final u in e.value) _guideHost(u)]
      },
    if (skipped.isNotEmpty) 'skipped': skipped.take(20).toList(),
  };
  if (count == 0) {
    return {'changed': false, ...result, 'note': 'Nothing to link.'};
  }
  if (preview) return {'preview': true, ...result};
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change playlists.');
  }
  await _confirmRemote(
      box,
      caller,
      'An AI app wants to link {count} channels to the TV guide.',
      {'count': count});
  final linkDiff = <String, Map<String, (String?, String?)>>{};
  final guideDiff = <String, (List<String>, List<String>)>{};
  for (final e in plan.entries) {
    final s = e.key;
    if (guidesToAdd[s] case final add?) {
      final before = List<String>.from(s.profile.extraEpgUrls);
      final after = [...before, ...add];
      await box.playlist
          .updatePlaylist(s.profile.copyWith(extraEpgUrls: after));
      guideDiff[s.profile.id] = (before, after);
    }
    linkDiff[s.profile.id] = {
      for (final l in e.value.entries)
        l.key: (s.epgIdOverrides[l.key], l.value.id)
    };
    await s.setEpgIdOverridesBulk(
        {for (final l in e.value.entries) l.key: l.value.id});
  }
  final log = _guideLog(box);
  final change = log.add('link $count channels to the guide',
      links: linkDiff, guides: guideDiff);
  await _saveGuideLog(box, log);
  _reloadGuideSoon(box);
  return {
    'changed': true,
    'change_id': change.id,
    ...result,
    'note': 'Linked. The guide reloads in the background (from about 20 s; '
        'a big guide takes a few minutes), then these channels show their '
        'programmes.',
    'undo': 'epg_matching action "undo" with change_id "${change.id}".',
  };
}

Future<Map<String, Object?>> _guideUnlink(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  final ids = _strList(args, 'channel_ids');
  if (ids.isEmpty) throw VesperToolError('Give channel_ids.');
  final plan = <PlaylistSession, Set<String>>{};
  final skipped = <String>[];
  for (final id in ids.take(3000)) {
    try {
      final (s, c) = _editorChannel(box, id);
      if (s.epgIdOverrides.containsKey(c.rawId)) {
        (plan[s] ??= {}).add(c.rawId);
      } else {
        skipped.add('${c.name} (not linked)');
      }
    } on VesperToolError {
      skipped.add('$id (no such channel)');
    }
  }
  final count = plan.values.fold(0, (n, m) => n + m.length);
  final result = {
    'unlinks': count,
    if (skipped.isNotEmpty) 'skipped': skipped.take(20).toList(),
  };
  if (count == 0) {
    return {'changed': false, ...result, 'note': 'Nothing to unlink.'};
  }
  if (preview) return {'preview': true, ...result};
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change playlists.');
  }
  await _confirmRemote(
      box,
      caller,
      'An AI app wants to unlink {count} channels from the TV guide.',
      {'count': count});
  final diff = <String, Map<String, (String?, String?)>>{};
  for (final e in plan.entries) {
    diff[e.key.profile.id] = {
      for (final raw in e.value) raw: (e.key.epgIdOverrides[raw], null)
    };
    await e.key.restoreEpgIdOverrides({for (final raw in e.value) raw: null});
  }
  final log = _guideLog(box);
  final change = log.add('unlink $count channels', links: diff);
  await _saveGuideLog(box, log);
  _reloadGuideSoon(box);
  return {
    'changed': true,
    'change_id': change.id,
    ...result,
    'note': 'Back to the provider\'s own guide ids.',
    'undo': 'epg_matching action "undo" with change_id "${change.id}".',
  };
}

Future<Map<String, Object?>> _guideUndo(VesperToolbox box,
    Map<String, Object?> args, VesperCaller caller, bool preview) async {
  final log = _guideLog(box);
  final id = _str(args, 'change_id');
  final change = log.find(id);
  if (change == null) {
    throw VesperToolError(log.changes.isEmpty
        ? 'There is no AI guide change to undo.'
        : 'No change "$id". Recent ones: '
            '${log.changes.reversed.take(10).map((c) => '${c.id} (${c.summary})').join(', ')}.');
  }
  var restored = 0, kept = 0;
  final linkPlans = <PlaylistSession, Map<String, String?>>{};
  for (final e in change.links.entries) {
    final s = box.playlist.editorSession(e.key);
    if (s == null) continue;
    final (out, left) = revertLinks(e.value, s.epgIdOverrides);
    kept += left;
    restored += out.length;
    if (out.isNotEmpty) linkPlans[s] = out;
  }
  final guidePlans = <PlaylistSession, List<String>>{};
  for (final e in change.guides.entries) {
    final s = box.playlist.editorSession(e.key);
    if (s == null) continue;
    final next = revertGuides(e.value, s.profile.extraEpgUrls);
    if (!_sameStrings(next, s.profile.extraEpgUrls)) guidePlans[s] = next;
  }
  final result = {
    'undoes': '${change.id}: ${change.summary}',
    'links_restored': restored,
    'guides_changed': guidePlans.length,
    if (kept > 0)
      'kept': '$kept link(s) were changed again since and are left as they '
          'are now.',
  };
  if (preview) return {'preview': true, ...result};
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change playlists.');
  }
  if (linkPlans.isNotEmpty || guidePlans.isNotEmpty) {
    await _confirmRemote(
        box, caller, 'An AI app wants to undo its TV guide change.', {});
    for (final e in guidePlans.entries) {
      await box.playlist
          .updatePlaylist(e.key.profile.copyWith(extraEpgUrls: e.value));
    }
    for (final e in linkPlans.entries) {
      await e.key.restoreEpgIdOverrides(e.value);
    }
    _reloadGuideSoon(box);
  }
  final fresh = _guideLog(box);
  fresh.changes.removeWhere((c) => c.id == change.id);
  await _saveGuideLog(box, fresh);
  return {'changed': linkPlans.isNotEmpty || guidePlans.isNotEmpty, ...result};
}

bool _sameStrings(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

Future<Map<String, Object?>> _runEpgMatching(
    VesperToolbox box, Map<String, Object?> args, VesperCaller caller) async {
  final action = _str(args, 'action');
  final preview = _bool(args, 'preview') ?? false;
  await box.playlist.ensureLiveChannelsLoaded();
  switch (action) {
    case 'status':
      return _guideStatus(box, _str(args, 'playlist'));
    case 'suggest':
      return _guideSuggest(box, args);
    case 'find_guide':
      return _guideFind(box, args);
    case 'add_guide':
      return _guideAdd(box, args, caller, preview);
    case 'remove_guide':
      return _guideRemove(box, args, caller, preview);
    case 'link':
      return _guideLink(box, args, caller, preview);
    case 'unlink':
      return _guideUnlink(box, args, caller, preview);
    case 'undo':
      return _guideUndo(box, args, caller, preview);
  }
  throw VesperToolError('Unknown action "$action". Call vesper_help with '
      'topic "epg_matching".');
}

const _epgMatchingTool = VesperTool(
  name: 'epg_matching',
  description:
      'Fill in missing TV guide (EPG) data on the viewer\'s live channels: '
      'add an XMLTV guide link to a playlist (or borrow another playlist\'s '
      'guide), get guide matches for the channels without guide data '
      '(prefixes, spelling and spacing differences handled, a score and '
      'what airs now on each), and link channels to guide channels. Every '
      'change returns a change_id and can be undone. Call vesper_help topic '
      '"epg_matching" first.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': [
          'status',
          'suggest',
          'find_guide',
          'add_guide',
          'remove_guide',
          'link',
          'unlink',
          'undo',
        ],
      },
      'playlist': {
        'type': 'string',
        'description': 'The playlist to fill (name or id).',
      },
      'from_playlist': {
        'type': 'string',
        'description': 'Also use this playlist\'s guide and its channels\' '
            'names (suggest / find_guide / link), or add its guide '
            '(add_guide).',
      },
      'url': {
        'type': 'string',
        'description': 'add_guide: an XMLTV guide link (.xml or .xml.gz).',
      },
      'guide': {
        'type': 'integer',
        'description': 'remove_guide: the guide\'s n from status.',
      },
      'preview': {
        'type': 'boolean',
        'description': 'true = only report what would change.',
      },
      'show': {
        'type': 'string',
        'enum': ['unsure', 'sure', 'none', 'all'],
        'description': 'suggest: which channels to list (default unsure).',
      },
      'group': {
        'type': 'string',
        'description': 'suggest / link sure: only channels in groups with '
            'these words.',
      },
      'query': {
        'type': 'string',
        'description': 'suggest / link sure: words in the channel name. '
            'find_guide: words in the guide channel\'s name or id.',
      },
      'offset': {'type': 'integer'},
      'limit': {'type': 'integer'},
      'sure': {
        'type': 'boolean',
        'description': 'link: link every sure suggestion of the playlist.',
      },
      'links': {
        'type': 'array',
        'description': 'link: [{"channel_id": ..., "guide_id": ...}] '
            '(ids from suggest / find_guide), at most 3000.',
        'items': {'type': 'object'},
      },
      'channel_ids': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'unlink: channels back to their own guide ids.',
      },
      'change_id': {
        'type': 'string',
        'description': 'undo: the change to take back (default: the latest).',
      },
    },
    'required': ['action'],
  },
  run: _runEpgMatching,
);
