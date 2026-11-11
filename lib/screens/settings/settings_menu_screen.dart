import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/l10n.dart';
import '../../services/recording_service.dart';
import '../../utils/title_search.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/native_video_hole.dart';
import '../../widgets/roll_down_menu.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'settings_catalog.dart';

/// Settings (rebuilt 2026-11-10, owner: "if I'm brand new to this app and I
/// open the settings I get discouraged"): two glass panels over the
/// wallpaper. Left, the categories ([SettingsCatalog]); right, the focused
/// category's rows, with switches and choices changed right there (no page
/// for one switch) and the focused row's full explanation under the list.
/// Right / OK goes into the rows, Left / Back returns to the categories. A
/// portrait phone gets the categories as a list, each opening its own page.
///
/// Up/Down inside each column is plain Flutter default traversal on
/// purpose — every custom Up/Down interception tried on these screens
/// (`DpadVerticalNav`, `ExplicitFocusOrder`...) was unreliable on real
/// hardware, while plain top-to-bottom lists always worked. Each column is
/// its own [FocusScope] so Up/Down never crosses over; only Left/Right
/// between the two are explicit ([CallbackShortcuts], CLAUDE.md §10).
class SettingsMenuScreen extends StatefulWidget {
  const SettingsMenuScreen({super.key});

  @override
  State<SettingsMenuScreen> createState() => _SettingsMenuScreenState();
}

class _SettingsMenuScreenState extends State<SettingsMenuScreen> {
  final _railScope = FocusScopeNode(debugLabel: 'settings-rail');
  final _paneScope = FocusScopeNode(debugLabel: 'settings-pane');
  final List<FocusNode> _railNodes = [];
  final _firstEntryNode = FocusNode(debugLabel: 'settings-first-entry');
  final _help = ValueNotifier<String?>(null);
  final _searchNode = FocusNode(debugLabel: 'settings-search');
  final _query = TextEditingController();

  /// The rail's entries: 0 = Search, then the categories.
  int _selected = 1;
  bool _inPane = false;
  String? _nativeStatus;
  List<RecordingVolume> _volumes = const [];

  @override
  void initState() {
    super.initState();
    _paneScope.addListener(_onPaneFocus);
    _query.addListener(_refresh);
    if (Platform.isAndroid) {
      NativeVideoSurface.statusLine().then((s) {
        if (mounted) setState(() => _nativeStatus = s);
      }, onError: (_) {});
    }
    loadRecordingVolumes().then((v) {
      if (mounted) setState(() => _volumes = v);
    });
  }

  void _onPaneFocus() {
    if (_paneScope.hasFocus != _inPane) {
      setState(() => _inPane = _paneScope.hasFocus);
      if (!_inPane) _help.value = null;
    }
  }

