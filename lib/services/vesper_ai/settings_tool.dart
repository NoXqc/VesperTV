part of 'vesper_tools.dart';

// `settings`: the TV's own settings for an AI (a chosen list it can read
// and change), clearing histories, and updating the guide now. Left out on
// purpose: Ask on the TV first, AI keys and apps, the PIN, profiles,
// playlists and the video troubleshooting switches. An AI app must never be
// able to turn its own confirmations off.

/// One setting the AI can read and change: a switch, or [choices], or a
/// number from [min] to [max].
class _AiSetting {
  const _AiSetting(
    this.key,
    this.section,
    this.label,
    this.about, {
    required this.read,
    required this.write,
    this.choices,
    this.min,
    this.max,
    this.unit = '',
    this.androidOnly = false,
    this.nextStart = false,
    this.shown,
  });

  final String key;
  final String section;

  /// Its title in Settings (English; translated in the TV's confirm).
  final String label;

  /// For the model: what it does.
  final String about;

  /// The values allowed, with their names in Settings.
  final List<(String, String)>? choices;
  final int? min;
  final int? max;
  final String unit;

  final bool androidOnly;

  /// Read once at launch: a change applies at the next app start.
  final bool nextStart;

  /// How the TV's confirm names [value], when the choice names alone
  /// can't (they take a number).
  final String Function(Object value)? shown;
  final Object Function(VesperToolbox box) read;
  final Future<void> Function(VesperToolbox box, Object value) write;

  bool get isSwitch => choices == null && min == null;
}

_AiSetting _switch(
        String key,
        String section,
        String label,
        String about,
        bool Function(VesperToolbox box) read,
        FutureOr<void> Function(VesperToolbox box, bool on) write,
        {bool androidOnly = false,
        bool nextStart = false}) =>
    _AiSetting(key, section, label, about,
        read: read,
        write: (box, value) async => write(box, value as bool),
        androidOnly: androidOnly,
        nextStart: nextStart);

/// Live buffer choices: (key, ms, name in Settings).
const _liveBuffers = [
  ('off', 0, 'Off'),
  ('gradual', -1, 'Gradual (starts fast, builds up)'),
  ('1.5s', 1500, 'Small (1.5 seconds)'),
  ('4s', 4000, '4 seconds'),
  ('8s', 8000, '8 seconds'),
  ('12s', 12000, '12 seconds'),
];

/// Colour themes: (key, palette id). The key is the name without accents.
const _themes = [
  ('platinum', 'minimal'),
  ('rose', 'red_blue'),
  ('neon_purple', 'purple_magenta'),
  ('neon_green', 'neon_green'),
  ('aqua', 'aqua'),
  ('red', 'red'),
  ('blue', 'blue'),
  ('dark_gold', 'dark_gold'),
];

