import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../services/sports_networks.dart';
import '../services/storage_service.dart';
import '../utils/time_format.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/player_controls.dart';
import '../widgets/settings_scaffold.dart';
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

/// Sports Trak › Channels: the user's sports channels as **network cards**
/// (every TSN feed and copy behind one "TSN" card) in rows — My lists,
/// League networks, Sports networks, Regional channels — under a hero that
/// previews the picked channel. OK previews a card's first channel, OK
/// again goes full screen; hold OK picks another of its channels or adds
/// one to a list. Owner, 2026-10-22: the first version was a plain list
/// ("looks like our Settings"); modelled on a user's photo of another app.
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

/// One row of cards on the Channels page.
class _CardRow {
  _CardRow(this.id, this.title, this.cards, {this.list});
  final String id;
  final String title;
  final List<SportsNetworkGroup> cards;

  /// Set for a My lists row.
  final SportsChannelList? list;

  int get channelCount => cards.fold(0, (n, g) => n + g.channels.length);
}

class _SportsChannelsScreenState extends State<SportsChannelsScreen> {
  late SportsChannelLists _store;
  Channel? _preview;
  Map<String, List<String>> _viewFilters = {};

  /// The card focused last (hero text + backdrop) and its row.
  SportsNetworkGroup? _focused;

  /// The channel picked for a card with hold OK (card id -> channel id).
  final Map<String, String> _picked = {};

  /// Rows as last built, for the arrow keys.
  List<_CardRow> _rows = const [];
  final Map<String, FocusNode> _cardNodes = {};
  final Map<String, int> _lastColumn = {};
  final List<FocusNode> _chipNodes = [for (var i = 0; i < 3; i++) FocusNode()];

  /// Rows are rebuilt only when the playlists, filters or lists change
  /// ([_dirty]), not on every focus move — grouping the whole catalogue on
  /// each rebuild froze a Fire Stick.
  bool _dirty = true;
  SportsChannelLibrary? _library;
  late final PlaylistManager _playlist;

  void _markDirty() {
    if (mounted) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _store = SportsChannelLists(context.read<StorageService>());
    _playlist = context.read<PlaylistManager>()..addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rows.isNotEmpty && _rows.first.cards.isNotEmpty) {
        _focusCard(0, 0);
      } else {
        _chipNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _playlist.removeListener(_markDirty);
    for (final n in [..._cardNodes.values, ..._chipNodes]) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(String rowId, String cardId) =>
      _cardNodes.putIfAbsent('$rowId/$cardId', FocusNode.new);

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
    if (mounted) setState(() => _dirty = true);
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
    }
    await _store.save();
    if (mounted) setState(() => _dirty = true);
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

  /// The channel OK previews on [g]: the one picked with hold OK, else the
  /// first ([compareNetworkChannels]: TSN 1 before TSN 2, FHD before 4K).
  Channel _mainOf(SportsNetworkGroup g) {
    final picked = _picked[g.id];
    return g.channels
        .firstWhere((c) => c.id == picked, orElse: () => g.channels.first);
  }

  bool _previewing(SportsNetworkGroup g) =>
      _preview != null && g.channels.any((c) => c.id == _preview!.id);

  Future<void> _watch(Channel c) async {
    if (_preview?.id == c.id) {
      await widget.onFullScreen(c);
      return;
    }
    setState(() => _preview = c);
    await widget.onPreview(c);
  }

