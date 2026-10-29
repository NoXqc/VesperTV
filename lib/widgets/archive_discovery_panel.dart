import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../models/archive_library.dart';
import '../services/archive_discovery_service.dart';
import '../services/archive_service.dart';
import '../services/storage_service.dart';
import '../screens/archive_detail_screen.dart';
import '../screens/archive_playback.dart';
import '../screens/settings/tmdb_settings_screen.dart';
import 'poster_card.dart';
import 'hold_to_activate.dart';

Widget _remoteCard(PosterCard card) =>
    HoldToActivate(onTap: card.onTap, child: card);

class ArchiveDiscoveryPanel extends StatefulWidget {
  const ArchiveDiscoveryPanel(
      {super.key,
      required this.source,
      required this.meta,
      required this.entryNode,
      required this.onReturn,
      this.discovery});
  final ArchiveSource source;
  final ArchiveMeta meta;
  final FocusNode entryNode;
  final VoidCallback onReturn;
  final ArchiveDiscoveryService? discovery;
  @override
  State<ArchiveDiscoveryPanel> createState() => _ArchiveDiscoveryPanelState();
}

class _ArchiveDiscoveryPanelState extends State<ArchiveDiscoveryPanel> {
  late final _api = widget.discovery ?? ArchiveDiscoveryService();
  ArchiveDiscovery _data = const ArchiveDiscovery();
  bool _loading = true, _failed = false, _opening = false;
  final _nodes = <String, FocusNode>{};
  final _scrolls = <String, ScrollController>{};
  final _indices = <String, int>{};
  late final int _viewer;
  List<String> _rows = [];
  final _localSources = <ArchiveMeta, ArchiveSource>{};
  int _request = 0;
  StorageService get storage => context.read<StorageService>();
  String get key => storage.getTmdbApiKey() ?? '';
  @override
  void initState() {
    super.initState();
    _viewer = storage.viewerGeneration;
    _load();
  }