  @override
  void dispose() {
    _paneScope.removeListener(_onPaneFocus);
    _railScope.dispose();
    _paneScope.dispose();
    _firstEntryNode.dispose();
    _help.dispose();
    _searchNode.dispose();
    _query.dispose();
    for (final n in _railNodes) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _railNode(int i) {
    while (_railNodes.length <= i) {
      _railNodes.add(FocusNode(debugLabel: 'settings-category'));
    }
    return _railNodes[i];
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _enterPane() => _selected == 0
      ? _searchNode.requestFocus()
      : _firstEntryNode.requestFocus();

  void _backToRail() => _railNode(_selected).requestFocus();

  /// Left goes back to the categories, except inside the search text (a
  /// keyboard's Left moves the cursor there until its start).
  KeyEventResult _paneKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    if (_searchNode.hasPrimaryFocus && _query.selection.baseOffset > 0) {
      return KeyEventResult.ignored;
    }
    _backToRail();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(context, (context) {
      final categories = SettingsCatalog(context,
              refresh: _refresh, nativeStatus: _nativeStatus, volumes: _volumes)
          .build();
      if (_selected > categories.length) _selected = 1;
      final narrow = MediaQuery.sizeOf(context).width < 700;
      return PopScope(
        canPop: narrow || !_inPane,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backToRail();
        },
        child: SettingsScaffold(
          title: tr('Settings'),
          panel: false,
          body: narrow
              ? ListView(children: [
                  SettingRow(
                    icon: Icons.search,
                    title: tr('Search settings'),
                    trailing: const SettingValue(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsSearchScreen())),
                  ),
                  for (final c in categories)
                    SettingRow(
                      icon: c.icon,
                      title: c.title,
                      subtitle: c.description,
                      trailing: const SettingValue(),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              SettingsCategoryScreen(categoryId: c.id))),
                    ),
                  const SettingsFooter(),
                ])
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: SettingsScaffold.compact ? 250 : 290,
                          child: GlassPanel(child: _buildRail(categories))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: GlassPanel(
                              child: _selected == 0
                                  ? _buildSearchPane(categories)
                                  : _buildPane(categories[_selected - 1]))),
                    ],
                  ),
                ),
        ),
      );
    });
  }

  Widget _buildRail(List<SettingsCategory> categories) {
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
              _railEntry(0, Icons.search, tr('Search settings')),
              const Divider(
                  height: 13, indent: 10, endIndent: 10, color: Colors.white12),
              for (var i = 0; i < categories.length; i++) ...[
                if (categories[i].advanced)
                  const Divider(
                      height: 13,
                      indent: 10,
                      endIndent: 10,
                      color: Colors.white12),
                _railEntry(i + 1, categories[i].icon, categories[i].title),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Focus follows the selector: the pane shows whichever entry is focused
  /// (wrapper not itself a focus target, CLAUDE.md §10).
  Widget _railEntry(int i, IconData icon, String title) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) {
          if (f && _selected != i) setState(() => _selected = i);
        },
        child: SettingRow(
          focusNode: _railNode(i),
          // Opens on the first category; Search is one Up away.
          autofocus: i == 1,
          icon: icon,
          title: title,
          selected: i == _selected,
          trailing: i == _selected
              ? Icon(Icons.chevron_right,
                  size: 20, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            setState(() => _selected = i);
            _enterPane();
          },
        ),
      );

  Widget _buildSearchPane(List<SettingsCategory> categories) {
    return FocusScope(
      node: _paneScope,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _paneKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPaneHeader(category: _searchCategory()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: SettingsSearchField(
                  controller: _query, focusNode: _searchNode),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: settingsSearchResults(categories, _query.text,
                      refresh: _refresh, help: _help),
                ),
              ),
            ),
            SettingsHelpStrip(help: _help),
          ],
        ),
      ),
    );
  }

  Widget _buildPane(SettingsCategory c) {
    final first = c.items.where((i) => i is! SettingsCustom).firstOrNull;
    return FocusScope(
      node: _paneScope,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _paneKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsPaneHeader(category: c),
            // Non-lazy on purpose: every row has a context, so the remote
            // reaches the last one (a lazy list once left Media Hub's Add
            // field unbuilt and unreachable, CLAUDE.md §13).
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(c.id),
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...settingsSectionWidgets(c,
                        refresh: _refresh,
                        help: _help,
                        firstNode: first == null ? null : _firstEntryNode,
                        first: first),
                    if (c.id == 'help') const SettingsFooter(),
                  ],
                ),
              ),
            ),
            SettingsHelpStrip(help: _help),
          ],
        ),
      ),
    );
  }
}

/// The rows of [category], under their section titles. [help] follows the
/// focused row's explanation; [firstNode] goes on [first] (the row Right
/// from the categories lands on).
List<Widget> settingsSectionWidgets(SettingsCategory category,
    {required VoidCallback refresh,
    ValueNotifier<String?>? help,
    FocusNode? firstNode,
    SettingsItem? first}) {
  return [
    for (final section in category.sections)
      if (section.items.isNotEmpty)
        if (section.highlight)
          SettingsHighlightCard(
            title: section.title,
            children: [
              for (final item in section.items)
                SettingsItemTile(
                  key: ValueKey('setting-${item.id}'),
                  item: item,
                  refresh: refresh,
                  help: help,
                  focusNode: identical(item, first) ? firstNode : null,
                ),
            ],
          )
        else ...[
          if (section.title != null) SettingsSectionTitle(section.title!),
          for (final item in section.items)
            SettingsItemTile(
              key: ValueKey('setting-${item.id}'),
              item: item,
              refresh: refresh,
              help: help,
              focusNode: identical(item, first) ? firstNode : null,
            ),
        ],
  ];
}

