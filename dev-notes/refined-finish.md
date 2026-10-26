# Refined finish (Codex, 2026-10-26; unreleased)

Owner approved the finish-only direction and requested an Interface > Theme
Refined finish toggle. Layout, spacing, navigation, text sizes, theme colours,
artwork and playback must remain the same. Default off; independent per viewer.

Implementation
- StorageService stores vesper_refined_finish through _vk. AppPreferences loads it
  and notifies on toggle; reloadPaletteForViewer also compares finish when the
  palette is unchanged. Generic backup/transfer retains independent values.
- RefinedFinish ThemeExtension is installed at root MaterialApp and existing
  withTvThemeIfNeeded/TvHomeScreen ThemeData boundaries. Theme updates preserve
  widget/FocusNode slots; no additional layers, wrappers, blur or animations.
- RefinedFinish.decorate returns the exact original BoxDecoration while off.
  While on it preserves border/radius/padding/image geometry, uses a quiet dark
  three-stop highlight, and reduces existing focused glow. Artwork only receives
  the shadow adjustment; never wash or blur posters/logos. EPG focus decorations
  change only for the focused cell; no extra per-cell gradients while idle.
- Low-alpha white/accent fills are first composited over dark before raising
  panel opacity, preventing a white panel with unreadable white labels. Bright
  video scrims use at least82% opacity, preserving readable text. No HDMI/native
  video capture/filter/configuration changes. Frame timing still needs device QA.
- Dialog/bottom-sheet/popup backgrounds and existing Material overlays use dark
  surface shading; themed buttons get a restrained focused tint. Existing shapes,
  dimensions, positions, focus/selected borders, labels and semantics remain.

Coverage
- Shared menu/switch/mode/app-bar controls, settings panels, TV rail/group rows;
  Home/IPTV/Media Hub poster chrome; Sports games/network/channel/live cards;
  focused guide controls; source drawer, player bars/side panels and Data pool;
  source info, game reminder and Goals alert surfaces; shared dialogs/sheets.
- Off state intentionally remains the existing appearance everywhere. No new
  colour palettes; the owner's separate theme expansion remains on hold.

Verification
- refined_finish_test.dart checks default/persistence/profile isolation (including
  same-palette profile change), backup/transfer, real Theme toggle and unchanged
  component geometry/state/focus for Dark Gold/Habs/Minimal/Neon Green.
- Existing profile_theme_test now checks finish reload on the real profile switch;
  adds the previously missing Wakelock platform mock for PlaybackService.dispose.
- Full analyze/test results in root HANDOFF.md; no release/build/install requested.
- Pending separate branches: game-card-reminders173d08d, decoder-hdr-reportingb0b0889.

Primary references: Flutter BackdropFilter/performance docs were checked during
investigation. This implementation deliberately uses paint only rather than blur.
