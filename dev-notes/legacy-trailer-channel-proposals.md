> Historical proposal, merged for reference on 2026-10-26. Trailer and channel-list features have since been implemented; this is not the current task list.

# Proposal for Claude Code: trailers in IPTV and Media Hub

Written by Codex · 2026-10-22 · branch `codex/trailer-research`.

## Goal and scope

Add a **Trailer** action beside Play on movie and TV show detail pages in
both the IPTV catalog and Media Hub. Use one discovery/launch service so all
entry points behave consistently on Android TV, Fire TV, phones and Windows.

This is an implementation proposal, not an implemented feature or an instruction
to release. Read `AGENTS.md` and all of `CLAUDE.md` before starting. Research,
public endpoint results and primary-source references are in
[`dev-notes/trailers-research.md`](dev-notes/trailers-research.md).

## Recommended first version

- Put the Trailer action inside VesperTV; play YouTube trailers in the installed
  YouTube app or browser. This follows the owner's earlier external-only choice.
- Use source-provided trailer metadata first, optional TMDB lookup second, then
  a strict Cinemeta identity lookup where needed. No mandatory API key.
- Hide the action when no suitable trailer or supported handler exists. Handle
  launch failure without leaving a broken page or losing focus.
- Resolve on detail-page entry, not during startup or for every catalog poster.
- No automatic previews, embedded WebView, YouTube stream extraction, patched
  player changes or VPS changes in this first version.

Fully embedded YouTube playback is technically possible through the official
iframe player, but needs a separate owner decision and platform prototype.
Genuine direct/local server trailers also need a separate native playback flow;
do not silently route either case through normal movie/episode playback.

## 1. Shared trailer discovery

Introduce a small `TrailerCandidate` model and `TrailerService` (names flexible).
A candidate should carry its source, label, validated YouTube video ID or
explicit playback kind, and language/type/official status when supplied.

Normalize and deduplicate these inputs:

- Xtream: optional `youtube_trailer` in movie/series metadata, accepting a bare
  video ID or recognized YouTube URL. Provider formats are not guaranteed;
  verify with redacted fixtures, never log account URLs or credentials.
- Media Hub: legacy `trailers: [{source, type}]` and stream-shaped YouTube
  candidates such as `trailerStreams: [{ytId, title}]`. Keep missing fields valid.
- Jellyfin/Emby: `RemoteTrailers`; YouTube entries can use the same external
  route. Classify local/direct trailers separately for later support.
- TMDB, only with the user's configured key: movie/series `/videos` endpoints.
  Prefer existing TMDB IDs; resolve a known IMDb ID through `/find` if needed.
  Prefer official Trailers, then teasers, app language then English.
- Cinemeta: use a known IMDb ID directly; otherwise search by media type and
  cleaned title/year, require an unambiguous strong match, then fetch its meta.
  Localized names/remakes may have no confident match; do not guess.

Reuse `cleanDisplayTitle`, extracting the year before stripping decorations.
The subtitle helper `AddonService._searchImdb` falls back to the first search
result: **do not reuse that fallback for automatic trailer selection**.
Keep external metadata lookups to title/type/IDs, never provider credentials.

Cache by media type, stable identity and requested language, with bounded cache
size, timeouts, request deduplication and positive/negative expiry. Reuse full
metadata already loaded. Do not block Play or the rest of the detail page.

## 2. Preserve metadata through existing adapters

| Location | Change |
| --- | --- |
| `lib/models/vod_details.dart`, `series_details.dart` | Optional provider trailer candidates. |
| `lib/services/xtream_api_service.dart` | Parse supplied trailer metadata without new per-poster API requests. |
| `lib/models/archive_models.dart` (`ArchiveMeta`) | Parse and serialize trailer candidates, preserving old caches without the field. |
| `lib/services/media_server_api.dart` | Preserve remote trailer metadata from full items. |
| `lib/screens/archive_playback.dart` | Pass real Hub source/meta trailer loading through the series adapter. |

