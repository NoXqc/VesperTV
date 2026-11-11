import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/hub_collection.dart';
import '../../services/archive_api_service.dart';
import '../../services/archive_service.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/hold_to_activate.dart';
import '../../widgets/setting_row.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_text_field_gate.dart';
import 'phone_link_screen.dart';
import 'settings_catalog.dart' show SettingsCategory;
import 'settings_menu_screen.dart' show SettingsPaneHeader;

/// A community pack offered as a suggestion: Nuvio Perfect Collections
/// (luckynumb3rs/stremio-perfect-setup, its own AIOMetadata catalogs).
const kPerfectCollectionsLink =
    'https://raw.githubusercontent.com/luckynumb3rs/stremio-perfect-setup/main/templates/Nuvio-Collections.json';

/// Settings > Media Hub sources > Collections (owner, 2026-11-11): import
/// a Nuvio collections file, turn each collection on or off, order them,
/// update or remove them, and choose whether their catalogs also stay in
/// the tab's rows. The tiles themselves are on the Media Hub tab.
class HubCollectionsPane extends StatefulWidget {
  const HubCollectionsPane({super.key, this.help});

  /// The page's help line (TV layout).
  final ValueNotifier<String?>? help;

  @override
  State<HubCollectionsPane> createState() => _HubCollectionsPaneState();
}

