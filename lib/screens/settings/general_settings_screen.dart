import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_preferences.dart';
import '../../services/playback_service.dart';
import '../../services/storage_service.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/live_resume_hint.dart';
import '../../widgets/section_label.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../l10n/l10n.dart';

/// Small behaviour switches that don't belong to one feature's own screen —
/// a home for future ones too (planned candidates: start-on tab, default
/// picture fit, preferred audio language, 12/24 h time, confirm on exit).
/// Multiview is Android only (Windows has its own Multiview without the
/// tip); everything else is shown on every platform. Startup and Tabs are
/// device-wide, not per viewer profile.
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
  late bool _resumeInGuide =
      !_resumeAtStartup && _storage.getResumeLastChannelInGuide();
  late bool _showMultiviewTip = !_storage.getMultiviewHideTips();
  late bool _showResumePill = _storage.getShowResumePill();

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
            child: Text(tr('Clear')),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Cancel')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearSearchAndChannelHistory() async {
    if (!await _confirm(tr('Clear search & channel history?'),
        tr('Removes your recent searches and the History list of live channels.'))) {
      return;
    }
    if (!mounted) return;
    final playback = context.read<PlaybackService>();
    await _storage.clearRecentSearches();
    await playback.clearRecentlyPlayed(live: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Search and channel history cleared.'))));
  }

  Future<void> _clearMoviesAndShowsHistory() async {
    if (!await _confirm(tr('Clear Movies & TV Shows history?'),
        tr('Removes Continue Watching and the saved progress of every movie and episode.'))) {
      return;
    }
    if (!mounted) return;
    await context.read<PlaybackService>().clearRecentlyPlayed(live: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Movies & TV Shows history cleared.'))));
  }

  /// Language settings in the picker, in order. A new language = one entry
  /// here (native name, never translated) plus its dictionary in l10n.
  static const _languages = [
    ('auto', ''),
    ('en', 'English'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('it', 'Italiano'),
  ];

  String _languageLabel(String setting) => setting == 'auto'
      ? tr('Automatic')
      : _languages.firstWhere((l) => l.$1 == setting).$2;

  /// One row + a short pop-up list (current one focused) instead of a
  /// button per language, so the row stays small as languages are added.
  Future<void> _pickLanguage() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('Language')),
        children: [
          for (final (code, _) in _languages)
            TvMenuTile(
              autofocus: code == L10n.setting,
              title: _languageLabel(code),
              subtitle:
                  code == 'auto' ? tr('Follows the device language') : null,
              trailing: code == L10n.setting
                  ? Icon(Icons.check,
                      color: Theme.of(dialogContext).colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(code),
            ),
        ],
      ),
    );
    if (picked != null) await _setLanguage(picked);
  }

  /// Back to home first: main.dart remounts home on a language change, but
  /// routes already pushed above it would keep their old-language strings.
  Future<void> _setLanguage(String value) async {
    if (value == L10n.setting || !mounted) return;
    final prefs = context.read<AppPreferences>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await prefs.setLanguage(value);
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: tr('General'),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionLabel(tr('Language')),
                  const SizedBox(height: 4),
                  TvMenuTile(
                    icon: Icons.translate,
                    title: _languageLabel(L10n.setting),
                    subtitle: L10n.setting == 'auto'
                        ? tr('Follows the device language')
                        : null,
                    onTap: _pickLanguage,
                  ),
                  const Divider(height: 32),
                  SectionLabel(tr('Startup')),
                  const SizedBox(height: 4),
                  // At most one of the two is on; both off = nothing plays.
                  TvSwitchListTile(
                    title: Text(tr('Resume last channel in full screen')),
                    subtitle: Text(tr(
                        'Opens the last live channel full screen after the splash.')),
                    value: _resumeAtStartup,
                    onChanged: (v) {
                      setState(() {
                        _resumeAtStartup = v;
                        if (v) _resumeInGuide = false;
                      });
                      _storage.setResumeLastChannelAtStartup(v);
                      if (v) _storage.setResumeLastChannelInGuide(false);
                    },
                  ),
                  TvSwitchListTile(
                    title: Text(tr('Resume last channel with the guide open')),
                    subtitle: Text(tr(
                        'Plays the last live channel in the small preview, with the channel list.')),
                    value: _resumeInGuide,
                    onChanged: (v) {
                      setState(() {
                        _resumeInGuide = v;
                        if (v) _resumeAtStartup = false;
                      });
                      _storage.setResumeLastChannelInGuide(v);
                      if (v) _storage.setResumeLastChannelAtStartup(false);
                    },
                  ),
                  if (!Platform.isWindows)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        tr('Both off: nothing plays at startup (a "Hold > to resume" reminder instead).'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const Divider(height: 32),
                  SectionLabel(tr('Tabs')),
                  const SizedBox(height: 4),
                  TvSwitchListTile(
                    title: Text(tr('Hide Movies and TV Shows')),
                    subtitle: Text(tr(
                        'Removes both tabs and their search results, e.g. if you watch movies and shows elsewhere.')),
                    value: context.watch<AppPreferences>().hideMoviesShows,
                    onChanged: (v) =>
                        context.read<AppPreferences>().setHideMoviesShows(v),
                  ),
                  const Divider(height: 32),
                  if (!Platform.isWindows) ...[
                    SectionLabel(tr('Multiview')),
                    const SizedBox(height: 4),
                    TvSwitchListTile(
                      title: Text(tr('Show the Multiview tip')),
                      subtitle: Text(tr(
                          'The connections reminder shown when opening Multiview.')),
                      value: _showMultiviewTip,
                      onChanged: (v) {
                        setState(() => _showMultiviewTip = v);
                        _storage.setMultiviewHideTips(!v);
                      },
                    ),
                    const Divider(height: 32),
                  ],
                  SectionLabel(tr('Resume reminder')),
                  const SizedBox(height: 4),
                  TvSwitchListTile(
                    title: Text(tr('Show the "Hold > to resume" reminder')),
                    subtitle: Text(Platform.isWindows
                        ? tr(
                            'The pill at the bottom while a channel plays in the background. Off: hidden.')
                        : tr(
                            'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.')),
                    value: _showResumePill,
                    onChanged: (v) {
                      setState(() => _showResumePill = v);
                      LiveResumeHint.pillEnabled.value = v;
                      _storage.setShowResumePill(v);
                    },
                  ),
                  const Divider(height: 32),
                  SectionLabel(tr('History')),
                  const SizedBox(height: 4),
                  TvMenuTile(
                    icon: Icons.manage_search,
                    title: tr('Clear search & channel history'),
                    subtitle:
                        tr('Recent searches and the live channel History'),
                    onTap: _clearSearchAndChannelHistory,
                  ),
                  TvMenuTile(
                    icon: Icons.movie_outlined,
                    title: tr('Clear Movies & TV Shows history'),
                    subtitle: tr('Continue Watching and saved progress'),
                    onTap: _clearMoviesAndShowsHistory,
                  ),
                ],
              ),
            ));
  }
}
