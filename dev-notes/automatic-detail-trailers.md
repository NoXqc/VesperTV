# Automatic detail-page trailers (Codex, 2026-10-25)

Initial implementation: codex/automatic-detail-trailers.
Owner-requested backdrop follow-up: codex/trailer-backdrop-fade, 2026-10-25.
Playback follow-up after +439: codex/trailer-playback-performance (+440).
Settings > Interface > Trailers > Automatic trailers (moved from Theme, 2026-10-25), device preference, **off by default**. Fire TV (manufacturer Amazon): the trailer WebView uses texture composition, because Fire OS puts <video> on its own native overlay (`SurfaceViewOverlayCore$NoPunchingSurfaceView`): under hybrid composition it was black with audio; now it shows but on top of everything, so trailers play full screen there (the setting says so). Other devices keep hybrid composition.
Uses the strict trailer lookup in dev-notes/external-trailers.md, with one shared
request for the manual button and automatic preview. Covers IPTV movies/shows
and Media Hub movies/shows (Hub shows use SeriesDetailScreen).
No additional automatic lookup/player is created when disabled.

- Owner tested +438 and explicitly requested replacing the separate YouTube
  preview with a full-page trailer behind the poster and text, replacing artwork.
  Both direct trailers and the official YouTube iframe now use the full detail
  viewport. Details retain their normal width and layout; no split Row/Column.
- Keep artwork visible through lookup/loading. On playing, fade its black cover
  and artwork away over 650ms with easeInOut, exposing the opaque video. Keep readability gradients and
  a light scrim. End/error fades back to artwork. No loop; disabled/leave/play
  still stops immediately. The detail subtree stays mounted so focus/scroll stay.
- Automatic YouTube embeds use controls:0, audible playback, IgnorePointer and
  ExcludeFocus; the explicit Trailer button still opens the normal player with
  controls:1. No stream extraction (superseded 2026-11-26: see the last section), proxy, enlarged iframe cropping or changes
  to YouTube's own branding implementation.
- This supersedes the earlier uncovered side/top preview design at the owner's
  explicit request. YouTube's no-obscuring embed requirements remain a provider
  limitation; the requested background presentation is not a compliance claim.
  https://developers.google.com/youtube/terms/required-minimum-functionality
  and https://developers.google.com/youtube/player_parameters.
- End, error or a 20-second autoplay timeout returns to static details. No loop
  or automatic launch of YouTube/browser on failure.
- Stop/dispose on navigation, app inactivity, disable and unmount. Returning to
  an active route can start another preview. Play/Resume/Restart, episode startup
  and manual Trailer await stop before main playback or Media Hub stream lookup.
  Those actions suppress automatic previews for the rest of that page visit.
- Pause an existing live player before starting a preview, matching the manual
  Trailer action. Never automatically restart live playback on leaving details.
- Independent controllers: no history, tracking, resume writes, main-player
  channel assignment, display matching or up-next queue changes. Android texture
  view with mixed audio focus, Windows media_kit, official YouTube WebView.
  No vendored native changes, version bump or Formuler driving.

Tests cover default/persistence, disabled state, mute-before-play, cancellation,
metadata refresh, awaited stop/disposal, route/lifecycle transitions, fallback,
full-viewport wide/phone layouts, fade timing, fade-back and preserved Play focus. Real-device WebView autoplay, decoder
availability and remote focus still need testing; tests use platform fakes.

## Playback performance and sound (+440)

Owner reports full-screen +439 is sluggish/freezing and silent. Muting was
intentional in the initial implementation; owner now requests sound. Background
YouTube explicitly unMute/setVolume(100) before play, direct players use normal
volume (Android 1.0, Windows 100). Manual Trailer player remains unchanged.

Remove the full-screen Opacity around the platform video. At opacity zero Flutter
does not paint that child; fractional opacity uses an intermediate buffer. Leave
the video fully painted under a simple fading ColoredBox/artwork mask instead.
Source: https://api.flutter.dev/flutter/widgets/Opacity-class.html.
This removes a concrete composition cost and avoids suppressing initial paints;
it does not prove the cause of continuing dropped frames on the Formuler.
Read-only renderer log check produced no relevant messages (Android SDK 30).
No decoder, hybrid-composition mode or native plugin changes made speculatively.
Test hardware again; if stutter persists, compare explicit Trailer playback and
collect a fresh Send log before choosing another rendering path.

## IPTV shading and startup (+441)

The IPTV wide movie/series artwork panel occupied only the upper-right 74% width,
80%/74% height. Its gradients remain visible during trailers, producing a hard
rectangular brightness boundary over full-screen video. Give that backdrop the
same full-viewport bounds as the trailer (as Hub movies already do). Foreground
controls keep their layout. No decoder, colour-space or Media Hub movie changes.

There is no intentional 6-7 second startup wait. Trailer lookup, provider iframe
startup and buffering can take that long. Late detail metadata previously closed
and recreated an active iframe even when resolving to the same trailer URL. Keep
a same-title preview mounted during that lookup; retain it if the URL matches,
replace it if the URL differs. Known differing IDs/year or title still clear the
old preview immediately. Route/stop generation guards still cancel stale results.
Tests cover preserved pending lookup, unchanged URL, changed URL and stale lookup.
Hardware startup time and visual acceptance must still be checked by the owner.

## Our own player for YouTube trailers + Media Hub card trailers (Claude, 2026-11-26)

