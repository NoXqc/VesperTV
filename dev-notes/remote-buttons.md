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
  live / catch-up channel. VOD keeps Right = sources, Up/Down = bar.

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
