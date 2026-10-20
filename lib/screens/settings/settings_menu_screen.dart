import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utils/tv_theme.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../services/backup_service.dart';
import 'backup_screen.dart';
import 'check_updates_screen.dart';
import 'epg_settings_screen.dart';
import 'general_settings_screen.dart';
import 'playlist_manager_screen.dart';
import 'profiles_screen.dart';
import 'transfer_screen.dart';
import 'theme_screen.dart';
import 'addons_screen.dart';
import 'archive_sources_screen.dart';
import 'trackers_screen.dart';
import 'tmdb_settings_screen.dart';
import '../../l10n/l10n.dart';

/// Settings entry point — a plain menu of destinations instead of one long
/// scrollable form. Much easier to navigate with a D-pad (a handful of big
/// rows, not a dense form with several text fields packed in), and each
/// destination stays focused on one concern.
///
/// No custom D-pad handling here at all, deliberately — every custom
/// Up/Down interception tried on this app's Settings screens (a
/// `DpadVerticalNav` using `FocusScope.nextFocus()`, then an
/// `ExplicitFocusOrder` using an explicit node list, several dispatch
/// mechanisms) was reported as unreliable on real hardware, while
/// `GroupManagementScreen`'s checkbox lists — which never had any custom
/// Up/Down code — were confirmed working flawlessly on the same remote.
/// Plain Flutter default focus traversal turned out to be the answer all
/// along; every row below is a single, ordinary focusable widget in
/// simple top-to-bottom document order, exactly like that working list.
class SettingsMenuScreen extends StatelessWidget {
  const SettingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: tr('Settings'),
              body: ListView(
                children: [
                  TvMenuTile(
                    icon: Icons.video_library_outlined,
                    title: tr('Playlist Manager'),
                    subtitle:
                        tr('Every playlist: login, groups, enable/disable'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PlaylistManagerScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.people_outline,
                    title: tr('Profiles'),
                    subtitle: tr(
                        'Separate favorites, history & hidden groups per viewer'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfilesScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.tune,
                    title: tr('General'),
                    subtitle: Platform.isWindows
                        ? tr('Language and history')
                        : tr('Language, startup, Multiview and history'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const GeneralSettingsScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.palette_outlined,
                    title: tr('Theme'),
                    subtitle: tr('Clock, accent color, layout'),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemeScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.calendar_month_outlined,
                    title: tr('EPG'),
                    subtitle: tr(
                        'Auto-refresh, channel matching & pairing, clear cache'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const EpgSettingsScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.movie_filter_outlined,
                    title: tr('TMDB (Release Dates)'),
                    subtitle:
                        tr('Optional key for sorting by real release date'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TmdbSettingsScreen())),
                  ),
                  // Online subtitles: both players (Windows' own since
                  // its Subtitles button, desktop_subtitles.dart).
                  TvMenuTile(
                    icon: Icons.extension_outlined,
                    title: tr('Add-ons'),
                    subtitle: tr('Online subtitles in more languages'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AddonsScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.local_movies_outlined,
                    title: tr('Media Hub sources'),
                    subtitle: tr('Add-on sources for the Media Hub tab'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ArchiveSourcesScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.playlist_add_check,
                    title: tr('Trakt & Simkl'),
                    subtitle:
                        tr('Track what you watch, lists in the Media Hub'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TrackersScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.system_update_outlined,
                    title: tr('Check for Updates'),
                    subtitle: tr('Download and install the latest release'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CheckUpdatesScreen())),
                  ),
                  TvMenuTile(
                    icon: Icons.devices,
                    title: tr('Transfer to another device'),
                    subtitle:
                        tr('Copy playlists, favorites and settings over Wi-Fi'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const TransferScreen())),
                  ),
                  if (BackupService.supported)
                    TvMenuTile(
                      icon: Icons.settings_backup_restore,
                      title: tr('Backup & restore'),
                      subtitle: tr('Save everything to a file on this device'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const BackupScreen())),
                    ),
                  // Reads whatever code is actually running via
                  // PackageInfo (same source CheckUpdatesScreen's
                  // "Current version" line uses) rather than a hand-typed
                  // constant — requested directly, after the previous
                  // buildMarker string (a version number plus a long
                  // hand-maintained per-release changelog) was replaced
                  // with just the line below: "so I can confirm easily
                  // the current version inside the app" needed *some*
                  // version stamp back, just not the changelog text.
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
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      tr('Report any bugs or glitches to noxqcx@gmail.com'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  // TMDB's terms ask for this wherever their data/images
                  // show — posters and backdrops come from TMDB's image
                  // CDN even without a key (provider links, upgraded to HD
                  // by hdImageUrl), so it lives here, not only in the
                  // TMDB key screen.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      '${tr('Movie and TV artwork and data may come from TMDB (The Movie Database).')} '
                      '${tr('This product uses the TMDB API but is not endorsed or certified by TMDB.')} '
                      // Credit for the watch trackers (Settings > Trakt &
                      // Simkl), owner 2026-10-19.
                      '${tr('Watch tracking powered by Trakt and Simkl; VesperTV is not affiliated with or endorsed by either.')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ));
  }
}
