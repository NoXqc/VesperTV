import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/desktop_mini_player.dart';
import '../services/epg_service.dart';
import '../services/playlist_manager.dart';
import '../services/sports_channel_library.dart';
import '../services/storage_service.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/player_controls.dart';
import '../widgets/sports_widgets.dart';
import '../widgets/tv_menu_tile.dart';
import '../widgets/tv_text_field_gate.dart';

/// Shared all-channel picker: selection is independent of filters and paging.
class SportsChannelPicker extends StatefulWidget {
  const SportsChannelPicker(
      {super.key,
      required this.channels,
      this.selected = const {},
      this.multiple = true,
      this.groupFirst = false,
      this.allowRules = false,
      this.initialRules = const {},
      this.onSaveRules});
  final List<Channel> channels;
  final Set<String> selected;
  final bool multiple;
  final bool groupFirst;
  final bool allowRules;
  final Map<String, List<String>> initialRules;
  final ValueChanged<Map<String, List<String>>>? onSaveRules;
  @override
  State<SportsChannelPicker> createState() => _SportsChannelPickerState();
}

class _SportsChannelPickerState extends State<SportsChannelPicker> {
  late final _selected =
      widget.selected.intersection(widget.channels.map((c) => c.id).toSet());
  String _query = '';
  String? _group;
  late final _store = SportsChannelLists(context.read<StorageService>());
  late Map<String, List<String>> _filters = {...widget.initialRules};
  late bool _updated = widget.initialRules.isNotEmpty;
  Future<void> _filter(SportsChannelLibrary library) async {
    final picked = await showSportsChannelFilters(context, library, _filters);
    if (picked != null && mounted) setState(() => _filters = picked);
  }

  Future<void> _tags() async {
    final kind = await showDialog<String>(
        context: context,
        builder: (dialog) =>
            SimpleDialog(title: Text(tr('Edit tags')), children: [
              for (final key in ['Country', 'Network', 'Sport', 'League'])
                TvMenuTile(
                    icon: Icons.label,
                    title: tr(key),
                    onTap: () => Navigator.pop(dialog, key)),
            ]));
    if (kind == null || !mounted) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: Text(tr(kind)),
                content: FocusNodeOwner(
                    builder: (_, node) => TvTextFieldGate(
                        focusNode: node,
                        builder: (_, readOnly) => TextField(
                            controller: controller,
                            focusNode: node,
                            readOnly: readOnly,
                            decoration: InputDecoration(
                                hintText: tr('Comma-separated tags'))))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(tr('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, controller.text),
                      child: Text(tr('Save')))
                ]));
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (value == null) return;
    for (final id in _selected) {
      (_store.tags[id] ??= {})[kind] = value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    await _store.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final library = SportsChannelLibrary(widget.channels, store: _store);
    final results = library
        .search(query: _query, group: _group)
        .where((c) => library.accepts(c, _filters))
        .toList();
    final groups = {
      for (final c in library.channels) '${c.playlistId}::${c.group}': c
    };
    final playlist = context.read<PlaylistManager>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pick channels myself')), actions: [
        TextButton(
            onPressed: () {
              widget.onSaveRules?.call(_updated
                  ? {
                      ..._filters,
                      if (_group != null) 'Group': [_group!],
                      if (_query.trim().isNotEmpty) 'Query': [_query],
                      if (_filters.isEmpty &&
                          _group == null &&
                          _query.trim().isEmpty)
                        'All': ['true']
                    }
                  : {});
              Navigator.pop(context, _selected);
            },
            child: Text(tr('Save'))),
      ]),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              FocusNodeOwner(
                  builder: (_, node) => TvTextFieldGate(
                      focusNode: node,
                      builder: (_, readOnly) => TextField(
                          focusNode: node,
                          readOnly: readOnly,
                          decoration:
                              InputDecoration(labelText: tr('Search channels')),
                          onChanged: (v) => setState(() => _query = v)))),
              DropdownButton<String?>(
                  autofocus: widget.groupFirst,
                  isExpanded: true,
                  value: _group,
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(tr('All groups'))),
                    for (final e in groups.entries)
                      DropdownMenuItem(
                          value: e.key,
                          child: Text(
                              '${playlist.playlistNameFor(e.value.playlistId)} · ${e.value.group}',
                              maxLines: 1))
                  ],
                  onChanged: (v) => setState(() => _group = v)),
              Wrap(spacing: 12, children: [
                TextButton(
                    onPressed: () => _filter(library),
                    child: Text(tr('Filters'))),
                if (_selected.isNotEmpty)
                  TextButton(onPressed: _tags, child: Text(tr('Edit tags'))),
                Text(tr('{count} selected', {'count': _selected.length})),
                if (widget.multiple)
                  TextButton(
                      onPressed: () => setState(
                          () => _selected.addAll(results.map((c) => c.id))),
                      child: Text(tr('Select results'))),
                TextButton(
                    onPressed: () => setState(
                        () => _selected.removeAll(results.map((c) => c.id))),
                    child: Text(tr('Clear results'))),
              ]),
              if (widget.allowRules)
                CheckboxListTile(
                    title: Text(tr('Keep this list updated')),
                    value: _updated,
                    onChanged: (v) => setState(() {
                          _updated = v ?? false;
                          if (_updated) {
                            _selected.addAll(results.map((c) => c.id));
                          }
                        })),
            ])),
        Expanded(
            child: results.isEmpty
                ? Center(
                    child: TextButton(
                        onPressed: () => setState(() {
                              _query = '';
                              _group = null;
                              _filters = {};
                            }),
                        child: Text(tr('Browse all channels'))))
                : SportsChannelTiles(
                    channels: results,
                    selected: _selected,
                    onTap: (c) {
                      if (!widget.multiple) {
                        Navigator.pop(context, <String>{c.id});
                        return;
                      }
                      setState(() => _selected.contains(c.id)
                          ? _selected.remove(c.id)
                          : _selected.add(c.id));
                    })),
      ]),
    );
  }
}

