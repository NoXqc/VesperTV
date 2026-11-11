import '../services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/archive_models.dart';
import '../services/archive_service.dart';
import 'archive_playback_settings.dart';
import 'tv_text_field_gate.dart';
import 'glass_menu.dart';

Future<void> renameArchiveRow(BuildContext context, ArchiveRow row) async {
  final service = context.read<ArchiveService>();
  final storage = context.read<StorageService>();
  final viewer = storage.viewerGeneration;
  final title = await showDialog<String>(
      context: context, builder: (_) => _RenameArchiveRow(title: row.title));
  if (title != null && context.mounted && storage.viewerGeneration == viewer) {
    await service.renameRow(row.key, title);
  }
}

class _RenameArchiveRow extends StatefulWidget {
  const _RenameArchiveRow({required this.title});
  final String title;
  @override
  State<_RenameArchiveRow> createState() => _RenameArchiveRowState();
}

class _RenameArchiveRowState extends State<_RenameArchiveRow> {
  late final _controller = TextEditingController(text: widget.title);
  final _focus = FocusNode();
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(tr('Rename row')),
          content: TvTextFieldGate(
              focusNode: _focus,
              builder: (_, readOnly) => TextField(
                  focusNode: _focus,
                  controller: _controller,
                  readOnly: readOnly,
                  autofocus: true,
                  maxLength: 60,
                  onSubmitted: (v) => Navigator.pop(context, v),
                  decoration:
                      InputDecoration(hintText: tr('Leave empty to reset')))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(context, _controller.text),
                child: Text(tr('Save')))
          ]);
}

Future<void> showArchiveRowSettings(BuildContext context, ArchiveType type) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85, maxWidth: 800),
        builder: (_) => _ArchiveRowSettings(type: type));

class _ArchiveRowSettings extends StatefulWidget {
  const _ArchiveRowSettings({required this.type});
  final ArchiveType type;

  @override
  State<_ArchiveRowSettings> createState() => _ArchiveRowSettingsState();
}

/// Left / Right walk a row's buttons in order: hide, pin, up, down,
/// rename. Flutter's own directional search jumped from hide straight to
/// the pen and back, so pin / up / down were out of the remote's reach
/// (owner photo, 2026-11-11). Up / Down stay Flutter's (row to row).
class _ArchiveRowSettingsState extends State<_ArchiveRowSettings> {
  final Map<String, List<FocusNode>> _nodes = {};

  List<FocusNode> _rowNodes(String key) => _nodes.putIfAbsent(
      key, () => List.generate(5, (_) => FocusNode(debugLabel: 'row-tool')));

  @override
  void dispose() {
    for (final list in _nodes.values) {
      for (final n in list) {
        n.dispose();
      }
    }
    super.dispose();
  }

  KeyEventResult _onRowKey(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = event.logicalKey == LogicalKeyboardKey.arrowRight
        ? 1
        : event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? -1
            : 0;
    if (step == 0) return KeyEventResult.ignored;
    final nodes = _rowNodes(key);
    final at = nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (at < 0) return KeyEventResult.ignored;
    // The next button that can take focus (a Continue watching row's pin
    // and arrows are off); at either end the selector stays.
    for (var k = at + step; k >= 0 && k < nodes.length; k += step) {
      if (nodes[k].canRequestFocus && nodes[k].context != null) {
        nodes[k].requestFocus();
        break;
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final service = context.watch<ArchiveService>();
    final rows = service
        .rows(type, includeHidden: true)
        .where((r) => !r.isSearch)
        .toList();
    return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
          title: Text(tr('Customize Media Hub')),
          subtitle:
              Text(tr('Hide a row without disabling its playback source.')),
          trailing: IconButton(
              tooltip: tr('Playback preferences'),
              icon: const Icon(Icons.tune),
              onPressed: () => showArchivePlaybackSettings(context))),
      Flexible(
          child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final row = rows[i];
                final nodes = _rowNodes(row.key);
                return GlassFocusFrame(
                    key: ValueKey(row.key),
                    child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (_, e) => _onRowKey(row.key, e),
                    child: ListTile(
                    title: Text(row.title),
                    subtitle: Text(row.sourceLabel ?? row.source.name),
                    leading: IconButton(
                        focusNode: nodes[0],
                        autofocus: i == 0,
                        tooltip: service.rowHidden(row.key)
                            ? tr('Show row')
                            : tr('Hide row'),
                        icon: Icon(service.rowHidden(row.key)
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => service.setRowFlag(
                            row.key, 'hidden', !service.rowHidden(row.key))),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          focusNode: nodes[1],
                          tooltip: tr('Pin row'),
                          icon: Icon(service.rowPinned(row.key)
                              ? Icons.push_pin
                              : Icons.push_pin_outlined),
                          onPressed: row.continuations != null
                              ? null
                              : () => service.setRowFlag(row.key, 'pinned',
                                  !service.rowPinned(row.key))),
                      IconButton(
                          focusNode: nodes[2],
                          tooltip: tr('Move up'),
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: row.continuations != null
                              ? null
                              : () => service.moveRow(type, row.key, -1)),
                      IconButton(
                          focusNode: nodes[3],
                          tooltip: tr('Move down'),
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: row.continuations != null
                              ? null
                              : () => service.moveRow(type, row.key, 1)),
                      IconButton(
                          focusNode: nodes[4],
                          tooltip: tr('Rename row'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => renameArchiveRow(context, row)),
                    ]))));
              })),
    ]));
  }
}
