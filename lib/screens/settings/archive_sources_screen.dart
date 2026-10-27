import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/archive_models.dart';
import '../../services/addon_import.dart';
import '../../services/addon_service.dart';
import '../../services/archive_api_service.dart';
import '../../services/app_preferences.dart';
import '../../services/archive_service.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/storage_service.dart';
import '../../utils/refined_finish.dart';
import '../../widgets/hold_to_activate.dart';
import '../../widgets/phone_pair_panel.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'media_server_screen.dart';
import 'stremio_import_screen.dart';
import 'trackers_screen.dart';

/// Settings > Archive sources: the servers the Archive tab browses. Any
/// source following the catalog/stream add-on schema works (see
/// [ArchiveApiService]); adding one checks its manifest first. Hold OK on
/// a source's enable control to remove it. Shared by Settings and the Hub rail.
class ArchiveSourcesScreen extends StatefulWidget {
  const ArchiveSourcesScreen({super.key});

  @override
  State<ArchiveSourcesScreen> createState() => _ArchiveSourcesScreenState();
}

class _ArchiveSourcesScreenState extends State<ArchiveSourcesScreen> {
  final _link = TextEditingController();
  final _linkFocus = FocusNode(debugLabel: 'source-link');
  final _addFocus = FocusNode(debugLabel: 'source-add');
  final _backFocus = FocusNode(debugLabel: 'source-back');
  final _nodes = <String, FocusNode>{};
  // A band is a visible grid row; each cell contains its vertical controls.
  // All cells stay mounted so off-screen D-pad targets always have a context.
  final _bands = <List<List<FocusNode>>>[];
  bool _adding = false;

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: id));

  void _reveal(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.hasFocus || node.context == null) return;
      final viewport =
          Scrollable.maybeOf(node.context!)?.context.findRenderObject();
      var target = node.context!;
      // Entering a card should reveal its header and all controls together.
      // Oversized accessibility cards still reveal only the focused control.
      if (viewport is RenderBox) {
        node.context!.visitAncestorElements((element) {
          if (element.widget is! _SourceCard) return true;
          final box = element.findRenderObject();
          if (box is RenderBox && box.size.height <= viewport.size.height) {
            target = element;
          }
          return false;
        });
      }
      final targetBox = target.findRenderObject();
      final top = targetBox is RenderBox
          ? targetBox.localToGlobal(Offset.zero).dy
          : node.rect.top;
      final above =
          viewport is RenderBox && top < viewport.localToGlobal(Offset.zero).dy;
      Scrollable.ensureVisible(target,
          duration: Duration.zero,
          alignmentPolicy: above
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    });
  }

  void _focus(FocusNode node) {
    node.requestFocus();
    _reveal(node);
  }

  void _move(TraversalDirection direction) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (_linkFocus.hasFocus) {
      if (direction == TraversalDirection.down ||
          direction == TraversalDirection.right) {
        _focus(_addFocus);
      } else if (direction == TraversalDirection.up) {
        _focus(_backFocus);
      }
      return;
    }
    final current = FocusManager.instance.primaryFocus;
    for (var row = 0; row < _bands.length; row++) {
      final band = _bands[row];
      for (var column = 0; column < band.length; column++) {
        final controls = band[column];
        final action = controls.indexWhere((n) => n == current || n.hasFocus);
        if (action < 0) continue;
        final horizontal = direction == TraversalDirection.left ||
            direction == TraversalDirection.right;
        final forward = direction == TraversalDirection.down ||
            direction == TraversalDirection.right;
        final step = forward ? 1 : -1;
        if (horizontal) {
          final next = column + step;
          if (next >= 0 && next < band.length) {
            final cell = band[next];
            _focus(cell[action.clamp(0, cell.length - 1)]);
          }
        } else if (action + step >= 0 && action + step < controls.length) {
          _focus(controls[action + step]);
        } else if (row + step >= 0 && row + step < _bands.length) {
          final nextBand = _bands[row + step];
          // Preserve the visual column, including between header buttons and
          // source cards, and clamp partial last rows to their last card.
          final x = current!.rect.center.dx;
          final nextCell = nextBand.reduce((a, b) =>
              (a.first.rect.center.dx - x).abs() <=
                      (b.first.rect.center.dx - x).abs()
                  ? a
                  : b);
          _focus(forward ? nextCell.first : nextCell.last);
        } else if (!forward) {
          _focus(_backFocus);
        }
        return;
      }
    }
    // Down/Right from the app-bar Back button enters the page again.
    if (direction == TraversalDirection.down ||
        direction == TraversalDirection.right) {
      _focus(_linkFocus);
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_escapeLinkField);
    // TV: start on the link field (keyboard only on OK, see
    // TvTextFieldGate) instead of nothing focused.
    if (context.read<AppPreferences>().isTelevision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _linkFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_escapeLinkField);
    _link.dispose();
    _linkFocus.dispose();
    _addFocus.dispose();
    _backFocus.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Up/Down out of the link field (EditableText keeps the arrow keys —
  /// same fix as AddonsScreen._escapeLinkField).
  bool _escapeLinkField(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (!_linkFocus.hasFocus) return false;
    if (!context.read<AppPreferences>().isTelevision ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focus(_addFocus);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focus(_backFocus);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _focus(_addFocus);
      return true;
    }
    return false;
  }

  Future<void> _viewSourceUrl(ArchiveSource source) async {
    final url = source.server == null ? source.manifestUrl : source.baseUrl;
    final copied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Source URL')),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: SelectableText(url)),
        ),
        actions: [
          TextButton.icon(
            autofocus: true,
            icon: const Icon(Icons.copy),
            label: Text(tr('Copy URL')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
    if (mounted && copied == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('URL copied'))));
    }
  }

  Future<void> _remove(ArchiveSource source) async {
    final service = context.read<ArchiveService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
          child: AlertDialog(
        title: Text(tr('Remove {name}?', {'name': source.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Remove')),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancel')),
          ),
        ],
      )),
    );
    if (ok != true) return;
    final sources = service.sources;
    final index = sources.indexWhere((s) => s.key == source.key);
    final remaining = sources.where((s) => s.key != source.key).toList();
    await service.removeSource(source);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus(remaining.isEmpty
          ? _linkFocus
          : _node(
              'source-${remaining[index.clamp(0, remaining.length - 1)].key}-enabled'));
    });
  }

  Future<void> _add() async {
    if (_adding) return;
    final url = _link.text.trim();
    if (url.isEmpty) return;
    // Several links pasted at once (from Nuvio, a notes file…): all of them.
    final links = AddonImporter.linksIn(url);
    if (links.length > 1) return _addMany(links);
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ArchiveService>();
    final storage = context.read<StorageService>();
    setState(() => _adding = true);
    String? error;
    ArchiveSource? added;
    try {
      added = await service.addSource(url);
    } on StateError {
      error = tr('That source is already in the list.');
    } on ArchiveApiException {
      // Not movies/shows: a subtitles-only add-on (OpenSubtitles v3...) goes
      // to Settings > Add-ons, like in a multi-link paste (_addMany).
      final result = await AddonImporter(service, AddonService(storage))
          .importLinks([url]);
      if (result.subtitles.isNotEmpty || result.alreadyThere.isNotEmpty) {
        if (!mounted) return;
        setState(() => _adding = false);
        _link.clear();
        messenger
            .showSnackBar(SnackBar(content: Text(addonImportSummary(result))));
        return;
      }
      error = tr(
          'That link isn\'t a Media Hub source (it needs movie or series streams).');
    } catch (_) {
      error = tr("Couldn't reach that link.");
    }
    if (!mounted) return;
    setState(() => _adding = false);
    if (error != null) {
      messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red.shade900));
      return;
    }
    _link.clear();
    messenger.showSnackBar(
        SnackBar(content: Text(tr('{name} added.', {'name': added!.name}))));
  }

  Future<void> _addMany(List<String> links) async {
    final importer = AddonImporter(context.read<ArchiveService>(),
        AddonService(context.read<StorageService>()));
    setState(() => _adding = true);
    final result = await importer.importLinks(links);
    if (!mounted) return;
    setState(() => _adding = false);
    _link.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('{n} links checked', {'n': result.total})),
        content: SingleChildScrollView(child: Text(addonImportSummary(result))),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('OK')),
          ),
        ],
      ),
    );
    if (mounted) _addFocus.requestFocus();
  }

  Future<void> _clearAll() async {
    final service = context.read<ArchiveService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
          child: AlertDialog(
        title: Text(tr('Clear Media Hub?')),
        content: Text(tr(
            'Removes every Media Hub source and its saved catalog from this device.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Clear')),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancel')),
          ),
        ],
      )),
    );
    if (ok != true) return;
    await service.clearAll();
    if (!mounted) return;
    _focus(_linkFocus);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('Media Hub cleared.'))));
  }

  /// "From my phone": the Add Playlist QR flow, link kind — the phone
  /// pastes the long manifest URL, it lands in the field here to check.
  Future<void> _fromPhone() async {
    final link = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _PhoneLinkScreen()));
    if (link == null || !mounted) return;
    _link.text = link;
    _addFocus.requestFocus();
  }

  String _summary(ArchiveSource s) {
    if (s.streamOnly) return tr('Catalogs from Cinemeta');
    final movies = s.catalogs
        .where((c) => c.type == ArchiveType.movie && c.wireType == null)
        .length;
    final shows = s.catalogs
        .where((c) => c.type == ArchiveType.series && c.wireType == null)
        .length;
    final other = s.catalogs.where((c) => c.wireType != null).length;
    return [
      if (movies > 0) tr('{n} movie catalogs', {'n': movies}),
      if (shows > 0) tr('{n} TV show catalogs', {'n': shows}),
      if (other > 0) tr('{n} other catalogs', {'n': other}),
    ].join(' · ');
  }

  List<FocusNode> _sourceNodes(ArchiveSource source) => [
        _node('source-${source.key}-enabled'),
        if (source.tracker == null) _node('source-${source.key}-url'),
        if (source.server == null && source.tracker == null)
          _node('source-${source.key}-other'),
      ];

  Widget _sourceCard(ArchiveSource source, ArchiveService service) {
    final nodes = _sourceNodes(source);
    final controlId = 'source-${source.key}';
    final catalogOnly = source.listOnly || source.tracker != null;
    final role = source.server != null
        ? tr('Media server')
        : source.tracker != null
            ? tr('Tracker lists')
            : source.listOnly
                ? tr('Catalogs only')
                : source.streamOnly
                    ? tr('Streams only')
                    : tr('Catalogs + streams');
    return _SourceCard(
      key: ValueKey('source-card-${source.key}'),
      nodes: nodes,
      icon: source.server != null
          ? Icons.dns_outlined
          : catalogOnly
              ? Icons.video_library_outlined
              : Icons.play_circle_outline,
      name: source.name,
      role: role,
      summary: _summary(source),
      children: [
        HoldToActivate(
          onTap: () => service.setEnabled(source, !source.enabled),
          onHold: () => _remove(source),
          child: _SourceControl(
            id: '$controlId-enabled',
            node: nodes.first,
            label: tr('Enabled'),
            value: source.enabled,
            onTap: () => service.setEnabled(source, !source.enabled),
            onFocus: () => _reveal(nodes.first),
          ),
        ),
        if (source.tracker == null)
          _SourceControl(
            id: '$controlId-url',
            node: nodes[1],
            label: tr('View source URL'),
            icon: Icons.link,
            onTap: () => _viewSourceUrl(source),
            onFocus: () => _reveal(nodes[1]),
          ),
        if (source.server == null && source.tracker == null)
          _SourceControl(
            id: '$controlId-other',
            node: nodes.last,
            label: tr('Show under Other'),
            value: source.underOther,
            onTap: () => service.setUnderOther(source, !source.underOther),
            onFocus: () => _reveal(nodes.last),
          ),
      ],
    );
  }

  /// Eager rows keep every focus target attached, unlike a lazy GridView.
  /// IntrinsicHeight matches each row's card heights without clipping large text.
  Widget _grid(
      List<Widget> cards, List<List<FocusNode>> controls, int columns) {
    final rows = <Widget>[];
    for (var start = 0; start < cards.length; start += columns) {
      final end = (start + columns).clamp(0, cards.length);
      _bands.add(controls.sublist(start, end));
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) const SizedBox(width: 16),
                Expanded(child: i < end ? cards[i] : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final sources = service.sources;
    final playback =
        sources.where((s) => !s.listOnly && s.tracker == null).toList();
    final catalogs =
        sources.where((s) => s.listOnly || s.tracker != null).toList();
    final cinemetaNode = _node('source-cinemeta');
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        for (final entry in {
          LogicalKeyboardKey.arrowUp: TraversalDirection.up,
          LogicalKeyboardKey.arrowDown: TraversalDirection.down,
          LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
          LogicalKeyboardKey.arrowRight: TraversalDirection.right,
        }.entries)
          SingleActivator(entry.key): () => _move(entry.value),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: SettingsScaffold(
        backFocusNode: _backFocus,
        title: tr('Media Hub sources'),
        body: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth - 40;
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns =
              ((width + 16) / (260 * scale + 16)).floor().clamp(1, 4);
          final connectorColumns =
              ((width + 16) / (210 * scale + 16)).floor().clamp(1, 5);
          _bands.clear();
          _bands.add([
            [_linkFocus]
          ]);
          final connectors = <(FocusNode, IconData, String, VoidCallback)>[
            (_addFocus, Icons.add, tr('Add'), _add),
            (
              _node('source-phone'),
              Icons.qr_code_2,
              tr('From phone'),
              _fromPhone
            ),
            (
              _node('source-import'),
              Icons.move_down,
              tr('Import from Stremio'),
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StremioImportScreen()))
            ),
            (
              _node('source-server'),
              Icons.dns_outlined,
              tr('Connect Jellyfin / Emby'),
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MediaServerScreen()))
            ),
            (
              _node('source-trackers'),
              Icons.playlist_add_check,
              tr('Trakt & Simkl'),
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrackersScreen()))
            ),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(tr('Add a source')),
                const SizedBox(height: 8),
                TvTextFieldGate(
                  focusNode: _linkFocus,
                  builder: (context, readOnly) => TextField(
                    controller: _link,
                    focusNode: _linkFocus,
                    readOnly: readOnly,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _focus(_addFocus);
                      _add();
                    },
                    decoration: InputDecoration(
                      labelText: tr('Source link (ends with manifest.json)'),
                      helperText: tr('Several links at once work too.'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _grid([
                  for (final (node, icon, label, action) in connectors)
                    OutlinedButton.icon(
                      focusNode: node,
                      onFocusChange: (focused) {
                        if (focused) _reveal(node);
                      },
                      // Keep Add attached and focusable during a request.
                      onPressed: action,
                      icon: node == _addFocus && _adding
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(icon, size: 20),
                      label: Text(label, textAlign: TextAlign.center),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14)),
                    ),
                ], [
                  for (final c in connectors) [c.$1]
                ], connectorColumns),
                const SizedBox(height: 8),
                SectionLabel(tr('Playback sources')),
                Text(tr('These sources provide the video when you press Play.'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                if (playback.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(tr('No playback sources yet.')),
                  ),
                _grid([
                  for (final source in playback) _sourceCard(source, service),
                ], [
                  for (final source in playback) _sourceNodes(source)
                ], columns),
                SectionLabel(tr('Catalogs & lists')),
                Text(
                    tr('Discover titles here; playback comes from your sources above.'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _grid([
                  _SourceCard(
                    key: const ValueKey('source-card-cinemeta'),
                    nodes: [cinemetaNode],
                    icon: Icons.auto_awesome_outlined,
                    name: ArchiveCatalogProvider.name,
                    role: tr('Catalogs only'),
                    summary: tr('Popular · New · Featured'),
                    children: [
                      _SourceControl(
                        id: 'source-cinemeta',
                        node: cinemetaNode,
                        label: tr('Show Cinemeta catalog'),
                        value: service.showCinemetaCatalog,
                        onTap: () => service.setShowCinemetaCatalog(
                            !service.showCinemetaCatalog),
                        onFocus: () => _reveal(cinemetaNode),
                      ),
                    ],
                  ),
                  for (final source in catalogs) _sourceCard(source, service),
                ], [
                  [cinemetaNode],
                  for (final source in catalogs) _sourceNodes(source),
                ], columns),
                Text(tr('Posters and episode details may still use Cinemeta when this is off.'),
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text(tr('Hold OK on Enabled to remove a source.'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Text(
                    tr('Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                Text(tr('Refresh Media Hub after changing Other.'),
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                if (sources.isNotEmpty) ...[
                  const Divider(height: 32),
                  _grid([
                    OutlinedButton.icon(
                      focusNode: _node('source-clear'),
                      onFocusChange: (focused) {
                        if (focused) _reveal(_node('source-clear'));
                      },
                      onPressed: _clearAll,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(tr('Clear Media Hub')),
                    ),
                  ], [
                    [_node('source-clear')]
                  ], columns),
                ],
                const SizedBox(height: 8),
                Text(
                  tr('VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.'),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    super.key,
    required this.nodes,
    required this.icon,
    required this.name,
    required this.role,
    required this.summary,
    required this.children,
  });

  final List<FocusNode> nodes;
  final IconData icon;
  final String name;
  final String role;
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge(nodes),
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final focused = nodes.any((n) => n.hasFocus);
          final polished = RefinedFinish.of(context);
          final radius = BorderRadius.circular(16);
          final ink = Color.alphaBlend(
              scheme.primary.withValues(
                  alpha: focused
                      ? 0.20
                      : polished
                          ? 0.10
                          : 0.045),
              const Color(0xFF060909));
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF060909),
              borderRadius: radius,
              border: Border.all(
                  color: scheme.primary.withValues(
                      alpha: focused
                          ? 1
                          : polished
                              ? 0.40
                              : 0.20),
                  width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      scheme.primary.withValues(alpha: polished ? 0.16 : 0.03),
                      ink),
                  ink,
                  const Color(0xFF050707),
                  Color.alphaBlend(
                      scheme.secondary
                          .withValues(alpha: polished ? 0.07 : 0.02),
                      const Color(0xFF080A0C)),
                ],
                stops: const [0, 0.22, 0.68, 1],
              ),
              boxShadow: [
                if (focused)
                  BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.24),
                      blurRadius: 18),
                if (polished)
                  const BoxShadow(
                      color: Colors.black87,
                      blurRadius: 16,
                      offset: Offset(0, 7)),
              ],
            ),
            // Preserve this palette-tinted dark glass instead of replacing it
            // with the shared neutral grey fill; reuse the same painted bevel.
            foregroundDecoration:
                RefinedFinish.artworkRim(context, radius, focused: focused),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: polished ? 0.14 : 0.07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.30)),
                    ),
                    child: Icon(icon, size: 18, color: scheme.primary),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.24))),
                    child: Text(role,
                        style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 5),
                ...children,
                const Spacer(),
              ],
            ),
          );
        },
      );
}

