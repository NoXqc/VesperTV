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
      this.groupFirst = false});
  final List<Channel> channels;
  final Set<String> selected;
  final bool multiple;
  final bool groupFirst;
  @override
  State<SportsChannelPicker> createState() => _SportsChannelPickerState();
}

class _SportsChannelPickerState extends State<SportsChannelPicker> {
  late final _selected = {...widget.selected};
  String _query = '';
  String? _group;
  @override
  Widget build(BuildContext context) {
    final library = SportsChannelLibrary(widget.channels);
    final results = library.search(query: _query, group: _group);
    final groups = {
      for (final c in library.channels) '${c.playlistId}::${c.group}': c
    };
    final playlist = context.read<PlaylistManager>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pick channels myself')), actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, _selected),
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
            ])),
        Expanded(
            child: results.isEmpty
                ? Center(
                    child: TextButton(
                        onPressed: () => setState(() {
                              _query = '';
                              _group = null;
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
    final chosen = await Navigator.push<Set<String>>(
        context,
        MaterialPageRoute(
            builder: (_) => SportsChannelPicker(
                channels: visible,
                selected: list?.channels.toSet() ?? {},
                groupFirst: groupFirst)));
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
    } else {
      list.channels
        ..clear()
        ..addAll({...chosen, ...missing});
    }
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
    final library =
        SportsChannelLibrary(playlist.visibleChannels(category: 'tv'));
    final list = _store.lists.where((l) => l.id == _list).firstOrNull;
    final channels = _section == 'My lists'
        ? (list == null ? <Channel>[] : library.members(list))
        : library.channels
            .where((c) => SportsChannelLibrary.category(c) == _section)
            .toList();
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