/// Lazy fixed-height rows with explicit remote movement and jump-to scrolling.
class SportsChannelTiles extends StatefulWidget {
  const SportsChannelTiles(
      {super.key,
      required this.channels,
      required this.onTap,
      this.onHold,
      this.selected = const {}});
  final List<Channel> channels;
  final Set<String> selected;
  final ValueChanged<Channel> onTap;
  final ValueChanged<Channel>? onHold;
  @override
  State<SportsChannelTiles> createState() => _SportsChannelTilesState();
}

class _SportsChannelTilesState extends State<SportsChannelTiles> {
  final _scroll = ScrollController();
  final _nodes = <int, FocusNode>{};
  int _index = 0;
  FocusNode _node(int i) => _nodes.putIfAbsent(i, () {
        final node = FocusNode();
        node.addListener(() {
          if (node.hasFocus) _index = i;
        });
        return node;
      });
  void _move(int delta) {
    final target = (_index + delta).clamp(0, widget.channels.length - 1);
    if (target == _index && delta < 0) {
      FocusScope.of(context).focusInDirection(TraversalDirection.up);
      return;
    }
    _index = target;
    if (_scroll.hasClients) {
      _scroll
          .jumpTo((target * 84.0).clamp(0, _scroll.position.maxScrollExtent));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[target]?.requestFocus();
    });
  }

  @override
  void didUpdateWidget(SportsChannelTiles old) {
    super.didUpdateWidget(old);
    if (old.channels.map((c) => c.id).join('|') !=
        widget.channels.map((c) => c.id).join('|')) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();
    final playlist = context.watch<PlaylistManager>();
    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        },
        child: ListView.builder(
            controller: _scroll,
            itemExtent: 84,
            itemCount: widget.channels.length,
            itemBuilder: (_, i) {
              final c = widget.channels[i];
              final now = epg.getCurrentProgram(c.epgId)?.title;
              final next = epg.getNextProgram(c.epgId)?.title;
              return HoldToActivate(
                  onTap: () => widget.onTap(c),
                  onHold:
                      widget.onHold == null ? null : () => widget.onHold!(c),
                  child: TvMenuTile(
                      focusNode: _node(i),
                      leading: SportsLogo(
                          url: c.logoUrl, size: 42, fallback: c.name),
                      title: c.name,
                      subtitle: [
                        playlist.playlistNameFor(c.playlistId),
                        if (now != null) now,
                        if (next != null) '${tr('Next')}: $next'
                      ].join(' · '),
                      trailing: widget.selected.contains(c.id)
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => widget.onTap(c)));
            }));
  }
}

