import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/app_preferences.dart';
import '../../services/archive_service.dart';
import '../../services/audio_delay.dart';
import '../../services/backup_service.dart';
import '../../services/desktop_mini_player.dart';
import '../../services/desktop_stream_setup.dart';
import '../../services/device_defaults.dart';
import '../../services/launcher_channels.dart';
import '../../services/playback_service.dart';
import '../../services/recording_service.dart';
import '../../services/remote_buttons.dart';
import '../../services/storage_service.dart';
import '../../services/subtitle_tracks.dart';
import '../../services/vod_buffering.dart';
import '../../utils/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/desktop_platform.dart';
import '../../widgets/audio_delay_adjuster.dart';
import '../../widgets/goal_overlay_probe_settings.dart';
import '../../widgets/goals_alert_overlay.dart';
import '../../widgets/live_buffer_picker.dart';
import '../../widgets/download_sheet.dart';
import '../../widgets/live_resume_hint.dart';
import '../../utils/time_format.dart';
import '../../services/vesper_ai/vesper_ai.dart';
import '../vesper_ai/phone_mic_sheet.dart';
import 'addons_screen.dart';
import 'archive_posters_screen.dart';
import 'archive_sources_screen.dart';
import 'backup_screen.dart';
import 'check_updates_screen.dart';
import 'community_screen.dart';
import 'debrid_settings_screen.dart';
import 'epg_settings_screen.dart';
import 'home_wallpaper_screen.dart';
import 'network_folder_screen.dart';
import 'playlist_editor_screen.dart';
import 'playlist_manager_screen.dart';
import 'profiles_screen.dart';
import 'add_playlist_screen.dart';
import 'remote_buttons_screen.dart';
import 'remote_tips_screen.dart';
import 'send_log_screen.dart';
import 'sports_country_settings_screen.dart';
import 'support_screen.dart';
import 'sync_screen.dart';
import 'tmdb_settings_screen.dart';
import 'trackers_screen.dart';
import 'transfer_screen.dart';
import 'vesper_ai_settings_screen.dart';

/// One row of a Settings category. [title] stays short, [subtitle] is one
/// line at most, and [help] (the full explanation) shows under the list
/// while the row has focus (owner, 2026-11-10: Settings that a newcomer
/// can read at a glance).
sealed class SettingsItem {
  const SettingsItem(
      {required this.id,
      required this.icon,
      required this.title,
      this.subtitle,
      this.help});

  /// Stable, for tests and (later) search.
  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? help;
}

/// Opens its own page: a real tool (playlists, profiles, guide matching).
class SettingsLink extends SettingsItem {
  const SettingsLink(
      {required super.id,
      required super.icon,
      required super.title,
      super.subtitle,
      super.help,
      required this.page,
      this.value,
      this.floating = false});

  final WidgetBuilder page;
  final String? value;

  /// A short page (a form, a QR code): a glass panel over Settings on a TV
  /// box or computer instead of a page of its own ([openSettingsPage]).
  final bool floating;
}

