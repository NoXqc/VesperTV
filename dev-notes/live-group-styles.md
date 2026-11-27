# Live group styles

Owner, 2026-11-26: "Users do like the colored groups ... can we add the option to favourites
history catch-up group. And can we somehow create a bank of *live* group that users could download
... Like a Christmas theme one with snowflakes that starts to move on focus. Some with small shooting
stars *vesper style* a few sports one for popular sports ... It'd be a similar *download* that we do
for the custom badges for add-ons."

Branch `claude/live-groups` (worktree `VesperTV-claude-livegroups`, from main 1670eb2).

## What the viewer sees

- Hold OK on a TV group (or an own group) > **Colour…** > **Live styles…** (after the 8 colours):
  a gallery downloaded from the site, by category (Seasonal, Vesper, Sports, Fun). Each row previews
  its style at group-row size and moves while the remote is on it. OK = the group wears it.
- A styled group is **still** while the remote is elsewhere (one frame, particles spread along their
  way) and **moves** while the remote is on it. The usual focus border stays.
- **Favourites, History, Catch-up and Recently added** (TV tab) get Colour… too: their hold is now a
  small menu, Colour… first, then what the hold did before (Clear favourites…, Delete watched
  history…, Catch-up playlists). Movies / TV Shows' Favourites hold still clears straight away.
- **Select more groups…** lists those four rows first, and its colour menu offers Live styles… too
  ("Live style for N groups").
- Vesper AI / AI apps (MCP connector) `groups` action `colour` takes `style` (id or name in any language)
  instead of `colour`, and reaches Favourites / History / Catch-up / Recently added by name (`_colourRows`:
  Favorites, Catch up... too; words match only the shown name). `list` on tab tv adds `rows` with their colour.
  An AI app sees new actions only after the connector is reconnected (its tool list is cached).

## Saving

A style is saved where a colour is: `vesper_group_colors_<playlist|own>` (per viewer, synced,
backed up, follows a rename), as `style:<id>`. The four special rows use the own scope with keys
`__favorites__`, `__history__`, `__catchup__`, `__recent__`. An app older than this reads
`style:...` as no colour (GroupColor.of returns null). A device that gets a style id by sync and has
no bank downloads it the first time a row needs it (`LiveGroupStyles.ensureLoaded(wanted:)`, once a
run).

## The bank

`docs/styles/group-styles.json` in the repo = **https://vespertv.app/styles/group-styles.json**
(GitHub Pages: a push to main publishes it; no server deploy). The owner said "from our relay";
the site was chosen because a new style is then one commit, and the relay's deployed `relay.py`
has a pending, unapproved update (tools/pair_relay/README.md) that a deploy would drag along. Moving
it to `pair.vespertv.app` later = a static route there + `LiveGroupStyles.bankUrl`.

A test build can point elsewhere: `--dart-define=VESPER_STYLES_URL=http://<pc>:<port>/group-styles.json`.

The app (`lib/services/live_group_styles.dart`, `LiveGroupStyles`):

- reads the saved copy (`live_group_styles.json` in app support) the first time a styled row or the
  picker needs it, never at startup;
