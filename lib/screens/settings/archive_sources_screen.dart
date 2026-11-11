import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/archive_models.dart';
import '../../models/hub_collection.dart';
import '../../services/addon_import.dart';
import '../../services/addon_service.dart';
import '../../services/app_preferences.dart';
import '../../services/archive_api_service.dart';
import '../../services/archive_service.dart';
import '../../services/hub_remote.dart';
import '../../services/storage_service.dart';
import '../../services/vesper_ai/mcp_bridge.dart';
import '../../widgets/archive_row_settings.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/hold_to_activate.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart' show CompactMenus;
import '../../widgets/tv_text_field_gate.dart';
import 'addons_screen.dart';
import 'hub_collections_pane.dart';
import 'media_server_screen.dart';
import 'phone_link_screen.dart';
import 'settings_catalog.dart' show SettingsCategory;
import 'settings_menu_screen.dart'
    show SettingsHelpStrip, SettingsPaneHeader, SettingsSectionTitle;
import 'stremio_import_screen.dart';
import 'trackers_screen.dart';

/// What the rail picks: a way to add, a filter of the list, or a tool.
enum _Pane {
  add,
  all,
  streams,
  catalogs,
  servers,
  live,
  subtitles,
  collections,
  phone,
  rows,
  advanced
}

/// Settings > Media Hub sources (owner, 2026-11-11: like Stremio's and
/// Nuvio's add-on pages, in the glass of the new Settings). Left, a rail:
/// Add a source, the filters with their counts, Manage from phone,
/// Customize Media Hub and Advanced. Right, one row per add-on ([HubEntry]:
/// sources, the built-in Cinemeta catalog, subtitle add-ons) with its logo,
/// version, description and what it gives. OK on a row turns it on or off
/// for this profile; Right (or holding OK) goes to its options: Show under
/// Other, TV add-on, its link and Remove. The rules the page used to print
/// at the bottom follow the focused row in the help line.
///
/// Same remote pattern as Settings: each column its own [FocusScope], plain
/// Up/Down inside, only Left/Right between them explicit (CLAUDE.md §10).
/// Every row is built (no lazy list) so the remote reaches the last one.
/// A phone gets the filters as chips over the list; tap a row for its
/// options, the switch to turn it on or off.
class ArchiveSourcesScreen extends StatefulWidget {
  const ArchiveSourcesScreen({super.key});

  @override
  State<ArchiveSourcesScreen> createState() => _ArchiveSourcesScreenState();
}

class _ArchiveSourcesScreenState extends State<ArchiveSourcesScreen> {
  final _railScope = FocusScopeNode(debugLabel: 'sources-rail');
  final _paneScope = FocusScopeNode(debugLabel: 'sources-pane');
  final _railNodes = <_Pane, FocusNode>{};
  final _rowNodes = <String, FocusNode>{};
  final _moreNodes = <String, FocusNode>{};
  final _toolNodes = <String, FocusNode>{};
  final _help = ValueNotifier<String?>(null);
  final _addPane = GlobalKey<_AddSourceState>();
  _Pane _selected = _Pane.all;
  bool _inPane = false;

  /// Manage from phone's page, once the link started.
  Future<String?>? _hubLink;

  @override
  void initState() {
    super.initState();
    _paneScope.addListener(_onPaneFocus);
  }

  @override
  void dispose() {
    _paneScope.removeListener(_onPaneFocus);
    _railScope.dispose();
    _paneScope.dispose();
    for (final n in [
      ..._railNodes.values,
      ..._rowNodes.values,
      ..._moreNodes.values,
      ..._toolNodes.values,
    ]) {
      n.dispose();
    }
    _help.dispose();
    super.dispose();
  }

  void _onPaneFocus() {
    if (_paneScope.hasFocus != _inPane) {
      setState(() => _inPane = _paneScope.hasFocus);
      if (!_inPane) _help.value = null;
    }
  }

