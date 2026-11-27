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

Edit `docs/styles/group-styles.json` (29 styles on 2026-11-27, 4 of them scenes), keep names in the 9 languages
(test/live_group_styles_test.dart checks every style parses whole, has every language and a fade
that ends clear). To see them: `flutter test tool/live_styles_sheet_test.dart
--dart-define=OUT=<folder>` writes `live_styles_sheet.png` (every style at 4 moments, with the SDK's
Roboto + MaterialIcons fonts; not part of the suite). Rows are about 260 x 44 px on the TV.

## Your own styles (2026-11-27)

Owner: "import custom live groups so if users want to build their own they could import it into
Vesper"; picked import by **link + pasted text**, a **format page + starter**, and **Vesper AI through
the MCP connector** (no web builder; the scene editor came the same day, see Scenes).

- **Where:** Colour… > Live styles… > **Your own styles…** (first row of the gallery) and Settings >
  Appearance > Look > **Your live styles**: one page (`screens/settings/my_live_styles_screen.dart`)
  with a field (a link, or the text on a computer), **Import**, **From phone** (`PairingKind.styles`:
  pair.html's link form worded for it, mode `styles`, up to 200 KB of text, whitespace kept; Wi-Fi
  only like every non-playlist kind) and the viewer's styles below (OK = remove; a style from a link
  removes the link and all its styles, or the next refresh would bring it back). On a TV box a small QR code (96
  px, `MyLiveStylesScreen.qrSize`) beside "How to make one" opens vespertv.app/styles/make.html on the phone (owner:
  "not too big ... TV only"); phones and computers get the address as text.
- **Format:** the bank's (above): a pack `{"styles": [...]}`, a list, or one style. `MyLiveStyles.ours`
  lower-cases the id to a-z 0-9 -, puts **`my-`** in front (the bank must never use that prefix: a
  test checks), takes a name in any language as the English one (or the id), sets category `mine`
  ("Your styles", first in the gallery). An entry the app can't draw is left out and counted.
- **Saved:** `vesper_live_styles_mine` (`AppConstants.keyMyLiveStyles`): a JSON list of sources
  `{"url": link or null, "styles": [...]}`, one per household, synced / transferred / backed up like
  the group colours that name the styles (not a live sync key: a pulled change lands at the next
  launch). Read at startup by `MyLiveStyles.attach` (a small preference) and handed to
  `LiveGroupStyles.useMine` (viewer's styles + the bank in `styles` and `styleOf`). At most 60 styles
  (the oldest go); the same id again replaces it; the same link again replaces its styles.
- **Links** are downloaded again when the gallery opens, once a run, in the background (15 s timeout,
  200 KB cap); a failed refresh keeps the saved copy.
- **AI apps (MCP) / Your AI:** tool `live_styles` (`list` / `add` with `style` object or `url` /
  `remove`); its description carries the whole format, shapes, motions and icons, so an AI can write
  a style from a sentence, then put it on a group with `groups` colour `style my-<id>` (`groups` also
  finds `my-<name>` by the plain name). An AI app sees the new tool after reconnecting the connector.
- **Site:** https://vespertv.app/styles/make.html (`docs/styles/make.html`: steps, Ask your AI, the
  fields, shapes, motions, icons, tips) + `docs/styles/starter.json` (two styles). A test checks the
  starter imports whole and the page lists every shape / motion / icon the app knows: a new one =
  add it to the page too.
- Tests: test/my_live_styles_test.dart.

## Scenes (engine 2, 2026-11-27)

Owner, after the Claude app wouldn't make a Mario style (a known character; and the particle engine
couldn't draw a character anyway): "Scope the sprite-scene engine", then "Loop on focus ... Rest when
out of focus/highlight. Editor page now and AI connector updated". Branch `claude/live-style-scenes`
(worktree `VesperTV-claude-scenes`, from main bde3ba0).

