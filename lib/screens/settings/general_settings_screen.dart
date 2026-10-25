import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_preferences.dart';
import '../../services/device_defaults.dart';
import '../../services/playback_service.dart';
import '../../services/recording_service.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/native_video_hole.dart';
import '../../widgets/live_resume_hint.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_dialog_option.dart';
import '../../widgets/tv_menu_tile.dart';
import '../../widgets/tv_switch_list_tile.dart';
import '../../l10n/l10n.dart';

/// Small behaviour switches that don't belong to one feature's own screen —
/// a home for future ones too (planned candidates: start-on tab, default
/// picture fit, preferred audio language, confirm on exit).
/// Multiview is Android only (Windows has its own Multiview without the
/// tip); everything else is shown on every platform. Startup and Tabs are
/// device-wide, not per viewer profile.
///
/// No custom D-pad handling — see SettingsMenuScreen's doc comment.
///
/// Settings' Interface and General categories open it on one section each
/// ([sections] = that id, shown open without its header, [title] = the
/// section's name); null shows every section, collapsible.
class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key, this.sections, this.title});

  final Set<String>? sections;
  final String? title;

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
    ('el', 'Ελληνικά'),
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

  /// Sections open right now (all closed on entry — the screen had grown
  /// into a long scroll).
  final Set<String> _open = {};

  /// [text] plus a note when [setting] is on only because this device is on
  /// the automatic list (DeviceDefaults); the user's own choice drops it.
  String _withAutomatic(BuildContext context, String setting, String text) =>
      context.watch<AppPreferences>().isAutomaticOn(setting)
          ? '$text\n${tr('Automatic: on for this device.')}'
          : text;

  /// One collapsible category: a [TvMenuTile] header (same focus look as
  /// the rest of Settings, so D-pad needs nothing special) that rolls its
  /// [children] open underneath on OK / tap.
  Widget _section(String id, IconData icon, String title,
      {String? subtitle, required List<Widget> children}) {
    final only = widget.sections;
    if (only != null && !only.contains(id)) return const SizedBox.shrink();
    if (only != null && only.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    final open = _open.contains(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvMenuTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more),
          ),
          onTap: () => setState(() => open ? _open.remove(id) : _open.add(id)),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 0, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return withTvThemeIfNeeded(
        context,
        (context) => SettingsScaffold(
              title: widget.title ?? tr('General'),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('language', Icons.translate, tr('Language'),
                      subtitle: _languageLabel(L10n.setting),
                      children: [
                        TvMenuTile(
                          icon: Icons.translate,
                          title: _languageLabel(L10n.setting),
                          subtitle: L10n.setting == 'auto'
                              ? tr('Follows the device language')
                              : null,
                          onTap: _pickLanguage,
                        ),
                        TvSwitchListTile(
                          title: Text(tr('24-hour clock')),
                          subtitle: Text(context.watch<AppPreferences>().use24h
                              ? tr('Times show as 21:30')
                              : tr('Times show as 9:30 PM')),
                          value: context.watch<AppPreferences>().use24h,
                          onChanged: (v) =>
                              context.read<AppPreferences>().setUse24h(v),
                        ),
                      ]),
                  _section('startup', Icons.power_settings_new, tr('Startup'),
                      children: [
                        _StartSectionPicker(),
                        // At most one of the two is on; both off = nothing
                        // plays.
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
                          title: Text(
                              tr('Resume last channel with the guide open')),
                          subtitle: Text(tr(
                              'Plays the last live channel in the small preview, with the channel list.')),
                          value: _resumeInGuide,
                          onChanged: (v) {
                            setState(() {
                              _resumeInGuide = v;
                              if (v) _resumeAtStartup = false;
                            });
                            _storage.setResumeLastChannelInGuide(v);
                            if (v) {
                              _storage.setResumeLastChannelAtStartup(false);
                            }
                          },
                        ),
                        TvSwitchListTile(
                          title: Text(tr('Fast startup')),
                          subtitle: Text(tr(
                              'Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.')),
                          value: context.watch<AppPreferences>().fastStartup,
                          onChanged: (v) =>
                              context.read<AppPreferences>().setFastStartup(v),
                        ),
                        if (!Platform.isWindows)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Text(
                              tr('Both off: nothing plays at startup (a "Hold > to resume" reminder instead).'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ]),
                  _section('tabs', Icons.tab_outlined, tr('Tabs'), children: [
                    TvSwitchListTile(
                      title: Text(tr('Hide Movies')),
                      subtitle: Text(tr(
                          'Removes the Movies tab and movie search results.')),
                      value: context.watch<AppPreferences>().hideMovies,
                      onChanged: (v) =>
                          context.read<AppPreferences>().setHideMovies(v),
                    ),
                    TvSwitchListTile(
                      title: Text(tr('Hide TV Shows')),
                      subtitle: Text(tr(
                          'Removes the TV Shows tab and show search results.')),
                      value: context.watch<AppPreferences>().hideShows,
                      onChanged: (v) =>
                          context.read<AppPreferences>().setHideShows(v),
                    ),
                    TvSwitchListTile(
                      title: Text(tr('Hide Media Hub')),
                      subtitle: Text(tr('Removes the Media Hub tab.')),
                      value: context.watch<AppPreferences>().hideArchive,
                      onChanged: (v) =>
                          context.read<AppPreferences>().setHideArchive(v),
                    ),
                    if (RecordingService.supported)
                      TvSwitchListTile(
                        title: Text(tr('Hide Recordings')),
                        subtitle: Text(tr('Removes the Recordings tab.')),
                        value: context.watch<AppPreferences>().hideRecordings,
                        onChanged: (v) =>
                            context.read<AppPreferences>().setHideRecordings(v),
                      ),
                    TvSwitchListTile(
                      title: Text(tr('Hide Multiview')),
                      subtitle: Text(tr(
                          'Removes the Multiview row and the player\'s Open in Multiview button.')),
                      value: context.watch<AppPreferences>().hideMultiview,
                      onChanged: (v) =>
                          context.read<AppPreferences>().setHideMultiview(v),
                    ),
                  ]),
                  if (!Platform.isWindows)
                    _section('background', Icons.picture_in_picture_alt,
                        tr('Background video'),
                        children: [
                          TvSwitchListTile(
                            title: Text(
                                tr('Hide the live picture behind other pages')),
                            subtitle: Text(_withAutomatic(
                                context,
                                DeviceDefaults.hideVideoOnSports,
                                tr('A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device\'s software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.',
                                    {'tab': AppConstants.sportsTabName}))),
                            value: context
                                .watch<AppPreferences>()
                                .hideVideoOnSports,
                            onChanged: (v) => context
                                .read<AppPreferences>()
                                .setHideVideoOnSports(v),
                          ),
                          if (Platform.isAndroid)
                            TvSwitchListTile(
                              title: Text(tr('Native video surface (beta)')),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr(
                                      'Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.')),
                                  // Live state, so testers can see it's
                                  // really on (English: diagnostic text).
                                  FutureBuilder<String>(
                                    future: NativeVideoSurface.statusLine(),
                                    builder: (context, snap) => Text(
                                        'Status: ${snap.data ?? '…'}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                  ),
                                ],
                              ),
                              value: context
                                  .watch<AppPreferences>()
                                  .nativeVideoSurface,
                              onChanged: (v) {
                                context
                                    .read<AppPreferences>()
                                    .setNativeVideoSurface(v);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(tr(
                                        'Close the app completely and open it again to apply this change.'))));
                              },
                            ),
                        ]),
                  // Android only: Windows plays through media_kit.
                  if (Platform.isAndroid)
                    _section(
                        'audio', Icons.surround_sound_outlined, tr('Audio'),
                        children: [
                          TvSwitchListTile(
                            title:
                                Text(tr('Surround passthrough (Dolby Atmos)')),
                            subtitle: Text(tr(
                                'Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.')),
                            value: context
                                .watch<AppPreferences>()
                                .audioPassthrough,
                            onChanged: (v) => context
                                .read<AppPreferences>()
                                .setAudioPassthrough(v),
                          ),
                        ]),
                  // Android only (DisplayMatch); Windows follows the monitor.
                  if (Platform.isAndroid)
                    _section('display', Icons.tv_outlined, tr('Display'),
                        children: [
                          TvSwitchListTile(
                            title: Text(tr('Match frame rate')),
                            subtitle: Text(tr(
                                'Switches the TV to the video\'s frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don\'t switch again. Leaving the app gives the TV its own setting back.')),
                            value:
                                context.watch<AppPreferences>().matchFrameRate,
                            onChanged: (v) => context
                                .read<AppPreferences>()
                                .setMatchFrameRate(v),
                          ),
                          if (context.watch<AppPreferences>().matchFrameRate)
                            TvSwitchListTile(
                              title:
                                  Text(tr('Only switch between 50 and 60 Hz')),
                              subtitle: Text(tr(
                                  'Films at 24 frames per second keep the current rate, so fewer switches.')),
                              value:
                                  context.watch<AppPreferences>().match5060Only,
                              onChanged: (v) => context
                                  .read<AppPreferences>()
                                  .setMatch5060Only(v),
                            ),
                          TvSwitchListTile(
                            title: Text(tr('Match resolution')),
                            subtitle: Text(tr(
                                'Switches the TV to the video\'s resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.')),
                            value:
                                context.watch<AppPreferences>().matchResolution,
                            onChanged: (v) => context
                                .read<AppPreferences>()
                                .setMatchResolution(v),
                          ),
                        ]),
                  // Windows has no OK info card yet, so no Data pool there.
                  if (!Platform.isWindows)
                    _section(
                        'datapool', Icons.analytics_outlined, tr('Data pool'),
                        children: [
                          TvSwitchListTile(
                            title: Text(tr('Data pool display')),
                            subtitle: Text(tr(
                                'Press OK while a channel, movie or episode plays to open a card with the stream\'s details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.')),
                            value: context.watch<AppPreferences>().dataPool,
                            onChanged: (v) =>
                                context.read<AppPreferences>().setDataPool(v),
                          ),
                        ]),
                  _section('trailers', Icons.movie_outlined, tr('Trailers'),
                      children: [
                        TvSwitchListTile(
                          title: Text(tr('Automatic trailers')),
                          subtitle: Text([
                            tr('Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.'),
                            if (Platform.isAndroid)
                              tr('On Fire TV sticks, the trailer plays full screen.'),
                          ].join(' ')),
                          value: context.watch<AppPreferences>().autoTrailers,
                          onChanged: (v) =>
                              context.read<AppPreferences>().setAutoTrailers(v),
                        ),
                      ]),
                  _section('favourites', Icons.star_outline, tr('Favourites'),
                      children: [
                        TvSwitchListTile(
                          title: Text(tr('Mix playlists in Favourites')),
                          subtitle: Text(tr(
                              'TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.')),
                          value: context
                              .watch<AppPreferences>()
                              .mixFavoritePlaylists,
                          onChanged: (v) => context
                              .read<AppPreferences>()
                              .setMixFavoritePlaylists(v),
                        ),
                      ]),
                  if (!Platform.isWindows)
                    _section('multiview', Icons.grid_view, tr('Multiview'),
                        children: [
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
                        ]),
                  _section('resume', Icons.play_circle_outline,
                      tr('Resume reminder'),
                      children: [
                        TvSwitchListTile(
                          title:
                              Text(tr('Show the "Hold > to resume" reminder')),
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
                      ]),
                  _section('history', Icons.history, tr('History'), children: [
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
                  ]),
                ],
              ),
            ));
  }
}

/// Startup > Open on: TV / Movies / TV Shows / Media Hub / Sports Trak
/// ([AppPreferences.startSection]). One row; OK opens the choices.
class _StartSectionPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final current = prefs.startSection;
    final name = AppPreferences.startSections
        .firstWhere((s) => s.$1 == current,
            orElse: () => AppPreferences.startSections.first)
        .$2;
    return TvMenuTile(
      leading: const Icon(Icons.home_outlined),
      title: tr('Open on'),
      subtitle: tr(
          '{section}. Where the app opens after starting. With "Resume last channel in full screen" on, the channel then plays in the background instead.',
          {'section': tr(name)}),
      onTap: () async {
        final picked = await showDialog<String>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: Text(tr('Open on')),
            children: [
              for (final (id, label) in AppPreferences.startSections)
                TvDialogOption(
                  autofocus: id == current,
                  onPressed: () => Navigator.of(dialogContext).pop(id),
                  child: Row(children: [
                    Icon(id == current
                        ? Icons.check_circle
                        : Icons.circle_outlined),
                    const SizedBox(width: 12),
                    Text(tr(label)),
                  ]),
                ),
            ],
          ),
        );
        if (picked != null) prefs.setStartSection(picked);
      },
    );
  }
}