Future<Map<String, List<String>>?> showSportsChannelFilters(
    BuildContext context,
    SportsChannelLibrary library,
    Map<String, List<String>> initial) {
  final selected = {
    for (final e in initial.entries) e.key: [...e.value]
  };
  final counts = <String, Map<String, int>>{};
  for (final c in library.channels) {
    for (final e in library.tagsFor(c).entries) {
      final facet = counts[e.key] ??= {};
      for (final value in e.value.isEmpty ? ['Unknown'] : e.value) {
        facet[value] = (facet[value] ?? 0) + 1;
      }
    }
  }
  return showDialog<Map<String, List<String>>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (_, update) => AlertDialog(
                title: Text(tr('Filters')),
                content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                        child: Column(children: [
                      for (final dimension in [
                        'Playlist',
                        'Group',
                        'Network',
                        'Country',
                        'Sport',
                        'League'
                      ])
                        TvMenuTile(
                            icon: Icons.filter_list,
                            title: tr(dimension),
                            subtitle: selected[dimension]?.join(', '),
                            onTap: () async {
                              final options = {
                                'Unknown',
                                ...?counts[dimension]?.keys,
                                ...?selected[dimension]
                              }.toList()
                                ..sort();
                              var query = '';
                              await showDialog<void>(
                                  context: dialog,
                                  builder:
                                      (facetDialog) =>
                                          StatefulBuilder(builder: (_, change) {
                                            final visible = options
                                                .where((s) => s
                                                    .toLowerCase()
                                                    .contains(
                                                        query.toLowerCase()))
                                                .toList();
                                            String label(String value) =>
                                                dimension == 'Playlist'
                                                    ? context
                                                        .read<PlaylistManager>()
                                                        .playlistNameFor(value)
                                                    : dimension == 'Group' &&
                                                            value.contains('::')
                                                        ? value
                                                            .split('::')
                                                            .skip(1)
                                                            .join('::')
                                                        : tr(value);
                                            return AlertDialog(
                                                title: Text(tr(dimension)),
                                                content: SizedBox(
                                                    width: 560,
                                                    height: 360,
                                                    child: Column(children: [
                                                      FocusNodeOwner(
                                                          builder: (_, node) => TvTextFieldGate(
                                                              focusNode: node,
                                                              builder: (_, readOnly) => TextField(
                                                                  focusNode:
                                                                      node,
                                                                  readOnly:
                                                                      readOnly,
                                                                  decoration: InputDecoration(
                                                                      labelText: tr(
                                                                          'Search')),
                                                                  onChanged: (v) =>
                                                                      change(() =>
                                                                          query =
                                                                              v)))),
                                                      Expanded(
                                                          child:
                                                              ListView.builder(
                                                                  itemCount:
                                                                      visible
                                                                          .length,
                                                                  itemBuilder:
                                                                      (_, i) {
                                                                    final value =
                                                                        visible[
                                                                            i];
                                                                    return CheckboxListTile(
                                                                        title: Text(
                                                                            '${label(value)} (${counts[dimension]?[value] ?? 0})'),
                                                                        value: selected[dimension]?.contains(value) ??
                                                                            false,
                                                                        onChanged: (on) =>
                                                                            change(() {
                                                                              final values = selected[dimension] ??= [];
                                                                              on == true ? values.add(value) : values.remove(value);
                                                                            }));
                                                                  })),
                                                    ])),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              facetDialog),
                                                      child: Text(tr('Save')))
                                                ]);
                                          }));
                              update(() {});
                            }),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => update(selected.clear),
                      child: Text(tr('Clear all'))),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(tr('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(
                          dialog,
                          Map<String, List<String>>.fromEntries(selected.entries
                              .where((e) => e.value.isNotEmpty))),
                      child: Text(tr('Save')))
                ],
              )));
}

class SportsChannelsScreen extends StatefulWidget {
  const SportsChannelsScreen(
      {super.key,
      required this.onGames,
      required this.onPreview,
      required this.onFullScreen});
  final VoidCallback onGames;
  final Future<void> Function(Channel?) onPreview;
  final Future<void> Function(Channel) onFullScreen;
  @override
  State<SportsChannelsScreen> createState() => _SportsChannelsScreenState();
}

class _SportsChannelsScreenState extends State<SportsChannelsScreen> {
  late SportsChannelLists _store;
  String _section = 'My lists';
  String? _list;
  Channel? _preview;
  Map<String, List<String>> _viewFilters = {};
  @override
  void initState() {
    super.initState();
    _store = SportsChannelLists(context.read<StorageService>());
  }

