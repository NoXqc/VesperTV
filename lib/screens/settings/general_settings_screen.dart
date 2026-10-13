import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/playback_service.dart';
import '../../services/storage_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';

/// Small behaviour switches that don't belong to one feature's own screen —
/// a home for future ones too (planned candidates: start-on tab, default
/// picture fit, preferred audio language, 12/24 h time, confirm on exit).
/// Startup and Multiview are Android only (Windows always resumes the last
/// channel and has its own Multiview without the tip); History is shown on
/// every platform. Everything here applies to the active viewer profile.
///
/// No custom D-pad handling — see SettingsMenuScreen's doc comment.
class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  late final StorageService _storage = context.read<StorageService>();
  late bool _resumeAtStartup = _storage.getResumeLastChannelAtStartup();
  late bool _showMultiviewTip = !_storage.getMultiviewHideTips();

  /// Cancel is focused by default so a stray Select can't wipe anything.
  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearSearchAndChannelHistory() async {
    if (!await _confirm('Clear search & channel history?',
        'Removes your recent searches and the History list of live channels.')) {
      return;
    }
    if (!mounted) return;
    final playback = context.read<PlaybackService>();
    await _storage.clearRecentSearches();
    await playback.clearRecentlyPlayed(live: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search and channel history cleared.')));
  }

  Future<void> _clearMoviesAndShowsHistory() async {
    if (!await _confirm(
        'Clear Movies & TV Shows history?',
        'Removes Continue Watching and the saved progress of every movie and '
            'episode.')) {
      return;
    }
    if (!mounted) return;
    await context.read<PlaybackService>().clearRecentlyPlayed(live: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movies & TV Shows history cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: 'General',
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!Platform.isWindows) ...[
                    const SectionLabel('Startup'),
                    const SizedBox(height: 4),
                    TvSwitchListTile(
                      title: const Text('Resume last channel at startup'),
                      subtitle: const Text(
                          'Opens the last live channel full screen after the '
                          'splash. Off: a "Hold > to resume" reminder instead.'),
                      value: _resumeAtStartup,
                      onChanged: (v) {
                        setState(() => _resumeAtStartup = v);
                        _storage.setResumeLastChannelAtStartup(v);
                      },
                    ),
                    const Divider(height: 32),
                    const SectionLabel('Multiview'),
                    const SizedBox(height: 4),
                    TvSwitchListTile(
                      title: const Text('Show the Multiview tip'),
                      subtitle: const Text(
                          'The connections reminder shown when opening '
                          'Multiview.'),
                      value: _showMultiviewTip,
                      onChanged: (v) {
                        setState(() => _showMultiviewTip = v);
                        _storage.setMultiviewHideTips(!v);
                      },
                    ),
                    const Divider(height: 32),
                  ],
                  const SectionLabel('History'),
                  const SizedBox(height: 4),
                  TvMenuTile(
                    icon: Icons.manage_search,
                    title: 'Clear search & channel history',
                    subtitle: 'Recent searches and the live channel History',
                    onTap: _clearSearchAndChannelHistory,
                  ),
                  TvMenuTile(
                    icon: Icons.movie_outlined,
                    title: 'Clear Movies & TV Shows history',
                    subtitle: 'Continue Watching and saved progress',
                    onTap: _clearMoviesAndShowsHistory,
                  ),
                ],
              ),
            ));
  }
}