/// The Settings search category's header.
SettingsCategory _searchCategory() => SettingsCategory(
    id: 'search',
    icon: Icons.search,
    title: tr('Search settings'),
    description: tr(
        'Type a word, like subtitles, clock or Atmos. OK on a result changes it right there.'),
    sections: const []);

/// Where recordings / downloads can go, for the Recordings rows (empty
/// where there are none, and in tests).
Future<List<RecordingVolume>> loadRecordingVolumes() async {
  if (!RecordingService.downloadsSupported) return const [];
  try {
    await RecordingService.instance.init();
    return await RecordingService.instance.volumes();
  } catch (_) {
    return const [];
  }
}

/// Every row matching [query] (title, description, help, choices, its
/// category and section; accents and case ignored), each a working row:
/// a switch flips right in the results.
List<Widget> settingsSearchResults(
    List<SettingsCategory> categories, String query,
    {required VoidCallback refresh, ValueNotifier<String?>? help}) {
  final words = TitleSearch.fold(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];
  final rows = <Widget>[];
  for (final c in categories) {
    for (final section in c.sections) {
      for (final item in section.items) {
        if (item is SettingsCustom) continue;
        final text = TitleSearch.fold([
          item.title,
          item.subtitle ?? '',
          item.help ?? '',
          c.title,
          section.title ?? '',
          if (item is SettingsChoice) ...item.options.map((o) => o.label),
        ].join(' '));
        if (!words.every(text.contains)) continue;
        rows.add(SettingsItemTile(
          key: ValueKey('search-${item.id}'),
          item: item,
          refresh: refresh,
          help: help,
          where:
              [c.title, if (section.title != null) section.title!].join(' › '),
        ));
      }
    }
  }
  if (rows.isEmpty) {
    rows.add(Padding(
      padding: const EdgeInsets.all(16),
      child: Text(tr('No setting matches "{query}".', {'query': query.trim()}),
          style: const TextStyle(color: Colors.white70)),
    ));
  }
  return rows;
}

/// The search text: gated on a TV box (OK opens the keyboard,
/// CLAUDE.md §10), Down goes on to the results.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField(
      {super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => TvTextFieldGate(
        focusNode: focusNode,
        builder: (context, readOnly) => TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          // The keyboard closes; the first result is one Down away.
          onSubmitted: (_) =>
              focusNode.focusInDirection(TraversalDirection.down),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr('Search settings'),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: tr('Clear'),
                    onPressed: controller.clear,
                  ),
          ),
        ),
      );
}

/// A phone's Settings search: the field, then working result rows.
class SettingsSearchScreen extends StatefulWidget {
  const SettingsSearchScreen({super.key});

  @override
  State<SettingsSearchScreen> createState() => _SettingsSearchScreenState();
}

class _SettingsSearchScreenState extends State<SettingsSearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode(debugLabel: 'settings-search-phone');
  List<RecordingVolume> _volumes = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_refresh);
    loadRecordingVolumes().then((v) {
      if (mounted) setState(() => _volumes = v);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(context, (context) {
      final categories =
          SettingsCatalog(context, refresh: _refresh, volumes: _volumes)
              .build();
      return SettingsScaffold(
        title: tr('Search settings'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [
            SettingsSearchField(controller: _query, focusNode: _focus),
            const SizedBox(height: 8),
            ...settingsSearchResults(categories, _query.text,
                refresh: _refresh),
          ],
        ),
      );
    });
  }
}

