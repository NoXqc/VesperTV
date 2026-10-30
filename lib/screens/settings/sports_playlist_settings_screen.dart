import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../models/playlist_profile.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

class SportsPlaylistSettingsScreen extends StatefulWidget {
  const SportsPlaylistSettingsScreen({super.key});

  @override
  State<SportsPlaylistSettingsScreen> createState() =>
      _SportsPlaylistSettingsScreenState();
}

class _SportsPlaylistSettingsScreenState
    extends State<SportsPlaylistSettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late final List<PlaylistProfile> _playlists;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _selected = _storage.getSportsPreferredPlaylist();
    _playlists = _storage.getPlaylists()
      ..sort((a, b) => a.sortOrderFor('tv').compareTo(b.sortOrderFor('tv')));
  }

  Future<void> _save(String? playlistId) async {
    if (!mounted || _storage.viewerGeneration != _viewer) return;
    setState(() => _selected = playlistId);
    await _storage.setSportsPreferredPlaylist(playlistId);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: tr('Preferred playlist'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(
                'Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.')),
            const SizedBox(height: 12),
            if (_selected != null &&
                !_playlists.any((p) => p.id == _selected && p.enabled)) ...[
              Text(tr(
                  'Your preferred playlist is unavailable or disabled. Other matching playlists will be used.')),
              const SizedBox(height: 12),
            ],
            TvMenuTile(
              key: const ValueKey('sports-playlist-automatic'),
              autofocus: true,
              icon: Icons.playlist_play,
              title: tr('No playlist preference'),
              trailing: Icon(_selected == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () => _save(null),
            ),
            for (final playlist in _playlists)
              TvMenuTile(
                key: ValueKey('sports-playlist-${playlist.id}'),
                icon: Icons.playlist_play,
                title: playlist.name,
                subtitle: playlist.enabled ? null : tr('Disabled'),
                enabled: playlist.enabled,
                trailing: Icon(_selected == playlist.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                onTap: () => _save(playlist.id),
              ),
            if (_playlists.isEmpty) Text(tr('No playlists yet')),
          ],
        ),
      );
}
