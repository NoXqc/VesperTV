# One bottom info bar for the live player (planned, 2026-11-17)

Not built. Waiting for the owner's Discord poll (90 % for "at the bottom" so far).

## Why
Users suggested moving the live player's top info card (logo, channel, playlist tag, Channel
schedule, programme, times + progress, description) into the bottom bar, like other IPTV apps
(owner's example: a French app's one-row bar with clock, logo, channel, programme, progress,
star, pause, PROGRAMMES, time left, FHD / 25 FPS). Today the channel name, the times and the
progress show twice (card + bar), and the two take ~370 px at 1080p.

## Mockups
`C:\Users\aarse\VesperTV-mockups\vesper_bar_zap.png` (channel up/down) and `vesper_bar_ok.png`
(after OK), rendered with Flutter over a real frame (CNews), 1920x1080. Not in git (images).

## Layout (logical px at 960x540, the box's 1080p)
- Line 1 (34): clock | channel logo | channel name + playlist GoldTag | programme title
  .......... "24 min left" + quality / FPS GoldTags.
- Line 2: start time ─── gold progress ─── end time.
- Line 3: programme description, one line (owner: viewers want it on a zap too).
  - Channel up/down: full width, display only (nothing focused: Up/Down keep zapping),
    hides after a few seconds.
  - OK: the line shortens and ☆ / Play-Pause / Channel schedule appear at its right; the
    bar doesn't change height. Down = the options row as today.
- Height: 225 px at 1080p in both states (vs ~370 px for card + bar today). Owner: subtitles /
  CC don't need moving for that much; check they sit above it while it shows.

## To do when it's built
- Android `PlayerControls` live layout + the zap info card + Channel schedule moves into the
  bar; catch-up keeps its own controls. Windows (`DesktopPlayerScreen`) later.
- Keep the old top card as an option for a release if the poll is split (it isn't so far).
