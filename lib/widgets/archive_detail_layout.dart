import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/storage_service.dart';

/// Stable ids; missing rows keep their place for titles that do have them.
class ArchiveDetailLayout {
  static const defaults = ['collection', 'related', 'cast'];
  static List<String> load(StorageService storage) {
    try {
      final value =
          jsonDecode(storage.getArchiveOptionsJson('detail_rows') ?? '[]');
      return normalize(value);
    } catch (_) {
      return [...defaults];
    }
  }

  static List<String> normalize(Object? value) => [
        ...{
          if (value is List)
            for (final id in value)
              if (defaults.contains(id)) id as String,
          ...defaults
        }
      ];

  static String label(String id) => switch (id) {
        'cast' => tr('Cast and credits'),
        'related' => tr('More like this'),
        _ => tr('Collection'),
      };
}

Future<List<String>?> showArchiveDetailLayout(
        BuildContext context, List<String> order) =>
    showDialog<List<String>>(
        context: context, builder: (_) => _DetailLayoutDialog(order));

class _DetailLayoutDialog extends StatefulWidget {
  const _DetailLayoutDialog(this.order);
  final List<String> order;
  @override
  State<_DetailLayoutDialog> createState() => _DetailLayoutDialogState();
}

class _DetailLayoutDialogState extends State<_DetailLayoutDialog> {
  late final _order = [...widget.order];
  final _up = {for (final id in ArchiveDetailLayout.defaults) id: FocusNode()};
  final _down = {
    for (final id in ArchiveDetailLayout.defaults) id: FocusNode()
  };

  @override
  void dispose() {
    for (final node in [..._up.values, ..._down.values]) {
      node.dispose();
    }
    super.dispose();
  }

  void _move(String id, int delta) {
    final at = _order.indexOf(id), next = _order.indexOf(id) + delta;
    if (next < 0 || next >= _order.length) return;
    setState(() {
      _order.removeAt(at);
      _order.insert(next, id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = delta < 0
          ? (next > 0 ? _up[id] : _down[id])
          : (next < _order.length - 1 ? _down[id] : _up[id]);
      target!.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(tr('Customize title page')),
          content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr(
                    'Choose the order of rows below title details. Saved for this viewer.')),
                const SizedBox(height: 12),
                for (var i = 0; i < _order.length; i++)
                  ListTile(
                      key: ValueKey(_order[i]),
                      title: Text(ArchiveDetailLayout.label(_order[i])),
                      contentPadding: EdgeInsets.zero,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            key: ValueKey('up-${_order[i]}'),
                            focusNode: _up[_order[i]],
                            tooltip: tr('Move up'),
                            icon: const Icon(Icons.arrow_upward),
                            onPressed:
                                i == 0 ? null : () => _move(_order[i], -1)),
                        IconButton(
                            key: ValueKey('down-${_order[i]}'),
                            focusNode: _down[_order[i]],
                            tooltip: tr('Move down'),
                            autofocus: i == 0,
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: i == _order.length - 1
                                ? null
                                : () => _move(_order[i], 1)),
                      ])),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('Cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(_order),
                child: Text(tr('Save'))),
          ]);
}