Media Hub shows are adapted to a synthetic `XtreamSeries` with id 0. Add an
optional trailer loader/action hook to `SeriesDetailScreen`, like its existing
episode hooks, rather than querying Xtream using that synthetic identity.

## 3. Detail-page action and external launch

Add matching `DetailPillButton` actions to:

1. `MovieDetailScreen`: IPTV movies, including titles opened from Search/Expand.
2. `ArchiveDetailScreen`: Media Hub movies.
3. `SeriesDetailScreen`: IPTV series and Media Hub shows through the hook above.

Use `url_launcher`, already a dependency, through a shared launcher. Detect a
handler without assuming a particular YouTube package or a browser on every TV.
The Android manifest currently queries only PROCESS_TEXT: configure the required
VIEW/URL visibility before trusting capability checks on Android 11+.
An affirmative capability check does not guarantee launch success; handle both
false returns and exceptions, and return focus to the Trailer action if present.

Use existing D-pad/focus conventions. Keep new focus targets stable as async
metadata arrives; removing an unavailable/loading action must not strand focus.
If background playback is audible, pause/park it before launching externally;
test return behaviour independently for Android and Windows. Do not change
startup resume settings or resume the film/show automatically on return.

Every new displayed string uses `tr()` with matching placeholders in
`lib/l10n/fr.dart`, `es.dart`, `it.dart`, `el.dart`. Update `docs/remote.html`
for the final user-facing action. Avoid adding settings for the first version.

## 4. Playback state must stay separate

Watching a trailer must not create or modify title resume positions, watch
history, watched marks, Trakt/Simkl scrobbles, Ready-watch state, recordings or
episode auto-advance. Do not invoke `playArchiveTitle` or the normal episode
queue just to play a trailer. Provider/server direct-file support is deferred
until an isolated trailer route can meet these same requirements.

## 5. Validation and acceptance

- Parser tests: optional fields, both Stremio forms, provider URL/ID variants,
  invalid IDs/schemes, duplicates, and ArchiveMeta cache round trips.
- Resolver tests: known identity, movie vs series, title/year ambiguity,
  translated titles, language preference, no configured key, missing trailer,
  timeouts, cache expiry and concurrent request deduplication.
- UI/launcher tests where useful: each of the three pages, Hub series hook,
  absent handler, failed launch, async focus stability, returning from a detail
  page opened through Search/Expand, and no normal playback/tracker callbacks.
- Real devices: Fire Stick, phone, owner-operated Formuler Z11 and Windows;
  test available/unavailable YouTube/browser handlers, removed/unplayable
  videos, Back/return focus, background audio, and unchanged watch state.
- Preserve file line endings; format only changed Dart files; analyze must
  remain at 17 baseline infos and all tests must pass. Restore generated plugin
  files, commit on the task branch and update main-checkout `HANDOFF.md`.
- No version bump, APK build/install, merge, push or release without the
  owner's corresponding request. Do not drive the owner's Formuler over adb.

## Current evidence and limits

Four public Cinemeta samples returned trailer IDs: Interstellar, The Shawshank
Redemption, Breaking Bad and Game of Thrones. Two title searches returned the
expected IMDb IDs. This verifies metadata discovery only: not device playback,
global coverage, upload authenticity or localization quality.

Unmerged Codex work remains separate: `codex/fix-vod-favorites` (`2e0a834`) and
`codex/favorites-channel-order` (`2578427`). Do not overwrite or assume either
feature is already on main; both touch files involved in this proposal.

---

# Proposal for Claude Code: Sports Trak Channels and customizable sports lists

Written by Codex · 2026-10-22. Investigation and plan only; the owner explicitly
requested no app changes. This section is separate from the trailer proposal.
Reference: the user-supplied `2478.jpg` suggestion and embedded TV screenshot.

## A. What the user's picture asks for

The message describes three related improvements:

1. Find more of the user's IPTV sources for each game.
2. Add a **Channels** area inside Sports Trak: browse league networks, general
   sports networks and regional channels, and directly open ESPN, TSN, NBA TV,
   etc., without needing a matched game first.
3. Give the selected sport/league a large themed background/banner.

The embedded TV photo shows a channel preview with now/next information,
horizontal network-logo rows, and quality/feed versions behind a channel card.
Treat it as a reference for the experience, not a layout to copy pixel for pixel.
The photo does not establish why that user's game sources are missing in VesperTV.

**Owner's priority:** users must be able to create and maintain useful lists
even when VesperTV cannot classify channels, match a game, or populate a list.
Manual selection is a first-version requirement, not an advanced fallback
hidden in Settings or something to add after automatic lists ship.

## B. Existing code findings and their implications

| Existing capability | Implication for this feature |
| --- | --- |
| `SportsChannelMatcher.matchDay` returns at most 8 results by default; network fallback takes at most 3 hits per broadcaster | A valid source can be absent from the displayed result set. Investigate with fixtures; do not claim every missing source has this cause or simply remove safeguards. |
| `MatchReason` separates saved picks, channel-name/guide matches and unverified team/network suggestions | Preserve those distinctions; being an ESPN/TSN channel does not establish that it carries today's game. |
| `SportsChannelPicks` saves one channel per event/team/series; event picks expire after 7 days | Reuse preferred-playback choices, but add a separate list/multi-source model rather than overwriting the existing pick. |
| `_ChannelPickerScreen` has team/league/network search chips; matcher search returns nothing for an empty query and stops at 200 | A new manual list builder needs an unfiltered visible-catalog entry, multi-select and load-more/virtualization; it cannot depend on this limited search alone. |
| `MultiviewSports.isSports` uses name/group keywords | Useful starter suggestions, not a complete sports catalog. An unfamiliar or untagged channel must remain manually addable. |
| `UserGroups` moves a channel out of its provider group and assigns one own group | Do not reuse its membership model for sports lists. Lists must be non-destructive and many-to-many. |
| `SportsLeague` has IDs, logos, paths and some country preferences; `SportsKind.team` covers several different sports | Add/derive consistent sport IDs for filters; do not present every team sport as one sport or confuse league country preferences with channel-feed country. |
| `Channel` has no authoritative general country/sport/team/network fields | Filters need conservative inferred tags plus user overrides and an Unknown state; missing tags must never block manual inclusion. |
| `canonicalChannelKey` strips leading tags/quality | Reuse cautiously for suggestions, not as the sole identity for merging countries, regions or different feeds. |
| Sports models expose team/league logos and colours, not player/fanart banners | A logo/colour-based first version is achievable from current metadata; player artwork needs a separate source decision. |

Inspect `lib/screens/sports_screen.dart`, `lib/services/sports_channel_matcher.dart`,
`sports_follows.dart`, `multiview_sports.dart`, `lib/widgets/game_channel_chooser.dart`,
`sports_widgets.dart`, `lib/models/sports.dart`, `channel.dart`, and
`lib/utils/channel_name_matching.dart`. Current behaviour is more authoritative
than old status text at the top of `dev-notes/sports-tab.md`.

## C. Proposed entry and normal browsing

Add **Games / Channels** within Sports Trak, rather than another main app tab.
Preserve the current Games screen, league selection, My Teams and Standings.
Channels offers **My lists**, **League networks**, **Sports networks** and
**Regional channels**, with a visible **Create list** action and Search.

Starter rows contain only channels from the viewer's enabled, visible live IPTV
catalog. They are suggestions based on conservative network aliases, provider
groups and channel names. Do not populate cards for services the user does not
have or imply that subscriptions/streams are supplied by VesperTV.

Channel cards show logo/name, feed country/region when known, playlist and
now/next if available. No EPG must still allow direct playback. Use the app's
existing preview/fullscreen convention, with a hold menu for versions, add to
list and edit tags. Support equivalent tap/mouse actions without requiring a
long press to discover basic list creation.

