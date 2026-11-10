# Home: live channel look + Home wallpaper (2026-11-10, test +703/+704)

Discord idea (Kal-el23, with a mock-up of CP24 over a Toronto skyline): the Home hero is empty for a
live channel; a banner that changes with the channel, or your own wallpaper. Owner picked
**automatic channel look** + **Home wallpaper**, and "when wallpaper is used it supersedes the channel
banner". Not done (offered, not chosen): a banner picture per channel, guide programme pictures
(XMLTV `<icon>` would need a new EPG DB column).

## Channel look (`home_screen.dart`)
- `_HomeItem.logoUrl` + `programme` (set in `_channelItem`). The card itself is unchanged.
- `_LiveHero`: logo (CachedNetworkImage, height = 32 % of the hero, 28-72 px, max 4x as wide) + LIVE
  pill, programme title (else the channel name), "channel · start – stop" (else the group), then the
  guide description in as many lines as the hero has room for (0-3). A 960x540 TV has ~167 px.
- `_ChannelGlow`: two radial glows in the logo's colours (`services/logo_colors.dart`), one key for
  every channel so the colours blend from channel to channel (AnimatedContainer, 600 ms). Black /
  white / grey logos (or a logo that doesn't load) = the theme colour, dimmer.
- `LogoColors.dominant`: logo decoded at 48 px (ResizeImage over the cards' CachedNetworkImageProvider,
  `rawStraightRgba`), 12 hue bins weighted by saturation x value, transparent / dark (<0.2) / grey
  (s<0.25) pixels skipped, top bin needs 3 % of the opaque pixels; second colour = 2+ bins away and a
  fifth of the weight. `glow()` = saturation >= 0.6, lightness 0.4-0.55. Cached per URL (200).

## Wallpaper (`services/home_wallpaper.dart`)
- One file per viewer: app support `wallpapers/<viewerId>.jpg`, centre-cropped to 16:9, at most
  1920x1080, JPEG 85. A file, not a setting: never in Transfer / Backup. Deleted with the viewer.
- Settings > **General** > **Home wallpaper** (owner moved it there from Interface > Tabs, +704):
  `screens/settings/home_wallpaper_screen.dart`, a 16:9 preview of the current one + the profile-photo
  buttons (`ProfilePhotoActions(kind: wallpaper)`): QR (Wi-Fi), Choose a photo (computers / phones,
  up to 15 MB), Remove photo (focus goes back to the first button).
- `PairingKind.wallpaper` = suffix `wallpaper`, same `photo` payload. `pair.html` crops to a 1920x1080
  canvas and lowers the JPEG quality until it fits the TV's 2 MB limit. The relay's old pair.html
  doesn't matter: photo kinds are Wi-Fi only (the TV serves the page).
- `_Backdrop` order: team game -> its game backdrop; card art -> the art; else wallpaper if set;
  else a live channel's glow; else nothing. The wallpaper gets lighter gradients than art (left 70 %
  black fading out by 60 % width, bottom dark for the rows).

Tests: `test/home_look_test.dart`. Not device-tested at first.