/// Exactly one focus stop per control. The switch is visual; the whole row
/// toggles it, including OK and pointer input, without a nested switch stop.
class _SourceControl extends StatelessWidget {
  const _SourceControl({
    required this.id,
    required this.node,
    required this.label,
    required this.onTap,
    required this.onFocus,
    this.icon,
    this.value,
  });

  final FocusNode node;
  final String id;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final IconData? icon;
  final bool? value;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: node,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final compact = context.read<AppPreferences>().isTelevision ||
              MediaQuery.sizeOf(context).width >= 700;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(9),
              child: Semantics(
                toggled: value,
                child: InkWell(
                  // FocusNode.debugLabel is always null in a release APK.
                  key: ValueKey(id),
                  focusNode: node,
                  focusColor: Colors.transparent,
                  hoverColor: scheme.primary.withValues(alpha: 0.06),
                  onTap: onTap,
                  onFocusChange: (focused) {
                    if (focused) onFocus();
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    constraints: BoxConstraints(minHeight: compact ? 28 : 44),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                          scheme.primary
                              .withValues(alpha: node.hasFocus ? 0.18 : 0.035),
                          const Color(0xFF050707)),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: node.hasFocus
                              ? scheme.primary
                              : Colors.transparent,
                          width: 2),
                    ),
                    child: Row(children: [
                      if (icon != null) ...[
                        Icon(icon, size: 15, color: scheme.primary),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                          child: Text(label,
                              style: const TextStyle(fontSize: 12))),
                      if (value != null)
                        ExcludeFocus(
                          child: ExcludeSemantics(
                            child: IgnorePointer(
                              child: SizedBox(
                                width: compact ? 32 : 46,
                                height: compact ? 20 : 30,
                                child: FittedBox(
                                  child: Switch(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      value: value!,
                                      activeTrackColor: scheme.primary,
                                      activeThumbColor: scheme.onPrimary,
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.12),
                                      onChanged: (_) => onTap()),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// The QR page behind "From my phone"; pops with the link the phone sent.
class _PhoneLinkScreen extends StatefulWidget {
  const _PhoneLinkScreen();

  @override
  State<_PhoneLinkScreen> createState() => _PhoneLinkScreenState();
}

class _PhoneLinkScreenState extends State<_PhoneLinkScreen> {
  final _toggleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The panel's only focusable control; without it the remote has
    // nothing focused (CLAUDE.md §10).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toggleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: tr('Media Hub sources'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: PhonePairPanel(
          kind: PairingKind.link,
          toggleFocusNode: _toggleFocus,
          onResult: (r) {
            if (mounted) Navigator.of(context).pop(r.link);
          },
        ),
      ),
    );
  }
}
