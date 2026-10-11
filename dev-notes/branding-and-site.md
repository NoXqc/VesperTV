# Branding assets, palettes, website & screenshots

Read when touching icons, the site, the carousel or screenshots.

## 8. Branding assets & website
- **Logo:** `python assets/icon/gen_icon.py` (Pillow) regenerates `icon_flat/background/foreground.png`,
  `tv_banner.png` and the five `android/app/src/main/res/drawable-*/vespertv_banner.png`. Then
  `dart run flutter_launcher_icons` for launcher icons (Android adaptive, iOS, Windows `.ico`, web,
  macOS). The splash and welcome screen load `assets/icon/icon_flat.png`. Revert incidental
  line-ending-only diffs the icon tool causes (e.g. `ios/Runner.xcodeproj/project.pbxproj`).
  **Android icon/banner resource names were changed on purpose** (3.53.1) to
  `@mipmap/vespertv_launcher` and `@drawable/vespertv_banner` (pubspec `flutter_launcher_icons.android:
  "vespertv_launcher"`) as an attempt to make the Fire TV home screen drop the old purple "N" tile.
  **It did not work:** on the owner's Fire Stick the tile stays purple after updating to 3.53.1,
  clearing caches and restarting, while phones show the new gold V. The APK is correct (verified by
  extracting the icon/banner); Fire OS keeps the icon it captured at first install. Only an
  uninstall + reinstall refreshes it (which wipes that device's playlists/settings) — known,
  unfixable from the app. Leave the new resource names as they are.
- **Palettes:** the default fresh-install theme is **Platinum** (`id: 'minimal'`, first entry of
  `cyberpunkPalettes`); its `primary`/`secondary` only drive the wordmark and small accent bars and
  are now brand gold `F0C75E`/`C9781A` (they used to be the old purple/magenta — that was the bug
  behind "still purple after the rename"). The splash screen's glow/wordmark in `main.dart` are gold
  too. **Dark / Gold** (`dark_gold`) is the full gold theme. Don't move `dark_gold` to first place:
  fresh-install fallback is `cyberpunkPalettes.first`, and users who never picked a palette would
  silently switch theme on update.
- **Site (`docs/index.html`):** one file, design tokens on `:root` (gold = `--violet*` names kept
  from the old purple palette; text on gold fills must be dark `#1A1205`, not white). Hero has a
  `.sky` layer (CSS sun rays + twinkling stars, honours `prefers-reduced-motion`). Under the hero is
  the **swipeable screenshot carousel** (`#galTrack`: native scroll-snap + arrows, dots, ←/→ keys,
  mouse drag; JS at the top of the `<script>`). Windows is advertised in the hero (kicker, "Windows
  (.zip)" button), FAQ and Install section 04. Inline screenshots were deliberately removed in
  favour of the carousel.
- **Screenshots** (`docs/assets/shot-*.png|jpg`, also used in `README.md`): captured from the
  Formuler via `adb screencap` (1920×1080) in Dark / Gold, the **"Hold to resume" pill blurred out**
  (Pillow: crop box (740,902)-(1180,1064), Gaussian blur 30, brightness ×0.5, feathered paste), then
  resized to 1600×900. Retake them after any big UI change.
