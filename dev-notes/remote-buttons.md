# Remote buttons (Settings > Backup & devices > Remote)

Owner, 2026-11-11: give the remote's spare buttons VesperTV actions, and let the full-screen player's
arrows be remapped (side drawer on Right, last channel on Left...). TV boxes only (`prefs.isTelevision`);
the section sits in **Backup & devices** (owner: a remote is a device), not Playback.

## Files
- `lib/services/remote_buttons.dart` - `RemoteButtons.instance`: storage cache (per `viewerGeneration`),
  key handling, learn mode, `RemoteAction.all` (ids are stored: never rename), `PlayerArrow`,
  `RemotePlayerTarget` (the open PlayerScreen registers itself).
- `lib/screens/remote_button_actions.dart` - `RemoteButtonActions.run`: what each action does. Sections go
  through `VesperHost.openSection` (TV home openers; new `'favourites'` case in `TvHomeScreen.openSection`),
  audio / subtitles through Vesper AI's `player` tool, record = the TV home hold menu's Record (until the
  programme ends, or stops the running one), Multiview from the player = its own `_openMultiview`.
- `lib/screens/settings/remote_buttons_screen.dart` - learn page (Add a button, list, edit: short press /
  hold / forget). 15 s with nothing = "your device keeps it for itself".
- `settings_catalog.dart` `_remote()` - the link, the four arrow choices, Reset.
- `player_screen.dart` `_runArrow` - Left/Right (no bar focused) and Up/Down (nothing on screen) on a
  live / catch-up channel. VOD keeps Right = sources, Up/Down = bar. Choices (`PlayerArrow.actions`):
  Side drawer, Last channel, Channel up / down, Player bar, **Back to the guide** (`back`, 2026-11-21,
  uzumaki: Left = what Back does, `Navigator.maybePop` through the player's PopScope; then Left in the
  guide walks to the groups and the tabs), Nothing.

## Rules
- **Key interception = `FocusManager.addEarlyKeyEventHandler`.** A `HardwareKeyboard` handler can't stop
  the focused widget getting the key too (both run), so a CH+ mapped to Favourites would also zap.
  `KeyEventManager.keyMessageHandler` works but is deprecated (analyzer +7 infos): don't use it.
- OK / Back / arrows are never learned or taken (`isNavigation`). Keys are matched on
  `LogicalKeyboardKey.keyId` (unnamed Android keys = `0x11 << 32 | keycode`).
- Short-only button: fires on key down. With a hold: short fires on release, hold on the first key
  repeat (the release is then swallowed). A mapped button does only what it was set to.
- Not taken before the app is ready / during Who's watching (`isActive`), nor while a text field has the
  cursor. Guide key and voice key handlers skip a key a binding owns.
- Storage: `vesper_remote_buttons`, `vesper_player_arrows`, per viewer (`_vk`), **never transferred /
  synced but kept by a backup** (`_transferOnlySkipPrefixes`, new list: `_transferSkipPrefixes` also
  skips backups).
