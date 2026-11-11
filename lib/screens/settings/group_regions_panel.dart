import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/m3u_group.dart';
import '../../utils/group_regions.dart';
import '../../widgets/glass_menu.dart';
import '../../widgets/tv_menu_tile.dart';

/// Group Management > Countries (owner, 2026-11-11): every country (and
/// shared prefix) found at the start of the group names, each showing or
/// hiding all its groups at once. The rows follow the groups' state live.
Future<void> showGroupRegions(
  BuildContext context, {
  required Listenable listenable,
  required List<M3uGroup> Function() groups,
  required Future<void> Function(List<String> titles, bool hidden) setHidden,
}) =>
    showGlassMenu<void>(
      context: context,
      builder: (_) => GroupRegionsPanel(
          listenable: listenable, groups: groups, setHidden: setHidden),
    );

class GroupRegionsPanel extends StatefulWidget {
  const GroupRegionsPanel({
    super.key,
    required this.listenable,
    required this.groups,
    required this.setHidden,
  });

  /// Notifies when a group is shown or hidden ([PlaylistManager]).
  final Listenable listenable;

  /// The tab's groups of this playlist, with their current hidden state.
  final List<M3uGroup> Function() groups;

  final Future<void> Function(List<String> titles, bool hidden) setHidden;

  @override
  State<GroupRegionsPanel> createState() => _GroupRegionsPanelState();
}

class _GroupRegionsPanelState extends State<GroupRegionsPanel> {
  // The names don't change while this is open; only shown/hidden does.
  late final List<GroupRegion> _regions =
      GroupRegions.detect([for (final g in widget.groups()) g.title]);

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) {
        final hidden = {
          for (final g in widget.groups())
            if (g.isHidden) g.title
        };
        return GlassMenuDialog(
          title: Text(tr('Countries and prefixes')),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    tr('Found at the start of the group names. Select one to show or hide all its groups at once.'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Flexible(
                  // Every row built: the remote reaches past the viewport.
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, region) in _regions.indexed)
                          _row(context, region, hidden, autofocus: i == 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, GroupRegion region, Set<String> hidden,
      {required bool autofocus}) {
    final total = region.titles.length;
    final shown = region.titles.where((t) => !hidden.contains(t)).length;
    final flag = region.flag;
    final subtitle = [
      total == 1 ? tr('1 group') : tr('{count} groups', {'count': '$total'}),
      if (shown > 0 && shown < total)
        tr('{shown} of {total} shown', {'shown': '$shown', 'total': '$total'}),
      ...region.variants.take(3),
      if (region.variants.length > 3) '…',
    ].join(' · ');
    return TvMenuTile(
      key: ValueKey('region:${region.key}'),
      autofocus: autofocus,
      leading: flag == null
          ? null
          : SizedBox(
              width: 40,
              child: Center(
                  child: Text(flag, style: const TextStyle(fontSize: 24)))),
      icon: region.key.isEmpty
          ? Icons.folder_outlined
          : region.country
              ? Icons.public
              : Icons.label_outline,
      title: region.key.isEmpty ? tr('Groups without a country') : region.key,
      subtitle: subtitle,
      trailing: Icon(
        shown == total
            ? Icons.check_circle
            : shown == 0
                ? Icons.circle_outlined
                : Icons.remove_circle_outline,
        color: shown == 0
            ? Colors.white54
            : Theme.of(context).colorScheme.primary,
      ),
      // All shown = hide them; otherwise show every one.
      onTap: () => widget.setHidden(region.titles, shown == total),
    );
  }
}
