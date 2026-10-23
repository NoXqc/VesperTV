# In-app trailers and YouTube streams

The shared Trailer action covers IPTV movies/shows and Media Hub details. Xtream
`youtube_trailer` and metadata from the user's own sources take priority. Otherwise
TrailerService resolves an IMDb identity from supplied metadata, a known TMDB id
with the user's TMDB key, or a unique exact Cinemeta title/type/year match. It asks
only enabled user-installed add-ons declaring movie/series `tt` meta/stream support.
No IMDb identity means no add-on lookup; there is no first-result title guessing.
Built-in Cinemeta supplies identity only, never an implicit trailer source. No
YouTube add-on, extraction library, service key or proxy is bundled.

Add-on meta trailers and stream responses accept validated YouTube IDs and direct
HTTP(S) media URLs. Metadata trailer lists survive caching. Old saved add-ons can
have their own manifest rechecked in memory for IMDb capabilities, without changing
preferences. Positive/negative trailer caches expire after 6 hours/10 minutes,
bounded to 128 identities; concurrent lookups deduplicate and requests time out.

YouTube IDs open YouTube's official IFrame API in a full-screen WebView on Android
and Windows. `YouTubePlatformView` intercepts exactly the local wrapper request at
`https://vespertv.app/_local/youtube.html`, returning app-generated HTML. This gives
an HTTPS origin and Referer on both platforms: Windows `loadData` ignores baseUrl.
The wrapper is local; no website deployment is required. All YouTube resources
and ads pass through normally. The JavaScript bridge queues events until ready
and exposes only playback events and fixed player commands. User-initiated external
links open outside the wrapper; camera/microphone permissions are denied.

On a remote, OK toggles play/pause, Left/Right seek 10 seconds and Back closes.
Phones also have touch controls. Errors 101/150 automatically try the external
YouTube handler once; other errors and startup timeout offer Open in YouTube.
Leaving or backgrounding pauses playback. A WebView2 profile lives in Windows app
support storage; Android needs System WebView. Old Fire OS WebViews may be choppy.
YouTube ads are possible and this embed path has no HDR support.

Direct add-on URLs use the normal player. Googlevideo links get no special handling
and may be tied to the add-on server's IP; a LAN-hosted add-on may be needed.
Trailer channels are transient: no recently played entry, resume position, watched
event, tracker report or next-episode queue. YouTube playback also bypasses those
movie paths. Existing background playback pauses; returning never starts a movie.

Mock HTTP, widget remote-control and playback-history tests cover these paths.
Native embed rendering, real remote focus and external-app return still need owner
checks on Android TV/Fire TV and Windows. No native build or device test was run.

Protocol references: [Stremio metadata](https://stremio.github.io/stremio-addon-sdk/api/responses/meta.html),
[stream objects](https://stremio.github.io/stremio-addon-sdk/api/responses/stream.html),
[YouTube IFrame API](https://developers.google.com/youtube/iframe_api_reference),
[YouTube embedded-player requirements](https://developers.google.com/youtube/terms/required-minimum-functionality).

## 2026-10-23 fixes (Claude, owner test)
- Trailer played the movie: a stream add-on's `/stream/` answer (TorBox, Torrentio…) is the title
  itself, and the first playable entry was taken. Now only `ytId` entries or rows labelled
  "trailer" count.
- No trailer add-on needed: after the user's add-ons, Cinemeta's own meta
  (`v3-cinemeta.strem.io/meta/{type}/{imdb}.json`, `trailerStreams`/`trailers`, YouTube ids) is
  used — what Stremio shows. Owner had tried `v3-channels.strem.io` (Stremio's YouTube *channel*
  browser, type `channel`, no trailers); it's correctly refused as a Media Hub source.
