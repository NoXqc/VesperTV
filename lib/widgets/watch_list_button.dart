import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/storage_service.dart';
import '../services/vesper_ai/watch_list.dart';
import 'detail_header.dart';

/// The Watch list button on a movie / show page (IPTV and Media Hub): puts
/// [item] on the viewer's watch list, or takes it off again.
class WatchListButton extends StatefulWidget {
  const WatchListButton({
    super.key,
    required this.item,
    required this.focusNode,
    required this.scale,
    this.onFocused,
  });

  final WatchListItem item;
  final FocusNode focusNode;
  final double scale;
  final VoidCallback? onFocused;

  @override
  State<WatchListButton> createState() => _WatchListButtonState();
}

class _WatchListButtonState extends State<WatchListButton> {
  @override
  void initState() {
    super.initState();
    // The list can also change from Vesper AI or a phone while open.
    WatchList.instance.changes.addListener(_changed);
  }

  @override
  void dispose() {
    WatchList.instance.changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    final storage = context.read<StorageService>();
    final on = await WatchList.instance.toggle(storage, widget.item);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content:
          Text(on ? tr('Added to watch list') : tr('Removed from watch list')),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool on;
    try {
      on = WatchList.instance
          .contains(context.read<StorageService>(), widget.item.id);
    } on ProviderNotFoundException {
      on = false;
    }
    return DetailPillButton(
      focusNode: widget.focusNode,
      icon: on ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
      label: tr('Watch list'),
      selected: on,
      scale: widget.scale,
      onPressed: _toggle,
      onFocused: widget.onFocused,
    );
  }
}