  Future<void> _edit([SportsChannelList? list]) async {
    bool groupFirst = false;
    if (list == null) {
      final choice = await showDialog<bool>(
          context: context,
          builder: (dialog) =>
              SimpleDialog(title: Text(tr('Create list')), children: [
                TvMenuTile(
                    icon: Icons.checklist,
                    title: tr('Pick channels myself'),
                    onTap: () => Navigator.pop(dialog, false)),
                TvMenuTile(
                    icon: Icons.folder,
                    title: tr('Use a playlist group'),
                    onTap: () => Navigator.pop(dialog, true)),
              ]));
      if (choice == null || !mounted) return;
      groupFirst = choice;
    }
    final playlist = context.read<PlaylistManager>();
    final visible = playlist.visibleChannels(category: 'tv');
    final library = SportsChannelLibrary(visible, store: _store);
    Map<String, List<String>> rules = list?.filters ?? {};
    final chosen = await Navigator.push<Set<String>>(
        context,
        MaterialPageRoute(
            builder: (_) => SportsChannelPicker(
                channels: visible,
                selected: list == null
                    ? {}
                    : library.members(list).map((c) => c.id).toSet(),
                groupFirst: groupFirst,
                allowRules: true,
                initialRules: rules,
                onSaveRules: (value) => rules = value)));
    if (chosen == null || !mounted) return;
    // Keep temporarily unavailable references without displaying their names.
    final missing =
        list?.channels.where((id) => !visible.any((c) => c.id == id)) ??
            <String>[];
    if (list == null) {
      final name = await _name(tr('My sports channels'));
      if (name == null || !mounted) return;
      final made = _store.create(name, chosen);
      _list = made.id;
      list = made;
    } else {
      list.channels
        ..clear()
        ..addAll({...chosen, ...missing});
    }
    _store.tags
      ..clear()
      ..addAll(SportsChannelLists(context.read<StorageService>()).tags);
    final matched = rules.isEmpty
        ? <String>{}
        : library.channels
            .where((c) => library.accepts(c, rules))
            .map((c) => c.id)
            .toSet();
    list.filters = rules;
    list.excluded
      ..clear()
      ..addAll(matched.difference(chosen));
    if (rules.isNotEmpty) list.channels.removeWhere(matched.contains);
    await _store.save();
    if (mounted) setState(() {});
  }

