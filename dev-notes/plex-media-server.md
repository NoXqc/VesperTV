# Plex media-server connector (Codex, 2026-10-29)

Settings > Media Hub sources > Connect Jellyfin / Emby / Plex retains the
Jellyfin/Emby address/password form and adds Connect Plex. The viewer approves
a short-lived code on plex.tv/link (or scans its QR), then selects an accessible
owned/shared server. VesperTV stores that server's resource access token, not
the temporary account token or account password. Local connections are preferred;
remote connections and then relay are attempted if earlier connections fail.

PlexApi maps movie/show libraries, paginated rows/search, metadata, episodes,
artwork, IMDb GUIDs, versions, sizes and external subtitle streams onto existing
Media Hub models. Direct Part URLs use server authentication; metadata cannot
send that token to absolute/cross-origin assets. Reconnecting the same server
keeps its stable source key and its saved enabled/Other choices. Existing source,
history, resume, Android/Windows playback and transfer paths are reused.

This uses Plex's documented traditional PIN/token flow; it does not implement
the newer optional JWK/JWT flow. The client id is saved with the viewer's Hub
preferences. Only original files are played: no Plex transcoding, server watch-state
sync, managed-user switching or multipart-file stitching. A multipart version
is excluded instead of silently playing only its first file. A real Plex account,
server and physical-device playback remain to be tested; mock API checks cannot
establish those outcomes. No device build or publication was requested.

Implementation: lib/services/plex_api.dart, media_server_api.dart,
archive_service.dart; lib/screens/settings/plex_connect_screen.dart and the
shared media_server_screen.dart. Contract coverage: test/plex_api_test.dart and
the retained test/media_server_test.dart Jellyfin/Emby cases.

API reference: https://developer.plex.tv/pms/ (authentication, resources,
libraries, pagination, metadata/allLeaves and direct media parts).