class _HubCollectionsPaneState extends State<HubCollectionsPane> {
  final Map<String, FocusNode> _nodes = {};
  bool _busy = false;

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'collections-$id'));

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _say(String? text) => widget.help?.value = text;

  void _toast(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade900 : null));

  /// Imports [link]; says how it went.
  /// Imports [link]; says how it went. [streamingOnly] (the community
  /// pack): its new collections start off except Streaming, the row most
  /// people want (owner, 2026-11-11); the others wait here to be turned on.
  Future<void> _import(String link, {bool streamingOnly = false}) async {
    if (_busy) return;
    final service = context.read<ArchiveService>();
    setState(() => _busy = true);
    try {
      final before = {
        for (final c in service.collections) c.id,
        // Removed ones get their own switches back.
        ...service.rememberedCollectionIds,
      };
      final n = await service.importCollections(link);
      final fresh =
          service.collections.where((c) => !before.contains(c.id)).toList();
      if (streamingOnly &&
          service.collections.any((c) => c.label == 'Streaming')) {
        for (final c in fresh) {
          if (c.label != 'Streaming') {
            await service.setCollectionEnabled(c.id, false);
          }
        }
        if (!mounted) return;
        if (!fresh.any((c) => c.label == 'Streaming')) {
          _toast(tr('{n} collections added. They show on the Media Hub tab.',
              {'n': n}));
          return;
        }
        _toast(tr(
            'Streaming is on. Turn on the other collections here when you want them.'));
        return;
      }
      if (!mounted) return;
      _toast(tr(
          '{n} collections added. They show on the Media Hub tab.', {'n': n}));
    } on ArchiveApiException {
      if (mounted) _toast(tr('No collections in that file.'), error: true);
    } catch (_) {
      if (mounted) _toast(tr("Couldn't reach that link."), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _typeLink() async {
    final link = await showGlassMenu<String>(
        context: context, builder: (_) => const _LinkDialog());
    if (link != null && link.trim().isNotEmpty && mounted) {
      await _import(link.trim());
    }
  }

  Future<void> _fromPhone() async {
    final link = await PhoneLinkScreen.open(context, title: tr('Collections'));
    if (link != null && link.trim().isNotEmpty && mounted) {
      await _import(link.trim());
    }
  }

  /// OK on a collection: its menu.
  Future<void> _options(HubCollection c, int index, int count) async {
    final service = context.read<ArchiveService>();
    final choice = await showGlassMenu<String>(
      context: context,
      builder: (dialogContext) => SwallowHeldActivate(
        child: GlassMenuDialog(
          title: Text(c.label),
          children: [
            TvDialogOption(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop('toggle'),
              child: Text(c.enabled ? tr('Turn off') : tr('Turn on')),
            ),
            TvDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('home'),
              child:
                  Text(c.onHome ? tr('Remove from Home') : tr('Show on Home')),
            ),
            if (index > 0)
              TvDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop('up'),
                child: Text(tr('Move up')),
              ),
            if (index < count - 1)
              TvDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop('down'),
                child: Text(tr('Move down')),
              ),
            if (c.link != null)
              TvDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop('update'),
                child: Text(tr('Update from its link')),
              ),
            TvDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('remove'),
              child: Text(tr('Remove')),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'toggle':
        await service.setCollectionEnabled(c.id, !c.enabled);
      case 'home':
        await service.setCollectionOnHome(c.id, !c.onHome);
      case 'up':
        await service.moveCollection(c.id, -1);
      case 'down':
        await service.moveCollection(c.id, 1);
      case 'update':
        await _import(c.link!);
      case 'remove':
        await service.removeCollection(c.id);
        if (mounted) _node('import').requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ArchiveService>();
    final list = service.collections;
    final perfect = list.any((c) => c.link == kPerfectCollectionsLink);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPaneHeader(
            category: SettingsCategory(
              id: 'collections',
              icon: Icons.dashboard_customize_outlined,
              title: tr('Collections'),
              description: tr(
                  'Rows of tiles on the Media Hub tab, like Nuvio: each tile opens a page of catalogs from your add-ons.'),
              sections: const [],
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SettingRow(
            focusNode: _node('import'),
            icon: Icons.link,
            title: tr('Add from a link'),
            subtitle: tr('A Nuvio collections file (.json)'),
            trailing: const SettingValue(),
            onFocusChange: (f) {
              if (f) {
                _say(tr(
                    'Tiles need their catalogs in your add-ons (AIOMetadata with the same catalogs). Missing ones are left out.'));
              }
            },
            onTap: _typeLink,
          ),
          SettingRow(
            focusNode: _node('phone'),
            icon: Icons.qr_code_2,
            title: tr('From phone'),
            subtitle: tr('Send the file link from your phone'),
            trailing: const SettingValue(),
            onFocusChange: (f) {
              if (f) _say(null);
            },
            onTap: _fromPhone,
          ),
          if (!perfect)
            SettingRow(
              focusNode: _node('perfect'),
              icon: Icons.auto_awesome_outlined,
              title: tr('Community pack: Nuvio Perfect Collections'),
              subtitle: tr(
                  'Streaming, genres, studios, decades… made for the AIOMetadata catalogs of the same setup'),
              subtitleMaxLines: 2,
              trailing: const SettingValue(),
              onFocusChange: (f) {
                if (f) {
                  _say(tr(
                      'By luckynumb3rs (stremio-perfect-setup). Its tiles show once your AIOMetadata has the same catalogs.'));
                }
              },
              onTap: () =>
                  _import(kPerfectCollectionsLink, streamingOnly: true),
            ),
          SettingRow(
            focusNode: _node('hide'),
            icon: Icons.layers_clear_outlined,
            title: tr('Hide their catalogs from the rows'),
            subtitle:
                tr("A catalog in a collection shows only on its tile's page"),
            toggled: service.collectionsHideRows,
            trailing: GlassSwitch(value: service.collectionsHideRows),
            onFocusChange: (f) {
              if (f) _say(null);
            },
            onTap: () =>
                service.setCollectionsHideRows(!service.collectionsHideRows),
          ),
          if (list.isNotEmpty) const SizedBox(height: 8),
          for (var i = 0; i < list.length; i++)
            _collectionRow(service, list[i], i, list.length),
        ],
      ),
    );
  }

  Widget _collectionRow(
      ArchiveService service, HubCollection c, int index, int count) {
    final found =
        c.folders.where((f) => service.folderCatalogs(f).isNotEmpty).length;
    return SettingRow(
      key: ValueKey('collection-${c.id}'),
      focusNode: _node('c-${c.id}'),
      icon: Icons.view_carousel_outlined,
      title: c.label,
      subtitle: [
        tr('{found} of {n} tiles found in your add-ons',
            {'found': found, 'n': c.folders.length}),
        if (c.onHome) tr('On Home'),
      ].join(' · '),
      trailing: GlassSwitch(value: c.enabled),
      onFocusChange: (f) {
        if (f) {
          _say(found == 0
              ? tr(
                  'None of its catalogs are in your add-ons: add the AIOMetadata setup it was made for.')
              : tr(
                  'OK for its options: on or off, Home, order, update, remove.'));
        }
      },
      onTap: () => _options(c, index, count),
    );
  }
}

/// Typing the file's link (a remote can, a phone pastes it).
class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _text = TextEditingController();
  final _field = FocusNode(debugLabel: 'collections-link');
  final _ok = FocusNode(debugLabel: 'collections-link-ok');

  @override
  void dispose() {
    _text.dispose();
    _field.dispose();
    _ok.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassMenuDialog(
      title: Text(tr('Collections file link')),
      content: SizedBox(
        width: 460,
        child: TvTextFieldGate(
          focusNode: _field,
          builder: (context, readOnly) => TextField(
            controller: _text,
            focusNode: _field,
            readOnly: readOnly,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _ok.requestFocus(),
            decoration:
                const InputDecoration(hintText: 'https://…/collections.json'),
          ),
        ),
      ),
      actions: [
        TextButton(
          focusNode: _ok,
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(tr('Import')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
      ],
    );
  }
}
