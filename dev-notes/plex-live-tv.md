# Plex Live TV (idea, not started)

Owner question (2026-10-30): some Plex servers offer TV channels. Where would they go?
Decision so far: **later**, after the basic Plex connector (`dev-notes/plex-media-server.md`)
is tested on a real server, and only once a test server **with Live TV** is available
(it needs a tuner, e.g. HDHomeRun or an IPTV list via Threadfin/xTeVe, plus Plex Pass on the
owner's side). Nothing is built.

## Two different "Live TV"s
1. **The server's Live TV & DVR** (owner's tuner, shared users if the owner allows it).
   This is the one to support.
2. **Plex's free ad-supported channels** (Plex's own service, not the user's server). Leave out.

## Where: the IPTV section, as its own playlist
"Plex · <server name>", enable/disable/hide like any playlist. That way the Timeline guide,
favourites, own groups, CH+/CH- zapping, Multiview, Sports Trak matching, history and the resume
pill all work unchanged. A separate TV tab was rejected: a second guide + channel list to keep in
sync for few users.

## The hard part: playback
- A Plex channel has no fixed URL: each play asks the server to **tune** it (uses one of the
  owner's tuners, returns a temporary session, usually HLS, that must be kept alive and released
  on stop). Needs a resolve-at-play step (like Media Hub's URL-less queue placeholders,
  `PlaybackService.setUpNextQueue(resolve:)`), and the release on stop/zap.
- Tuners are few (2-4): Multiview, zapping and parallel plays hit the limit. Clear
  "No free tuner" message; never auto-retry in a loop.
- Guide: read the server's EPG and import it into `EpgDatabase`, keyed to the channels.
- Not possible: catch-up (Plex has none), our own Recording of these channels (the owner's
  Plex DVR records on the server).

## Plan when it's picked up
1. On adding a Plex server, detect Live TV this user may watch; offer "Add its TV channels to
   Live TV".
2. A Plex playlist kind whose channels tune on play (resolve + release).
3. EPG import + refresh with the other guides.
4. Free-tuner checks, `Send log` lines for tune errors (no tokens/URLs).

**Verify first:** Plex's Live TV endpoints (DVR list, channel list, tune, session keep-alive,
EPG) are poorly documented; confirm every call against a real server before writing code.
Don't guess them from memory.