  bool get current => mounted && storage.viewerGeneration == _viewer;
  @override
  void didUpdateWidget(covariant ArchiveDiscoveryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.id != widget.meta.id ||
        oldWidget.meta.imdb != widget.meta.imdb) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final result = await _api.discover(widget.meta, key, L10n.code);
      if (current && request == _request) {
        setState(() {
          _data = result;
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (current && request == _request) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _api.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    for (final c in _scrolls.values) {
      c.dispose();
    }
    super.dispose();
  }

  FocusNode node(String row, int i) => _nodes.putIfAbsent(
      '$row:$i', () => FocusNode(debugLabel: 'discovery-$row'));
  void _focus(String row, int index) {
    final count = row == 'cast'
        ? _data.cast.length
        : row == 'collection'
            ? _data.collection.length
            : _related.length;
    if (count == 0) return;
    final i = index.clamp(0, count - 1);
    _indices[row] = i;
    final c = _scrolls[row];
    if (c != null && c.hasClients) {
      c.jumpTo(
          (i * (PosterCard.width + 20)).clamp(0.0, c.position.maxScrollExtent));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node(row, i).requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  List<ArchiveMeta> get _related {
    if (_data.related.isNotEmpty) return _data.related;
    final hub = context.read<ArchiveService>();
    final seen = <String>{archiveTitleIdentity(widget.source, widget.meta)};
    final result = <ArchiveMeta>[];
    _localSources.clear();
    for (final row in hub.rows(widget.meta.type)) {
      for (var i = 0; i < row.items.length; i++) {
        final item = row.items[i];
        if (!item.genres.any(widget.meta.genres.contains) ||
            !seen.add(archiveTitleIdentity(row.sourceAt(i), item))) {
          continue;
        }
        result.add(item);
        _localSources[item] = row.sourceAt(i);
        if (result.length == 16) return result;
      }
    }
    return result;
  }

  Future<void> _open(ArchiveMeta preview) async {
    if (_opening) return;
    setState(() => _opening = true);
    final hub = context.read<ArchiveService>();
    ArchiveSource? source = _localSources[preview];
    var meta = preview;
    try {
      if (source == null && key.isNotEmpty && preview.imdb == null) {
        meta = await _api.identify(preview, key, L10n.code);
      }
      if (!mounted || !current) return;
      for (final row in source == null
          ? hub.rows(meta.type, includeHidden: true)
          : const <ArchiveRow>[]) {
        for (var i = 0; i < row.items.length; i++) {
          final candidate = row.items[i];
          if (meta.wireType == null &&
              candidate.wireType == null &&
              ((meta.imdb != null && meta.imdb == candidate.imdb) ||
                  (meta.id.startsWith('tmdb:') && candidate.id == meta.id))) {
            source = row.sourceAt(i);
            meta = candidate;
            break;
          }
        }
        if (source != null) break;
      }
      if (source == null) {
        final match = await hub.findServerTitle(meta);
        if (!mounted || !current) return;
        if (match != null) {
          source = match.source;
          meta = match.meta;
        }
      }
      if (source == null && meta.imdb != null) {
        source = hub.enabledSources
            .where((s) =>
                s.server == null &&
                (s.streamOnly || s.supportsImdb('stream', meta.type.wire)))
            .firstOrNull;
      }
      if (!mounted || !current) return;
      if (source == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(
                'No compatible source for this title. Add a playback source in Media Hub settings.'))));
        return;
      }
      if (meta.type == ArchiveType.series) {
        await openArchiveSeries(context, source, meta);
      } else {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                ArchiveDetailScreen(source: source!, preview: meta)));
      }
    } catch (_) {
      if (mounted && current) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Could not load this title. Try again.'))));
      }
    } finally {
      if (current) setState(() => _opening = false);
    }
  }

  Future<void> _person(ArchivePerson person) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _ArchiveCreditsScreen(
            name: person.name,
            load: () => _api.credits(person, key, L10n.code),
            open: _open)));
  }

  Widget _row(String id, String title, int count, Widget Function(int) card) {
    final row = _rows.indexOf(id);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
      Focus(
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final i = _indices[id] ?? 0;
            if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _focus(id, i - 1);
            } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              _focus(id, i + 1);
            } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (row == 0) {
                widget.entryNode.requestFocus();
              } else {
                _focus(_rows[row - 1], _indices[_rows[row - 1]] ?? 0);
              }
            } else if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (row + 1 < _rows.length) {
                _focus(_rows[row + 1], _indices[_rows[row + 1]] ?? 0);
              }
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
              height: PosterCard.height + 20,
              child: ListView.builder(
                  controller: _scrolls.putIfAbsent(id, ScrollController.new),
                  scrollDirection: Axis.horizontal,
                  itemExtent: PosterCard.width + 20,
                  itemCount: count,
                  itemBuilder: (_, i) => card(i)))),
    ]);
  }

  Widget _titleCard(String row, int i, ArchiveMeta meta) =>
      _remoteCard(PosterCard(
          focusNode: node(row, i),
          title: meta.name,
          imageUrl: meta.posterUrl,
          rating: meta.year,
          onTap: () async {
            await _open(meta);
            if (current) _focus(row, i);
          },
          onFocusGained: () => _reveal(row, i)));
  void _reveal(String row, int i) {
    _indices[row] = i;
    final ctx = node(row, i).context;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: .65, duration: const Duration(milliseconds: 180));
    }
  }

  @override
  Widget build(BuildContext context) {
    final related = _related;
    _rows = [
      if (_data.collection.isNotEmpty) 'collection',
      if (related.isNotEmpty) 'related',
      if (_data.cast.isNotEmpty) 'cast'
    ];
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Focus(
              onKeyEvent: (_, e) {
                if (e is! KeyDownEvent) return KeyEventResult.ignored;
                if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                  widget.onReturn();
                  return KeyEventResult.handled;
                }
                if (e.logicalKey == LogicalKeyboardKey.arrowDown &&
                    _rows.isNotEmpty) {
                  _focus(_rows.first, 0);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: OutlinedButton.icon(
                  focusNode: widget.entryNode,
                  icon: Icon(_failed ? Icons.refresh : Icons.explore_outlined),
                  label: Text(_loading
                      ? tr('Loading recommendations…')
                      : _failed
                          ? tr('Retry recommendations')
                          : tr('Explore more')),
                  onFocusChange: (has) {
                    if (has) {
                      if (widget.entryNode.context case final ctx?) {
                        Scrollable.ensureVisible(ctx, alignment: .2);
                      }
                    }
                  },
                  onPressed: () {
                    if (_failed) {
                      setState(() => _loading = true);
                      _load();
                    } else if (_rows.isNotEmpty) {
                      _focus(_rows.first, 0);
                    }
                  })),
          if (_opening) const LinearProgressIndicator(),
          if (key.isEmpty)
            TextButton.icon(
                icon: const Icon(Icons.movie_outlined),
                label: Text(
                    tr('Add your TMDB key for collections and cast credits')),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TmdbSettingsScreen()));
                  if (current) {
                    setState(() => _loading = true);
                    await _load();
                    widget.entryNode.requestFocus();
                  }
                }),
          if (_data.collection.isNotEmpty)
            _row(
                'collection',
                _data.collectionName ?? tr('Collection'),
                _data.collection.length,
                (i) => _titleCard('collection', i, _data.collection[i])),
          if (related.isNotEmpty)
            _row(
                'related',
                _data.related.isEmpty
                    ? tr('Explore this genre')
                    : tr('More like this'),
                related.length,
                (i) => _titleCard('related', i, related[i])),
          if (_data.cast.isNotEmpty)
            _row('cast', tr('Cast and credits'), _data.cast.length, (i) {
              final person = _data.cast[i];
              return _remoteCard(PosterCard(
                  focusNode: node('cast', i),
                  title: person.name,
                  imageUrl: person.image,
                  sourceLabel: person.role,
                  onTap: () async {
                    await _person(person);
                    if (current) _focus('cast', i);
                  },
                  onFocusGained: () => _reveal('cast', i)));
            }),
          if (key.isNotEmpty)
            const Text('Metadata provided by TMDB.',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]));
  }
}