final List<_AiSetting> _aiSettings = [
  // ---- playback
  _switch(
      'skip_intro',
      'playback',
      'Skip intro',
      'Skip intro / recap / credits buttons on episodes.',
      (b) => b.storage.getSkipSegments(),
      (b, on) => b.storage.setSkipSegments(on),
      androidOnly: true),
  _AiSetting('up_next', 'playback', 'Up Next',
      'When the next episode starts by itself.',
      choices: const [
        ('early', '30 seconds before the end'),
        ('end', 'When the episode ends'),
        ('off', 'Never'),
      ],
      read: (b) => b.storage.getUpNextMode(),
      write: (b, v) => b.storage.setUpNextMode(v as String)),
  _AiSetting(
      'live_buffer',
      'playback',
      'Live buffer',
      'Live video stored before playing: hides short server dropouts, but '
          'channels start later and play that much behind live.',
      choices: [
        for (final (key, ms, name) in _liveBuffers)
          if (ms >= 0 || !usesMediaKitTarget) (key, name)
      ],
      read: (b) => _liveBuffers
          .firstWhere((c) => c.$2 == b.storage.getLiveBufferMs(),
              orElse: () => _liveBuffers.first)
          .$1,
      write: (b, v) async {
        final ms = _liveBuffers.firstWhere((c) => c.$1 == v).$2;
        await b.storage.setLiveBufferMs(ms);
        await VodBuffering.setLiveBufferDefault(ms);
      }),
  _AiSetting('audio_delay', 'playback', 'Audio delay',
      'Audio sync: positive plays the sound later, negative sooner.',
      min: -5000,
      max: 5000,
      unit: ' ms',
      read: (b) => b.prefs.audioDelayMs,
      write: (b, v) async => b.prefs.setAudioDelayMs(v as int)),
  _switch(
      'audio_passthrough',
      'playback',
      'Surround passthrough (Dolby Atmos)',
      'Sends Dolby / DTS audio to the soundbar or receiver undecoded; the '
          'app volume no longer applies.',
      (b) => b.prefs.audioPassthrough,
      (b, on) => b.prefs.setAudioPassthrough(on)),
  _AiSetting(
      'subtitle_size', 'playback', 'Subtitle size', 'Subtitle text size.',
      choices: const [
        ('extra_small', 'Extra small'),
        ('small', 'Small'),
        ('normal', 'Normal'),
        ('large', 'Large'),
        ('extra_large', 'Extra large'),
      ],
      read: (b) => _subtitleSizeKey(b.prefs.subtitleScale),
      write: (b, v) async => b.prefs.setSubtitleScale(_subtitleScales[v]!)),
  _AiSetting(
      'audio_language',
      'playback',
      'Preferred audio language',
      'Audio track picked first on movies and episodes (default = the '
          'source\'s own).',
      choices: [
        ('default', 'Source default'),
        for (final code in trackLanguages) (code, languageName(code)),
      ],
      read: (b) {
        final code = b.storage.getPreferredAudioLanguage();
        return code.isEmpty ? 'default' : code;
      },
      write: (b, v) =>
          b.storage.setPreferredAudioLanguage(v == 'default' ? '' : '$v')),
  _AiSetting('subtitle_language', 'playback', 'Preferred subtitle language',
      'Subtitles turned on by themselves in that language (off = none).',
      choices: [
        ('off', 'Off'),
        for (final code in trackLanguages) (code, languageName(code)),
      ],
      read: (b) => b.storage.getPreferredSubtitleLanguage(),
      write: (b, v) => b.storage.setPreferredSubtitleLanguage('$v')),
  _switch(
      'match_frame_rate',
      'playback',
      'Match frame rate',
      'Switches the TV to the video\'s frame rate.',
      (b) => b.prefs.matchFrameRate,
      (b, on) => b.prefs.setMatchFrameRate(on),
      androidOnly: true),
  _switch(
      'match_50_60_only',
      'playback',
      'Only switch between 50 and 60 Hz',
      'With match_frame_rate: never 24 Hz.',
      (b) => b.prefs.match5060Only,
      (b, on) => b.prefs.setMatch5060Only(on),
      androidOnly: true),
  _switch(
      'match_resolution',
      'playback',
      'Match resolution',
      'Switches the TV to the video\'s resolution.',
      (b) => b.prefs.matchResolution,
      (b, on) => b.prefs.setMatchResolution(on),
      androidOnly: true),
  _switch(
      'data_pool',
      'playback',
      'Data pool',
      'OK on a playing channel also shows the stream details card.',
      (b) => b.prefs.dataPool,
      (b, on) => b.prefs.setDataPool(on)),
  _switch(
      'fill_screen',
      'playback',
      'Fill screen',
      'The picture fills the screen (no black bars, edges cropped).',
      (b) => b.prefs.videoFill,
      (b, on) => b.prefs.setVideoFill(on)),
  _switch(
      'automatic_trailers',
      'playback',
      'Automatic trailers',
      'Movie and show pages play their trailer behind the details.',
      (b) => b.prefs.autoTrailers,
      (b, on) => b.prefs.setAutoTrailers(on)),
  // Media Hub playback (per viewer): which stream a title starts with
  // (hubBestStream / archive_playback). Preferred source is left out: its
  // choices are the viewer's sources.
  _switch(
      'media_hub_largest_file',
      'playback',
      'Automatically play the largest file',
      'Media Hub: a title starts with its largest file among the streams '
          'with the preferred audio language (alone or among others). '
          'Resume keeps the stream picked before.',
      (b) => b.storage.getArchiveAutoLargest(),
      (b, on) => b.storage.setArchiveAutoLargest(on)),
  _switch(
      'media_hub_auto_play',
      'playback',
      'Auto-play preferred stream',
      'Media Hub: a title starts with the best stream (language, preferred '
          'source, highest quality within the limits) without asking; '
          'media_hub_largest_file wins when on. Both off = the TV lists the '
          'streams.',
      (b) => _hubPlayback(b).autoPlay,
      (b, on) => _setHubPlayback(b, autoPlay: on)),
  _AiSetting(
      'media_hub_language',
      'playback',
      'Media Hub audio language',
      'Media Hub: only streams whose label has this language (alone or '
          'among others; untagged counts as English); any = audio_language '
          'only ranks them.',
      choices: [
        ('any', 'Any language'),
        for (final code in const ['en', 'fr', 'es', 'de', 'it', 'pt'])
          (code, languageName(code)),
      ],
      read: (b) {
        final code = _hubPlayback(b).language;
        return code.isEmpty ? 'any' : code;
      },
      write: (b, v) => _setHubPlayback(b, language: v == 'any' ? '' : '$v')),
  _AiSetting('media_hub_max_quality', 'playback', 'Maximum quality',
      'Media Hub: streams above this are skipped when starting a title.',
      choices: const [
        ('any', 'Any quality'),
        ('720p', '720p'),
        ('1080p', '1080p'),
        ('4k', '4K'),
      ],
      read: (b) => switch (_hubPlayback(b).maxHeight) {
            720 => '720p',
            1080 => '1080p',
            2160 => '4k',
            _ => 'any',
          },
      write: (b, v) => _setHubPlayback(b,
          maxHeight: switch (v) {
            '720p' => 720,
            '1080p' => 1080,
            '4k' => 2160,
            _ => 0,
          })),
  _switch(
      'media_hub_prefer_sdr',
      'playback',
      'Prefer SDR',
      'Media Hub: HDR / Dolby Vision streams are skipped when starting a '
          'title.',
      (b) => _hubPlayback(b).avoidHdr,
      (b, on) => _setHubPlayback(b, avoidHdr: on)),
  _switch(
      'panel_keep_open',
      'playback',
      'Keep the side panel open',
      'Left in the full-screen live player opens the side panel (Last '
          'channels, My Teams, Live now); on = it stays open after a pick '
          '(Back closes it).',
      (b) => b.prefs.panelKeepOpen,
      (b, on) => b.prefs.setPanelKeepOpen(on)),
  _switch(
      'panel_zap_on_move',
      'playback',
      'Switch channels while moving in the side panel',
      'The channel changes when the side panel\'s highlight stops on it, '
          'without OK (the panel stays open).',
      (b) => b.prefs.panelZapOnMove,
      (b, on) => b.prefs.setPanelZapOnMove(on)),
  _AiSetting(
      'dispatcharr_sources',
      'playback',
      'Sources in the player',
      'Dispatcharr channels (Settings > Dispatcharr): which streams the '
          "player's Sources lists. first = the channel, the streams "
          "Dispatcharr merged into it, then VesperTV's own matches (quality "
          'copies, fallbacks, other playlists); only = the channel and '
          "Dispatcharr's streams; vesper = VesperTV's matches only.",
      choices: const [
        ('first', "Dispatcharr's first"),
        ('only', "Only Dispatcharr's"),
        ('vesper', "Only VesperTV's"),
      ],
      read: (b) => Dispatcharr.instance.sources.name,
      write: (b, v) => Dispatcharr.instance
          .setSources(DispatcharrSources.parse(v as String)),
      androidOnly: true),
  _switch(
      'catchup_keep_playing',
      'playback',
      'Keep playing after the programme',
      'Off = catch-up pauses when the programme picked ends; on = it keeps '
          'going like the channel did.',
      (b) => b.storage.getCatchupKeepPlaying(),
      (b, on) => b.storage.setCatchupKeepPlaying(on)),
  // ---- startup
  _AiSetting('open_on', 'startup', 'Open on',
      'The part of the app it opens on after the splash.',
      choices: [
        for (final (key, name) in AppPreferences.startSections) (key, name)
      ],
      read: (b) => b.prefs.startSection,
      write: (b, v) async => b.prefs.setStartSection('$v'),
      nextStart: true),
  _switch(
      'resume_full_screen',
      'startup',
      'Resume last channel in full screen',
      'At start, the last live channel plays full screen (turns '
          'resume_in_guide off).',
      (b) => b.storage.getResumeLastChannelAtStartup(), (b, on) async {
    await b.storage.setResumeLastChannelAtStartup(on);
    if (on) await b.storage.setResumeLastChannelInGuide(false);
  }, nextStart: true),
  _switch(
      'resume_in_guide',
      'startup',
      'Resume last channel with the guide open',
      'At start, the last live channel plays in the guide preview (turns '
          'resume_full_screen off).',
      (b) =>
          !b.storage.getResumeLastChannelAtStartup() &&
          b.storage.getResumeLastChannelInGuide(), (b, on) async {
    await b.storage.setResumeLastChannelInGuide(on);
    if (on) await b.storage.setResumeLastChannelAtStartup(false);
  }, nextStart: true),
  _switch(
      'fast_startup',
      'startup',
      'Fast startup',
      'Opens without waiting for Movies and TV Shows to load.',
      (b) => b.prefs.fastStartup,
      (b, on) => b.prefs.setFastStartup(on),
      nextStart: true),
  _switch(
      'ask_before_exit',
      'startup',
      'Ask before exiting',
      'Back on the first screen asks "Exit VesperTV?" before leaving.',
      (b) => b.prefs.askBeforeExit,
      (b, on) => b.prefs.setAskBeforeExit(on),
      androidOnly: true),
  _switch(
      'update_in_background',
      'startup',
      'Update in the background',
      'When a content update is due, opens on Live TV at once and updates '
          'Movies and TV Shows behind it.',
      (b) => b.prefs.backgroundSync,
      (b, on) => b.prefs.setBackgroundSync(on),
      nextStart: true),
  _switch(
      'update_while_closed',
      'startup',
      'Update while VesperTV is closed',
      'The guide and playlists update on their usual schedule with the app '
          'closed.',
      (b) => b.prefs.contentUpdates,
      (b, on) => b.prefs.setContentUpdates(on),
      androidOnly: true),
  _switch(
      'launch_with_profiles',
      'startup',
      'Launch with profiles selector',
      'Who\'s watching? at every start.',
      (b) => b.prefs.launchWithProfiles,
      (b, on) => b.prefs.setLaunchWithProfiles(on),
      nextStart: true),
  // ---- look
  _AiSetting('language', 'look', 'Language', 'The app\'s language.',
      choices: const [
        ('auto', 'Automatic'),
        ('en', 'English'),
        ('fr', 'Français'),
        ('es', 'Español'),
        ('it', 'Italiano'),
        ('el', 'Ελληνικά'),
        ('de', 'Deutsch'),
        ('pl', 'Polski'),
        ('uk', 'Українська'),
      ],
      read: (b) => b.prefs.language,
      write: (b, v) => b.prefs.setLanguage('$v')),
  _AiSetting('theme', 'look', 'Theme', 'The colour theme.',
      choices: [
        for (final (key, id) in _themes)
          (
            key,
            AppConstants.cyberpunkPalettes
                .firstWhere((p) => p.id == id,
                    orElse: () => AppConstants.cyberpunkPalettes.first)
                .label
          )
      ],
      read: (b) => _themes
          .firstWhere((t) => t.$2 == b.prefs.palette.id,
              orElse: () => _themes.first)
          .$1,
      write: (b, v) async {
        final id = _themes.firstWhere((t) => t.$1 == v).$2;
        b.prefs.setPalette(
            AppConstants.cyberpunkPalettes.firstWhere((p) => p.id == id));
      }),
  // Owner, 2026-11-25: the colour by voice / AI app, like Settings.
  _AiSetting(
      'column_lines',
      'look',
      'Column lines',
      'The colour of the lines between the TV home\'s columns and in the '
          'guide (this profile).',
      choices: [
        ('default', 'Default'),
        ('accent', 'Theme color'),
        ('white', 'White'),
        for (final c in GroupColor.presets) (c.id, c.name),
      ],
      read: (b) =>
          b.prefs.columnLines.isEmpty ? 'default' : b.prefs.columnLines,
      write: (b, v) async =>
          b.prefs.setColumnLines(v == 'default' ? '' : '$v')),
  _switch(
      'refined_finish',
      'look',
      'Refined finish',
      'Glass look with reflections and soft depth.',
      (b) => b.prefs.refinedFinish,
      (b, on) => b.prefs.setRefinedFinish(on)),
  _switch(
      'minimalist',
      'look',
      'Minimalist',
      'A plain IPTV player in one switch: the classic compact Timeline '
          'guide, groups that fold away, no Refined finish, and no Home, '
          'profiles, Sports Trak or Media Hub; opens on TV. Off puts every '
          'one of those back as it was. Each can still be changed by itself.',
      (b) => b.prefs.minimalist,
      (b, on) => b.prefs.setMinimalist(on)),
  _switch('show_clock', 'look', 'Show clock', 'The clock on screen.',
      (b) => b.prefs.showClock, (b, on) => b.prefs.setShowClock(on)),
  _switch(
      'player_clock',
      'look',
      'Clock in full screen',
      'A small clock in the full-screen player\'s top-right corner.',
      (b) => b.prefs.playerClock,
      (b, on) => b.prefs.setPlayerClock(on)),
  _switch('clock_24h', 'look', '24-hour clock', 'Times as 24-hour.',
      (b) => b.prefs.use24h, (b, on) => b.prefs.setUse24h(on)),
  // ---- guide
  _AiSetting('guide_layout', 'guide', 'Guide',
      'Live = one channel\'s now / next at a time; Timeline = a schedule grid.',
      choices: const [('live', 'Live'), ('timeline', 'Timeline')],
      read: (b) => b.prefs.guideViewMode,
      write: (b, v) async => b.prefs.setGuideViewMode('$v')),
  _switch(
      'guide_full_video',
      'guide',
      'Full-screen video behind the guide',
      'The channel plays full screen behind a see-through guide.',
      (b) => b.prefs.guideFullVideo,
      (b, on) => b.prefs.setGuideFullVideo(on)),
  _AiSetting('guide_transparency', 'guide', 'Guide transparency',
      'With guide_full_video: 0 is solid, 100 is clear.',
      min: 0,
      max: 100,
      unit: '%',
      read: (b) => b.prefs.guideTransparency,
      write: (b, v) async => b.prefs.setGuideTransparency(v as int)),
  _switch(
      'guide_compact',
      'guide',
      'Compact guide',
      'Shorter Timeline rows: more channels fit.',
      (b) => b.prefs.guideCompact,
      (b, on) => b.prefs.setGuideCompact(on)),
  _switch(
      'guide_expand',
      'guide',
      'Expand',
      'With guide_full_video: the Timeline fills the screen.',
      (b) => b.prefs.guideExpanded,
      (b, on) => b.prefs.setGuideExpanded(on)),
  _switch(
      'guide_row_details',
      'guide',
      'Programme details in the guide',
      'With guide_full_video: resting 1 s on a programme opens its '
          'description under the row.',
      (b) => b.prefs.guideRowDetails,
      (b, on) => b.prefs.setGuideRowDetails(on)),
  _switch(
      'guide_channel_numbers',
      'guide',
      'Channel numbers',
      'A number before each channel in the guide channel list.',
      (b) => b.prefs.guideChannelNumbers,
      (b, on) => b.prefs.setGuideChannelNumbers(on)),
  _switch(
      'guide_two_line_names',
      'guide',
      'Long channel names on two lines',
      'Channel names that don\'t fit wrap onto a second line in the guide.',
      (b) => b.prefs.guideTwoLineNames,
      (b, on) => b.prefs.setGuideTwoLineNames(on)),
  _switch(
      'keep_groups_open',
      'guide',
      'Keep groups open',
      'The TV tab\'s groups column stays open beside the channels after a '
          'pick.',
      (b) => b.prefs.keepGroupsOpen,
      (b, on) => b.prefs.setKeepGroupsOpen(on)),
  _switch(
      'groups_follow_focus',
      'guide',
      'Show channels while moving through groups',
      'Remote / keyboard: the group the highlight rests on shows its '
          'channels without OK.',
      (b) => b.prefs.groupsFollowFocus,
      (b, on) => b.prefs.setGroupsFollowFocus(on)),
  _switch(
      'preview_badges',
      'guide',
      'Quality on the preview',
      'HD / FHD / 4K and the frame rate in a corner of the guide\'s preview.',
      (b) => b.prefs.previewBadges,
      (b, on) => b.prefs.setPreviewBadges(on)),
  // ---- tabs
  _AiSetting(
      'ui_size',
      'tabs',
      'Interface size',
      'Compact = smaller tabs, groups and channel rows (more fit on screen); '
          'Large = bigger text and rows, easier to read.',
      choices: const [
        ('compact', 'Compact'),
        ('normal', 'Normal'),
        ('large', 'Large'),
      ],
      read: (b) => b.prefs.uiSize,
      write: (b, v) async => b.prefs.setUiSize('$v')),
  _switch(
      'compact_ui',
      'tabs',
      'Compact UI',
      'Same as ui_size compact (off = normal).',
      (b) => b.prefs.compactUi,
      (b, on) => b.prefs.setCompactUi(on)),
  _switch(
      'hide_home',
      'tabs',
      'Hide Home',
      'Removes the Home tab (Home stays when it is the only page left).',
      (b) => b.prefs.hideHome,
      (b, on) => b.prefs.setHideHome(on)),
  _switch('hide_live_tv', 'tabs', 'Hide Live TV', 'Hides the TV tab.',
      (b) => b.prefs.hideLiveTv, (b, on) => b.prefs.setHideLiveTv(on)),
  _switch('hide_movies', 'tabs', 'Hide Movies', 'Hides the Movies tab.',
      (b) => b.prefs.hideMovies, (b, on) => b.prefs.setHideMovies(on)),
  _switch('hide_tv_shows', 'tabs', 'Hide TV Shows', 'Hides the TV Shows tab.',
      (b) => b.prefs.hideShows, (b, on) => b.prefs.setHideShows(on)),
  _switch(
      'hide_whats_new',
      'tabs',
      "Hide What's New",
      "Movies and TV Shows open on All, without the What's New carousel.",
      (b) => b.prefs.hideWhatsNew,
      (b, on) => b.prefs.setHideWhatsNew(on)),
  _switch(
      'hide_sports_trak',
      'tabs',
      'Hide Sports Trak',
      'Hides Sports Trak (and turns Sports Mode off).',
      (b) => b.prefs.hideSportsTrak,
      (b, on) => b.prefs.setHideSportsTrak(on)),
  _switch('hide_media_hub', 'tabs', 'Hide Media Hub', 'Hides the Media Hub.',
      (b) => b.prefs.hideArchive, (b, on) => b.prefs.setHideArchive(on)),
  _switch(
      'hide_recordings',
      'tabs',
      'Hide Recordings',
      'Hides the Recordings tab.',
      (b) => b.prefs.hideRecordings,
      (b, on) => b.prefs.setHideRecordings(on),
      androidOnly: true),
  _switch(
      'hide_multiview',
      'tabs',
      'Hide Multiview',
      'Hides Multiview and the player\'s Open in Multiview.',
      (b) => b.prefs.hideMultiview,
      (b, on) => b.prefs.setHideMultiview(on)),
  _switch(
      'hide_catch_up_group',
      'tabs',
      'Hide Catch-up group',
      'Hides the TV tab\'s Catch-up group.',
      (b) => b.prefs.hideCatchupGroup,
      (b, on) => b.prefs.setHideCatchupGroup(on),
      androidOnly: true),
  _switch(
      'recently_added_group',
      'tabs',
      'Recently added channels',
      'A TV tab group with the channels added in the last 14 days.',
      (b) => b.prefs.recentChannelsGroup,
      (b, on) => b.prefs.setRecentChannelsGroup(on)),
  _switch(
      'hide_home_profiles',
      'tabs',
      'Hide profiles',
      'Hides the profile cards on Home.',
      (b) => b.prefs.hideProfiles,
      (b, on) => b.prefs.setHideProfiles(on)),
  _switch(
      'home_mini_player',
      'tabs',
      'Mini player on Home',
      'The live channel highlighted on Home plays in a small player at the top right.',
      (b) => b.prefs.homeMiniPlayer,
      (b, on) => b.prefs.setHomeMiniPlayer(on)),
  _switch(
      'show_group_counts',
      'tabs',
      'Show group counts',
      'How many channels / titles each group holds, beside its name.',
      (b) => b.prefs.showGroupCounts,
      (b, on) => b.prefs.setShowGroupCounts(on)),
  _switch(
      'mix_favourite_playlists',
      'tabs',
      'Mix playlists in Favourites',
      'Favourites of every playlist together, A-Z.',
      (b) => b.prefs.mixFavoritePlaylists,
      (b, on) => b.prefs.setMixFavoritePlaylists(on)),
  _switch(
      'open_groups_expanded',
      'tabs',
      'Open groups as expanded catalog',
      'Movies / TV Shows groups open as a full poster grid.',
      (b) => b.prefs.expandedBrowse,
      (b, on) => b.prefs.setExpandedBrowse(on)),
  _switch(
      'wide_cards',
      'tabs',
      'Wide cards',
      'Movies / TV Shows rows as bigger 16:9 backdrop cards.',
      (b) => b.prefs.wideCards,
      (b, on) => b.prefs.setWideCards(on)),
  _switch(
      'hide_background_video',
      'tabs',
      'Hide the live picture behind other pages',
      'Sports Trak, Settings and Search hide the playing channel\'s picture '
          '(the sound keeps going).',
      (b) => b.prefs.hideVideoOnSports,
      (b, on) => b.prefs.setHideVideoOnSports(on),
      androidOnly: true),
  _switch(
      'vesper_shortcut',
      'tabs',
      'Vesper shortcut',
      'The Vesper row in the menu.',
      (b) => b.prefs.vesperShortcut,
      (b, on) => b.prefs.setVesperShortcut(on)),
  // ---- Sports Trak
  _switch(
      'sports_mode',
      'sports',
      'Sports Mode',
      'The sports-first home (beta).',
      (b) => b.prefs.sportsMode,
      (b, on) => b.prefs.setSportsMode(on)),
  _switch(
      'hide_scores',
      'sports',
      'Hide scores',
      'Hides every score (no spoilers).',
      (b) => b.prefs.sportsHideScores,
      (b, on) => b.prefs.setSportsHideScores(on)),
  _switch(
      'goals_alert',
      'sports',
      'Goals alert',
      'Score popups for My Teams on any screen.',
      (b) => b.prefs.goalsAlert,
      (b, on) => b.prefs.setGoalsAlert(on)),
  _AiSetting(
      'goal_alert_delay',
      'sports',
      'Goals alert delay',
      'Waits before showing a goal, so the popup doesn\'t come before the '
          'stream shows it (HLS streams often run 20 to 30 s behind).',
      choices: const [
        ('0', 'No delay'),
        ('15', '15 seconds'),
        ('30', '30 seconds'),
        ('60', '60 seconds'),
      ],
      read: (b) => '${b.storage.getGoalAlertDelay()}',
      write: (b, v) => b.storage.setGoalAlertDelay(int.parse('$v')),
      shown: (v) => v == '0' ? tr('No delay') : tr('{n} seconds', {'n': '$v'})),
  _switch(
      'redzone_button',
      'sports',
      'NFL RedZone button',
      'The RedZone button beside Standings, shown when a playlist has an NFL '
          'RedZone channel.',
      (b) => !b.storage.getSportsHideRedZone(),
      (b, on) => b.storage.setSportsHideRedZone(!on)),
  _switch(
      'transparent_popups',
      'sports',
      'Transparent popups',
      'Goal alerts and reminders without their background.',
      (b) => b.prefs.transparentPopups,
      (b, on) => b.prefs.setTransparentPopups(on)),
  _switch(
      'betting_odds',
      'sports',
      'Betting odds',
      'Betting lines on game cards (display only).',
      (b) => b.storage.getSportsShowOdds(),
      (b, on) => b.storage.setSportsShowOdds(on)),
  _switch(
      'hide_empty_leagues',
      'sports',
      'Hide leagues with no games',
      'Only leagues with games on the selected day.',
      (b) => b.storage.getSportsHideEmptyLeagues(),
      (b, on) => b.storage.setSportsHideEmptyLeagues(on)),
  _AiSetting('sports_layout', 'sports', 'Games layout',
      'Cards, or a TV guide-style list of the day\'s games.',
      choices: const [('cards', 'Cards'), ('guide', 'Guide')],
      read: (b) => b.storage.getSportsLayout(),
      write: (b, v) => b.storage.setSportsLayout('$v')),
  _AiSetting(
      'game_card_size', 'sports', 'Game card size', 'Size of the game cards.',
      choices: const [
        ('large', 'Large'),
        ('medium', 'Medium'),
        ('small', 'Small'),
      ],
      read: (b) => b.storage.getSportsCardSize(),
      write: (b, v) => b.storage.setSportsCardSize('$v')),
];

