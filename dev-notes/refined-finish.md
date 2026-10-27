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
  widget/FocusNode slots; the existing stable wrappers now enable bounded focus blur only when on.
- RefinedFinish.decorate returns the exact original BoxDecoration while off.
  While on it preserves border/radius/padding/image geometry, uses a brighter four-stop
  reflection, painted inner/outer bevels and deeper accent/drop shadows. Artwork
  receives shadows and a foreground rim; never wash or blur posters/logos. EPG focus decorations
  change only for the focused cell; no extra per-cell gradients while idle.
- Low-alpha white/accent fills are first composited over dark before raising
  panel opacity, preventing a white panel with unreadable white labels. Bright
  video scrims use at least78% opacity, preserving readable text. No HDMI/native
  video capture/filter/configuration changes. Frame timing still needs device QA.
- Dialog/bottom-sheet/popup backgrounds and existing Material overlays use dark
  surface shading; themed buttons get a stronger focused tint. Existing shapes,
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
- Full analyze/test/build/install results in root HANDOFF.md.
- Owner requested stronger visible polish and accepted more graphics cost on
  2026-10-26. codex/refined-glass-finish replaces the initial subtle finish.
- Focused menu/switch/mode/app-bar/group controls use the existing clipped sigma14
  BackdropFilter; no blur for idle guide cells or every poster. Settings uses a
  dark, opaque palette-lit backdrop. The native video plane is never sampled.
- Render test checks actual reflection contrast; focus checks verify one active
  blur, stable state/bounds, restored original decoration when off, and intact
  artwork. Actual Theme-screen captures are Logs/refined-glass-{off,on}.png.

Primary references: Flutter BackdropFilter/performance docs were checked during
investigation. The revised finish uses paint plus bounded focus blur; weak devices can disable it.

Translucent guide correction (Codex, 2026-10-27)
- Full-screen video behind the guide now scopes RefinedFinishBackdrop around the
  existing tab/group/guide scrims. Refined chrome uses see-through reflection
  stops and lighter shadows there, retaining rounded geometry and edge bevels.
- Without this scope the .78 opacity floor stays in place for ordinary panels.
  The off state remains original. No setting, native-video or focus dispatch change.
- Render tests compare two background colours through focused/idle chrome; real
  TV-root tests exercise tabs/groups, both toggles, rounded corners and focus.