/// An on/off setting: OK flips it in place.
class SettingsToggle extends SettingsItem {
  const SettingsToggle(
      {required super.id,
      required super.icon,
      required super.title,
      super.subtitle,
      super.help,
      required this.value,
      required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;
}

class SettingsOption {
  const SettingsOption(this.value, this.label, {this.subtitle, this.dimmed});

  final String value;
  final String label;
  final String? subtitle;
  final bool? dimmed;
}

/// One of a few values: OK rolls the choices down beside the row. With
/// [onStep], Left/Right also move through them while the row has focus.
class SettingsChoice extends SettingsItem {
  const SettingsChoice(
      {required super.id,
      required super.icon,
      required super.title,
      super.subtitle,
      super.help,
      required this.options,
      required this.selected,
      required this.onPick,
      this.onStep,
      this.valueText});

  final List<SettingsOption> options;
  final String selected;
  final ValueChanged<String> onPick;
  final ValueChanged<int>? onStep;

  /// Shown instead of the picked option's label (a value between options).
  final String? valueText;

  String get valueLabel =>
      valueText ??
      options.where((o) => o.value == selected).firstOrNull?.label ??
      '';
}

/// Does something (clear history, a test popup, a dialog of its own).
class SettingsAction extends SettingsItem {
  const SettingsAction(
      {required super.id,
      required super.icon,
      required super.title,
      super.subtitle,
      super.help,
      required this.run,
      this.value});

  final Future<void> Function(BuildContext context) run;
  final String? value;
}

/// A widget of its own inside the list (the Goals alert overlay probe, the
/// version footer).
class SettingsCustom extends SettingsItem {
  const SettingsCustom({required super.id, required this.builder})
      : super(icon: Icons.circle, title: '');

  final WidgetBuilder builder;
}

class SettingsSection {
  const SettingsSection(this.items, {this.title, this.highlight = false});

  final String? title;
  final List<SettingsItem> items;

  /// Drawn as a gold-edged card (Start here).
  final bool highlight;
}

class SettingsCategory {
  const SettingsCategory(
      {required this.id,
      required this.icon,
      required this.title,
      required this.description,
      required this.sections,
      this.advanced = false});

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final List<SettingsSection> sections;

  /// Shown last, after a divider: fixes and tools most people never need.
  final bool advanced;

  Iterable<SettingsItem> get items => sections.expand((s) => s.items);
}

/// Every Settings category and row, read fresh on each build (values come
/// straight from [AppPreferences] / [StorageService]). Same keys and
/// defaults as before the 2026-11-10 rework: only where things live and how
/// they look changed. [refresh] rebuilds the screen after a row that saves
/// to storage only (no [AppPreferences] notification).
class SettingsCatalog {
  SettingsCatalog(this.context,
      {required this.refresh, this.nativeStatus, this.volumes = const []});

  final BuildContext context;
  final VoidCallback refresh;

  /// The native video surface's live state, for its help line (testers).
  final String? nativeStatus;

  /// Where recordings / downloads can go (loaded by the screen: async).
  final List<RecordingVolume> volumes;

  AppPreferences get _prefs => context.read<AppPreferences>();
  StorageService get _storage => _prefs.storage;

  /// Language settings in the picker, in order (native names, never
  /// translated).
  static const languages = [
    ('auto', ''),
    ('en', 'English'),
    ('fr', 'Français'),
    ('es', 'Español'),
    ('it', 'Italiano'),
    ('el', 'Ελληνικά'),
    ('de', 'Deutsch'),
    ('pl', 'Polski'),
  ];

  static String languageLabel(String setting) => setting == 'auto'
      ? tr('Automatic')
      : languages.firstWhere((l) => l.$1 == setting).$2;

  /// The viewer these rows were read for ([_saveViewer]).
  int _viewer = -1;

  List<SettingsCategory> build() {
    final prefs = context.watch<AppPreferences>();
    _viewer = _storage.viewerGeneration;
    return [
      _sources(),
      _appearance(prefs),
      _playback(prefs),
      _sports(prefs),
      _profiles(prefs),
      if (RecordingService.downloadsSupported) _recordings(),
      _vesper(),
      _devices(),
      _help(),
      _advanced(prefs),
    ];
  }

  // ---------------------------------------------------------------- sources

  SettingsCategory _sources() => SettingsCategory(
        id: 'sources',
        icon: Icons.video_library_outlined,
        title: tr('Playlists & sources'),
        description: tr('Where your channels, movies and shows come from.'),
        sections: [
          // Until the first playlist: the three things a newcomer needs.
          if (_storage.getPlaylists().isEmpty)
            SettingsSection(title: tr('Start here'), highlight: true, [
              SettingsLink(
                  id: 'start_add_playlist',
                  icon: Icons.add_circle_outline,
                  title: tr('Add Playlist'),
                  subtitle: tr('An M3U link or an Xtream Codes login'),
                  page: (_) => const AddPlaylistScreen()),
              _languageChoice('start_language', _prefs),
              _paletteChoice('start_palette', _prefs),
            ]),
          SettingsSection([
            SettingsLink(
                id: 'playlists',
                icon: Icons.video_library_outlined,
                title: tr('Playlist Manager'),
                subtitle: tr('Every playlist: login, groups, enable/disable'),
                page: (_) => const PlaylistManagerScreen()),
            SettingsLink(
                id: 'epg',
                icon: Icons.calendar_month_outlined,
                title: tr('TV guide (EPG)'),
                subtitle:
                    tr('Auto-refresh, channel matching & pairing, clear cache'),
                page: (_) => const EpgSettingsScreen()),
            SettingsLink(
                id: 'hub_sources',
                icon: Icons.local_movies_outlined,
                title: tr('Media Hub sources'),
                subtitle: tr('Add-on sources for the Media Hub tab'),
                page: (_) => const ArchiveSourcesScreen()),
            SettingsLink(
                id: 'trackers',
                floating: true,
                icon: Icons.playlist_add_check,
                title: tr('Trakt & Simkl'),
                subtitle: tr('Track what you watch, lists in the Media Hub'),
                page: (_) => const TrackersScreen()),
            // Online subtitles: both players (Windows' own since its
            // Subtitles button, desktop_subtitles.dart).
            SettingsLink(
                id: 'addons',
                floating: true,
                icon: Icons.subtitles_outlined,
                title: tr('Online subtitles'),
                subtitle: tr('Online subtitles in more languages'),
                page: (_) => const AddonsScreen()),
            SettingsLink(
                id: 'playlist_editor',
                floating: true,
                icon: Icons.edit_note,
                title: tr('Playlist editor (Test flight)'),
                subtitle: tr(
                    'Rename, hide copies, fallbacks and stream test, from your phone or PC'),
                page: (_) => const PlaylistEditorScreen()),
          ]),
        ],
      );

  // ------------------------------------------------------------- appearance

  SettingsCategory _appearance(AppPreferences prefs) {
    final timeline = prefs.guideViewMode == 'timeline';
    return SettingsCategory(
      id: 'appearance',
      icon: Icons.palette_outlined,
      title: tr('Appearance'),
      description: tr('Colours, language, Home, tabs and how lists look.'),
      sections: [
        SettingsSection(title: tr('Look'), [
          _paletteChoice('palette', prefs),
          SettingsToggle(
              id: 'refined_finish',
              icon: Icons.auto_awesome_outlined,
              title: tr('Refined finish'),
              help: tr(
                  'Glossy surfaces, reflections and blur. Uses more graphics resources.'),
              value: prefs.refinedFinish,
              onChanged: prefs.setRefinedFinish),
          SettingsChoice(
              id: 'ui_size',
              icon: Icons.format_size,
              title: tr('Interface size'),
              help: tr(
                  'Compact fits more on screen. Large has bigger text and rows, easier to read. Just for this profile.'),
              options: [
                SettingsOption('compact', tr('Compact')),
                SettingsOption('normal', tr('Normal')),
                SettingsOption('large', tr('Large')),
              ],
              selected: prefs.uiSize,
              onPick: prefs.setUiSize),
          SettingsChoice(
              id: 'layout',
              icon: Icons.devices_outlined,
              title: tr('Layout'),
              help: tr(
                  'Auto picks phone vs TV layout by screen size — force one if your box isn\'t detected correctly.'),
              options: [
                SettingsOption('auto', tr('Auto')),
                SettingsOption('tv', tr('TV')),
              ],
              selected: prefs.layoutMode,
              onPick: prefs.setLayoutMode),
        ]),
        SettingsSection(title: tr('Language and clock'), [
          _languageChoice('language', prefs),
          SettingsToggle(
              id: 'clock_24h',
              icon: Icons.schedule,
              title: tr('24-hour clock'),
              subtitle: prefs.use24h
                  ? tr('Times show as 21:30')
                  : tr('Times show as 9:30 PM'),
              value: prefs.use24h,
              onChanged: prefs.setUse24h),
          SettingsToggle(
              id: 'show_clock',
              icon: Icons.access_time,
              title: tr('Show clock'),
              subtitle: tr('Displays the current time in the top bar'),
              value: prefs.showClock,
              onChanged: prefs.setShowClock),
        ]),
        SettingsSection(title: tr('Home'), [
          SettingsLink(
              id: 'wallpaper',
              floating: true,
              icon: Icons.wallpaper,
              title: tr('Home wallpaper'),
              subtitle: tr('A picture of your own behind Home.'),
              help: tr(
                  'A picture of your own behind Home and Settings, just for this profile.'),
              page: (_) => const HomeWallpaperScreen()),
          if (!_isPhone(prefs))
            SettingsToggle(
                id: 'home_mini_player',
                icon: Icons.picture_in_picture_outlined,
                title: tr('Mini player on Home'),
                help: tr(
                    'OK on a live card plays it at the top right of Home, OK again opens it full screen (with Preview on highlight on, the card you stop on plays by itself). Play/Pause or hold OK turns it off.'),
                value: prefs.homeMiniPlayer,
                onChanged: prefs.setHomeMiniPlayer),
          SettingsToggle(
              id: 'home_profiles',
              icon: Icons.groups_outlined,
              title: tr('Profiles row on Home'),
              help: tr('The profile cards at the top of Home.'),
              value: !prefs.hideProfiles,
              onChanged: (v) => prefs.setHideProfiles(!v)),
        ]),
        SettingsSection(title: tr('Tabs'), [
          _tab(
              'tab_live',
              Icons.live_tv_outlined,
              tr('Live TV'),
              tr('Removes the Live TV tab.'),
              !prefs.hideLiveTv,
              (v) => prefs.setHideLiveTv(!v)),
          _tab(
              'tab_movies',
              Icons.movie_outlined,
              tr('Movies'),
              tr('Removes the Movies tab and movie search results.'),
              !prefs.hideMovies,
              (v) => prefs.setHideMovies(!v)),
          _tab(
              'tab_shows',
              Icons.tv_outlined,
              tr('TV Shows'),
              tr('Removes the TV Shows tab and show search results.'),
              !prefs.hideShows,
              (v) => prefs.setHideShows(!v)),
          _tab(
              'tab_sports',
              Icons.sports_outlined,
              AppConstants.sportsTabName,
              tr('Removes Sports Trak from navigation and turns off Sports Mode.'),
              !prefs.hideSportsTrak,
              (v) => prefs.setHideSportsTrak(!v)),
          _tab(
              'tab_hub',
              Icons.local_movies_outlined,
              tr('Media Hub'),
              tr('Removes the Media Hub tab.'),
              !prefs.hideArchive,
              (v) => prefs.setHideArchive(!v)),
          if (RecordingService.downloadsSupported)
            _tab(
                'tab_recordings',
                RecordingService.supported
                    ? Icons.fiber_smart_record_outlined
                    : Icons.download_outlined,
                RecordingService.supported ? tr('Recordings') : tr('Downloads'),
                RecordingService.supported
                    ? tr('Removes the Recordings tab.')
                    : tr('Removes the Downloads tab.'),
                !prefs.hideRecordings,
                (v) => prefs.setHideRecordings(!v)),
          _tab(
              'tab_multiview',
              Icons.grid_view,
              tr('Multiview'),
              tr('Removes the Multiview row and the player\'s Open in Multiview button.'),
              !prefs.hideMultiview,
              (v) => prefs.setHideMultiview(!v)),
          if (Platform.isAndroid && prefs.isTelevision)
            SettingsToggle(
                id: 'launcher_rows',
                icon: Icons.home_outlined,
                title: tr('Show on the TV home screen'),
                help: tr(
                    "Continue watching and your Watch list in the launcher's Watch Next row, plus a row of your favourite channels. For Android TV launchers such as Projectivy."),
                value: prefs.launcherRows,
                onChanged: (v) {
                  prefs.setLauncherRows(v);
                  unawaited(LauncherChannels.instance.publish(force: true));
                }),
        ]),
        SettingsSection(title: tr('Live TV'), [
          SettingsChoice(
              id: 'guide_style',
              icon: Icons.view_timeline_outlined,
              title: tr('Guide'),
              help: tr(
                  'Timeline shows every channel at once, on a scrollable schedule grid, instead of one channel\'s now/next at a time.'),
              options: [
                SettingsOption('live', tr('Live')),
                SettingsOption('timeline', tr('Timeline')),
              ],
              selected: prefs.guideViewMode,
              onPick: prefs.setGuideViewMode),
          // Remote and keyboard only: a touch screen has no highlight to
          // follow (a tap already previews).
          if (prefs.isTelevision || isDesktopTarget)
            SettingsToggle(
                id: 'preview_on_highlight',
                icon: Icons.visibility_outlined,
                title: tr('Preview on highlight'),
                help: tr(
                    "The channel you stop on plays in the preview and in Home's mini player, without pressing OK. OK again opens it full screen."),
                value: prefs.guideFocusPreview,
                onChanged: prefs.setGuideFocusPreview),
          if (timeline)
            SettingsToggle(
                id: 'compact_guide',
                icon: Icons.density_medium,
                title: tr('Compact guide'),
                help: tr(
                    'Shorter Timeline rows so more channels fit in the same space.'),
                value: prefs.guideCompact,
                onChanged: prefs.setGuideCompact),
          // Android only for now — Windows' preview runs on its own
          // media_kit player and isn't wired for this yet.
          if (timeline && !isDesktopTarget) ...[
            SettingsToggle(
                id: 'guide_full_video',
                icon: Icons.fullscreen,
                title: tr('Full-screen video behind the guide'),
                help: tr(prefs.guideExpanded
                    ? 'The live channel fills the screen behind a see-through guide'
                    : 'The live channel fills the screen behind a see-through guide showing 3 rows'),
                value: prefs.guideFullVideo,
                onChanged: prefs.setGuideFullVideo),
            if (prefs.guideFullVideo) ...[
              SettingsChoice(
                  id: 'guide_transparency',
                  icon: Icons.opacity,
                  title: tr('Guide transparency'),
                  help: tr('0% is solid; 100% is clear.'),
                  options: [
                    for (var p = 0; p <= 100; p += 10)
                      SettingsOption('$p', tr('{percent}%', {'percent': '$p'})),
                  ],
                  selected: '${prefs.guideTransparency}',
                  // Left/Right step by 5, between the menu's 10s.
                  valueText: tr(
                      '{percent}%', {'percent': '${prefs.guideTransparency}'}),
                  onPick: (v) => prefs.setGuideTransparency(int.parse(v)),
                  onStep: (dir) => prefs.setGuideTransparency(
                      (prefs.guideTransparency + 5 * dir).clamp(0, 100))),
              SettingsToggle(
                  id: 'guide_expanded',
                  icon: Icons.unfold_more,
                  title: tr('Expand'),
                  help: tr('Fill the screen with the Timeline guide'),
                  value: prefs.guideExpanded,
                  onChanged: prefs.setGuideExpanded),
            ],
          ],
          SettingsToggle(
              id: 'group_counts',
              icon: Icons.pin_outlined,
              title: tr('Show group counts'),
              help: tr(
                  'How many channels, movies or shows each group holds, beside its name.'),
              value: prefs.showGroupCounts,
              onChanged: prefs.setShowGroupCounts),
          SettingsToggle(
              id: 'recent_channels',
              icon: Icons.fiber_new_outlined,
              title: tr('Recently added channels'),
              help: tr(
                  'Adds a TV tab group with the channels your playlists added in the last 14 days.'),
              value: prefs.recentChannelsGroup,
              onChanged: prefs.setRecentChannelsGroup),
          if (!isDesktop)
            SettingsToggle(
                id: 'catchup_group',
                icon: Icons.history_toggle_off,
                title: tr('Catch-up group'),
                help: tr(
                    'The TV tab\'s Catch-up row (every channel you can replay).'),
                value: !prefs.hideCatchupGroup,
                onChanged: (v) => prefs.setHideCatchupGroup(!v)),
          SettingsToggle(
              id: 'mix_favourites',
              icon: Icons.star_outline,
              title: tr('Mix playlists in Favourites'),
              help: tr(
                  'TV, Movies and TV Shows favourites from every playlist in one A-Z list, instead of one list per playlist.'),
              value: prefs.mixFavoritePlaylists,
              onChanged: prefs.setMixFavoritePlaylists),
        ]),
        SettingsSection(title: tr('Movies & TV Shows'), [
          SettingsToggle(
              id: 'wide_cards',
              icon: Icons.crop_16_9,
              title: tr('Wide cards'),
              help: tr(
                  'Movies and TV Shows rows show bigger 16:9 cards with the backdrop. A title without one shows its poster until the provider sends it.'),
              value: prefs.wideCards,
              onChanged: prefs.setWideCards),
          SettingsToggle(
              id: 'expanded_browse',
              icon: Icons.grid_view,
              title: tr('Open groups as expanded catalog'),
              help: tr(
                  'Movies and TV Shows groups open the full poster grid instead of the rows.'),
              value: prefs.expandedBrowse,
              onChanged: prefs.setExpandedBrowse),
        ]),
      ],
    );
  }

  SettingsChoice _paletteChoice(String id, AppPreferences prefs) =>
      SettingsChoice(
          id: id,
          icon: Icons.palette_outlined,
          title: tr('Theme color'),
          help: tr(
              'The colour of the focus outline, the selected tab and badges. Each profile has its own.'),
          options: [
            for (final p in AppConstants.cyberpunkPalettes)
              SettingsOption(p.id, tr(p.label)),
          ],
          selected: prefs.palette.id,
          onPick: (id) => prefs.setPalette(
              AppConstants.cyberpunkPalettes.firstWhere((p) => p.id == id)));

  SettingsChoice _languageChoice(String id, AppPreferences prefs) =>
      SettingsChoice(
          id: id,
          icon: Icons.translate,
          title: tr('Language'),
          help: tr('Follows the device language'),
          options: [
            for (final (code, _) in languages)
              SettingsOption(code, languageLabel(code),
                  subtitle: code == 'auto'
                      ? tr('Follows the device language')
                      : null),
          ],
          selected: prefs.language,
          onPick: _setLanguage);

  SettingsToggle _tab(String id, IconData icon, String title, String help,
          bool shown, ValueChanged<bool> onChanged) =>
      SettingsToggle(
          id: id,
          icon: icon,
          title: title,
          help: help,
          value: shown,
          onChanged: onChanged);

  /// A phone (no remote, no Home mini player).
  bool _isPhone(AppPreferences prefs) =>
      !prefs.isTelevision && !isDesktopTarget;

  /// Back to home first: main.dart remounts home on a language change, but
  /// routes already pushed above it would keep their old-language strings.
  Future<void> _setLanguage(String value) async {
    if (value == L10n.setting) return;
    final prefs = _prefs;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await prefs.setLanguage(value);
  }

  // --------------------------------------------------------------- playback

  SettingsCategory _playback(AppPreferences prefs) {
    final player = Platform.isAndroid || usesMediaKit;
    final audio = _storage.getPreferredAudioLanguage();
    final subtitles = _storage.getPreferredSubtitleLanguage();
    final archive = context.watch<ArchiveService?>();
    return SettingsCategory(
      id: 'playback',
      icon: Icons.play_circle_outline,
      title: tr('Playback'),
      description:
          tr('Video, audio, subtitles, trailers and player behaviour.'),
      sections: [
        // Windows: the same settings through mpv (DesktopAudio).
        if (player)
          SettingsSection(title: tr('Audio & subtitles'), [
            SettingsChoice(
                id: 'audio_language',
                icon: Icons.record_voice_over_outlined,
                title: tr('Preferred audio language'),
                help: tr(
                    'Movies and episodes use these languages when available. Your manual track choices take priority when resuming.'),
                options: [
                  SettingsOption('', tr('Source default')),
                  for (final code in trackLanguages)
                    SettingsOption(code, languageName(code)),
                ],
                selected: audio,
                onPick: (v) =>
                    _saveViewer(() => _storage.setPreferredAudioLanguage(v))),
            SettingsChoice(
                id: 'subtitle_language',
                icon: Icons.subtitles_outlined,
                title: tr('Preferred subtitle language'),
                help: tr(
                    'Movies and episodes use these languages when available. Your manual track choices take priority when resuming.'),
                options: [
                  SettingsOption('off', tr('Off')),
                  for (final code in trackLanguages)
                    SettingsOption(code, languageName(code)),
                ],
                selected: subtitles,
                onPick: (v) => _saveViewer(
                    () => _storage.setPreferredSubtitleLanguage(v))),
            SettingsAction(
                id: 'audio_delay',
                icon: Icons.av_timer,
                title: tr('Audio delay'),
                value: AudioDelay.label(prefs.audioDelayMs),
                help: tr(
                    'For sound that is ahead of or behind the picture. Also in the player: Audio sync.'),
                run: showAudioDelayAdjuster),
            SettingsToggle(
                id: 'audio_passthrough',
                icon: Icons.surround_sound_outlined,
                title: tr('Surround passthrough (Dolby Atmos)'),
                help: tr(
                    'Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1 first, so Atmos is lost. While on, the volume of that sound is set on your TV or receiver only, and if you hear nothing on a channel, turn this off. Multiview always uses plain sound (passthrough there kept muted screens playing). Applies from the next channel.'),
                value: prefs.audioPassthrough,
                onChanged: prefs.setAudioPassthrough),
          ]),
        // Android only (DisplayMatch); Windows follows the monitor.
        if (Platform.isAndroid)
          SettingsSection(title: tr('Frame rate & resolution'), [
            SettingsToggle(
                id: 'match_frame_rate',
                icon: Icons.slow_motion_video,
                title: tr('Match frame rate'),
                help: tr(
                    'Switches the TV to the video\'s frame rate a few seconds after it starts (50 Hz for UK and European channels, 24 Hz for films), for smooth motion. The screen goes black for a second or two while the TV switches; channels with the same rate don\'t switch again. Leaving the app gives the TV its own setting back.'),
                value: prefs.matchFrameRate,
                onChanged: prefs.setMatchFrameRate),
            if (prefs.matchFrameRate)
              SettingsToggle(
                  id: 'match_50_60',
                  icon: Icons.swap_vert,
                  title: tr('Only switch between 50 and 60 Hz'),
                  help: tr(
                      'Films at 24 frames per second keep the current rate, so fewer switches.'),
                  value: prefs.match5060Only,
                  onChanged: prefs.setMatch5060Only),
            SettingsToggle(
                id: 'match_resolution',
                icon: Icons.hd_outlined,
                title: tr('Match resolution'),
                help: tr(
                    'Switches the TV to the video\'s resolution (1080p, 4K…) so the TV does the upscaling. Off: this device scales every video to its current resolution.'),
                value: prefs.matchResolution,
                onChanged: prefs.setMatchResolution),
          ]),
        if (player)
          SettingsSection(title: tr('TV Shows'), [
            SettingsChoice(
                id: 'up_next',
                icon: Icons.queue_play_next,
                title: tr('Play the next episode'),
                help: tr(
                    'On TV show episodes, the Up Next card counts down and the next episode starts by itself. Never: no countdown; the episode plays to its end.'),
                options: [
                  SettingsOption('early', tr('30 seconds before the end')),
                  SettingsOption('end', tr('When the episode ends')),
                  SettingsOption('off', tr('Never')),
                ],
                selected: _storage.getUpNextMode(),
                onPick: (v) => _save(() => _storage.setUpNextMode(v))),
            SettingsToggle(
                id: 'skip_intro',
                icon: Icons.skip_next_outlined,
                title: tr('Skip intro and credits button'),
                help: tr(
                    'On TV show episodes, a button skips the intro, the recap and the credits (or plays the next episode). Press OK while it shows. Times come from IntroDB (introdb.app), a free community database: it is asked with the show\'s IMDb id, season and episode number, nothing else.'),
                value: _storage.getSkipSegments(),
                onChanged: (v) => _save(() => _storage.setSkipSegments(v))),
          ]),
        if (player)
          SettingsSection(title: tr('Live TV'), [
            SettingsChoice(
                id: 'live_buffer',
                icon: Icons.network_check,
                title: tr('Live buffer'),
                help: tr(
                    '{size}. Live channels store this much before playing, so short dropouts from the server don\'t show. Bigger hides longer dropouts, but channels start later and play that much behind live. Applies from the next channel.',
                    {'size': tr(liveBufferName(_storage.getLiveBufferMs()))}),
                options: [
                  for (final (ms, label) in liveBufferChoices())
                    SettingsOption('$ms', tr(label)),
                ],
                selected: '${_storage.getLiveBufferMs()}',
                onPick: (v) => _save(() async {
                      final ms = int.parse(v);
                      await _storage.setLiveBufferMs(ms);
                      await VodBuffering.setLiveBufferDefault(ms);
                    })),
            SettingsToggle(
                id: 'catchup_keep_playing',
                icon: Icons.history_toggle_off,
                title: tr('Keep playing after the programme'),
                help: tr(
                    "Off: catch-up pauses when the programme you picked ends, so the next one doesn't start on its own; press Play to carry on. On: it keeps going like the channel did."),
                value: _storage.getCatchupKeepPlaying(),
                onChanged: (v) =>
                    _save(() => _storage.setCatchupKeepPlaying(v))),
          ]),
        SettingsSection(title: tr('Movies & TV Shows'), [
          if (archive != null)
            SettingsToggle(
                id: 'hub_largest_file',
                icon: Icons.sd_storage_outlined,
                title: tr('Automatically play the largest file'),
                help: tr(
                    'Use the largest known file size when starting a title. Resume keeps your selected stream.'),
                value: archive.autoPlayLargest,
                onChanged: archive.setAutoPlayLargest),
          SettingsToggle(
              id: 'auto_trailers',
              icon: Icons.movie_outlined,
              title: tr('Automatic trailers'),
              help: [
                tr('Play available trailers automatically with sound on IPTV and Media Hub movie and show pages.'),
                if (Platform.isAndroid)
                  tr('On Fire TV sticks, the trailer plays full screen.'),
              ].join(' '),
              value: prefs.autoTrailers,
              onChanged: prefs.setAutoTrailers),
        ]),
      ],
    );
  }

  // ----------------------------------------------------------------- sports

  SettingsCategory _sports(AppPreferences prefs) {
    final playlists = _storage.getPlaylists()
      ..sort((a, b) => a.sortOrderFor('tv').compareTo(b.sortOrderFor('tv')));
    final countries = _storage.getSportsPreferredCountries();
    final preferred = _storage.getSportsPreferredPlaylist();
    final preferredGone = preferred != null &&
        !playlists.any((p) => p.id == preferred && p.enabled);
    return SettingsCategory(
      id: 'sports',
      icon: Icons.sports,
      title: AppConstants.sportsTabName,
      description: tr('Channel preferences and settings for {tab}.',
          {'tab': AppConstants.sportsTabName}),
      sections: [
        SettingsSection([
          SettingsToggle(
              id: 'sports_mode',
              icon: Icons.sports,
              title: tr('Sports Mode'),
              help: tr(
                  'Make Sports Trak your home, with your top five leagues at the side.'),
              value: prefs.sportsMode,
              onChanged: _setSportsMode),
        ]),
        SettingsSection(title: tr('Games'), [
          SettingsChoice(
              id: 'sports_layout',
              icon: Icons.view_list,
              title: tr('Games layout'),
              help: tr(
                  'Guide lists the day\'s games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.'),
              options: [
                SettingsOption('cards', tr('Cards'),
                    subtitle: tr('Game cards in rows')),
                SettingsOption('guide', tr('Guide'),
                    subtitle: tr('A TV guide-style list, one game per row')),
              ],
              selected: _storage.getSportsLayout(),
              onPick: (v) => _saveViewer(() => _storage.setSportsLayout(v))),
          SettingsChoice(
              id: 'sports_card_size',
              icon: Icons.photo_size_select_large,
              title: tr('Game card size'),
              help: tr(
                  'Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.',
                  {'tab': AppConstants.sportsTabName}),
              options: [
                SettingsOption('large', tr('Large'),
                    subtitle: tr(
                        'The original size, for watching from across the room')),
                SettingsOption('medium', tr('Medium'),
                    subtitle: tr('Smaller cards, more games on screen')),
                SettingsOption('small', tr('Small'),
                    subtitle: tr(
                        'The most games on screen, for sitting close to the TV')),
              ],
              selected: _storage.getSportsCardSize(),
              onPick: (v) => _saveViewer(() => _storage.setSportsCardSize(v))),
          SettingsToggle(
              id: 'sports_hide_empty',
              icon: Icons.filter_list,
              title: tr('Hide leagues with no games'),
              help: tr(
                  'Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.'),
              value: _storage.getSportsHideEmptyLeagues(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setSportsHideEmptyLeagues(v))),
          SettingsToggle(
              id: 'sports_odds',
              icon: Icons.trending_up,
              title: tr('Show betting odds'),
              help: tr(
                  'Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.',
                  {
                    'app': AppConstants.appName
                  }),
              value: _storage.getSportsShowOdds(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setSportsShowOdds(v))),
        ]),
        SettingsSection(title: tr('Channels'), [
          SettingsLink(
              id: 'sports_countries',
              floating: true,
              icon: Icons.flag_outlined,
              title: tr('Preferred channel countries'),
              subtitle: tr(
                  'Prefer local channels while keeping other matches available'),
              help: tr(
                  'Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.'),
              value: countries.isEmpty ? null : countries.join(', '),
              page: (_) => const SportsCountrySettingsScreen()),
          SettingsChoice(
              id: 'sports_playlist',
              icon: Icons.playlist_play,
              title: tr('Preferred playlist'),
              help: preferredGone
                  ? tr(
                      'Your preferred playlist is unavailable or disabled. Other matching playlists will be used.')
                  : tr(
                      'Among comparable game matches, prefer this playlist, then your preferred countries, then video quality. Your game and team channel choices still come first. Other playlists remain available.'),
              options: [
                SettingsOption('', tr('No playlist preference')),
                // A disabled playlist can't be picked; the saved one still
                // shows (dimmed) so the viewer sees why it is not used.
                for (final p in playlists)
                  if (p.enabled || p.id == preferred)
                    SettingsOption(p.id, p.name,
                        subtitle: p.enabled ? null : tr('Disabled'),
                        dimmed: !p.enabled),
              ],
              valueText: preferredGone
                  ? playlists
                      .where((p) => p.id == preferred)
                      .map((p) => '${p.name} · ${tr('Disabled')}')
                      .firstOrNull
                  : null,
              selected: preferred ?? '',
              onPick: (v) => _saveViewer(() =>
                  _storage.setSportsPreferredPlaylist(v.isEmpty ? null : v))),
          SettingsToggle(
              id: 'sports_quality',
              icon: Icons.high_quality_outlined,
              title: tr('Prefer highest quality'),
              help: tr('Prefer higher-quality channels among game matches'),
              value: _storage.getSportsPreferQuality(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setSportsPreferQuality(v))),
        ]),
        SettingsSection(title: tr('Goals alert'), [
          if (defaultTargetPlatform == TargetPlatform.android &&
              prefs.isTelevision)
            SettingsCustom(
                id: 'goal_overlay_probe',
                builder: (_) => const GoalOverlayProbeSettings()),
          SettingsToggle(
              id: 'goals_alert',
              icon: Icons.sports_score,
              title: tr('Goals alert'),
              help: tr(
                  'Show a top-left popup when a team in My Teams scores. Alerts follow the score feed and pause when scores are hidden.'),
              value: prefs.goalsAlert,
              onChanged: prefs.setGoalsAlert),
          SettingsToggle(
              id: 'transparent_popups',
              icon: Icons.blur_on,
              title: tr('Transparent popups'),
              help: tr(
                  'Reminders and goal alerts lose their background and outline, keeping only the logo and text.'),
              value: prefs.transparentPopups,
              onChanged: prefs.setTransparentPopups),
          SettingsAction(
              id: 'test_popup',
              icon: Icons.visibility_outlined,
              title: tr('Show a test popup'),
              help: tr('A sample goal alert for 8 seconds.'),
              run: (_) async => GoalsAlertOverlay.previewRequests.value++),
          SettingsToggle(
              id: 'sports_auto_play',
              icon: Icons.play_circle_outline,
              title: tr('Watch game button'),
              help: tr(
                  'When a reminded game is about to start, a Watch game button shows in the player for 10 minutes. Press Up from the player bar to reach it, then OK to switch to the game on its best channel. Set a reminder with a hold on the game. {app} must be open. Saved for this viewer.',
                  {
                    'app': AppConstants.appName
                  }),
              value: _storage.getSportsAutoPlay(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setSportsAutoPlay(v))),
        ]),
        SettingsSection(title: tr('Phone notifications'), [
          SettingsToggle(
              id: 'phone_reminders',
              icon: Icons.notifications_outlined,
              title: tr('Game reminders'),
              help: tr(
                  'Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.'),
              value: _storage.getPhoneGameReminders(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setPhoneGameReminders(v))),
          SettingsToggle(
              id: 'phone_goals',
              icon: Icons.notifications_active_outlined,
              title: tr('Goal alerts'),
              help: tr(
                  'Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.'),
              value: _storage.getPhoneGoalAlerts(),
              onChanged: (v) =>
                  _saveViewer(() => _storage.setPhoneGoalAlerts(v))),
        ]),
      ],
    );
  }

  /// Sports Mode changes the home: stop what plays and go back to the root
  /// (was SportsModeToggle).
  Future<void> _setSportsMode(bool value) async {
    final prefs = _prefs;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await context.read<PlaybackService>().stop();
      if (usesMediaKit) DesktopMiniPlayer.instance.clear();
      await prefs.setSportsMode(value);
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      messenger?.showSnackBar(SnackBar(
          content: Text(tr('Could not change Sports Mode. Try again.'))));
    }
  }

  // --------------------------------------------------------------- profiles

  SettingsCategory _profiles(AppPreferences prefs) {
    final full = _storage.getResumeLastChannelAtStartup();
    final guide = !full && _storage.getResumeLastChannelInGuide();
    return SettingsCategory(
      id: 'profiles',
      icon: Icons.people_outline,
      title: tr('Profiles & startup'),
      description: tr('Who is watching, and what happens when the app opens.'),
      sections: [
        SettingsSection([
          SettingsLink(
              id: 'profiles',
              floating: true,
              icon: Icons.people_outline,
              title: tr('Profiles'),
              subtitle:
                  tr('Separate favorites, history & hidden groups per viewer'),
              page: (_) => const ProfilesScreen()),
          SettingsToggle(
              id: 'launch_with_profiles',
              icon: Icons.how_to_reg_outlined,
              title: tr('Launch with profiles selector'),
              help: tr(
                  'Choose a profile after the splash, before the app opens. Applies from the next start.'),
              value: prefs.launchWithProfiles,
              onChanged: prefs.setLaunchWithProfiles),
        ]),
        SettingsSection(title: tr('Startup'), [
          SettingsChoice(
              id: 'start_section',
              icon: Icons.login,
              title: tr('Open on'),
              help: tr(
                  '{section}. Where the app opens after starting. With "Resume last channel in full screen" on, the channel then plays in the background instead.',
                  {
                    'section': tr(AppPreferences.startSections
                        .firstWhere((s) => s.$1 == prefs.startSection,
                            orElse: () => AppPreferences.startSections.first)
                        .$2)
                  }),
              options: [
                for (final (id, label) in AppPreferences.startSections)
                  SettingsOption(id, tr(label)),
              ],
              selected: prefs.startSection,
              onPick: prefs.setStartSection),
          // One choice instead of two switches that turned each other off.
          SettingsChoice(
              id: 'resume_last_channel',
              icon: Icons.restore,
              title: tr('Resume last channel'),
              help: isDesktop
                  ? tr('What plays after the splash.')
                  : tr(
                      'What plays after the splash. Off: nothing plays at startup (a "Hold > to resume" reminder instead).'),
              options: [
                SettingsOption('full', tr('Full screen'),
                    subtitle: tr(
                        'Opens the last live channel full screen after the splash.')),
                SettingsOption('guide', tr('With the guide open'),
                    subtitle: tr(
                        'Plays the last live channel in the small preview, with the channel list.')),
                SettingsOption('off', tr('Off')),
              ],
              selected: full
                  ? 'full'
                  : guide
                      ? 'guide'
                      : 'off',
              onPick: (v) => _save(() async {
                    await _storage.setResumeLastChannelAtStartup(v == 'full');
                    await _storage.setResumeLastChannelInGuide(v == 'guide');
                  })),
          SettingsToggle(
              id: 'fast_startup',
              icon: Icons.bolt,
              title: tr('Fast startup'),
              help: tr(
                  'Opens the app without waiting for Movies and TV Shows to load; they fill in a few seconds later. For fast devices — leave it off on an older box if the app closes by itself right after starting. Applies from the next start.'),
              value: prefs.fastStartup,
              onChanged: prefs.setFastStartup),
          SettingsToggle(
              id: 'background_sync',
              icon: Icons.sync,
              title: tr('Update in the background'),
              help: tr(
                  'When a content update is due, open on Live TV right away and update Movies and TV Shows behind it. They fill in over the next few minutes, and the remote can feel slower until it finishes. Applies from the next start.'),
              value: prefs.backgroundSync,
              onChanged: prefs.setBackgroundSync),
        ]),
      ],
    );
  }

  // ------------------------------------------------------------- recordings

  SettingsCategory _recordings() {
    final recording = RecordingService.supported;
    final s = RecordingService.instance.settings;
    return SettingsCategory(
      id: 'recordings',
      icon: recording
          ? Icons.fiber_smart_record_outlined
          : Icons.download_outlined,
      title: recording ? tr('Recordings & downloads') : tr('Downloads'),
      description: recording
          ? tr('Margins, space and where recordings are saved')
          : tr('Speed, space and where downloads are saved'),
      sections: [
        if (recording)
          SettingsSection(title: tr('Recordings'), [
            _minutes(
                'record_before',
                Icons.first_page,
                tr('Start early'),
                tr('Before the game\'s scheduled start'),
                const [0, 2, 5, 10, 15],
                s.minutesBefore,
                (v) => s.copyWith(minutesBefore: v)),
            _minutes(
                'record_after',
                Icons.last_page,
                tr('Keep recording'),
                tr('After the scheduled end, for overtime and delays'),
                const [15, 30, 45, 60, 90],
                s.minutesAfter,
                (v) => s.copyWith(minutesAfter: v)),
          ]),
        SettingsSection(title: recording ? tr('Downloads') : null, [
          SettingsChoice(
              id: 'download_speed',
              icon: Icons.speed,
              title: tr('Speed limit'),
              help: tr('Always slower while you watch something.'),
              options: [
                for (final speed in RecordingSettings.downloadSpeeds)
                  SettingsOption(speed, downloadSpeedLabel(speed),
                      subtitle: switch (speed) {
                        'watch' => tr(
                            'About the video\'s own bitrate: to the provider it looks like someone watching. The safest choice.'),
                        'none' => tr(
                            'As fast as the source sends. Some providers don\'t allow this.'),
                        _ => tr('At most this speed.'),
                      }),
              ],
              selected: s.downloadSpeed,
              onPick: (v) => _saveRecording(s.copyWith(downloadSpeed: v))),
          SettingsChoice(
              id: 'download_start',
              icon: Icons.nightlight_round,
              title: tr('Suggested start'),
              help: tr(
                  'What Download offers first: overnight, while nobody watches'),
              options: [
                for (final at in const [0, 60, 120, 180, 240, 300, 1320, 1380])
                  SettingsOption(
                      '$at',
                      TimeFormat.hm
                          .format(DateTime(2000, 1, 1, at ~/ 60, at % 60))),
              ],
              selected: '${s.downloadAt}',
              onPick: (v) =>
                  _saveRecording(s.copyWith(downloadAt: int.parse(v)))),
        ]),
        SettingsSection(title: tr('Storage'), [
          SettingsChoice(
              id: 'recording_space',
              icon: Icons.storage,
              title: recording
                  ? tr('Space for recordings')
                  : tr('Space for downloads'),
              help: recording
                  ? tr(
                      '{used} used. Recording stops when this is full or the storage has less than 1 GB left.',
                      {
                          'used': _gb(RecordingService.instance.usedBytes)
                        })
                  : tr(
                      '{used} used. Downloads stop when this is full or the drive has less than 1 GB left.',
                      {'used': _gb(RecordingService.instance.usedBytes)}),
              options: [
                for (final gb in const [5, 10, 20, 50, 100, 200])
                  SettingsOption('$gb', '$gb GB'),
              ],
              selected: '${s.capGb}',
              onPick: (v) => _saveRecording(s.copyWith(capGb: int.parse(v)))),
          if (volumes.isNotEmpty)
            SettingsChoice(
                id: 'recording_folder',
                icon: Icons.folder_outlined,
                title: recording
                    ? tr('Save recordings and downloads to')
                    : tr('Save downloads to'),
                help: recording && volumes.where((v) => !v.network).length < 2
                    ? tr(
                        'Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.')
                    : null,
                options: [
                  for (final v in volumes)
                    SettingsOption(
                        v.path,
                        v.network
                            ? tr('Network folder')
                            : v.removable
                                ? tr('USB drive / SD card')
                                : recording
                                    ? tr('This device')
                                    : tr('This computer'),
                        subtitle: v.network
                            ? s.network?.display
                            : v.free < 0
                                ? null
                                : tr('{free} free of {total}', {
                                    'free': _gb(v.free),
                                    'total': _gb(v.total)
                                  })),
                ],
                selected:
                    (volumes.where((v) => v.path == s.folder).firstOrNull ??
                            volumes.where((v) => !v.network).firstOrNull ??
                            volumes.first)
                        .path,
                onPick: (v) => _saveRecording(s.copyWith(folder: v))),
          SettingsLink(
              id: 'network_folder',
              floating: true,
              icon: Icons.lan_outlined,
              title: s.network == null
                  ? tr('Set up a network folder')
                  : tr('Network folder settings'),
              subtitle: tr('A shared folder on a computer or NAS (SMB)'),
              value: s.network?.display,
              page: (_) => const NetworkFolderScreen()),
        ]),
      ],
    );
  }

  SettingsChoice _minutes(
          String id,
          IconData icon,
          String title,
          String help,
          List<int> options,
          int current,
          RecordingSettings Function(int) apply) =>
      SettingsChoice(
          id: id,
          icon: icon,
          title: title,
          help: help,
          options: [
            for (final m in options)
              SettingsOption('$m', tr('{min} min', {'min': m})),
          ],
          selected: '$current',
          onPick: (v) => _saveRecording(apply(int.parse(v))));

  Future<void> _saveRecording(RecordingSettings s) =>
      _save(() => RecordingService.instance.updateSettings(s));

  static String _gb(int bytes) =>
      '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  // ------------------------------------------------------------------ vesper

  SettingsCategory _vesper() => SettingsCategory(
        id: 'vesper',
        icon: Icons.auto_awesome,
        title: 'Vesper AI',
        description: tr(
            'Talk to VesperTV with your remote\'s microphone, your phone or by typing. Bring your own AI for more, or link the AI app you already use.'),
        sections: [
          SettingsSection([
            SettingsAction(
                id: 'vesper_talk',
                icon: Icons.auto_awesome,
                title: tr('Talk to Vesper now'),
                subtitle: tr('Opens the Vesper panel'),
                run: (_) async => VesperAi.instance.openPanel()),
            SettingsAction(
                id: 'vesper_phone',
                icon: Icons.smartphone,
                title: tr('Talk from my phone'),
                subtitle: tr('A QR code for your phone: type or speak there'),
                run: (c) async => showPhoneMicSheet(c)),
            SettingsToggle(
                id: 'vesper_shortcut',
                icon: Icons.mic_none,
                title: tr('Vesper shortcut'),
                help: tr(
                    'A ✨ Vesper 🎙️ row in the TV menu, under Search (a mic in the phone header).'),
                value: _prefs.vesperShortcut,
                onChanged: (v) => _save(() => _prefs.setVesperShortcut(v))),
            if (Platform.isAndroid)
              SettingsToggle(
                  id: 'vesper_voice_button',
                  icon: Icons.settings_voice_outlined,
                  title: tr('Remote voice button opens Vesper'),
                  help: tr(
                      "The microphone / search button of your remote, while VesperTV is open. Off: it opens the device's own assistant."),
                  value: _storage.getAiVoiceButton(),
                  onChanged: (v) => _save(() => _storage.setAiVoiceButton(v))),
            SettingsToggle(
                id: 'vesper_speak',
                icon: Icons.volume_up_outlined,
                title: tr('Read replies aloud'),
                value: _storage.getAiSpeakReplies(),
                onChanged: (v) => _save(() => _storage.setAiSpeakReplies(v))),
            // The rest (your own AI's key, AI apps, teaching the remote's
            // button) is a page: text fields, a connector address, tests.
            SettingsLink(
                id: 'vesper_ai',
                icon: Icons.tune,
                title: 'Vesper AI',
                subtitle: tr('Voice, your own AI, AI apps'),
                page: (_) => const VesperAiSettingsScreen()),
          ]),
        ],
      );

  // ----------------------------------------------------------------- devices

  SettingsCategory _devices() => SettingsCategory(
        id: 'devices',
        icon: Icons.devices,
        title: tr('Backup & devices'),
        description: _prefs.isTelevision
            ? tr(
                'Move your whole setup to another device, keep a backup of it, update VesperTV and set up your remote.')
            : tr(
                'Move your whole setup to another device, keep a backup of it, and update VesperTV.'),
        sections: [
          SettingsSection([
            SettingsLink(
                id: 'sync',
                icon: Icons.sync,
                title: tr('Sync'),
                subtitle: tr(
                    'Keep your setup and watch progress together across devices'),
                page: (_) => const SyncScreen()),
            SettingsLink(
                id: 'transfer',
                icon: Icons.devices,
                title: tr('Transfer to another device'),
                subtitle: tr('Copy all of your data to another device'),
                page: (_) => const TransferScreen()),
            if (BackupService.supported)
              SettingsLink(
                  id: 'backup',
                  icon: Icons.settings_backup_restore,
                  title: tr('Backup & restore'),
                  subtitle: tr('Save everything to a file on this device'),
                  page: (_) => const BackupScreen()),
            // App Store rules: Apple installs the updates.
            if (!appStoreBuild)
              SettingsLink(
                  id: 'updates',
                  floating: true,
                  icon: Icons.system_update_outlined,
                  title: tr('Check for Updates'),
                  subtitle: tr('Download and install the latest release'),
                  page: (_) => const CheckUpdatesScreen()),
          ]),
          if (_prefs.isTelevision) _remote(),
        ],
      );

  /// A TV box's remote (owner, 2026-11-11: a remote is a device): its spare
  /// buttons and the full-screen player's arrows ([RemoteButtons]).
  SettingsSection _remote() {
    final buttons = RemoteButtons.instance;
    final count = buttons.bindings.length;
    return SettingsSection(title: tr('Remote'), [
      SettingsLink(
          id: 'remote_buttons',
          floating: true,
          icon: Icons.settings_remote_outlined,
          title: tr('Remote buttons'),
          subtitle: tr('Give spare buttons a job'),
          help: tr(
              'Press a button on your remote, then choose what a short press and a hold do: open Favourites or the guide, change the audio track, record... For this profile on this device.'),
          value: count == 0 ? null : '$count',
          page: (_) => const RemoteButtonsScreen()),
      for (final arrow in PlayerArrow.values)
        SettingsChoice(
            id: 'player_arrow_${arrow.name}',
            icon: switch (arrow) {
              PlayerArrow.left => Icons.arrow_back,
              PlayerArrow.right => Icons.arrow_forward,
              PlayerArrow.up => Icons.arrow_upward,
              PlayerArrow.down => Icons.arrow_downward,
            },
            title: tr(switch (arrow) {
              PlayerArrow.left => 'Left in the player',
              PlayerArrow.right => 'Right in the player',
              PlayerArrow.up => 'Up in the player',
              PlayerArrow.down => 'Down in the player',
            }),
            help: tr(
                'In the full-screen player on a live channel, with nothing on screen.'),
            options: [
              for (final (id, _) in PlayerArrow.actions)
                SettingsOption(id, playerArrowLabel(id),
                    subtitle: id == arrow.defaultAction ? tr('Default') : null),
            ],
            selected: buttons.arrowAction(arrow),
            onPick: (v) => _saveViewer(() => buttons.setArrow(arrow, v))),
      if (buttons.isCustomised)
        SettingsAction(
            id: 'remote_reset',
            icon: Icons.restart_alt,
            title: tr('Reset remote buttons'),
            subtitle: tr('Forget every button and put the arrows back'),
            run: (c) async {
              final ok = await showDialog<bool>(
                context: c,
                builder: (dialogContext) => AlertDialog(
                  title: Text(tr('Reset remote buttons')),
                  content: Text(tr(
                      "Forget every button you set and put the player's arrows back as they were?")),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(tr('Reset')),
                    ),
                    TextButton(
                      autofocus: true,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(tr('Cancel')),
                    ),
                  ],
                ),
              );
              if (ok == true) await _saveViewer(buttons.reset);
            }),
    ]);
  }

  // -------------------------------------------------------------------- help

  SettingsCategory _help() => SettingsCategory(
        id: 'help',
        icon: Icons.help_outline,
        title: tr('Help'),
        description: tr('Tips, support and how to reach us.'),
        sections: [
          SettingsSection([
            SettingsLink(
                id: 'remote_tips',
                floating: true,
                icon: Icons.settings_remote_outlined,
                title: tr('Remote tips'),
                subtitle: tr('Every hold menu and shortcut, on your phone'),
                page: (_) => const RemoteTipsScreen()),
            SettingsLink(
                id: 'discord',
                floating: true,
                icon: Icons.forum_outlined,
                title: tr('Discord'),
                subtitle: tr('Direct support through Discord'),
                page: (_) => const CommunityScreen()),
            SettingsLink(
                id: 'send_log',
                floating: true,
                icon: Icons.bug_report_outlined,
                title: tr('Send log'),
                subtitle: tr('Send the app\'s log to the developer'),
                page: (_) => const SendLogScreen()),
            SettingsLink(
                id: 'support',
                floating: true,
                icon: Icons.favorite_outline,
                title: tr('Support VesperTV'),
                subtitle: tr('How you can help'),
                help: tr(
                    'VesperTV is free, with no ads. See how you can help keep it running.'),
                page: (_) => const SupportScreen()),
          ]),
        ],
      );

  // ---------------------------------------------------------------- advanced

  SettingsCategory _advanced(AppPreferences prefs) => SettingsCategory(
        id: 'advanced',
        icon: Icons.build_outlined,
        title: tr('Advanced'),
        description: tr(
            'Fixes for some devices and extra tools. Most people never need these.'),
        advanced: true,
        sections: [
          SettingsSection(title: tr('Device fixes'), [
            if (!usesMediaKit)
              SettingsToggle(
                  id: 'hide_video_behind_pages',
                  icon: Icons.picture_in_picture_alt,
                  title: tr('Hide the picture behind other pages'),
                  subtitle:
                      prefs.isAutomaticOn(DeviceDefaults.hideVideoOnSports)
                          ? tr('Automatic: on for this device.')
                          : null,
                  help: tr(
                      'A live channel keeps playing behind {tab}, Settings and Search. Some Fire TV sticks keep showing its picture on top of those pages. Turn this on if that happens: the sound keeps going, only the picture is hidden until you go back. Updating the device\'s software (Fire TV: Settings > My Fire TV > About > Check for Updates) may fix it too.',
                      {'tab': AppConstants.sportsTabName}),
                  value: prefs.hideVideoOnSports,
                  onChanged: prefs.setHideVideoOnSports),
            if (Platform.isAndroid)
              SettingsToggle(
                  id: 'native_video_surface',
                  icon: Icons.layers_outlined,
                  title: tr('Native video surface (beta)'),
                  help: [
                    tr('Plays the picture the way native TV apps do, for HDR that looks washed out or green flashes under the guide (Fire TV Cube, NVIDIA Shield). Restart the app after changing it. If the picture is missing, in the wrong place or menus look wrong, turn it off and send us a log.'),
                    // Live state, so testers can see it's really on
                    // (English: diagnostic text).
                    if (nativeStatus != null) 'Status: $nativeStatus',
                  ].join(' '),
                  value: prefs.nativeVideoSurface,
                  onChanged: (v) {
                    prefs.setNativeVideoSurface(v);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                        content: Text(tr(
                            'Close the app completely and open it again to apply this change.'))));
                  }),
            if (isDesktop)
              SettingsToggle(
                  id: 'software_video',
                  icon: Icons.memory,
                  title: tr('Software video'),
                  help: tr(
                      'Turn on if channels or movies stay black while the sound or the stream plays. Draws the video without the graphics card path. Uses more CPU on 4K. Applies from the next video.'),
                  value: _storage.getDesktopSoftwareVideo(),
                  onChanged: (v) => _save(() async {
                        await _storage.setDesktopSoftwareVideo(v);
                        desktopSoftwareVideo = v;
                      })),
          ]),
          SettingsSection(title: tr('Info and tips'), [
            // Windows: a player bar button / the I key opens it
            // (DesktopDataPoolCard, mpv's numbers).
            SettingsToggle(
                id: 'data_pool',
                icon: Icons.analytics_outlined,
                title: tr('Data pool display'),
                subtitle: usesMediaKit
                    ? tr('Stream details from a button in the player bar')
                    : tr('Stream details when you press OK while watching'),
                help: usesMediaKit
                    ? tr(
                        'Adds a Data pool button to the player bar (or press I) that opens a card with the stream\'s details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer, HDR and decoder.')
                    : tr(
                        'Press OK while a channel, movie or episode plays to open a card with the stream\'s details: resolution, frame rate, codecs, bitrate, quality variants, audio tracks, buffer and HDR. Off: OK shows only the channel info.'),
                value: prefs.dataPool,
                onChanged: prefs.setDataPool),
            if (!usesMediaKit)
              SettingsToggle(
                  id: 'multiview_tip',
                  icon: Icons.grid_view,
                  title: tr('Show the Multiview tip'),
                  help: tr(
                      'The connections reminder shown when opening Multiview.'),
                  value: !_storage.getMultiviewHideTips(),
                  onChanged: (v) =>
                      _save(() => _storage.setMultiviewHideTips(!v))),
            SettingsToggle(
                id: 'resume_pill',
                icon: Icons.touch_app_outlined,
                title: tr('Show the "Hold > to resume" reminder'),
                help: usesMediaKit
                    ? tr(
                        'The pill at the bottom while a channel plays in the background. Off: hidden.')
                    : tr(
                        'The pill at the bottom while a channel plays in the background. Off: hidden — holding Right still resumes.'),
                value: _storage.getShowResumePill(),
                onChanged: (v) => _save(() async {
                      LiveResumeHint.pillEnabled.value = v;
                      await _storage.setShowResumePill(v);
                    })),
          ]),
          SettingsSection(title: tr('Keys and services'), [
            SettingsLink(
                id: 'tmdb',
                floating: true,
                icon: Icons.movie_filter_outlined,
                title: tr('TMDB (Release Dates)'),
                subtitle: tr('Optional key for sorting by real release date'),
                page: (_) => const TmdbSettingsScreen()),
            // App Store rules: no debrid keys (add-ons keep their own).
            if (!appStoreBuild)
              SettingsLink(
                  id: 'debrid',
                  floating: true,
                  icon: Icons.cloud_done_outlined,
                  title: tr('Debrid accounts'),
                  subtitle: tr('Optional keys for the "Ready" tag'),
                  page: (_) => const DebridSettingsScreen()),
            SettingsLink(
                id: 'custom_posters',
                floating: true,
                icon: Icons.image_outlined,
                title: tr('Custom posters'),
                subtitle: tr('Media Hub posters from a poster service'),
                page: (_) => const ArchivePostersScreen()),
          ]),
          SettingsSection(title: tr('History'), [
            SettingsAction(
                id: 'clear_channel_history',
                icon: Icons.manage_search,
                title: tr('Clear search & channel history'),
                subtitle: tr('Recent searches and the live channel History'),
                run: _clearSearchAndChannelHistory),
            SettingsAction(
                id: 'clear_watch_history',
                icon: Icons.movie_outlined,
                title: tr('Clear Movies & TV Shows history'),
                subtitle: tr('Continue Watching and saved progress'),
                run: _clearMoviesAndShowsHistory),
          ]),
        ],
      );

  // ----------------------------------------------------------------- helpers

  Future<void> _save(Future<void> Function() write) async {
    await write();
    refresh();
  }

  /// A per-viewer setting: dropped if the viewer changed under the open
  /// Settings (the old pages kept the same guard).
  Future<void> _saveViewer(Future<void> Function() write) async {
    if (_storage.viewerGeneration != _viewer) return;
    await write();
    refresh();
  }

  /// Cancel is focused by default so a stray Select can't wipe anything.
  static Future<bool> _confirm(
      BuildContext context, String title, String message) async {
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

  static Future<void> _clearSearchAndChannelHistory(
      BuildContext context) async {
    if (!await _confirm(context, tr('Clear search & channel history?'),
        tr('Removes your recent searches and the History list of live channels.'))) {
      return;
    }
    if (!context.mounted) return;
    final playback = context.read<PlaybackService>();
    await context.read<AppPreferences>().storage.clearRecentSearches();
    await playback.clearRecentlyPlayed(live: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Search and channel history cleared.'))));
  }

  static Future<void> _clearMoviesAndShowsHistory(BuildContext context) async {
    if (!await _confirm(context, tr('Clear Movies & TV Shows history?'),
        tr('Removes Continue Watching and the saved progress of every movie and episode.'))) {
      return;
    }
    if (!context.mounted) return;
    await context.read<PlaybackService>().clearRecentlyPlayed(live: false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Movies & TV Shows history cleared.'))));
  }
}