  /// Hold OK on a card: its channels (one press = preview it), adding the
  /// card's channel to a list, and the list's own menu on a My lists row.
  Future<void> _menu(_CardRow row, SportsNetworkGroup g) async {
    final epg = context.read<EpgService>();
    final main = _mainOf(g);
    final action = await showDialog<Object>(
        context: context,
        builder: (dialog) => SwallowHeldActivate(
                child: SimpleDialog(title: Text(g.name), children: [
              for (final c in g.channels)
                TvMenuTile(
                    autofocus: c.id == main.id,
                    icon: c.id == _preview?.id
                        ? Icons.play_circle
                        : Icons.live_tv,
                    title: c.name,
                    subtitle: epg.getCurrentProgram(c.epgId)?.title,
                    onTap: () => Navigator.pop(dialog, c)),
              for (final list in _store.lists)
                if (list != row.list)
                  TvMenuTile(
                      icon: Icons.playlist_add,
                      title: '${tr('Add to list')} · ${list.name}',
                      onTap: () => Navigator.pop(dialog, list)),
              if (row.list != null)
                TvMenuTile(
                    icon: Icons.edit,
                    title: tr('Edit list'),
                    onTap: () => Navigator.pop(dialog, 'manage')),
              TvMenuTile(
                  icon: Icons.add,
                  title: tr('Create list'),
                  onTap: () => Navigator.pop(dialog, 'create')),
            ])));
    if (!mounted || action == null) return;
    if (action is Channel) {
      _picked[g.id] = action.id;
      await _watch(action);
    } else if (action is SportsChannelList) {
      if (!action.channels.contains(main.id)) action.channels.add(main.id);
      action.excluded.remove(main.id);
      await _store.save();
      if (mounted) setState(() => _dirty = true);
    } else if (action == 'manage') {
      await _manage(row.list!);
    } else if (action == 'create') {
      await _edit();
    }
  }

  List<_CardRow> _buildRows(SportsChannelLibrary library) {
    // Sports channels only (cached per channel), before any filter work.
    final filtered = library.channels
        .where((c) =>
            SportsChannelLibrary.category(c).isNotEmpty &&
            library.accepts(c, _viewFilters))
        .toList();
    return [
      for (final list in _store.lists)
        _CardRow(
            'list:${list.id}',
            list.name,
            [
              for (final c in library.members(list))
                if (library.accepts(c, _viewFilters))
                  SportsNetworkGroup('ch:${c.id}', c.name, null)
                    ..channels.add(c),
            ],
            list: list),
      for (final row in const [
        'League networks',
        'Sports networks',
        'Regional channels'
      ])
        _CardRow(row, tr(row), SportsChannelLibrary.groups(filtered, row: row)),
    ].where((r) => r.cards.isNotEmpty || r.list != null).toList();
  }

  // ------------------------------------------------------------ remote