const _subtitleScales = {
  'extra_small': 0.6,
  'small': 0.8,
  'normal': 1.0,
  'large': 1.25,
  'extra_large': 1.5,
};

ArchivePlaybackPreferences _hubPlayback(VesperToolbox b) =>
    ArchivePlaybackPreferences.read(b.storage);

/// Saves the viewer's Media Hub playback choices with one of them changed.
Future<void> _setHubPlayback(VesperToolbox b,
    {bool? autoPlay, String? language, int? maxHeight, bool? avoidHdr}) {
  final p = _hubPlayback(b);
  return ArchivePlaybackPreferences(
          autoPlay: autoPlay ?? p.autoPlay,
          language: language ?? p.language,
          maxHeight: maxHeight ?? p.maxHeight,
          sourceKey: p.sourceKey,
          avoidHdr: avoidHdr ?? p.avoidHdr)
      .save(b.storage);
}

String _subtitleSizeKey(double scale) => _subtitleScales.entries
    .reduce(
        (a, b) => (a.value - scale).abs() <= (b.value - scale).abs() ? a : b)
    .key;

/// The settings this device has (Android-only ones left out on a computer).
List<_AiSetting> get _visibleSettings => [
      for (final s in _aiSettings)
        if ((!s.androidOnly || !usesMediaKitTarget) &&
            !(appStoreBuild && s.key == 'betting_odds'))
          s
    ];

