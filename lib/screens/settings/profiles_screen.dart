import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../services/viewer_profile_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/profile_card.dart';
import 'profile_editor_screen.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final viewers = context.watch<ViewerProfileService>();
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
            title: tr('Profiles'),
            body: SingleChildScrollView(
                child: Column(children: [
              for (final (index, profile) in viewers.profiles.indexed)
                TvMenuTile(
                    autofocus: index == 0,
                    leading: ProfilePortrait(
                        profile: profile, width: 44, height: 58),
                    title: profile.displayName,
                    subtitle: profile.isRestricted ? tr('Kids profile') : null,
                    trailing: profile.id == viewers.active.id
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => openProfileEditor(context, profile.id)),
              TvMenuTile(
                  icon: Icons.add,
                  title: tr('Add Profile'),
                  onTap: () async {
                    if (!await viewers.requireUnlock(context) ||
                        !context.mounted) {
                      return;
                    }
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddProfileScreen()));
                  }),
            ]))));
  }
}
