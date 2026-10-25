# Automatic detail-page trailers (Codex, 2026-10-25)

Local branch codex/automatic-detail-trailers, not built or published.
Settings > Theme > Automatic trailers, device preference, **off by default**.
Uses the strict trailer lookup in dev-notes/external-trailers.md, with one shared
request for the manual button and automatic preview. Covers IPTV movies/shows
and Media Hub movies/shows (Hub shows use SeriesDetailScreen).
No additional automatic lookup/player is created when disabled.

- Direct video trailers play muted behind the details and readability gradients.
  Artwork stays until initialization succeeds.
- YouTube uses the existing official iframe, muted before play, in a separate
  visible preview beside details on wide screens, above on phones. No details,
  fade or artwork obscure the player. Minimum 200x200; cramped viewports retain
  static details. No stream extraction or proxy. API requirements:
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
and uncovered wide/phone YouTube layouts. Real-device WebView autoplay, decoder
availability and remote focus still need testing; tests use platform fakes.