_AiSetting _settingFor(String key) {
  final k = key.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  for (final s in _visibleSettings) {
    if (s.key == k) return s;
  }
  throw VesperToolError('Unknown setting "$key". Call action list for the '
      'keys.');
}

/// [raw] as [s] stores it: a bool, a choice key or a number in range.
Object _settingValue(_AiSetting s, Object? raw) {
  if (s.isSwitch) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final t = '$raw'.trim().toLowerCase();
    if (const ['true', 'on', 'yes', '1', 'enabled'].contains(t)) return true;
    if (const ['false', 'off', 'no', '0', 'disabled'].contains(t)) {
      return false;
    }
    throw VesperToolError('${s.key} is a switch: give true or false.');
  }
  if (s.choices case final choices?) {
    final t = '$raw'.trim().toLowerCase();
    final folded = TitleSearch.fold('$raw');
    for (final (key, name) in choices) {
      if (key == t || TitleSearch.fold(name) == folded) return key;
    }
    throw VesperToolError('${s.key} takes one of: '
        '${choices.map((c) => c.$1).join(', ')}.');
  }
  final n = raw is num
      ? raw.round()
      : num.tryParse('$raw'.replaceAll(RegExp(r'[^0-9.\-]'), ''))?.round();
  if (n == null) {
    throw VesperToolError('${s.key} takes a number from ${s.min} to '
        '${s.max}.');
  }
  return n.clamp(s.min!, s.max!);
}