In Channels mode, the hero describes the focused/playing channel, not a fake
SportsGame. Reuse VideoPlayerPane/DesktopMiniPlayer through a channel-specific
preview state; do not fabricate a game or create a second stream. Keep the
playing selection, list position and filter state stable when changing modes.

## D. Easy list creation, including when automation finds nothing

Expose three understandable starting actions in the same builder:

| Start | User flow |
| --- | --- |
| **Use suggestions** | Choose sport/league or a starter such as Canadian sports; review detected channels; check/uncheck; Save. |
| **Pick channels myself** | Browse all visible live channels, search or filter, check multiple results, Save. Works without EPG, detected sports tags or a game feed. |
| **Use a playlist group** | Pick one or more existing provider/own groups, review channels, select all visible results or individual channels, Save. Channels are copied as references, never moved. |

Keep the flow to **Choose channels -> Review & save**. Generate an editable
name such as "My hockey channels" so naming is optional. Show a selected-count
bar, immediate result counts, Select results/Clear results, and a clear Back
path; do not force repeated keyboards or one dialog for every selected channel.
Selections survive filter changes, paging and Back to the previous step.

If suggestions return zero, the empty state must expose **Browse all channels**,
**Choose a playlist group**, and **Clear filters** on that screen. Do not leave
the user on an empty sports-only search with no way to reach unclassified feeds.
An empty custom list can be saved deliberately, then populated later.

Manual inclusion must work even when every automatic country/sport/network
inference is wrong. Offer quick **Country / Sport / League / Network** tag
correction on one or several selected channels, or include them without tags.
Optional custom labels support local clubs/competitions the sports API lacks.

Example with no useful EPG: Create list > Pick channels myself > Playlist A >
search "TSN" > select TSN 1 and TSN 2 > search "Sportsnet" > select desired
feeds > Save as "My hockey". The list is usable immediately, without a game
match, broadcaster schedule, API key or mandatory country classification.

## E. Filters that help instead of hiding the user's channels

| Filter | Meaning and fallback |
| --- | --- |
| Playlist and provider/own group | Reliable narrowing from the existing catalog; show group names scoped to playlist. |
| Channel name / network | Search raw and normalized names; allow multiple network choices and manual tags. Do not collapse ESPN into ESPN+ or TSN 1 into TSN 2. |
| Feed country, region, language | Use explicit user tags, then conservative provider/name hints; Unknown stays selectable. Feed country is distinct from competition country and app language. |
| Sport and league | Use stable sport/league IDs and many-to-many associations. A general network can cover several sports; membership is a browsing suggestion, not a broadcast-rights claim. |
| Team | Known team ID where available, or a user-defined team label. Can use followed teams; a saved team-channel association is a preference, not proof of the current game. |
| Game/date/live programme | Use available game/EPG matches for a temporary view. Explain when guide coverage is missing; allow switching to manually chosen channels immediately. |
| Feed/quality | Filter declared SD/HD/FHD/UHD separately from the existing measured Real 4K tag. A name containing 4K must not become verified 4K. |
| My selections / Unclassified | Make corrections and otherwise undiscoverable channels reachable. |

Multiple choices within a filter mean **any of these**; different filters
combine with **and**. Show active chips, per-filter Clear and Clear all,
including a visible Unknown option. Do not silently apply North America or
English as an exclusion filter. Rank preferences may remain preferences.

Use only choices supported by the current catalog or manual tags, with useful
counts. If a sport filter produces zero because channels lack tags, offer
"Include unclassified" and manual browsing; do not pretend the provider has
no relevant channels. Game/team views must label missing or unverified data.

## F. Keep lists useful after the next playlist refresh

At Save, offer plain-language options:

- **Keep these channels** (default): remember exactly what the user checked.
- **Keep this list updated**: save the chosen filters and include future
  matching channels; retain the user's explicit additions and exclusions.