/// A gold-edged card around a few rows: Start here, until the first
/// playlist is added.
class SettingsHighlightCard extends StatelessWidget {
  const SettingsHighlightCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(title!.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// One [SettingsItem] as a [SettingRow]: a switch flips in place, a choice
/// rolls down beside the row, a link opens its page.
class SettingsItemTile extends StatelessWidget {
  const SettingsItemTile(
      {super.key,
      required this.item,
      required this.refresh,
      this.help,
      this.focusNode,
      this.where});

  final SettingsItem item;
  final VoidCallback refresh;
  final ValueNotifier<String?>? help;
  final FocusNode? focusNode;

  /// A search result: where the row lives (category › section), shown
  /// instead of its description.
  final String? where;

  void _focus(bool f) {
    if (f) help?.value = item.help ?? item.subtitle;
  }

  /// Without a help strip (a phone's category page) the row shows its
  /// explanation itself.
  String? get _subtitle =>
      where ?? (help == null ? item.subtitle ?? item.help : item.subtitle);

  int get _subtitleLines => help == null ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    return switch (item) {
      SettingsCustom() => item.builder(context),
      SettingsToggle() => SettingRow(
          focusNode: focusNode,
          icon: item.icon,
          title: item.title,
          subtitle: _subtitle,
          subtitleMaxLines: _subtitleLines,
          toggled: item.value,
          trailing: GlassSwitch(value: item.value),
          onFocusChange: _focus,
          onTap: () {
            item.onChanged(!item.value);
            refresh();
          },
        ),
      SettingsChoice() => Builder(
          builder: (rowContext) => SettingRow(
            focusNode: focusNode,
            icon: item.icon,
            title: item.title,
            subtitle: _subtitle,
            subtitleMaxLines: _subtitleLines,
            trailing: SettingValue(
                text: item.valueLabel,
                icon: item.onStep == null
                    ? Icons.unfold_more
                    : Icons.code /* ‹ › : Left/Right change it */),
            onFocusChange: _focus,
            onLeft: item.onStep == null ? null : () => item.onStep!(-1),
            onRight: item.onStep == null ? null : () => item.onStep!(1),
            onTap: () => _pick(rowContext, item),
          ),
        ),
      SettingsLink() => SettingRow(
          focusNode: focusNode,
          icon: item.icon,
          title: item.title,
          subtitle: _subtitle,
          subtitleMaxLines: _subtitleLines,
          trailing: SettingValue(text: item.value),
          onFocusChange: _focus,
          onTap: () async {
            await openSettingsPage<void>(context, item.page,
                floating: item.floating);
            refresh();
          },
        ),
      SettingsAction() => SettingRow(
          focusNode: focusNode,
          icon: item.icon,
          title: item.title,
          subtitle: _subtitle,
          subtitleMaxLines: _subtitleLines,
          trailing: item.value == null
              ? null
              : SettingValue(text: item.value, icon: null),
          onFocusChange: _focus,
          onTap: () async {
            await item.run(context);
            refresh();
          },
        ),
    };
  }

  /// The choices roll down from the row's right end, the current one
  /// focused (it is "you are here").
  Future<void> _pick(BuildContext rowContext, SettingsChoice item) async {
    final box = rowContext.findRenderObject() as RenderBox?;
    Rect? anchor;
    const width = 320.0;
    if (box != null && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final left = (rect.right - width).clamp(rect.left, rect.right);
      anchor = Rect.fromLTWH(left, rect.top, width, rect.height);
    }
    final picked = await showRollDownMenu<String>(
      rowContext,
      anchor: anchor,
      title: item.title,
      centered: false,
      width: width,
      items: [
        for (final o in item.options)
          RollDownMenuItem(
            value: o.value,
            icon: Icons.circle_outlined,
            label: o.label,
            subtitle: o.subtitle,
            selected: o.value == item.selected,
            dimmed: o.dimmed ?? false,
          ),
      ],
    );
    if (picked == null || picked == item.selected) return;
    item.onPick(picked);
    refresh();
  }
}

/// A small caps title over a group of rows.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = CompactMenus.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, compact ? 12 : 16, 14, 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: compact ? 11 : 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5))),
    );
  }
}

