import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/backup_service.dart';
import '../services/icloud_backups.dart';
import '../utils/desktop_platform.dart';
import '../utils/tv_theme.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/tv_menu_tile.dart';
import 'settings/backup_screen.dart';
import 'settings/icloud_backups_screen.dart';
import 'settings/sync_screen.dart' show openSyncJoin;
import 'settings/transfer_screen.dart' show transferReceiveRoute;

/// First launch > "From another device" ([WelcomeAddPlaylistScreen]'s third
/// button): the three ways to bring a setup from another device, each
/// opened on its receiving side. BallerMC (Discord, 2026-11-22) installed
/// the Apple TV app and found no way to bring his iPhone's setup over
/// before adding a playlist by hand. Settings > Backup & devices has the
/// same three, built for both sides.
class FromAnotherDeviceScreen extends StatelessWidget {
  const FromAnotherDeviceScreen({super.key});

  /// Apple TV has no files to pick a backup from.
  static bool get offersBackup => BackupService.supported && !isAppleTv;

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('From another device'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                tr('Already use VesperTV on another device? Bring your playlists, favourites and settings here.'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            TvMenuTile(
              autofocus: true,
              icon: Icons.sync,
              title: tr('Sync'),
              subtitle: tr(
                  'Both devices stay up to date. On the other device: Settings > Backup & devices > Sync > Link a device, then enter its code here.'),
              onTap: () => openSyncJoin(Navigator.of(context)),
            ),
            TvMenuTile(
              icon: Icons.download,
              title: tr('Receive a transfer'),
              subtitle: tr(
                  'Copies everything once. On the other device: Settings > Backup & devices > Transfer to another device > Send from this device.'),
              onTap: () => Navigator.of(context).push(transferReceiveRoute()),
            ),
            // iPhone, iPad, Apple TV: the backup another Apple device (or
            // this one, before tvOS cleared its storage) kept in iCloud.
            if (ICloudBackups.supported)
              TvMenuTile(
                icon: Icons.cloud_download_outlined,
                title: tr('Restore from iCloud'),
                subtitle: tr(
                    'From a backup your iPhone, iPad or Apple TV saved to iCloud'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ICloudBackupsScreen())),
              ),
            if (offersBackup)
              TvMenuTile(
                icon: Icons.settings_backup_restore,
                title: tr('Restore a backup'),
                subtitle: tr('From a backup file VesperTV saved'),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
          ],
        ),
      ),
    );
  }
}