- **What:** a style's `scene` = pixel-art sprites on a timeline (`lib/services/live_style_scene.dart`,
  `LiveStyleScene`). A sprite: a `palette` (one character per colour, up to 24; `.` and space are
  always clear), `frames` = rows of palette characters (up to 32 x 32), one list or named sets (up to
  6 sets x 8 frames), `fps` (default 6). An actor: a sprite `at` [x, y] (still) or on a `path` of up to
  48 points `{t, x, y, play, flip, arc, ease}`, optional `show` windows ([a, b] or a list; b < a crosses
  the loop's end). x = the sprite's middle across the row, y = its feet down the row (0..1; outside =
  off the row). Between two points: straight, eased (`in`, `out`, `inout`), `arc` = a hop of that many
  rows peaking halfway in time; `play` and `flip` hold until a point changes them; before the first
  and after the last point the sprite stays. Scene: `length` (0.5-60 s, default 8), `rest` (the still
  moment, default length / 2), `grid` (sprite pixels per row height, 8-64, default 22). Limits: 12
  sprites, 16 actors. Anything it can't draw is left out with a note (`LiveStyleScene.check`).
- **Stateless:** `scene.at(t)` gives every placement from the time alone (like the particles).
- **Focus (owner: loop on focus, rest out of it):** still = the `rest` moment. With the remote on the
  row the scene plays from `rest` (`rest + elapsed`, `LiveStyleBackground._sceneElapsed`) and loops.
  A visit is whole loops of at least the usual 30 s (`LiveStyleBackground.visitFor`: an 8 s scene
  moves 32 s), so it stops exactly on its rest moment; the remote leaving = the rest moment at once.
  Touch screens: whole loops of at least 12 s.
- **Drawing:** `paintScene` (live_style_view.dart): a sprite pixel = `max(1, round(row height x dpr /
  grid))` device pixels (rounding down halved the sprites on rows a little shorter than the grid),
  positions snapped to device pixels, no smoothing; each frame is drawn once into an image
  (`toImageSync`, cached per sprite / set / frame in an Expando; rects if that fails). A sprite taller
  than `grid` is cut by the row. Same frame cost as a moving particle row (30 fps, one row at a time).
- **Older apps:** a style with a scene says `"engine": 2` (`LiveGroupStyles.engine` is 2): 1.0.73 and
  older leave it out. `MyLiveStyles.ours` marks an imported style with a scene engine 2.
- **Bank:** 4 scenes drawn for VesperTV: `fox-trail` (fun: a fox runs, jumps a log, a leaf falls),
  `rocket-ride` (fun), `sleigh-ride` (seasonal), `slapshot` (sports). Never a known character or logo:
  the bank and the editor are public.
- **Editor:** https://vespertv.app/styles/editor.html (`docs/styles/editor.html`, one page, plain JS
  module): pixel editor (pencil, eraser / right click, fill, flip, onion skin, colours with opacity,
  frame sets and frames, resize), actors with a path table (paused: pick a point, click the row to put
  it there; + Point at the current time), the fade and pulse, a preview playing the way the TV does,
  notes (what the app would leave out and why), copy / download / load the JSON, Start from a built-in
  scene, autosave in the browser (localStorage). Its maths are **`docs/styles/scene.js`, a copy of the
  Dart rules: change both together**; `node tools/styles_editor/scene.test.mjs` runs the Dart test's
  cases, the bank and make.html's example on it. Checked in headless Edge over the DevTools protocol
  (38 interactions incl. 390 px wide, no page errors; the driver script was not kept).
- **Vesper AI / AI apps:** the `live_styles` description has the SCENES format (with "draw original
  characters only") and `add` answers `scene_notes` (what of each scene was left out). AI apps see
  it after reconnecting the connector.
- **make.html:** a Scenes section (`#scenes`) with an example (`#scene-example`) and every key; the
  editor in the header. live_style_scene_test checks the example draws and the keys are listed.
- Tests: test/live_style_scene_test.dart (16), tools/styles_editor/scene.test.mjs (8).
  `tool/live_styles_sheet_test.dart` draws scene styles at 4 moments.

## Drawing and frame cost

**Touch screens (2026-11-27, owner on his phone: "one click opens a group so we don't really see the
animations"):** a phone / tablet has no remote focus, so a row never moved. `LiveStyleBackground` now
moves every styled row for `touchMovesFor` (12 s) when it shows on a touch screen
(`FocusManager.highlightMode == touch` and not `DeviceTypeService.television`: a TV box counts as touch
until its first key press), then rests; covering the page (TickerMode) and coming back replays it. The
gallery's previews do the same. TV boxes are unchanged (remote focus, 30 s per visit). Tests that check
the TV behaviour set `DeviceTypeService.television = true`.

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
- `lib/services/live_style_scene.dart` - scenes (engine 2): model, parser, timeline.
- `docs/styles/editor.html` + `docs/styles/scene.js` - the scene editor (scene.js = the Dart rules in JS).
- `lib/widgets/live_style_view.dart` - background widget + painter.
- `lib/widgets/live_style_picker.dart` - the gallery (`showLiveStylePicker`).
- `tv_home_screen.dart` - `_askGroupColor` (Live styles… row), `_specialRowMenu`, `_StyledRowBox`
  (fade + style layer for `_GroupRow` and `_SelectableRow`), `_liveStyleIdOf`, `_swatchOf`.
- `vesper_ai/vesper_tools.dart` - `groups` colour `style`.
- Tests: live_group_styles_test, tv_live_group_styles_test, tv_group_colors_test,
  vesper_my_groups_tool_test, catchup_guide_test (hold menu).
