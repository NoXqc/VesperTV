# External trailers

TrailerButton is shared by IPTV movies, Media Hub movies and SeriesDetailScreen.
Hub series metadata travels through the existing loadEpisodes hook/SeriesDetails;
the synthetic Xtream id 0 is never sent to Xtream for trailers. The optional
trailers field survives ArchiveMeta caching. Xtream youtube_trailer, add-on
trailers/trailerStreams and Jellyfin/Emby RemoteTrailers normalize to YouTube IDs.

TrailerService prioritizes supplied IDs, user-key TMDB videos (known TMDB or IMDb
identity), then Cinemeta by known IMDb or an unambiguous exact title/type/year.
There is no first search-result fallback. Year is extracted before display-title
cleanup. Official trailers rank before teasers and prefer app language then English.
Positive/negative cache expiry is 6 hours/10 minutes, bounded to 128 identities;
concurrent lookups deduplicate. Requests time out; failures do not block Play.

Only validated YouTube IDs/URLs are accepted, not arbitrary external/server file
URLs. Android queries HTTPS VIEW handlers. No handler hides the pill; launch failure
shows a localized message and preserves focus. Launch pauses the shared background
player and opens the installed external handler; returning never starts a movie.
No normal playback/history/resume/queue/Ready-watch/tracker code is invoked by it.
No WebView, stream extraction, embedded key or additional provider request per poster.

Parser/resolver and button tests use mock HTTP/launchers. Actual YouTube/browser
availability and return behaviour on Android TV, Fire TV and Windows still need
owner device checks. Source metadata is not proof a YouTube upload remains playable.

Protocol references: [Stremio metadata](https://stremio.github.io/stremio-addon-sdk/api/responses/meta.html),
[stream objects](https://stremio.github.io/stremio-addon-sdk/api/responses/stream.html),
[TMDB videos](https://developer.themoviedb.org/reference/movie-videos).