  FocusNode _railNode(_Pane p) =>
      _railNodes.putIfAbsent(p, () => FocusNode(debugLabel: 'sources-${p.name}'));
  FocusNode _rowNode(String key) =>
      _rowNodes.putIfAbsent(key, () => FocusNode(debugLabel: 'source-row'));
  FocusNode _moreNode(String key) =>
      _moreNodes.putIfAbsent(key, () => FocusNode(debugLabel: 'source-more'));
  FocusNode _toolNode(String id) =>
      _toolNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'sources-$id'));

  List<HubEntry> _entries(ArchiveService service) => HubEntry.all(
      service, AddonService(context.read<StorageService>()));

  static bool _inFilter(_Pane p, HubEntry e) => switch (p) {
        _Pane.all => true,
        _Pane.streams => e.tags.contains('streams'),
        _Pane.catalogs => e.kind == HubKind.catalogs ||
            e.kind == HubKind.lists ||
            (e.tags.contains('catalogs') && e.kind != HubKind.live),
        _Pane.servers => e.kind == HubKind.server,
        _Pane.live => e.kind == HubKind.live,
        _Pane.subtitles => e.kind == HubKind.subtitles,
        _ => false,
      };

  static bool _isFilter(_Pane p) => switch (p) {
        _Pane.all ||
        _Pane.streams ||
        _Pane.catalogs ||
        _Pane.servers ||
        _Pane.live ||
        _Pane.subtitles =>
          true,
        _ => false,
      };

  /// The focus target Right from the rail lands on.
  void _enterPane() {
    final first = _paneScope.traversalDescendants
        .where((n) => n.canRequestFocus && !n.skipTraversal)
        .firstOrNull;
    first?.requestFocus();
  }

  void _backToRail() => _railNode(_selected).requestFocus();

  /// Left goes back to the rail, except inside the link's typed text.
  KeyEventResult _paneKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (_addPane.currentState?.keepsLeft ?? false) {
      return KeyEventResult.ignored;
    }
    _backToRail();
    return KeyEventResult.handled;
  }

  Future<void> _toggle(HubEntry e) async {
    final storage = context.read<StorageService>();
    await HubRemote.setEntryEnabled(
        context.read<ArchiveService>(), AddonService(storage), e, !e.enabled);
    // Subtitle add-ons aren't in ArchiveService: show their new state too.
    if (mounted) setState(() {});
  }

  Future<void> _openOptions(HubEntry e) async {
    await openSettingsPage(context, (_) => _SourceOptions(entryKey: e.key),
        floating: true);
    if (!mounted) return;
    setState(() {});
    // Removed: land on its neighbour instead of nowhere.
    final service = context.read<ArchiveService>();
    if (_entries(service).every((x) => x.key != e.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_paneScope.hasFocus) _enterPane();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final entries = _entries(service);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return PopScope(
      canPop: narrow || !_inPane,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToRail();
      },
      child: SettingsScaffold(
        title: tr('Media Hub sources'),
        panel: false,
        body: narrow
            ? _phone(entries)
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: SettingsScaffold.compact ? 250 : 280,
                        child: GlassPanel(child: _rail(entries))),
                    const SizedBox(width: 12),
                    Expanded(child: GlassPanel(child: _pane(entries))),
                  ],
                ),
              ),
      ),
    );
  }

  // --------------------------------------------------------------- the rail

  List<(_Pane, IconData, String)> _railItems(List<HubEntry> entries) {
    int count(_Pane p) => entries.where((e) => _inFilter(p, e)).length;
    return [
      (_Pane.add, Icons.add_circle_outline, tr('Add a source')),
      (_Pane.all, Icons.apps, tr('All')),
      (_Pane.streams, Icons.play_circle_outline, tr('Streams')),
      (_Pane.catalogs, Icons.video_library_outlined, tr('Catalogs & lists')),
      if (count(_Pane.servers) > 0)
        (_Pane.servers, Icons.dns_outlined, tr('Media servers')),
      if (count(_Pane.live) > 0) (_Pane.live, Icons.live_tv, tr('Live TV')),
      (_Pane.subtitles, Icons.subtitles_outlined, tr('Subtitles')),
      (_Pane.collections, Icons.dashboard_customize_outlined,
          tr('Collections')),
      (_Pane.phone, Icons.phonelink, tr('Manage from phone')),
      (_Pane.rows, Icons.view_agenda_outlined, tr('Customize Media Hub')),
      (_Pane.advanced, Icons.tune, tr('Advanced')),
    ];
  }

  Widget _rail(List<HubEntry> entries) {
    final items = _railItems(entries);
    // A filter that emptied (its last server removed): back to All.
    if (!items.any((i) => i.$1 == _selected)) _selected = _Pane.all;
    const divider =
        Divider(height: 13, indent: 10, endIndent: 10, color: Colors.white12);
    return FocusScope(
      node: _railScope,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): _enterPane,
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (p, icon, title) in items) ...[
                if (p == _Pane.all || p == _Pane.collections) divider,
                _railEntry(p, icon, title,
                    _isFilter(p) ? entries.where((e) => _inFilter(p, e)).length : null),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Focus follows the selector: the pane shows the focused entry (the
  /// wrapper is not itself a focus target, CLAUDE.md §10).
  Widget _railEntry(_Pane p, IconData icon, String title, int? count) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) {
          if (f && _selected != p) setState(() => _selected = p);
        },
        child: SettingRow(
          key: ValueKey('sources-rail-${p.name}'),
          focusNode: _railNode(p),
          autofocus: p == _Pane.all,
          icon: icon,
          title: title,
          selected: p == _selected,
          trailing: count != null
              ? SettingValue(text: '$count', icon: null)
              : p == _selected
                  ? Icon(Icons.chevron_right,
                      size: 20, color: Theme.of(context).colorScheme.primary)
                  : null,
          onTap: () {
            setState(() => _selected = p);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _enterPane();
            });
          },
        ),
      );

  // --------------------------------------------------------------- the pane

  Widget _pane(List<HubEntry> entries) {
    final Widget body = switch (_selected) {
      _Pane.add => _AddSource(
          key: _addPane,
          help: _help,
          onManageFromPhone: () {
            setState(() => _selected = _Pane.phone);
            _railNode(_Pane.phone).requestFocus();
          }),
      _Pane.collections => HubCollectionsPane(help: _help),
      _Pane.phone => _phonePane(),
      _Pane.rows => _rowsPane(),
      _Pane.advanced => _advancedPane(entries),
      _ => _listPane(entries),
    };
    return FocusScope(
      node: _paneScope,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _paneKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            SettingsHelpStrip(help: _help),
          ],
        ),
      ),
    );
  }

  SettingsCategory _header(IconData icon, String title, String description) =>
      SettingsCategory(
          id: 'sources',
          icon: icon,
          title: title,
          description: description,
          sections: const []);

  Widget _listPane(List<HubEntry> entries) {
    final item =
        _railItems(entries).firstWhere((i) => i.$1 == _selected);
    final shown = entries.where((e) => _inFilter(_selected, e)).toList();
    final on = shown.where((e) => e.enabled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsPaneHeader(
            category: _header(item.$2, item.$3,
                tr('{n} sources · {on} on', {'n': shown.length, 'on': on}))),
        Expanded(
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(tr('No sources here yet. Add one with Add a source.'),
                      style: const TextStyle(color: Colors.white70)))
              // Non-lazy on purpose: the remote reaches the last row.
              : SingleChildScrollView(
                  key: ValueKey(_selected),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in shown)
                        _SourceRow(
                          key: ValueKey('source-row-${e.key}'),
                          entry: e,
                          node: _rowNode(e.key),
                          moreNode: e.builtIn ? null : _moreNode(e.key),
                          help: _help,
                          onToggle: () => _toggle(e),
                          onOptions: () => _openOptions(e),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Manage from phone. The link starts on OK, never just because the
  /// remote passed over the rail entry.
  Widget _phonePane() {
    final scheme = Theme.of(context).colorScheme;
    if (_hubLink == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPaneHeader(
                category: _header(Icons.phonelink, tr('Manage from phone'),
                    tr('Add, remove, turn on or off and copy links from your phone.'))),
            SettingRow(
              key: const ValueKey('sources-phone-start'),
              focusNode: _toolNode('phone-start'),
              icon: Icons.qr_code_2,
              title: tr('Show the code'),
              subtitle: tr("Scan it with your phone's camera"),
              trailing: const SettingValue(),
              onFocusChange: (f) {
                if (f) {
                  _help.value = tr(
                      "Your phone gets this TV's list of sources: add, remove, turn on or off, copy a link. From any network.");
                }
              },
              onTap: () => setState(() {
                _hubLink = McpBridge.instance.startHubLink();
              }),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPaneHeader(
              category: _header(Icons.phonelink, tr('Manage from phone'),
                  tr('Add, remove, turn on or off and copy links from your phone.'))),
          FutureBuilder<String?>(
            future: _hubLink,
            builder: (context, snap) {
              final url = snap.data;
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (url == null) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(tr('Not available right now. Try again in a moment.'),
                      style: const TextStyle(color: Colors.white70)),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      key: const ValueKey('sources-phone-qr'),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: QrImageView(data: url, size: 200),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Scan with your phone\'s camera.'),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                              tr('Works from any network while VesperTV is open, for an hour after its last use. On and Under Other are for the profile in use here.'),
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 10),
                          Text(url.split('#').first,
                              style: TextStyle(color: scheme.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _rowsPane() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPaneHeader(
                category: _header(Icons.view_agenda_outlined,
                    tr('Customize Media Hub'),
                    tr('Hide a row without disabling its playback source.'))),
            for (final (type, label) in [
              (ArchiveType.movie, tr('Movies')),
              (ArchiveType.series, tr('TV Shows')),
            ])
              SettingRow(
                focusNode: _toolNode('rows-${type.name}'),
                icon: type == ArchiveType.movie
                    ? Icons.movie_outlined
                    : Icons.live_tv_outlined,
                title: label,
                subtitle: tr('Order, rename, pin or hide its rows'),
                trailing: const SettingValue(),
                onFocusChange: (f) {
                  if (f) {
                    _help.value = tr(
                        'The rows of the Media Hub tab. Hiding a row keeps its source.');
                  }
                },
                onTap: () => showArchiveRowSettings(context, type),
              ),
          ],
        ),
      );

  Widget _advancedPane(List<HubEntry> entries) {
    final service = context.read<ArchiveService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPaneHeader(
              category: _header(Icons.tune, tr('Advanced'),
                  tr('VesperTV ships no sources. The titles you open are requested from the source you added; nothing else is shared.'))),
          SettingRow(
            focusNode: _toolNode('refresh'),
            icon: Icons.refresh,
            title: tr('Refresh Media Hub'),
            subtitle: tr('Reads every add-on again: new catalogs, logos, versions'),
            onFocusChange: (f) {
              if (f) {
                _help.value =
                    tr('Refresh Media Hub after changing Other.');
              }
            },
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await service.refresh(force: true, manifests: true);
              messenger.showSnackBar(
                  SnackBar(content: Text(tr('Media Hub refreshed.'))));
            },
          ),
          if (entries.any((e) => e.source != null))
            SettingRow(
              focusNode: _toolNode('clear'),
              icon: Icons.delete_sweep_outlined,
              title: tr('Clear Media Hub'),
              subtitle: tr(
                  'Removes every Media Hub source and its saved catalog from this device.'),
              onFocusChange: (f) {
                if (f) _help.value = null;
              },
              onTap: _clearAll,
            ),
        ],
      ),
    );
  }

  Future<void> _clearAll() async {
    final service = context.read<ArchiveService>();
    final ok = await showGlassMenu<bool>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
          child: GlassMenuDialog(
        title: Text(tr('Clear Media Hub?')),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(tr(
              'Removes every Media Hub source and its saved catalog from this device.')),
        ),
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
    setState(() => _selected = _Pane.add);
    _railNode(_Pane.add).requestFocus();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('Media Hub cleared.'))));
  }

  // --------------------------------------------------------------- a phone

  /// The filters as chips over the list: tap a row for its options, the
  /// switch to turn it on or off.
  Widget _phone(List<HubEntry> entries) {
    final filters = _railItems(entries).where((i) => _isFilter(i.$1)).toList();
    if (!_isFilter(_selected)) _selected = _Pane.all;
    final shown = entries.where((e) => _inFilter(_selected, e)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SettingRow(
          icon: Icons.add_circle_outline,
          title: tr('Add a source'),
          subtitle: tr('A link, Stremio, a media server or Trakt / Simkl'),
          trailing: const SettingValue(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScaffold(
                  title: tr('Add a source'), body: const _AddSource()))),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final (p, _, title) in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                        '$title ${entries.where((e) => _inFilter(p, e)).length}'),
                    selected: p == _selected,
                    onSelected: (_) => setState(() => _selected = p),
                  ),
                ),
            ],
          ),
        ),
        for (final e in shown)
          _SourceRow(
            key: ValueKey('source-row-${e.key}'),
            entry: e,
            touch: true,
            onToggle: () => _toggle(e),
            onOptions: () => _openOptions(e),
          ),
        const SizedBox(height: 8),
        SettingRow(
          icon: Icons.dashboard_customize_outlined,
          title: tr('Collections'),
          subtitle: tr('Rows of tiles, like Nuvio'),
          trailing: const SettingValue(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScaffold(
                  title: tr('Collections'),
                  body: const HubCollectionsPane()))),
        ),
        for (final (type, label) in [
          (ArchiveType.movie, tr('Movies')),
          (ArchiveType.series, tr('TV Shows')),
        ])
          SettingRow(
            icon: Icons.view_agenda_outlined,
            title: '${tr('Customize Media Hub')} · $label',
            trailing: const SettingValue(),
            onTap: () => showArchiveRowSettings(context, type),
          ),
        if (entries.any((e) => e.source != null))
          SettingRow(
            icon: Icons.delete_sweep_outlined,
            title: tr('Clear Media Hub'),
            onTap: _clearAll,
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- one source

/// Translated names of [HubEntry.tags].
String _tagLabel(String tag) => switch (tag) {
      'streams' => tr('Streams'),
      'catalogs' => tr('Catalogs'),
      'movies' => tr('Movies'),
      'shows' => tr('TV Shows'),
      'live' => tr('Live TV'),
      'subtitles' => tr('Subtitles'),
      'server' => tr('Media server'),
      'lists' => tr('Lists'),
      'builtin' => tr('Built in'),
      'other' => tr('Under Other'),
      _ => tag,
    };

/// What its catalogs are, for the help line and the options panel.
String _catalogSummary(HubEntry e) {
  if (e.key == HubEntry.cinemetaKey) return tr('Popular · New · Featured');
  if (e.cinemetaCatalogs) return tr('Catalogs from Cinemeta');
  return [
    if (e.movieCatalogs > 0) tr('{n} movie catalogs', {'n': e.movieCatalogs}),
    if (e.showCatalogs > 0) tr('{n} TV show catalogs', {'n': e.showCatalogs}),
    if (e.otherCatalogs > 0) tr('{n} other catalogs', {'n': e.otherCatalogs}),
  ].join(' · ');
}

/// The focused row's explanation (the help line under the list).
String _entryHelp(HubEntry e) {
  final summary = _catalogSummary(e);
  final state = e.key == HubEntry.cinemetaKey
      ? tr('Posters and episode details may still use Cinemeta when this is off.')
      : e.kind == HubKind.subtitles
          ? (e.enabled
              ? tr('On. OK turns it off, Right for its options.')
              : tr('Off. OK turns it on, Right for its options.'))
          : (e.enabled
              ? tr('On for this profile. OK turns it off, Right for its options.')
              : tr('Off for this profile. OK turns it on, Right for its options.'));
  return [
    if (e.description.isNotEmpty) e.description,
    if (summary.isNotEmpty) summary,
    state,
  ].join(' · ');
}

/// The add-on's own logo, or an icon for what it is.
class _SourceLogo extends StatelessWidget {
  const _SourceLogo({required this.entry, this.size = 44});

  final HubEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Icon(
          switch (entry.kind) {
            _ when entry.key == HubEntry.cinemetaKey => Icons.auto_awesome_outlined,
            HubKind.server => Icons.dns_outlined,
            HubKind.lists => Icons.playlist_add_check,
            HubKind.live => Icons.live_tv,
            HubKind.subtitles => Icons.subtitles_outlined,
            HubKind.catalogs => Icons.video_library_outlined,
            HubKind.streams => Icons.play_circle_outline,
          },
          size: size * 0.55,
          color: scheme.primary),
    );
    final url = entry.logoUrl;
    if (url == null || !url.startsWith('http')) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Container(
        width: size,
        height: size,
        color: Colors.black,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          memCacheWidth: (size * 2).round(),
          errorWidget: (_, __, ___) => fallback,
          placeholder: (_, __) => fallback,
        ),
      ),
    );
  }
}