  Future<void> _manage(SportsChannelList list) async {
    final action = await showDialog<String>(
        context: context,
        builder: (dialog) => SwallowHeldActivate(
                child: SimpleDialog(title: Text(list.name), children: [
              for (final key in [
                'Edit list',
                'Rename list',
                'Move Up / Down',
                'Delete list'
              ])
                TvMenuTile(
                    icon: Icons.edit,
                    title: tr(key),
                    onTap: () => Navigator.pop(dialog, key))
            ])));
    if (!mounted || action == null) return;
    if (action == 'Edit list') {
      await _edit(list);
      return;
    }
    if (action == 'Rename list') {
      final name = await _name(list.name);
      if (name == null) return;
      list.name = name;
    } else if (action == 'Move Up / Down') {
      final index = _store.lists.indexOf(list);
      final target = await showDialog<int>(
          context: context,
          builder: (dialog) => SimpleDialog(children: [
                for (var i = 0; i < _store.lists.length; i++)
                  TvMenuTile(
                      icon: Icons.swap_vert,
                      title: _store.lists[i].name,
                      onTap: () => Navigator.pop(dialog, i)),
              ]));
      if (target == null) return;
      _store.lists
        ..removeAt(index)
        ..insert(target, list);
    } else if (action == 'Delete list') {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: Text(tr('Delete list')),
                  content: Text(list.name),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: Text(tr('Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: Text(tr('Delete')))
                  ]));
      if (confirm != true) return;
      _store.lists.remove(list);
      _list = null;
    }
    await _store.save();
    if (mounted) setState(() {});
  }

  Future<String?> _name(String initial) async {
    final field = TextEditingController(text: initial);
    final result = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: Text(tr('List name')),
                content: FocusNodeOwner(
                    builder: (_, node) => TvTextFieldGate(
                        focusNode: node,
                        builder: (_, readOnly) => TextField(
                            controller: field,
                            focusNode: node,
                            readOnly: readOnly))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(tr('Cancel'))),
                  TextButton(
                      onPressed: () => Navigator.pop(
                          dialog,
                          field.text.trim().isEmpty
                              ? initial
                              : field.text.trim()),
                      child: Text(tr('Save')))
                ]));
    // Dialog route can still animate with the controller attached.
    WidgetsBinding.instance.addPostFrameCallback((_) => field.dispose());
    return result;
  }

  Future<void> _menu(Channel channel, SportsChannelLibrary library) async {
    final versions = library.versions(channel);
    await showDialog<void>(
        context: context,
        builder: (dialog) => SwallowHeldActivate(
                child: SimpleDialog(title: Text(channel.name), children: [
              for (final list in _store.lists)
                TvMenuTile(
                    icon: Icons.live_tv,
                    title: '${tr('Add to list')} · ${list.name}',
                    onTap: () async {
                      if (!list.channels.contains(channel.id)) {
                        list.channels.add(channel.id);
                      }
                      list.excluded.remove(channel.id);
                      await _store.save();
                      if (dialog.mounted) Navigator.pop(dialog);
                      if (mounted) setState(() {});
                    }),
              if (_store.lists.isEmpty)
                TvMenuTile(
                    icon: Icons.live_tv,
                    title: tr('Create list'),
                    onTap: () {
                      Navigator.pop(dialog);
                      _edit();
                    }),
              for (final c in versions)
                TvMenuTile(
                    icon: Icons.live_tv,
                    title: '${tr('Versions')} · ${c.name}',
                    onTap: () {
                      Navigator.pop(dialog);
                      _watch(c);
                    }),
            ])));
  }

  Future<void> _watch(Channel c) async {
    if (_preview?.id == c.id) {
      await widget.onFullScreen(c);
      return;
    }
    setState(() => _preview = c);
    await widget.onPreview(c);
  }

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistManager>();
    final library = SportsChannelLibrary(
        playlist.visibleChannels(category: 'tv'),
        store: _store);
    final list = _store.lists.where((l) => l.id == _list).firstOrNull;
    final sectionChannels = _section == 'My lists'
        ? (list == null ? <Channel>[] : library.members(list))
        : library.channels
            .where((c) => SportsChannelLibrary.category(c) == _section)
            .toList();
    final channels =
        sectionChannels.where((c) => library.accepts(c, _viewFilters)).toList();
    final mini =
        Platform.isWindows ? DesktopMiniPlayer.instance.controller : null;
    return PopScope(
        canPop: _preview == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _preview = null);
            widget.onPreview(null);
          }
        },
        child: Scaffold(
            appBar: AppBar(title: Text(tr('Channels')), actions: [
              IconButton(
                  tooltip: tr('Filters'),
                  icon: const Icon(Icons.filter_list),
                  onPressed: () async {
                    final filters = await showSportsChannelFilters(
                        context, library, _viewFilters);
                    if (filters != null && mounted) {
                      setState(() => _viewFilters = filters);
                    }
                  }),
              TextButton(onPressed: widget.onGames, child: Text(tr('Games'))),
              TextButton(
                  onPressed: () => _edit(), child: Text(tr('Create list'))),
              if (list != null)
                TextButton(
                    onPressed: () => _manage(list),
                    child: Text(tr('Edit list'))),
            ]),
            body: Column(children: [
              if (_preview case final c?)
                SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.28,
                    child: Row(children: [
                      Expanded(
                          child: mini != null
                              ? Video(
                                  controller: mini, controls: NoVideoControls)
                              : const VideoPlayerPane(
                                  showEpgBar: false, showControls: false)),
                      Expanded(
                          child: TextButton(
                              onPressed: () => widget.onFullScreen(c),
                              child: Text(c.name)))
                    ])),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final section in [
                      'My lists',
                      'League networks',
                      'Sports networks',
                      'Regional channels'
                    ])
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: ChoiceChip(
                              label: Text(tr(section)),
                              selected: _section == section,
                              onSelected: (_) =>
                                  setState(() => _section = section))),
                  ])),
              if (_section == 'My lists')
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final l in _store.lists)
                        Padding(
                            padding: const EdgeInsets.all(6),
                            child: ChoiceChip(
                                label: Text(l.name),
                                selected: l.id == _list,
                                onSelected: (_) =>
                                    setState(() => _list = l.id))),
                    ])),
              Expanded(
                  child: channels.isEmpty
                      ? Center(
                          child: TextButton(
                              onPressed: () => _edit(list),
                              child: Text(tr('Browse all channels'))))
                      : SportsChannelTiles(
                          channels: channels,
                          onTap: _watch,
                          onHold: (c) => _menu(c, library))),
            ])));
  }
}