Owner: "Even our background trailer is clunky and takes several seconds", with a
video of ARVIO (github.com/ProdigyV21/ARVIO, Apache-2.0) playing trailers in the
focused Home card about 1.3 s after focus. Measured on the Homatics before the change
(title page, Automatic trailers on): OK -> playing 7.6-8.0 s, of which the lookup
0.9-2.0 s and YouTube's web player 5.9-6.8 s; a 0.6-0.7 s frame opening the page;
YouTube's own title bar over our page. The owner chose ARVIO's way ("1 but not
muted"), knowing it goes against YouTube's terms and breaks when YouTube changes its
apps, and that it stays out of the Apple builds.

- `services/youtube_streams.dart` (`YouTubeStreams`, adapted from ARVIO's
  InAppYouTubeExtractor): asks YouTube's player API (`/youtubei/v1/player`) as three of
  YouTube's own apps at once: Vision Pro (`VISIONOS`, HLS playlist up to 1080p, needs the
  anonymous visitor id from `sw.js_data`), Android (`ANDROID`, one 360p mp4 with sound,
  itag 18, downloads at full speed) and iPhone (`IOS`). Quest (`ANDROID_VR`) answers
  LOGIN_REQUIRED since 2026-11 and is left out. **No API key** (the call works without one;
  the project rule stands). Ciphered formats are skipped (no player code is run). Kept 20
  min per video, "none" 2 min, one lookup per video at a time; `forget` after a failed
  play. Log: `Trailer: YouTube stream hls+mp4 360p in N ms (visionos OK, android OK, ...)`.
  `YouTubeStreams.supported` = not App Store builds, not Apple TV.
- `YouTubeTrailerStream.large` (title pages: the HD playlist) / `.small` (cards: the mp4).
  `resolveSmall` answers as soon as the Android client has the mp4 (~250-350 ms) without
  waiting for the Vision Pro playlist.
- `DetailTrailer`: a YouTube trailer plays its file in `TrailerVideo` (the old private
  `_Preview`, now public: our texture player / mpv; HLS gets `VideoFormat.hls`). A file that
  fails (error, 20 s start timeout) falls back once to YouTube's web player (`_failed`).
  `_found` (the trailer link) vs `_uri` (what plays) keeps the same-title preserve logic.
- `TrailerService` lookup order: the add-ons' details pages are asked all at once (taken
  in the add-ons' order), then Cinemeta's, then add-ons' stream lists one at a time (each
  is a debrid lookup on Torrentio-like add-ons; was meta + stream per add-on, then
  Cinemeta). `quick` (cards): the first details page with a trailer wins, stream lists are
  never asked. Found trailers are also kept by title (type + IMDb id + add-ons, 6 h): the
  card's lookup serves its title page.
- Media Hub card trailers: Settings > Playback > Movies & TV Shows > **Trailers on Media Hub
  cards** (`vesper_card_trailers`, device, off by default, hidden where unsupported; Vesper
  AI settings key `card_trailers`). `archive_screen.dart` `_armCardTrailer`: 300 ms after
  focus the lookup starts (`CardTrailer.find`, quick + `resolveSmall`; only files our
  player opens, never YouTube's web player in a card); the card widens after **0.5 s**
  with the switch on (2 s without, unchanged); the player starts after **1 s** on the card
  (`_cardTrailerDue`: at 0.5 s, stepping along a row opened and closed a player per card);
  `widgets/card_trailer.dart` plays it over the
  backdrop, under the logo (`PosterCard.wideVideo`), with sound, fading in on play and out
  at the end (not replayed until the remote leaves the card). The trailer state is a
  ValueNotifier: only the wide card's slot redraws (a Media Hub setState is ~450 ms on the
  Homatics). Widening / shrinking a card redraws only its row (`_wideTicks`,
  `_setExpanded`; was a screen setState each, twice per step: 467-482 ms builds while
  stepping, now <= 83 ms). Stepping frames stay ~28-34 ms raster either way (the Media Hub
  hero on the Homatics, same with the switch off).
- Measured on the Homatics (1030-1032): card focus -> playing 1.6-1.8 s (first title after
  a start 2.8 s; ARVIO ~1.3 s in the owner's video); title page OK -> playing 2.1-2.6 s (was
  7.6-8.0 s), 0.8 s of it the page's own first frame. Sound checked with `dumpsys audio`
  (our AudioTrack started, USAGE_MEDIA, 0 dB); one player at a time card -> page -> card;
  leaving the Media Hub = no player left.
- Collections (owner, 2026-11-26: "add it to collections and expand collection"; build
  1033): one `CardTrailerSlot` (card_trailer.dart: the 0.3 s lookup, the 1 s start, the
  `done` state, `video(place, id)`) now runs it for the Media Hub tab, a collection's page
  (`hub_folder_screen.dart`: its wide card widens at 0.5 s with the switch on, per-row
  `_wideTicks` like the tab) and Expand collection / Expand catalog
  (`archive_catalog_screen.dart`, owner's pick "Inside the focused card": only with Wide
  cards on, the focused 16:9 card, `PosterCard.wideVideo` now also on a `wideStyle` card; a
  poster grid plays none). Both pages stop it when the focus leaves their cards (their
  `Focus.onFocusChange`): a title page over them stays built and its player played on.
  test/hub_collection_trailer_test.dart. Homatics (1033): a step on the collection page or the
  grid -> playing 1.4-1.6 s; five quick steps opened one player (the last card), max build
  46 ms; title page from either = the card's player closes first, one sound; Back = the
  card plays again; Up to the grid's buttons / Back to Home = no sound left.
- Not changed: the Trailer button still opens YouTube's web player with controls; Home's
  and IPTV rows have no card trailers; Fire TV only needs full screen when the web player
  is the fallback.
- Tests: youtube_streams_test, hub_card_trailer_test, detail_trailer_test (file / fallback
  / no file), addon_trailer_test (lookup order, quick, shared by title).