  void _focusCard(int row, int column) {
    if (row < 0 || row >= _rows.length) return;
    final r = _rows[row];
    if (r.cards.isEmpty) return;
    final i = column.clamp(0, r.cards.length - 1);
    final node = _node(r.id, r.cards[i].id);
    node.requestFocus();
    _lastColumn[r.id] = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = node.context;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5);
    });
  }

  (int, int)? _focusedPosition() {
    for (final (ri, r) in _rows.indexed) {
      for (final (ci, g) in r.cards.indexed) {
        if (_cardNodes['${r.id}/${g.id}']?.hasFocus ?? false) return (ri, ci);
      }
    }
    return null;
  }

  /// Explicit arrows (CLAUDE.md §10: default traversal is unreliable
  /// across rows of different lengths). Up from the first row reaches the
  /// header buttons; Down from them comes back.
  void _arrow(int dx, int dy) {
    final chip = _chipNodes.indexWhere((n) => n.hasFocus);
    if (chip >= 0) {
      if (dy > 0) {
        final first = _rows.indexWhere((r) => r.cards.isNotEmpty);
        if (first >= 0) _focusCard(first, _lastColumn[_rows[first].id] ?? 0);
      } else if (dx != 0) {
        final target = chip + dx;
        if (target >= 0 && target < _chipNodes.length) {
          _chipNodes[target].requestFocus();
        }
      }
      return;
    }
    final pos = _focusedPosition();
    if (pos == null) return;
    final (row, column) = pos;
    if (dx != 0) {
      final target = column + dx;
      if (target >= 0 && target < _rows[row].cards.length) {
        _focusCard(row, target);
      }
      return;
    }
    var target = row + dy;
    while (
        target >= 0 && target < _rows.length && _rows[target].cards.isEmpty) {
      target += dy;
    }
    if (target < 0) {
      _chipNodes.first.requestFocus();
    } else if (target < _rows.length) {
      _focusCard(target, _lastColumn[_rows[target].id] ?? column);
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (_dirty || _library == null) {
      _library = SportsChannelLibrary(_playlist.visibleChannels(category: 'tv'),
          store: _store);
      _rows = _buildRows(_library!);
      _dirty = false;
    }
    final library = _library!;
    final total = {
      for (final r in _rows)
        if (r.list == null)
          for (final g in r.cards) ...g.channels.map((c) => c.id)
    }.length;
    final activeFilters = _viewFilters.values.where((v) => v.isNotEmpty).length;
    final focused = _focused;
    return PopScope(
      canPop: _preview == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _preview = null);
          widget.onPreview(null);
        }
      },
      child: Stack(
        children: [
          const Positioned.fill(child: SettingsGradientBackground()),
          if (focused != null)
            Positioned.fill(child: SportsBackdrop(logoUrl: focused.logoUrl)),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _arrow(0, -1),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _arrow(0, 1),
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      _arrow(-1, 0),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      _arrow(1, 0),
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(tr('Sports'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(width: 10),
                        Text(tr('{n} channels', {'n': total}),
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white54)),
                        const Spacer(),
                        SportsChip(
                            focusNode: _chipNodes[0],
                            label: tr('Games'),
                            icon: Icons.scoreboard_outlined,
                            compact: true,
                            selected: false,
                            onFocus: () {},
                            onTap: widget.onGames),
                        const SizedBox(width: 8),
                        SportsChip(
                            focusNode: _chipNodes[1],
                            label: activeFilters == 0
                                ? tr('Filters')
                                : '${tr('Filters')} · $activeFilters',
                            icon: Icons.filter_list,
                            compact: true,
                            selected: activeFilters > 0,
                            onFocus: () {},
                            onTap: () async {
                              final filters = await showSportsChannelFilters(
                                  context, library, _viewFilters);
                              if (filters != null && mounted) {
                                setState(() {
                                  _viewFilters = filters;
                                  _dirty = true;
                                });
                              }
                            }),
                        const SizedBox(width: 8),
                        SportsChip(
                            focusNode: _chipNodes[2],
                            label: tr('Create list'),
                            icon: Icons.playlist_add,
                            compact: true,
                            selected: false,
                            onFocus: () {},
                            onTap: () => _edit()),
                      ]),
                      const SizedBox(height: 12),
                      _ChannelsHero(
                        group: _preview == null
                            ? focused
                            : _rows
                                    .expand((r) => r.cards)
                                    .where(_previewing)
                                    .firstOrNull ??
                                focused,
                        channel: _preview ??
                            (focused == null ? null : _mainOf(focused)),
                        previewing: _preview != null,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _rows.every((r) => r.cards.isEmpty)
                            ? Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    Text(
                                        activeFilters > 0
                                            ? tr(
                                                'No channel matches these filters.')
                                            : tr(
                                                'No sports channels found in your playlists.'),
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    const SizedBox(height: 12),
                                    TextButton(
                                        onPressed: () => _edit(),
                                        child: Text(tr('Browse all channels'))),
                                  ]))
                            : SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final r in _rows) _buildRow(r),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_CardRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(row.title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(width: 8),
            Text(tr('{n} channels', {'n': row.channelCount}),
                style: const TextStyle(fontSize: 13, color: Colors.white54)),
          ]),
          const SizedBox(height: 8),
          if (row.cards.isEmpty)
            Text(tr('Empty list: hold OK on any channel card to add it here.'),
                style: const TextStyle(fontSize: 13, color: Colors.white38))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final g in row.cards)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _NetworkCard(
                        focusNode: _node(row.id, g.id),
                        group: g,
                        playing: _previewing(g),
                        single: row.list != null,
                        onFocus: () {
                          if (_focused?.id != g.id) {
                            setState(() => _focused = g);
                          }
                        },
                        onTap: () {
                          final playing = _previewing(g) ? _preview : null;
                          _watch(playing ?? _mainOf(g));
                        },
                        onHold: () => _menu(row, g),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The top of the Channels page: the preview video (or the focused
/// network's logo) and what's on.
class _ChannelsHero extends StatelessWidget {
  const _ChannelsHero(
      {required this.group, required this.channel, required this.previewing});
  final SportsNetworkGroup? group;
  final Channel? channel;
  final bool previewing;

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();
    final playlist = context.read<PlaylistManager>();
    final height =
        (MediaQuery.sizeOf(context).height * 0.30).clamp(150.0, 320.0);
    final c = channel;
    final now = c == null ? null : epg.getCurrentProgram(c.epgId);
    final next = c == null ? null : epg.getNextProgram(c.epgId);
    final mini =
        Platform.isWindows ? DesktopMiniPlayer.instance.controller : null;
    String hm(DateTime t) => TimeFormat.hm.format(t.toLocal());
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black54,
                child: previewing
                    ? (mini != null
                        ? Video(controller: mini, controls: NoVideoControls)
                        : const VideoPlayerPane(
                            showEpgBar: false, showControls: false))
                    : Center(
                        child: group == null
                            ? const Icon(Icons.live_tv,
                                size: 48, color: Colors.white24)
                            : _CardLogo(group: group!, height: height * 0.4)),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: group == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(group!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          [
                            if (c != null) c.name,
                            tr('{n} channels', {'n': group!.channels.length}),
                            if (c != null && playlist.profiles.length > 1)
                              playlist.playlistNameFor(c.playlistId),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white60)),
                      const SizedBox(height: 14),
                      if (now != null) ...[
                        Text(tr('On now'),
                            style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Colors.white38)),
                        Text(now.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        Text('${hm(now.start)} – ${hm(now.stop)}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white54)),
                      ],
                      if (next != null) ...[
                        const SizedBox(height: 8),
                        Text('${tr('Next')}: ${hm(next.start)} · ${next.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white54)),
                      ],
                      const Spacer(),
                      Text(
                          previewing
                              ? tr(
                                  'OK · Full screen   Hold OK · Pick a channel   Back · Stop')
                              : tr(
                                  'OK · Preview   Hold OK · Pick a channel or add to a list'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A network's logo, or its name when no channel has one.
class _CardLogo extends StatelessWidget {
  const _CardLogo({required this.group, required this.height});
  final SportsNetworkGroup group;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = group.logoUrl;
    final name = Text(group.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: height * 0.32,
            fontWeight: FontWeight.w800,
            color: Colors.white));
    if (url == null) return name;
    final px = (height * 3 * MediaQuery.of(context).devicePixelRatio)
        .round()
        .clamp(64, 400);
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      fit: BoxFit.contain,
      memCacheWidth: px,
      fadeInDuration: Duration.zero,
      errorWidget: (_, __, ___) => name,
    );
  }
}

/// One network card: logo, name, how many of the user's channels it holds.
class _NetworkCard extends StatefulWidget {
  const _NetworkCard({
    required this.focusNode,
    required this.group,
    required this.playing,
    required this.single,
    required this.onFocus,
    required this.onTap,
    required this.onHold,
  });
  final FocusNode focusNode;
  final SportsNetworkGroup group;
  final bool playing;

  /// A My lists card: one channel, so no "N channels" line.
  final bool single;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final VoidCallback onHold;

  static const double width = 200;
  static const double height = 124;

  @override
  State<_NetworkCard> createState() => _NetworkCardState();
}

class _NetworkCardState extends State<_NetworkCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = widget.group;
    return HoldToActivate(
      onTap: widget.onTap,
      onHold: widget.onHold,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (has) {
          setState(() => _focused = has);
          if (has) widget.onFocus();
        },
        child: GestureDetector(
          onTap: () {
            widget.focusNode.requestFocus();
            widget.onTap();
          },
          onLongPress: widget.onHold,
          child: AnimatedScale(
            scale: _focused ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: _NetworkCard.width,
              height: _NetworkCard.height,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                gradient: _focused ? sportsFocusSheen(scheme) : null,
                color: _focused ? null : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _focused
                        ? scheme.primary
                        : widget.playing
                            ? scheme.primary.withValues(alpha: 0.5)
                            : Colors.white10,
                    width: _focused ? 3 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(child: _CardLogo(group: g, height: 46)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (widget.playing) ...[
                      Icon(Icons.play_arrow, size: 14, color: scheme.primary),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                  if (!widget.single)
                    Text(tr('{n} channels', {'n': g.channels.length}),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
