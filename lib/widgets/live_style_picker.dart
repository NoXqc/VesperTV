import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/live_group_styles.dart';
import 'glass_menu.dart';
import 'live_style_view.dart';
import 'tv_dialog_option.dart';

/// Colour… > Live styles… (owner, 2026-11-26): the bank, downloaded when
/// this opens, by category; each row previews its style and moves while
/// the remote is on it. Returns the picked style's colour id
/// (`style:<id>`), null = closed.
Future<String?> showLiveStylePicker(BuildContext context,
        {String? currentId, int? count}) =>
    showGlassMenu<String>(
      context: context,
      builder: (context) => GlassMenuDialog(
        maxWidth: 380,
        title: Text(count == null
            ? tr('Live styles')
            : tr('Live style for {count} groups', {'count': '$count'})),
        content: _LiveStyleGallery(currentId: currentId),
      ),
    );

/// Category ids the bank uses, in the order shown.
const _categories = ['seasonal', 'vesper', 'sports', 'fun'];

String _categoryName(String id) => switch (id) {
      'seasonal' => tr('Seasonal'),
      // The brand's own look: never translated.
      'vesper' => 'Vesper',
      'sports' => tr('Sports'),
      'fun' => tr('Fun'),
      _ => tr('More'),
    };

class _LiveStyleGallery extends StatefulWidget {
  const _LiveStyleGallery({this.currentId});

  final String? currentId;

  @override
  State<_LiveStyleGallery> createState() => _LiveStyleGalleryState();
}

class _LiveStyleGalleryState extends State<_LiveStyleGallery> {
  List<LiveGroupStyle>? _styles;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final styles = await LiveGroupStyles.instance.load();
      if (mounted) setState(() => _styles = styles);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = _styles;
    if (_failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Text(
              tr("Couldn't get the live styles. Check the connection and try again."),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TvDialogOption(
            autofocus: true,
            onPressed: _load,
            child: Text(tr('Try again')),
          ),
        ],
      );
    }
    if (styles == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 14),
            Text(tr('Getting live styles…'),
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    final known = {
      for (final s in styles)
        if (_categories.contains(s.category)) s.id,
    };
    final groups = [
      for (final c in _categories)
        (
          c,
          [
            for (final s in styles)
              if (s.category == c) s
          ]
        ),
      (
        '',
        [
          for (final s in styles)
            if (!known.contains(s.id)) s
        ]
      ),
    ];
    final current = LiveGroupStyles.instance.styleOf(widget.currentId);
    final first = current ?? (styles.isEmpty ? null : styles.first);
    // GlassMenuDialog scrolls its content.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (category, list) in groups)
          if (list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                _categoryName(category),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            for (final style in list)
              TvDialogOption(
                key: ValueKey('live-style-${style.id}'),
                autofocus: style == first,
                padding: const EdgeInsets.all(3),
                onPressed: () => Navigator.of(context).pop(style.colorId),
                child: _StylePreview(style: style, on: style == current),
              ),
          ],
      ],
    );
  }
}

/// A group-row-sized preview: moves while its option has the remote.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style, required this.on});

  final LiveGroupStyle style;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus;
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Positioned.fill(
            child: LiveStyleBackground(
              colorId: style.colorId,
              style: style,
              animate: focused,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded,
                    size: 20, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    style.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
                if (on) const Icon(Icons.check, size: 18, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
