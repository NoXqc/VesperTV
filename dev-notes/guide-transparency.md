# Guide transparency (2026-11-04)

Settings > Interface > Guide > Timeline > Full-screen video behind the guide
now includes a **Guide transparency** slider, shown while that option is on.

- 0–100%, in 1% steps; 0% is solid and 100% is clear. Works with touch/mouse
  and the remote's Left/Right keys; the current percentage stays visible.
- Saved per device as `vesper_guide_transparency`. Default 45% preserves the
  previous 55% dark guide background. Stored/written values are clamped to range.
- Applies to the full-video guide's navigation/groups/grid background and
  description card. Current-programme cell shading scales proportionally from
  its previous 45% dark fill, reaching clear at 100%; focus borders/text remain.
- Updates existing widgets in place, preserving focus and scroll state. Turning
  off full-video mode keeps the saved percentage for next time. The regular
  Live layout, browse artwork backgrounds and Windows guide keep their behavior.
- Refined finish retains its foreground sheen/blur; the slider controls the
  dark background underneath it.

Implementation: `GuideSettingsScreen`, `AppPreferences.guideTransparency` /
`guideOverlayOpacity`, `StorageService`, `_fullVideoScrim`,
`_buildFullVideoNowCard` and the Timeline programme cell in `TvHomeScreen`.
Strings are translated in FR/ES/IT/EL/DE.

Tests: `guide_transparency_test.dart` verifies persistence, defaults, invalid
saved values, touch/remote control, visibility and Windows gating;
`wide_guide_back_test.dart` verifies background alpha and stable widget/focus
identity. No player/vendored plugin changes.

Validation: targeted `00:03 +27: All tests passed!`; analyze
`16 issues found. (ran in 8.3s)`; full suite
`00:40 +1236: All tests passed!`. No app build or physical-device QA.