class _ArchiveCreditsScreen extends StatefulWidget {
  const _ArchiveCreditsScreen(
      {required this.name, required this.load, required this.open});
  final String name;
  final Future<List<ArchiveMeta>> Function() load;
  final Future<void> Function(ArchiveMeta) open;
  @override
  State<_ArchiveCreditsScreen> createState() => _ArchiveCreditsScreenState();
}

class _ArchiveCreditsScreenState extends State<_ArchiveCreditsScreen> {
  final _nodes = <int, FocusNode>{};
  bool _focused = false;
  late final Future<List<ArchiveMeta>> _future = widget.load();
  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<List<ArchiveMeta>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? const <ArchiveMeta>[];
            if (items.isEmpty) {
              return Center(
                  child: Text(snap.hasError
                      ? tr('Could not load credits.')
                      : tr('No credits found.')));
            }
            return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisExtent: PosterCard.height + 16,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final node = _nodes.putIfAbsent(
                      i, () => FocusNode(debugLabel: 'cast-credit'));
                  if (!_focused && i == 0) {
                    _focused = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) node.requestFocus();
                    });
                  }
                  return _remoteCard(PosterCard(
                      focusNode: node,
                      title: items[i].name,
                      imageUrl: items[i].posterUrl,
                      rating: items[i].year,
                      onTap: () async {
                        await widget.open(items[i]);
                        if (mounted) node.requestFocus();
                      },
                      onFocusGained: () {
                        if (node.context case final c?) {
                          Scrollable.ensureVisible(c);
                        }
                      }));
                });
          }));
}
