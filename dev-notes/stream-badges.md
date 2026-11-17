# Stream badges (Media Hub sources)

Owner, 2026-11-16: "check this kind of media source package/addon, they add badges to the sources"
(xperience-app.com Badges page, Nuvio stream-badge packs). Branch `claude/stream-badges`, test +812.

## What it is

Settings > Playback > Movies & TV Shows > **Stream badges**: paste the address of a badge pack made
for **Nuvio** (mobile: Settings > Streams > Badge URLs; TV: Settings > Layout > Fusion badge URLs) or
**Fusion**. The same address works in VesperTV. Editors that publish one: xperience-app.com (Badge
Studio), Badger (github.com/Nintle/Badger), raw JSON on GitHub/Gitea (e.g. gitea.com/eclipsia/nuvio-badge,
`raw/branch/main/eclipsia.json`). Device-only setting (like Custom posters): never transferred.

Without a pack, sources show VesperTV's own tags (`archiveStreamFormats`: 4K / Dolby Vision / HDR10 /
HEVC...) as gold `GoldTag`s instead of the old "4K · HEVC" text.

## Pack format (no official spec; read from real packs + Badger's source)

```json
{
  "groups":  [{"id": "gr", "name": "Resolution", "color": "#FF858283", "borderColor": "...", "isExpanded": true}],
  "filters": [{"id": "r-4k", "name": "4K", "groupId": "gr", "type": "filter", "isEnabled": true,
               "pattern": "(?i)^(?=.*(?:2160[pi]?|4k|uhd))(?!.*(?:1080[pi]?|720[pi]?))",
               "imageURL": "data:image/png;base64,... | https://...png | \"\"",
               "tagColor": "#00000000", "textColor": "#FFFFFF", "borderColor": "#636366", "tagStyle": "filled"}]
}
```

- Colours: `#AARRGGBB` (Android order; Badger's comments confirm), `#RRGGBB`, `#RGB`. Alpha 00 = none.
- `pattern` is a **Java** regex (Nuvio is Kotlin). Dart's engine = V8 irregexp (same as Node): all
  106 patterns of the eclipsia pack run after dropping the leading `(?i)` and matching
  case-insensitively (`streamBadgeRegExp`). Mid-pattern `(?i)` / `(?i:` make the whole pattern
  case-insensitive; `(?x)`, possessive `*+`, atomic groups and other Java-only syntax = the filter is
  skipped (counted in `skipped`, shown on the Settings page). Badger's own preview does the same.
- Some patterns look for invisible marker characters (U+2060.., U+200B..) that AIOStreams' formatter
  adds for badge packs; they are kept in the matched text.
- Text matched: stream name + title + file name (if not already in the title) on **one line**
  (`streamBadgeText`): the patterns' `.` doesn't cross a line break.
- Drawing (`StreamBadgeChip`, after Badger's `makeBadgeHTML`): rounded pill (radius 24 % of height),
  fill = tagColor, 1 px border = borderColor; picture inside (edge to edge on a clear fill, padded on a
  filled one), else `name` in textColor.

## Code

- `lib/services/stream_badges.dart`: `StreamBadgePack.parse`, `streamBadgeRegExp`, `parseBadgeColor`,
  `streamBadgeText`, `matchStreamBadges`; `StreamBadges.instance` = pack (ValueNotifier), per-text result
  cache, batched matching (one isolate per frame's rows, **killed after 8 s**: a third-party pattern that
  backtracks forever turns the pack off for the session instead of freezing the box), download (25 s,
  12 MB cap), file cache `stream_badges.json` in app support, prefs `vesper_stream_badges_url` /
  `vesper_stream_badges_fetched`, re-download after 24 h (Xperience packs change as their owner edits).
  Loaded the first time a source list needs it (`ensureLoaded`), never at startup. Web: no isolate/file.
- `lib/widgets/stream_badge_row.dart`: `StreamBadgeRow` (picker: wraps; drawer: one clipped line) +
  `StreamBadgeChip`.
- `TvMenuTile.badges`: a row above the subtitle (stream picker).
- Settings page `screens/settings/stream_badges_screen.dart` (field + Save / From phone / Turn off +
  focusable preview of every badge). From phone = `PairingKind.badges` (pair.html "badges" kind, Wi-Fi).
- Pasted in a Media Hub Add field instead (sources list, Collections, the phone /hub page): those read a
  non-manifest `.json` as a Nuvio collections file; when that finds none, `StreamBadges.useIfPack`
  tries it as a badge pack and saves it ("No collections in that file." only if it is neither; owner hit
  this with k45sle's GOLD-NONAMES.json). GitHub page links are read as raw files (`HubCollection.rawLink`).
- Media Hub sources > **Stream badges** (rail entry under Collections; phones: a row under Collections) =
  `StreamBadgesPane`: Show stream badges switch, Change / Add a badge pack, Remove badge pack, preview. Owner
  (+815): a pack pasted in Add a source couldn't be found or turned off there. The switch
  (`StreamBadges.setOn`, `vesper_stream_badges_on`, default on; `use()` turns it on) keeps the pack;
  `remove()` forgets it. Settings shows a switched-off pack's badges (`ensureLoaded(switchedOff: true)`).

Measured (PC, JIT test): eclipsia pack parse 16 ms, 100 sources x 106 patterns = 208 ms in the isolate.

## Not done / ideas

- Per-group on/off, reorder, recolour (the editors do that; the pack URL carries it).
- Badges in the Vesper AI `media_hub` tool output (it still lists the built-in format words).
- Windows uses the same picker/drawer widgets: should just work, not run.
