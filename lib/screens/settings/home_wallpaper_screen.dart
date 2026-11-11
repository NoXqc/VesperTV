import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/home_wallpaper.dart';
import '../../services/phone_pairing_service.dart';
import '../../services/storage_service.dart';
import '../../services/viewer_profile_service.dart';
import '../../widgets/profile_photo_actions.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

/// Settings > General > Home wallpaper: the viewer's own picture behind
/// Home (see [HomeWallpaper]). A preview of the current one, then the
/// profile-photo buttons: from the phone (QR, Wi-Fi), Choose a photo on a
/// computer / phone, Remove. With a picture set, a switch also shows it
/// behind Who's watching while this viewer's card is highlighted (owner,
/// 2026-11-10).
class HomeWallpaperScreen extends StatefulWidget {
  const HomeWallpaperScreen({super.key});

  @override
  State<HomeWallpaperScreen> createState() => _HomeWallpaperScreenState();
}

class _HomeWallpaperScreenState extends State<HomeWallpaperScreen> {
  Uint8List? _current;
  final _first = FocusNode(debugLabel: 'wallpaper first');
  late final String _viewer = context.read<ViewerProfileService>().active.id;
  late final StorageService _storage = context.read<StorageService>();
  late bool _onProfiles = _storage.getWallpaperOnProfiles();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final bytes = await HomeWallpaper.instance.load(_viewer);
    if (mounted) setState(() => _current = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return SettingsScaffold(
      title: tr('Home wallpaper'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Shows behind Home when the card you are on has no picture of its own, instead of the live channels\' colours.')),
          const SizedBox(height: 16),
          if (current != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(current,
                        key: ValueKey(current),
                        fit: BoxFit.cover,
                        cacheWidth: 840,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr('On: your picture shows behind Home.'),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
          ],
          ProfilePhotoActions(
            kind: PairingKind.wallpaper,
            autofocus: true,
            firstFocusNode: _first,
            maxBytes: HomeWallpaper.maxBytes,
            errorText: tr(
                'Could not read the picture. Choose a JPEG or PNG under 15 MB.'),
            hasPhoto: current != null,
            onPhoto: (bytes) async {
              await HomeWallpaper.instance.save(_viewer, bytes);
              await _refresh();
            },
            onRemove: () async {
              await HomeWallpaper.instance.remove(_viewer);
              await _refresh();
              // Remove is gone: give the remote the first button.
              if (mounted) _first.requestFocus();
            },
          ),
          if (current != null) ...[
            const SizedBox(height: 16),
            TvSwitchListTile(
              title: Text(tr('Also behind "Who is watching?"')),
              subtitle: Text(tr(
                  'Shows while your profile is highlighted. Needs Launch with profiles selector (Settings > Profiles).')),
              value: _onProfiles,
              onChanged: (value) {
                setState(() => _onProfiles = value);
                _storage.setWallpaperOnProfiles(value);
              },
            ),
          ],
        ],
      ),
    );
  }
}
