import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../services/archive_service.dart';
import '../services/archive_stream_session.dart';
import '../services/archive_playback_sources.dart';
import '../services/archive_stream_size.dart';
import '../services/storage_service.dart';
import 'archive_playback_settings.dart';
import 'tv_menu_tile.dart';

class ArchiveStreamPicker extends StatefulWidget {
  const ArchiveStreamPicker(
      {super.key, required this.options, this.session, this.autoSelect});
  final List<ArchiveStreamOption> options;
  final ArchiveStreamSession? session;
  final Future<ArchiveStreamOption?> Function(List<ArchiveStreamOption>)?
      autoSelect;
  @override
  State<ArchiveStreamPicker> createState() => _ArchiveStreamPickerState();
}

class _ArchiveStreamPickerState extends State<ArchiveStreamPicker> {
  final Map<String, FocusNode> _nodes = {};
  final List<ArchiveStreamOption> _visible = [];
  String? _source;
  bool _interacted = false, _checked = false;
  late final int _viewer;
  String identity(ArchiveStreamOption o) =>
      '${o.source.key}|${o.stream.identity}';
  @override
  void initState() {
    super.initState();
    _viewer = context.read<StorageService>().viewerGeneration;
    widget.session?.addListener(_changed);
    _merge();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuto());
  }

  bool get current =>
      context.read<StorageService>().viewerGeneration == _viewer;
  void _merge() {
    final incoming = widget.session?.options ?? widget.options;
    final ids = incoming.map(identity).toSet();
    _visible.removeWhere((o) => !ids.contains(identity(o)));
    final known = _visible.map(identity).toSet();
    _visible.addAll(incoming.where((o) => known.add(identity(o))));
  }

  void _changed() {
    if (!mounted) return;
    setState(_merge);
    if (widget.session?.active == false) {
      if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
      return;
    }
    unawaited(_checkAuto());
  }

  Future<void> _checkAuto() async {
    if (_checked ||
        !mounted ||
        !current ||
        _interacted ||
        widget.autoSelect == null ||
        (widget.session != null && !widget.session!.complete)) {
      return;
    }
    _checked = true;
    final chosen = await widget.autoSelect!(List.of(_visible));
    if (mounted && current && !_interacted && chosen != null) {
      Navigator.pop(context, chosen);
    }
  }

  @override
  void dispose() {
    widget.session?.removeListener(_changed);
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final options = _visible
        .where((o) => _source == null || o.source.key == _source)
        .toList();
    return SafeArea(
        child: Listener(
            onPointerDown: (_) => _interacted = true,
            child: Focus(
                onKeyEvent: (_, event) {
                  _interacted = true;
                  return KeyEventResult.ignored;
                },
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                          child: Row(children: [
                            Expanded(
                                child: Text(tr('Choose a stream'),
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700))),
                            IconButton(
                                tooltip: tr('Playback preferences'),
                                icon: const Icon(Icons.tune),
                                onPressed: () async {
                                  _interacted = true;
                                  await showArchivePlaybackSettings(context);
                                }),
                          ])),
                      if (session?.loading == true)
                        const LinearProgressIndicator(minHeight: 2),
                      if (session != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: SizedBox(
                                height: 42,
                                child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                              label: Text(tr('All')),
                                              selected: _source == null,
                                              onSelected: (_) {
                                                _interacted = true;
                                                setState(() => _source = null);
                                              })),
                                      for (final e in session.statuses.entries)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                                selected: _source == e.key,
                                                label: Text(
                                                    '${session.names[e.key]} · ${switch (e.value) {
                                                  ArchiveSourceStatus.loading =>
                                                    tr('Loading'),
                                                  ArchiveSourceStatus.ready =>
                                                    tr('Ready'),
                                                  ArchiveSourceStatus.empty =>
                                                    tr('No streams'),
                                                  ArchiveSourceStatus.failed =>
                                                    tr('Retry'),
                                                }}'),
                                                onSelected: (_) {
                                                  _interacted = true;
                                                  if (e.value ==
                                                      ArchiveSourceStatus
                                                          .failed) {
                                                    unawaited(session
                                                        .retrySource
                                                        ?.call(e.key));
                                                  } else {
                                                    setState(
                                                        () => _source = e.key);
                                                  }
                                                })),
                                    ]))),
                      Flexible(
                          child: options.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(session?.loading == true
                                      ? tr('Looking for streams…')
                                      : tr(
                                          'No playable stream for this title.')))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 0, 8, 16),
                                  itemCount: options.length,
                                  itemBuilder: (_, i) {
                                    final o = options[i];
                                    final id = identity(o);
                                    final formats = archiveStreamFormats(o);
                                    final size = archiveStreamBytes(o);
                                    final badges = [
                                      o.source.name,
                                      ...formats,
                                      if (size > 0)
                                        '${(size / 1000000000).toStringAsFixed(1)} GB',
                                      if (o.stream.subtitles.isNotEmpty)
                                        '${o.stream.subtitles.length} ${tr('subtitles')}'
                                    ];
                                    return TvMenuTile(
                                        key: ValueKey(id),
                                        focusNode: _nodes.putIfAbsent(
                                            id,
                                            () => FocusNode(
                                                debugLabel: 'archive-stream')),
                                        autofocus: i == 0 && !_interacted,
                                        icon: Icons.play_circle_outline,
                                        title: archiveStreamLabel(
                                            o.stream.name ??
                                                o.stream.title ??
                                                tr('Stream {n}', {'n': i + 1})),
                                        titleMaxLines: 2,
                                        subtitle: [
                                          badges.join(' · '),
                                          if (o.stream.title != null &&
                                              o.stream.name != null)
                                            archiveStreamLabel(o.stream.title!)
                                        ].join('\n'),
                                        onTap: () {
                                          _interacted = true;
                                          if (current) {
                                            Navigator.pop(context, o);
                                          }
                                        });
                                  })),
                    ]))));
  }
}