The second option is optional, never required to build a list. Show a preview
of the resulting membership and explain that it follows channel metadata;
date/game-specific views need a separate explicit scope and expiry, not a
permanent list that silently tracks one expired event.

For an updating list, use a deterministic rule:
`(channels matching saved filters OR explicit additions) MINUS exclusions`,
then intersect with currently enabled/visible/allowed live channels. Exclusions
win; the UI should clear the opposite override when the user changes a choice.
This lets a user add a channel the detector missed and remove a false positive
without either decision being undone on the next refresh.

Hold a list to rename, reorder, duplicate, edit channels/filters, reset its
automatic suggestions, or delete with confirmation. Hold a member to remove,
reorder or edit tags; do not hide it globally or remove its IPTV favourite.
Allow one channel in multiple lists. Suggested automatic rows are also
customizable through persistent per-viewer additions/exclusions.

For unrestricted viewers, retain references to temporarily disabled/missing
channels and offer a simple Relink/Search action when needed, without silently
substituting a similarly named feed. Never expose hidden channel names to a
restricted viewer, and never bypass parental/hidden-group visibility with a
saved list, inferred tag or manual game source.

## G. More game sources, without claiming every sports channel is a match

Treat source completeness as a separate workstream from channel browsing:

1. Reproduce a missing source with a redacted expected channel/game fixture.
   Determine whether it was never found, filtered by visibility/country, outside
   guide coverage, lost to a per-network limit, or cut from the final eight.
2. Group **confirmed equivalent feed/quality versions before the display cap**;
   show a useful number of distinct sources with their versions expandable.
   Keep original scores/reasons and access to further candidates through a
   paged "More sources" action. Do not expand a known match to every channel
   sharing its network name without validating equivalence.
3. Add a visible **Add sources** action in the game menu, including when there
   are no matches. Reuse the multi-select builder: All channels, My lists,
   country/network/group/team filters, then choose several channels at once.
4. Let the user save **This game**, **Preferred channels for this team**, or
   **Preferred channels for this league/event series**. Keep the existing one
   preferred playback pick compatible; additional candidate lists are separate.
5. Display user-added sources as user choices, and network/team preferences
   without EPG evidence as suggestions. Never relabel them guide-confirmed or
   guarantee the game is airing there. Automatic game choices should continue
   to favour supported evidence and the user's explicit preferred pick.
6. If a game itself is absent from the scoreboard, the user can still open
   their static/team/sport list and watch a selected channel. A manually named
   event collection with optional date/time could be a later addition, clearly
   user-created and without invented scores; it is not required for the first
   Channels/list release.

Group versions conservatively: country/region/callsign, plus/extra channels,
east/west/time-shift, numbered event feeds and language can change the actual
broadcast. Preserve each underlying Channel.id/playlist and let the user split
or correct an inferred group. Deduplicate repeated references to the same
channel ID, not distinct provider streams. Define counts explicitly (networks,
channels or versions) rather than reproducing the photo's numbers.

Do not promise "all available sources": incomplete EPG, absent metadata and
provider naming prevent that guarantee. Manual Add sources must remain usable
regardless of how good the matcher becomes.

## H. Banner/artwork approach

Start with a dimmed league/team logo, existing team colours and a sport-themed
background behind the header, preserving the preview and readable controls.
For a mixed/custom list, let the user choose a bundled sport background or
league logo. No extra API key is needed for those existing metadata/assets.

Do not upscale a small logo and call it player artwork. Player photos/fanart
need a documented permitted source or supplied asset; the current Sports
models do not provide that content. Make that a separate optional enhancement
with a generic fallback. Cap image decoding, cache images and avoid loading
many large backdrops while scrolling on a Fire Stick. Respect hidden scores;
banner information must not leak results. No animated/autoplay backgrounds.

## I. Proposed implementation boundaries for Claude

- Add a shared `SportsChannelLibrary` for classification, conservative version
  grouping and faceted search. Reuse catalog indexes and invalidation patterns;
  cache by viewer/catalog/tag revisions. Classification must not mutate EPG,
  provider group names or the matcher evidence.