/// [value] as the TV says it in the confirm.
String _shownSetting(_AiSetting s, Object value) {
  if (s.shown case final shown?) return shown(value);
  if (s.isSwitch) return tr(value == true ? 'turn on' : 'turn off');
  if (s.choices case final choices?) {
    return tr(choices.firstWhere((c) => c.$1 == value).$2);
  }
  return '$value${s.unit}';
}

Map<String, Object?> _describeSetting(VesperToolbox box, _AiSetting s) => {
      'key': s.key,
      'name': s.label,
      'value': s.read(box),
      if (s.isSwitch) 'type': 'switch',
      if (s.choices case final choices?) ...{
        'type': 'choice',
        'choices': [for (final c in choices) c.$1],
      },
      if (s.min != null) ...{
        'type': 'number',
        'min': s.min,
        'max': s.max,
        if (s.unit.isNotEmpty) 'unit': s.unit.trim(),
      },
      'about': s.about,
      if (s.nextStart) 'applies': 'at the next app start',
    };

/// What `clear` can empty, for the model.
const _clearTargets = {
  'searches_and_channels':
      'recent searches and the live channel History (Recent channels)',
  'movies_and_shows':
      'Continue Watching and the saved progress of every movie and episode',
  'media_hub': 'Media Hub Recently watched',
  'watch_list': 'every title on the watch list',
  'all_history':
      'searches_and_channels, movies_and_shows and media_hub together (not '
          'the watch list)',
};