- Arrow actions other than zap run once per press (400 ms debounce: a held Left repeats).
- **Hold on an arrow** (owner, 2026-11-21: "Left -> guide and hold Left -> side drawer"): Settings
  rows "Hold Left / Right / Up / Down in the player" (default Nothing), stored in the same
  `vesper_player_arrows` JSON as `leftHold`... (older versions ignore those keys). With a hold set,
  `_runArrow` starts `_startArrowHold`: the normal action waits for the release (a
  `HardwareKeyboard` handler that only observes the arrow's key up), and 550 ms held runs the hold
  action instead (the release then does nothing; the arrow's repeats meanwhile are ignored).
  Without a hold, the arrow acts on key down as before (a held Up / Down still zaps fast).
  Tests: `test/remote_buttons_test.dart` (storage), `test/player_arrow_remap_test.dart` (quick Left
  = guide, held Left = drawer).
- **Options-row tiles as arrow actions** (owner, 2026-11-23: "assign them to an option in the option
  bar like sources - audio track - subtitles", hold Right = Sources for him): `PlayerArrow.actions`
  gained `opt:<tile id>` (Sources = `live_sources`, `audio`, `subtitles`, `audio_sync`, `recall`,
  `start_over`, `reload`, `buffer`, `stream_info`, `picture`, `multiview`, `search`), for a press and a
  hold alike. `_runArrowAction` -> `PlayerOptionsOrder.activate(id)`: the options row (always built,
  hidden = ExcludeFocus + opacity 0) finds the tile by its `GlobalKey` and invokes the first
  `Actions`' `ActivateIntent` inside it (the tile's InkWell), like OK on it, without showing the row.
  A tile the channel doesn't have (Start over without catch-up, Audio track with one track) does
  nothing. Tile ids are saved: never rename them. Test: holding Right presses Audio sync.
- **The rest of the press stays in the player** (owner, +983, 2026-11-24: hold Left = Back to the guide put the
  guide hours back in catch-up, drawn only at the release): a hold runs while the arrow is still down, so its repeats
  went to the guide (one programme back each). `HeldKeySwallow.restOfPress` (`services/held_key_swallow.dart`, an
  early FocusManager handler: a HardwareKeyboard handler can't keep keys from the focused widget) takes the arrow's
  repeats + release once a hold ran, and after a non-zap press action (Back, drawer, bar, tiles; a held Up / Down
  still zaps on). 5 s safety. Test: player_arrow_remap_test "keeps the rest of its press" (hold + long press).
- Android player only; Windows' `DesktopPlayerScreen` arrows are unchanged.

## Not verified
Which Homatics buttons (YouTube / Netflix / Prime / rocket = vendor keycodes, Settings, Input) reach the
app: learn mode on the box answers it (see `dev-notes/devices.md`). Not box-tested at all yet.
Tests: `test/remote_buttons_test.dart`, `test/player_arrow_remap_test.dart`.

## Owner test +735 (Homatics, 2026-11-12)
- None of the vendor buttons (YouTube / Netflix / Prime / rocket, Settings, Input) reach the app: the
  device keeps them. Bookmark works.
- Bookmark set to Play/Pause only paused the Home mini player. Fixed: Home registers
  `RemoteButtons.home`; a mapped Play/Pause or Stop with no full-screen player open goes through
  Home's own `_onPlayKey` (turns the mini player off / plays the focused live card when off).

## The add-on (2026-11-24)
Play Protect blocks a sideloaded APK that declares an accessibility service: "App blocked to protect your
device ... can request access to sensitive data", only "Got it", no Install anyway; turning Play Protect off
isn't enough (See61 on Reddit, Homatics R Plus with Android TV certification; true for every install since
+752). So the service moved out of VesperTV into **"VesperTV remote buttons"** (`android/remotebuttons`,
package `com.nox.nox_iptv.remotebuttons`, ~73 KB, signed with VesperTV's key):
- `RemoteKeyService` (same logic as before) + `LinkService` (Messenger, exported behind the signature
  permission `com.nox.nox_iptv.permission.REMOTE_KEYS`, declared by both apps).
- VesperTV `RemoteKeysLink.kt` binds it on every resume (when installed), sends HELLO (its Messenger), STATE
  (on screen, learning, taken key codes) on resume / pause / setTaken / setLearning; the add-on sends KEY
  (the KeyEvent) and STATUS (accessibility service running). Keys go to `MainActivity.dispatchKeyEvent`.
- Settings > Remote buttons: add-on missing = **Buttons your box keeps** downloads
  `https://vespertv.app/addons/VesperTV-remote-buttons.apk` (`RemoteKeys.addonUrl`, docs/addons, size from a
  HEAD) and hands it to Android's installer through `AppUpdateService`. Never attach it to a GitHub release:
  the updater installs a release's first `.apk`.
- Build: `flutter build apk --config-only` once (for gradlew), then from `android/`:
  `./gradlew :remotebuttons:assembleRelease` -> `build/remotebuttons/outputs/apk/release/`; verify the
  signature, copy to `docs/addons/VesperTV-remote-buttons.apk`, bump `versionCode` in its build.gradle.kts on
  any change.
- Viewers who had it on lose it after updating until they install the add-on (the row says so).
- Unknown: whether Play Protect also blocks the add-on when VesperTV installs it (it is a sideloaded app with an
  accessibility service). If so, those viewers need the Play Store workaround or adb for that one small app;
  VesperTV itself installs normally either way.
