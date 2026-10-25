# Automatic detail-page trailers (Codex, 2026-10-25)

Initial implementation: codex/automatic-detail-trailers.
Owner-requested backdrop follow-up: codex/trailer-backdrop-fade, 2026-10-25.
Settings > Theme > Automatic trailers, device preference, **off by default**.
Uses the strict trailer lookup in dev-notes/external-trailers.md, with one shared
request for the manual button and automatic preview. Covers IPTV movies/shows
and Media Hub movies/shows (Hub shows use SeriesDetailScreen).
No additional automatic lookup/player is created when disabled.

- Owner tested +438 and explicitly requested replacing the separate YouTube
  preview with a full-page trailer behind the poster and text, replacing artwork.
  Both direct trailers and the official YouTube iframe now use the full detail
  viewport. Details retain their normal width and layout; no split Row/Column.
- Keep artwork visible through lookup/loading. On playing, fade video in and
  artwork out together over 650ms with easeInOut. Keep readability gradients and
  a light scrim. End/error fades back to artwork. No loop; disabled/leave/play
  still stops immediately. The detail subtree stays mounted so focus/scroll stay.
- Automatic YouTube embeds use controls:0, muted playback, IgnorePointer and
  ExcludeFocus; the explicit Trailer button still opens the normal player with
  controls:1. No stream extraction, proxy, enlarged iframe cropping or changes
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