/// The same, as the TV names them in the confirm.
const _clearNames = {
  'searches_and_channels': 'Clear search & channel history',
  'movies_and_shows': 'Clear Movies & TV Shows history',
  'media_hub': 'Clear Media Hub history',
};

/// Every English text the TV's confirm can show for this tool (public for
/// the translations test). Language names and Sports Trak are names: left
/// out.
Set<String> get vesperSettingTexts => {
      'turn on',
      'turn off',
      for (final s in _aiSettings) ...[
        s.label,
        if (!const [
          'language',
          'audio_language',
          'subtitle_language',
          'media_hub_language',
          'media_hub_max_quality',
          'goal_alert_delay',
        ].contains(s.key))
          for (final (_, name) in s.choices ?? const <(String, String)>[])
            if (name != AppConstants.sportsTabName) name,
      ],
      'Source default',
      'Any language',
      'Any quality',
      'No delay',
      '{n} seconds',
      ..._clearNames.values,
    };

const _settingSections = [
  'playback',
  'startup',
  'look',
  'guide',
  'tabs',
  'sports',
];

Future<Map<String, Object?>> _setSettings(
    VesperToolbox box, Map<String, Object?> args, VesperCaller caller) async {
  final asked = <(_AiSetting, Object)>[];
  final changes = args['changes'];
  if (changes is List) {
    for (final c in changes) {
      if (c is! Map) continue;
      final s = _settingFor('${c['key'] ?? ''}');
      asked.add((s, _settingValue(s, c['value'])));
    }
  }
  final key = _str(args, 'key');
  if (key.isNotEmpty) {
    final s = _settingFor(key);
    asked.add((s, _settingValue(s, args['value'])));
  }
  if (asked.isEmpty) throw VesperToolError('Give key and value, or changes.');
  final todo = [
    for (final (s, v) in asked)
      if (s.read(box) != v) (s, v)
  ];
  final same = [
    for (final (s, v) in asked)
      if (s.read(box) == v) s.key
  ];
  if (todo.isEmpty) {
    return {'changed': const [], 'note': 'Already set that way.'};
  }
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot change settings.');
  }
  await _confirmRemote(
      box, caller, 'An AI app wants to change settings: {what}.', {
    'what': [
      for (final (s, v) in todo) '${tr(s.label)}: ${_shownSetting(s, v)}'
    ].join(', ')
  });
  for (final (s, v) in todo) {
    await s.write(box, v);
  }
  final later = [
    for (final (s, _) in todo)
      if (s.nextStart) s.key
  ];
  return {
    'changed': [
      for (final (s, v) in todo) {'key': s.key, 'value': v}
    ],
    if (same.isNotEmpty) 'already_set': same,
    if (later.isNotEmpty)
      'note': '${later.join(', ')}: applies at the next app start.',
  };
}