/// Its tags: what it gives.
class _Tags extends StatelessWidget {
  const _Tags({required this.entry});

  final HubEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(spacing: 5, runSpacing: 4, children: [
      for (final tag in entry.tags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: tag == 'builtin'
                    ? scheme.primary.withValues(alpha: 0.6)
                    : tag == 'other'
                        ? const Color(0xFFD98A6A)
                        : Colors.white24),
          ),
          child: Text(_tagLabel(tag),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: tag == 'builtin'
                      ? scheme.primary
                      : tag == 'other'
                          ? const Color(0xFFF0B49B)
                          : Colors.white70)),
        ),
    ]);
  }
}

/// One add-on: logo, name and version, its description, tags and switch.
/// OK (or a tap) turns it on or off; Right goes to its ⋯ button, holding OK
/// opens its options. [touch] (a phone): a tap opens the options and the
/// switch turns it on or off.
class _SourceRow extends StatefulWidget {
  const _SourceRow({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onOptions,
    this.node,
    this.moreNode,
    this.help,
    this.touch = false,
  });

  final HubEntry entry;
  final FocusNode? node;
  final FocusNode? moreNode;
  final ValueNotifier<String?>? help;
  final VoidCallback onToggle;
  final VoidCallback onOptions;
  final bool touch;

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  bool _focused = false;
  bool _moreFocused = false;

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    });
  }

  KeyEventResult _rowKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        widget.moreNode != null) {
      widget.moreNode!.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _moreKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.node?.requestFocus();
      return KeyEventResult.handled;
    }
    // Nothing further right: stay on it.
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    final compact = CompactMenus.of(context);
    final version = e.version == null || e.version!.isEmpty
        ? null
        : 'v${e.version!.replaceFirst(RegExp(r'^[vV]'), '')}';
    final dim = e.enabled ? 1.0 : 0.45;
    final content = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12, vertical: compact ? 6 : 8),
      child: Row(children: [
        Opacity(opacity: dim, child: _SourceLogo(entry: e, size: compact ? 38 : 44)),
        SizedBox(width: compact ? 12 : 14),
        Expanded(
          child: Opacity(
            opacity: dim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, children: [
                  Flexible(
                    child: Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: _focused ? scheme.primary : Colors.white)),
                  ),
                  if (version != null) ...[
                    const SizedBox(width: 8),
                    Text(version,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54)),
                  ],
                ]),
                if (e.description.isNotEmpty)
                  Text(e.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: compact ? 12 : 12.5,
                          color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                _Tags(entry: e),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        widget.touch
            ? GestureDetector(
                key: ValueKey('source-switch-${e.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggle,
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GlassSwitch(value: e.enabled)),
              )
            : GlassSwitch(value: e.enabled),
      ]),
    );
    final row = Container(
      decoration: GlassMenuSurface.rowDecoration(context,
          focused: _focused, radius: 12, quiet: true),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: widget.node,
          focusColor: Colors.transparent,
          hoverColor: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          onTap: widget.touch ? widget.onOptions : widget.onToggle,
          onFocusChange: (f) {
            setState(() => _focused = f);
            if (f) {
              widget.help?.value = _entryHelp(e);
              _reveal();
            }
          },
          child: content,
        ),
      ),
    );
    return Semantics(
      toggled: e.enabled,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
        child: Row(children: [
          Expanded(
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _rowKey,
              child: widget.touch
                  ? row
                  : HoldToActivate(
                      onTap: widget.onToggle,
                      onHold: widget.moreNode == null ? null : widget.onOptions,
                      child: row,
                    ),
            ),
          ),
          if (widget.moreNode != null) ...[
            const SizedBox(width: 8),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _moreKey,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('source-more-${e.key}'),
                  focusNode: widget.moreNode,
                  focusColor: Colors.transparent,
                  customBorder: const CircleBorder(),
                  onTap: widget.onOptions,
                  onFocusChange: (f) {
                    setState(() => _moreFocused = f);
                    if (f) {
                      widget.help?.value =
                          tr('Options for {name}: Show under Other, TV add-on, its link and Remove.',
                              {'name': e.name});
                    }
                  },
                  child: Container(
                    width: compact ? 36 : 42,
                    height: compact ? 36 : 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _moreFocused ? scheme.primary : Colors.white24,
                          width: 2),
                      boxShadow: _moreFocused
                          ? [
                              BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 12)
                            ]
                          : null,
                    ),
                    child: Icon(Icons.more_horiz,
                        size: compact ? 20 : 22,
                        color: _moreFocused ? scheme.primary : Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// -------------------------------------------------------- its options

/// A source's options: a glass panel over the list on a TV, a page on a
/// phone. Follows the source live (a switch flips in place).
class _SourceOptions extends StatefulWidget {
  const _SourceOptions({required this.entryKey});

  final String entryKey;

  @override
  State<_SourceOptions> createState() => _SourceOptionsState();
}

class _SourceOptionsState extends State<_SourceOptions> {
  bool _closing = false;

  Future<void> _set(HubEntry e, String field, bool value) async {
    final service = context.read<ArchiveService>();
    final storage = context.read<StorageService>();
    switch (field) {
      case 'enabled':
        await HubRemote.setEntryEnabled(
            service, AddonService(storage), e, value);
      case 'other':
        await service.setUnderOther(e.source!, value);
      case 'tv':
        await service.setLiveTv(e.source!, value);
    }
    if (mounted) setState(() {});
  }

  Future<void> _viewUrl(String url) async {
    final copied = await showGlassMenu<bool>(
      context: context,
      builder: (dialogContext) => GlassMenuDialog(
        title: Text(tr('Source URL')),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: 600,
            child: SingleChildScrollView(child: SelectableText(url)),
          ),
        ),
        actions: [
          TextButton.icon(
            autofocus: true,
            icon: const Icon(Icons.copy),
            label: Text(tr('Copy URL')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
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

  Future<void> _remove(HubEntry e) async {
    final service = context.read<ArchiveService>();
    final storage = context.read<StorageService>();
    final ok = await showGlassMenu<bool>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
          child: GlassMenuDialog(
        title: Text(tr('Remove {name}?', {'name': e.name})),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(e.kind == HubKind.subtitles
              ? tr('This removes it from this device.')
              : tr(
                  'This removes it for every profile on this device. To hide it for this profile only, turn off Enabled instead.')),
        ),
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
    if (ok != true || !mounted) return;
    _closing = true;
    await HubRemote.removeEntry(service, AddonService(storage), e);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final storage = context.read<StorageService>();
    final e = HubEntry.all(service, AddonService(storage))
        .where((x) => x.key == widget.entryKey)
        .firstOrNull;
    if (e == null) {
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      return const SizedBox.shrink();
    }
    final summary = _catalogSummary(e);
    final url = e.url;
    return SettingsScaffold(
      title: e.name,
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SourceLogo(entry: e, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.version != null || summary.isNotEmpty)
                        Text(
                            [
                              if (e.version != null)
                                'v${e.version!.replaceFirst(RegExp(r'^[vV]'), '')}',
                              if (summary.isNotEmpty) summary,
                            ].join(' · '),
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white60)),
                      if (e.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(e.description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                      const SizedBox(height: 6),
                      _Tags(entry: e),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SettingRow(
            autofocus: true,
            icon: Icons.power_settings_new,
            title: e.key == HubEntry.cinemetaKey
                ? tr('Show Cinemeta catalog')
                : tr('Enabled'),
            subtitle: e.kind == HubKind.subtitles
                ? tr('On this device')
                : tr('Just for this profile'),
            toggled: e.enabled,
            trailing: GlassSwitch(value: e.enabled),
            onTap: () => _set(e, 'enabled', !e.enabled),
          ),
          if (e.other != null)
            SettingRow(
              icon: Icons.filter_alt_outlined,
              title: tr('Show under Other'),
              subtitle: tr(
                  'Show under Other keeps a source behind the Other genre filter in Movies and TV Shows.'),
              subtitleMaxLines: 2,
              toggled: e.other,
              trailing: GlassSwitch(value: e.other!),
              onTap: () => _set(e, 'other', !e.other!),
            ),
          if (e.liveTv != null)
            SettingRow(
              icon: Icons.live_tv,
              title: tr('TV add-on'),
              subtitle: tr('Its channels in Media Hub > Live TV'),
              toggled: e.liveTv,
              trailing: GlassSwitch(value: e.liveTv!),
              onTap: () => _set(e, 'tv', !e.liveTv!),
            ),
          if (url != null)
            SettingRow(
              icon: Icons.link,
              title: tr('View source URL'),
              subtitle: tr('See and copy its link'),
              trailing: const SettingValue(),
              onTap: () => _viewUrl(url),
            ),
          if (e.removable)
            SettingRow(
              icon: Icons.delete_outline,
              title: tr('Remove'),
              subtitle: e.kind == HubKind.subtitles
                  ? tr('From this device')
                  : tr('For every profile on this device'),
              onTap: () => _remove(e),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- adding

/// Add a source: the link field (several links at once work too), then
/// every other way to add one.
class _AddSource extends StatefulWidget {
  const _AddSource({super.key, this.help, this.onManageFromPhone});

  final ValueNotifier<String?>? help;

  /// The TV's Manage from phone pane (not on a phone).
  final VoidCallback? onManageFromPhone;

  @override
  State<_AddSource> createState() => _AddSourceState();
}

class _AddSourceState extends State<_AddSource> {
  final _link = TextEditingController();
  final _linkFocus = FocusNode(debugLabel: 'source-link');
  final _addFocus = FocusNode(debugLabel: 'source-add');
  bool _adding = false;

  /// Left stays in the typed text until its start (a keyboard's Left).
  bool get keepsLeft =>
      _linkFocus.hasPrimaryFocus && _link.selection.baseOffset > 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_escapeLinkField);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_escapeLinkField);
    _link.dispose();
    _linkFocus.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  /// Down out of the link field (EditableText keeps the arrow keys — same
  /// fix as AddonsScreen._escapeLinkField).
  bool _escapeLinkField(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    if (!_linkFocus.hasFocus) return false;
    if (!context.read<AppPreferences>().isTelevision ||
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _addFocus.requestFocus();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) return true;
    return false;
  }

  void _say(String? text) => widget.help?.value = text;

  Future<void> _add() async {
    if (_adding) return;
    final url = _link.text.trim();
    if (url.isEmpty) {
      _linkFocus.requestFocus();
      return;
    }
    // Several links pasted at once (from Nuvio, a notes file…): all of them.
    final links = AddonImporter.linksIn(url);
    if (links.length > 1) return _addMany(links);
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<ArchiveService>();
    final storage = context.read<StorageService>();
    setState(() => _adding = true);
    // A Nuvio collections file (a .json that isn't a manifest) pasted here.
    if (links.isEmpty && HubCollection.isFileLink(url)) {
      String message;
      try {
        message = tr('{n} collections added. They show on the Media Hub tab.',
            {'n': await service.importCollections(url)});
        _link.clear();
      } on ArchiveApiException {
        message = tr('No collections in that file.');
      } catch (_) {
        message = tr("Couldn't reach that link.");
      }
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    String? error;
    ArchiveSource? added;
    try {
      added = await service.addSource(url);
    } on StateError {
      error = tr('That source is already in the list.');
    } on ArchiveApiException {
      // Not movies/shows: a subtitles-only add-on (OpenSubtitles v3...)
      // goes with the subtitle add-ons, like a multi-link paste.
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
    await showGlassMenu<void>(
      context: context,
      builder: (dialogContext) => GlassMenuDialog(
        title: Text(tr('{n} links checked', {'n': result.total})),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(child: Text(addonImportSummary(result))),
        ),
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

  /// "From phone": the Add Playlist QR flow, link kind — the phone pastes
  /// the long manifest URL, it lands in the field here to check.
  Future<void> _fromPhone() async {
    final link =
        await PhoneLinkScreen.open(context, title: tr('Media Hub sources'));
    if (link == null || !mounted) return;
    _link.text = link;
    _addFocus.requestFocus();
  }

  void _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final tools = <(String, IconData, String, String, VoidCallback)>[
      ('phone', Icons.qr_code_2, tr('From phone'),
          tr('Scan, paste the link on your phone'), _fromPhone),
      if (widget.onManageFromPhone != null)
        ('manage', Icons.phonelink, tr('Manage from phone'),
            tr('Your whole list on your phone'), widget.onManageFromPhone!),
      ('stremio', Icons.move_down, tr('Import from Stremio'),
          tr('Sign in once, pick your add-ons'),
          () => _push(const StremioImportScreen())),
      ('server', Icons.dns_outlined, tr('Connect Jellyfin / Emby / Plex'),
          tr('Your own media server'), () => _push(const MediaServerScreen())),
      ('trackers', Icons.playlist_add_check, tr('Trakt & Simkl'),
          tr('Your lists in the Media Hub'),
          () => openSettingsPage(context, (_) => const TrackersScreen(),
              floating: true)),
      ('subs', Icons.subtitles_outlined, tr('Online subtitles'),
          tr('OpenSubtitles, or any subtitle add-on'),
          () => openSettingsPage(context, (_) => const AddonsScreen(),
              floating: true)),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.help != null)
            SettingsPaneHeader(
                category: SettingsCategory(
                    id: 'add',
                    icon: Icons.add_circle_outline,
                    title: tr('Add a source'),
                    description: tr('An add-on link ends with manifest.json.'),
                    sections: const [])),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: TvTextFieldGate(
              focusNode: _linkFocus,
              builder: (context, readOnly) => TextField(
                controller: _link,
                focusNode: _linkFocus,
                readOnly: readOnly,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  _addFocus.requestFocus();
                  _add();
                },
                onTap: () => _say(tr('Several links at once work too.')),
                decoration: InputDecoration(
                  labelText: tr('Source link (ends with manifest.json)'),
                  helperText: tr('Several links at once work too.'),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
            ),
          ),
          SettingRow(
            key: const ValueKey('source-add'),
            focusNode: _addFocus,
            icon: Icons.add,
            title: tr('Add'),
            subtitle: tr('Checks the link, then adds it'),
            trailing: _adding
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onFocusChange: (f) {
              if (f) _say(tr('Several links at once work too.'));
            },
            onTap: _add,
          ),
          SettingsSectionTitle(tr('Other ways')),
          for (final (id, icon, title, subtitle, onTap) in tools)
            SettingRow(
              key: ValueKey('source-tool-$id'),
              icon: icon,
              title: title,
              subtitle: subtitle,
              trailing: const SettingValue(),
              onFocusChange: (f) {
                if (f) _say(subtitle);
              },
              onTap: onTap,
            ),
        ],
      ),
    );
  }
}
