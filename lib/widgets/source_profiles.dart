import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/parental_pin.dart';
import '../services/viewer_profile_service.dart';
import 'glass_menu.dart';
import 'pin_pad.dart';
import 'setting_row.dart';

/// Which profiles get a Media Hub source (owner, 2026-11-24: people
/// sharing a box use different add-ons / Stremio accounts). The "For" row
/// when adding (a link, Import from Stremio) and a source's Profiles row;
/// each profile's own Enabled underneath (`ArchiveService.setSourceProfiles`).
/// Not shown with one profile.
class SourceProfiles {
  SourceProfiles._();

  static bool shown(ViewerProfileService viewers) =>
      viewers.profiles.length > 1;

  /// The usual choice when adding: every regular profile, and the kids
  /// profile in use (one added there is on there).
  static Set<String> usual(ViewerProfileService viewers) => {
        for (final p in viewers.profiles)
          if (!p.isRestricted || p.id == viewers.active.id) p.id,
      };

  static String label(ViewerProfileService viewers, Set<String> ids) {
    final on = [
      for (final p in viewers.profiles)
        if (ids.contains(p.id)) p,
    ];
    if (on.isEmpty) return tr('No profile');
    if (on.length == viewers.profiles.length) return tr('Every profile');
    if (on.length == 1 && on.single.id == viewers.active.id) {
      return tr('Only this profile ({name})', {'name': on.single.displayName});
    }
    return on.map((p) => p.displayName).join(', ');
  }

  /// The picker, starting from [current]; null = cancelled.
  static Future<Set<String>?> pick(BuildContext context, Set<String> current) =>
      showGlassMenu<Set<String>>(
        context: context,
        builder: (_) => _SourceProfilesDialog(current: current),
      );
}

/// The row that shows the choice and opens the picker.
class SourceProfilesRow extends StatelessWidget {
  const SourceProfilesRow({
    super.key,
    required this.title,
    this.profileIds,
    required this.onChanged,
    this.focusNode,
  });

  final String title;

  /// Null = the usual choice ([SourceProfiles.usual]).
  final Set<String>? profileIds;
  final ValueChanged<Set<String>> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    // No profile service (a page on its own in a test) = one profile.
    final viewers = context.watch<ViewerProfileService?>();
    if (viewers == null || !SourceProfiles.shown(viewers)) {
      return const SizedBox.shrink();
    }
    final ids = profileIds ?? SourceProfiles.usual(viewers);
    return SettingRow(
      focusNode: focusNode,
      icon: Icons.people_alt_outlined,
      title: title,
      subtitle: SourceProfiles.label(viewers, ids),
      trailing: const SettingValue(),
      onTap: () async {
        final picked = await SourceProfiles.pick(context, ids);
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _SourceProfilesDialog extends StatefulWidget {
  const _SourceProfilesDialog({required this.current});

  final Set<String> current;

  @override
  State<_SourceProfilesDialog> createState() => _SourceProfilesDialogState();
}

class _SourceProfilesDialogState extends State<_SourceProfilesDialog> {
  late final Set<String> _ids = {...widget.current};

  /// A kids profile gets a source only from a parent: the PIN, unless a
  /// kids profile is in use (its sources page already asked it).
  Future<bool> _mayTurnOnKids() async {
    final viewers = context.read<ViewerProfileService>();
    if (viewers.isActiveRestricted) return true;
    if (!context.read<ParentalPin>().isSet) return true;
    return promptForPin(context);
  }

  Future<void> _toggle(String id, bool restricted, bool on) async {
    if (on && restricted && !await _mayTurnOnKids()) return;
    if (!mounted) return;
    setState(() => on ? _ids.add(id) : _ids.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final viewers = context.watch<ViewerProfileService>();
    final active = viewers.active.id;
    return GlassMenuDialog(
      title: Text(tr('Which profiles get it?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 12, children: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop({active}),
              child: Text(tr('Only this profile')),
            ),
            TextButton(
              onPressed: () async {
                final kids = viewers.profiles
                    .any((p) => p.isRestricted && !_ids.contains(p.id));
                if (kids && !await _mayTurnOnKids()) return;
                if (!context.mounted) return;
                Navigator.of(context)
                    .pop({for (final p in viewers.profiles) p.id});
              },
              child: Text(tr('Every profile')),
            ),
          ]),
          for (final p in viewers.profiles)
            GlassFocusFrame(
              child: CheckboxListTile(
                value: _ids.contains(p.id),
                secondary: Icon(
                    p.isRestricted ? Icons.child_care : Icons.person_outline),
                title: Text(p.displayName),
                subtitle: p.id == active
                    ? Text(tr('This profile'))
                    : p.isRestricted
                        ? Text(tr('Kids profile'))
                        : null,
                onChanged: (v) => _toggle(p.id, p.isRestricted, v == true),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _ids.isEmpty ? null : () => Navigator.of(context).pop({..._ids}),
          child: Text(tr('Done')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
      ],
    );
  }
}