Future<Map<String, Object?>> _clearHistory(
    VesperToolbox box, String what, VesperCaller caller) async {
  if (!_clearTargets.containsKey(what)) {
    throw VesperToolError('clear takes what: '
        '${_clearTargets.keys.join(', ')}.');
  }
  if (box.restrictedViewer) {
    throw VesperToolError('This profile cannot clear history.');
  }
  if (what == 'watch_list') {
    await _confirmRemote(
        box, caller, 'An AI app wants to clear your watch list.', const {});
    return {
      'cleared': ['watch_list'],
      'titles': await WatchList.instance.clear(box.storage),
    };
  }
  final parts = [
    if (what == 'all_history') ...[
      'searches_and_channels',
      'movies_and_shows',
      if (box.clearHubHistory != null) 'media_hub',
    ] else
      what,
  ];
  if (parts.contains('media_hub') && box.clearHubHistory == null) {
    throw VesperToolError('There is no Media Hub on this TV.');
  }
  await _confirmRemote(box, caller, 'An AI app wants to: {what}.', {
    'what': [for (final p in parts) tr(_clearNames[p]!)].join(', '),
  });
  final out = <String, Object?>{'cleared': parts};
  for (final p in parts) {
    switch (p) {
      case 'searches_and_channels':
        await box.storage.clearRecentSearches();
        await box.playback.clearRecentlyPlayed(live: true);
      case 'movies_and_shows':
        await box.playback.clearRecentlyPlayed(live: false);
      case 'media_hub':
        out['media_hub_titles'] = await box.clearHubHistory!();
    }
  }
  return out;
}