- Add a per-viewer `SportsChannelLists` store with schema version, stable list
  IDs, names/order, selected Channel.ids, optional saved filter rules,
  inclusions/exclusions, tags and preferred version/order. Use composite IDs
  after Channel.withUniqueIds, never raw EPG IDs or just channel names.
- Keep these many-to-many references independent of UserGroups and IPTV
  favourites. Include list/tag/rule data in Backup/Transfer and delete it with
  its viewer. Do not persist or export duplicate stream URLs/credentials.
- Store manual country/network/sport corrections as overrides with provenance;
  retain Unknown for unclassified entries. For a provider group without a
  stable ID, scope a saved reference by playlist and detect rename/missing data.
- Extract a reusable picker/list editor from the private `_ChannelPickerScreen`
  rather than duplicating three incompatible search/filter experiences. Keep
  matcher ranking and list membership separate services.
- Wire Channels/My lists into SportsScreen with explicit focus zones. Preview,
  fullscreen and CH+/CH- must use the displayed list/version order, with the
  appropriate Android and Windows playback paths. Multiview may consume the
  shared picker later; don't change its player implementation for this feature.
- Use lazy channel rows/grids and paged search; no silent 200-result ceiling,
  full-catalog widget build, extra provider stream probes, or SQL guide scan
  for every list/keystroke. No-EPG lists should not need SportsService calls.
- Wrap every new TextField in TvTextFieldGate. Use HoldToActivate and swallow
  held activation in menus. Follow explicit traversal/jumpTo rules and preserve
  stable list/card identities across filters, selection and async refresh.
- New user strings require tr() and FR/ES/IT/EL entries. Update remote tips and
  feature notes only when implementing. This proposal changes no app behaviour.

## J. Delivery order and acceptance checks

**Phase 1:** shared manual multi-select picker, create/edit/reorder lists,
Channels entry, basic playlist/group/network/country filters and Unknown,
direct preview/play, per-viewer persistence. Ship no automatic-only version.

**Phase 2:** customizable automatic rows, persistent sport/league/team tagging,
saved updating filters, multi-source game associations and version grouping
before caps. Evaluate matching changes with false-positive fixtures, not only
larger result counts. Existing audit item 5 is related; review its work separately.

**Phase 3:** banners using existing assets; player/fanart sources and deeper
Multiview integration only if separately chosen. These must not delay the
manual list escape hatch.

Required acceptance scenarios:

- Empty EPG, unknown channel names and unsupported league: create a useful
  named list entirely from All channels/provider groups, save, restart and play.
- Filter Canada + hockey, get no suggestions, clear/include unclassified and
  add TSN/Sportsnet manually without restarting the wizard or losing selections.
- Select across multiple networks, countries and playlists; create multiple
  lists sharing a channel; no provider groups or IPTV favourites change.
- Updating list gains a newly matching channel, preserves manual additions,
  respects exclusions and handles playlist disable/refresh/rename predictably.
- Team/game association without guide evidence remains labelled as a user
  suggestion. Event pick expiry does not erase a permanent custom channel list.
- Version grouping does not combine ESPN/ESPN+, TSN 1/TSN 2, different regions
  or different events; one network's quality copies cannot consume all slots.
- Hidden/restricted channels are neither playable nor disclosed by counts,
  tags, empty-state suggestions, stale lists or saved game associations.
- Viewer isolation, deletion, Backup/Transfer, schema migration and unresolved
  IDs have tests. Existing picks/followed teams survive unchanged.
- On TV, complete the workflow with D-pad and minimal typing; exercise filter
  chips, multi-select, Select results, keyboard Back, save/cancel and focus
  restoration. Test touch and Windows separately; do not drive Formuler via adb.
- No score spoilers, audio overlap, duplicate preview controller or heavy-image
  scroll stalls; run required analyzer/test checks before handing implementation
  back. No build/release/version change is authorized by this planning request.