- downloads when the picker opens (once a run), when the copy is a day old, or when a saved id isn't
  in it; 15 s timeout, 1 MB cap; a failed download keeps the saved copy ("Couldn't get the live
  styles..." only when there is none).

### Format

```json
{
  "version": 1,
  "styles": [
    {
      "id": "snowfall",                    // a-z 0-9 -, never rename (it is what's saved)
      "category": "seasonal",              // seasonal | vesper | sports | fun (else: More)
      "name": {"en": "Snowfall", "fr": "Chute de neige", ...},   // en required
      "engine": 1,                         // optional: a style needing a newer app is left out
      "fade": ["#993A7BD5", "#4D1E3C72", "#00000000"],  // left to right, #AARRGGBB; end clear
      "pulse": 0.35,                       // optional: the fade breathes (cycles/s)
      "layers": [
        {"shape": "snowflake", "motion": "fall", "count": 12, "size": [3, 9], "speed": 11,
         "color": ["#FFFFFF", "#BBDEFB"], "opacity": [0.5, 1], "spin": 0.2, "sway": 6}
      ]
    }
  ]
}
```

Layer fields: `shape`, `motion`, `count` (1-40), `size` px (one number or [min, max]), `speed`
(px/s for moving motions; cycles/s for twinkle, chase, wave), `color` (one or a list), `opacity`
([min, max]), `spin` (turns/s), `sway` (px side to side; a wave's height), `tilt` (px sideways per px
down: slanted rain), `gap` (s between passes: streak, slide, arc, burst), `glow`, `fadeOut` (fades
along its way: embers), `x` / `y` (the part of the row, fractions: one number or [from, to]), `chars`
(the char shape's characters).

Shapes (engine 1): `dot`, `snowflake`, `star4` (Vesper's four-point star), `star5`, `heart`,
`spark`, `bubble`, `confetti`, `balloon`, `puck`, `dash`, `vline`, `hline`, `band`, `char`,
`glyph:<name>` (Material icons listed in `liveStyleGlyphs`: sports_soccer, sports_hockey,
sports_football, sports_basketball, sports_baseball, sports_tennis, sports_golf, sports_motorsports,
sports_rugby, sports_volleyball, sports_cricket, sports_mma, sports_esports, emoji_events,
music_note, movie, eco, local_florist, ac_unit, favorite, bolt, pets, cake, rocket_launch, park,
nightlight, local_fire_department, celebration; a new icon needs an app update).

Motions (engine 1): `fall`, `rise`, `drift`, `drift-left`, `twinkle` (in place, brightness pulses),
`chase` (evenly spaced lights, a bright one runs along: Christmas / cinema lights), `streak`
(shooting star with a tail, then a pause), `bounce`, `roll` (along the bottom, turning), `slide` (a
fast pass with a short trail: puck), `arc` (thrown: football), `burst` (fireworks), `still` (lines:
rink, pitch), `wave` (soft bands rolling: aurora, neon).

A layer with an unknown shape or motion is skipped; a style with no fade and no usable layer is left
out. A new shape or motion = an app update + `engine: 2` on the styles that use it.

### Adding a style

Edit `docs/styles/group-styles.json` (25 styles on 2026-11-26), keep names in the 9 languages
(test/live_group_styles_test.dart checks every style parses whole, has every language and a fade
that ends clear). To see them: `flutter test tool/live_styles_sheet_test.dart
--dart-define=OUT=<folder>` writes `live_styles_sheet.png` (every style at 4 moments, with the SDK's
Roboto + MaterialIcons fonts; not part of the suite). Rows are about 260 x 44 px on the TV.

## Drawing and frame cost

`lib/widgets/live_style_view.dart`: `LiveStyleBackground` (a 30 fps timer, only while the row has
focus and for at most 30 s per visit, then still until the remote comes back; off when the page is
covered (TickerMode) or `MediaQuery.disableAnimations`) +
`LiveStylePainter` (every particle's place comes from its seed and the time: no per-particle state;
repaints alone through `CustomPainter(repaint:)` inside its own RepaintBoundary). Glyphs / characters
are laid out once and cached (alpha in 16 steps). One moving row at a time: the focused one.

Homatics (1034 / 1035, 2026-11-26, `Frames:` lines): a still styled row costs nothing (no frames).
A moving one: every frame re-rasters the whole screen on this box, however small the change: ~21 ms
raster without video (a vsync ticker gave ~44 uneven frames a second, 3-8 over 33 ms per 10 s), ~27 ms
with a channel in the preview (40-53 frames over 33 ms per 10 s, ticker or 30 fps timer alike). The
painter itself is a few hundred lines and circles. Hence 30 fps (steady pacing, half the frames of a
60 Hz ticker without video) and the 30 s limit per visit (a remote left on a group doesn't keep the
GPU busy). Video plays on its own surface and keeps its frames.

## Code

- `lib/services/live_group_styles.dart` - model, parser, bank download / cache.
- `lib/widgets/live_style_view.dart` - background widget + painter.
- `lib/widgets/live_style_picker.dart` - the gallery (`showLiveStylePicker`).
- `tv_home_screen.dart` - `_askGroupColor` (Live styles… row), `_specialRowMenu`, `_StyledRowBox`
  (fade + style layer for `_GroupRow` and `_SelectableRow`), `_liveStyleIdOf`, `_swatchOf`.
- `vesper_ai/vesper_tools.dart` - `groups` colour `style`.
- Tests: live_group_styles_test, tv_live_group_styles_test, tv_group_colors_test,
  vesper_my_groups_tool_test, catchup_guide_test (hold menu).