final _settingsTool = VesperTool(
  name: 'settings',
  description: 'The TV\'s VesperTV settings: list them (keys, current '
      'values, choices), get one, or set one or several (playback, startup, '
      'look and language, guide, tabs, Sports Trak). Also clear histories '
      '(recent searches and channels, Continue Watching and saved progress, '
      'Media Hub Recently watched, the watch list) and update_guide (reload '
      'the TV guide now). Call list first: only its keys can be set. Profiles, '
      'the PIN, playlists and the AI settings themselves are not here.',
  schema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'get', 'set', 'clear', 'update_guide'],
      },
      'section': {
        'type': 'string',
        'enum': _settingSections,
        'description': 'For list: only that part.',
      },
      'key': {
        'type': 'string',
        'description': 'For get / set: a key from list.',
      },
      'value': {
        'type': 'string',
        'description': 'For set: "true" / "false" for a switch, one of its '
            'choices, or a number.',
      },
      'changes': {
        'type': 'array',
        'description': 'For set, several at once: [{"key": ..., "value": '
            '...}]. The TV asks once for all of them.',
        'items': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string'},
            'value': {'type': 'string'},
          },
          'required': ['key', 'value'],
        },
      },
      'what': {
        'type': 'string',
        'enum': _clearTargets.keys.toList(),
        'description': 'For clear.',
      },
    },
    'required': ['action'],
  },
  run: (box, args, caller) async {
    switch (_str(args, 'action')) {
      case 'list':
        final section = _str(args, 'section');
        return {
          'settings': [
            for (final s in _visibleSettings)
              if (section.isEmpty || s.section == section)
                {'section': s.section, ..._describeSetting(box, s)}
          ],
          if (section.isEmpty) 'clear': _clearTargets,
          if (box.restrictedViewer)
            'note': 'This is a kids profile: settings can be read, not '
                'changed.',
        };
      case 'get':
        final key = _str(args, 'key');
        if (key.isEmpty) throw VesperToolError('Which setting? Give key.');
        return _describeSetting(box, _settingFor(key));
      case 'set':
        return _setSettings(box, args, caller);
      case 'clear':
        return _clearHistory(box, _str(args, 'what'), caller);
      case 'update_guide':
        if (box.epg.isLoading) {
          return {'updating': true, 'note': 'The guide is already updating.'};
        }
        unawaited(box.epg.refreshAll());
        return {
          'updating': true,
          'note': 'The guide reloads in the background; a big guide can take '
              'a few minutes.',
        };
    }
    throw VesperToolError('action is list, get, set, clear or update_guide.');
  },
);