/// The pane's top: the category's icon, name and what's inside it.
class SettingsPaneHeader extends StatelessWidget {
  const SettingsPaneHeader({super.key, required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = CompactMenus.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 12 : 18, 20, compact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.icon, size: compact ? 26 : 34, color: scheme.primary),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.title,
                    style: TextStyle(
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(category.description,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: compact ? 12.5 : null)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the rows: the focused row's full explanation, so the rows
/// themselves stay one short line each.
class SettingsHelpStrip extends StatelessWidget {
  const SettingsHelpStrip({super.key, required this.help});

  final ValueListenable<String?> help;

  @override
  Widget build(BuildContext context) {
    final compact = CompactMenus.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: help,
      builder: (context, text, _) => Container(
        constraints: BoxConstraints(minHeight: compact ? 44 : 52),
        padding:
            EdgeInsets.fromLTRB(20, compact ? 8 : 10, 20, compact ? 8 : 12),
        decoration: const BoxDecoration(
          color: Color(0x2E000000),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: text == null || text.isEmpty
            ? const SizedBox.shrink()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: compact ? 16 : 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: compact ? 12.5 : 13.5,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Portrait phone: one category's rows on their own page.
class SettingsCategoryScreen extends StatefulWidget {
  const SettingsCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<SettingsCategoryScreen> createState() => _SettingsCategoryScreenState();
}

class _SettingsCategoryScreenState extends State<SettingsCategoryScreen> {
  List<RecordingVolume> _volumes = const [];

  @override
  void initState() {
    super.initState();
    loadRecordingVolumes().then((v) {
      if (mounted) setState(() => _volumes = v);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(context, (context) {
      final category =
          SettingsCatalog(context, refresh: _refresh, volumes: _volumes)
              .build()
              .where((c) => c.id == widget.categoryId)
              .firstOrNull;
      if (category == null) {
        return SettingsScaffold(title: tr('Settings'), body: const SizedBox());
      }
      return SettingsScaffold(
        title: category.title,
        // Non-lazy, like the TV pane: every row is reachable (a keyboard,
        // a remote on a small screen).
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsPaneHeader(category: category),
              // No focus to follow on a touch screen: each row shows its
              // explanation itself (two lines).
              ...settingsSectionWidgets(category, refresh: _refresh),
              if (category.id == 'help') const SettingsFooter(),
            ],
          ),
        ),
      );
    });
  }
}

/// Version, bug-report address and the TMDB / Trakt / Simkl / sports
/// data credits.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 11, color: Colors.grey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reads whatever code is actually running via PackageInfo (same
        // source CheckUpdatesScreen's "Current version" line uses) rather
        // than a hand-typed constant — requested directly: "so I can
        // confirm easily the current version inside the app".
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version;
              return Text(
                version == null
                    ? tr('Version —')
                    : tr('Version {version}', {'version': version}),
                style: small,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(tr('Report any bugs or glitches to noxqcx@gmail.com'),
              style: small),
        ),
        // TMDB's terms ask for this wherever their data/images show —
        // posters and backdrops come from TMDB's image CDN even without a
        // key (provider links, upgraded to HD by hdImageUrl), so it lives
        // here, not only in the TMDB key screen.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            '${tr('Movie and TV artwork and data may come from TMDB (The Movie Database).')} '
            '${tr('This product uses the TMDB API but is not endorsed or certified by TMDB.')} '
            // Credit for the watch trackers (Settings > Trakt & Simkl),
            // owner 2026-10-19.
            '${tr('Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.')} '
            // Sports Trak's data (owner, 2026-11-11): the README and site
            // already name it.
            '${tr("Sports scores, schedules and standings come from ESPN's and TheSportsDB's public data; VesperTV is not affiliated with or endorsed by either.")}',
            style: small,
          ),
        ),
      ],
    );
  }
}
