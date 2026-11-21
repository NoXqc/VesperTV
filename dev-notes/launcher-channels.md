# TV launcher rows (Watch Next + Favourite channels)

Branch `claude/tv-channels` (from main 4dbe5cf), test builds +678, +679. Not merged or released.

## What it does
Settings > Interface > **TV home screen** (Android TV only, on by default, device-only
`vesper_launcher_rows`) publishes through Android TV's TvProvider:

- **Watch Next**: Continue watching (playlist movies/episodes in progress, Media Hub titles; the
  same titles and order as Home's Continue Watching row, max 10), Media Hub's next episode as
  `WATCH_NEXT_TYPE_NEXT`, and the Watch list's movies/shows as `WATCH_NEXT_TYPE_WATCHLIST`
  (max 10, live channels skipped).
- **Next episode (IPTV, +679)**: an Xtream episode watched to the end gets a `NEXT` card for the
  following one. `PlaybackService._rememberNextEpisode` notes it from the show's up-next queue
  when the episode is left (`vesper_next_episodes`, per viewer, device-only, 30 shows).
- **New episodes (+679)**: "Notify me" shows with a new episode (Home's New episodes row) as
  `WATCH_NEXT_TYPE_NEW`, max 5, not when the show is already in Continue watching.
- **App channel "Favourite channels"**: the favourite live channels in the app's order (max 30).
- **App channel "Live now in Sports" (+935, 2026-11-21, Discord request: katayba, Projectivy, after
  a Nuvio+IPTV fork's row of the same name):** games on now in the viewer's Sports Trak leagues (+
  followed teams' leagues) that one of their channels carries (`MultiviewSports.liveGames`, same
  matching and picks as Sports Trak), Home's order, max 15. Own switch under TV home screen
  (Settings > Interface > Tabs > Live games on the TV home screen, `vesper_launcher_live`, on by
  default, device-only); no Sports Trak leagues = no row. A card plays the game's channel full
  screen (and saves it as the game's pick, like Home's game cards); a game that's over opens Sports
  Trak.

Launchers read these: Projectivy (also on Fire TV sticks, user report 2026-11-08: its Channels and
Watch next rows list SmartTube, VLC, Tub Player), the stock Android TV home. Projectivy is only a
consumer of this system API (spocky/miproja1#385); it has no plugin API for rows yet (#521, #676).

## How
- Dart `lib/services/launcher_channels.dart` builds the cards for the **active viewer** and sends
  the whole set when the app is hidden (2 s later, so the player's last position is saved) and
  once 20 s after startup. An identical set is not resent.
- Kotlin `LauncherChannels.kt` (channel `vespertv/launcher`, androidx.tvprovider 1.1.0) diffs
  by internal provider id: unchanged cards are not rewritten, a card the viewer removed in the
  launcher (browsable = 0) only comes back after it was watched again.
- Each card's link is `vespertv://launcher/open?k=<key>` naming MainActivity; keys are per
  episode: prefix (`cw`, `nx`, `hub`, `wl`, `ne`, `fav`) + a sha1 of the identity (+679; +678
  put the Watch list's Media Hub source address, which can hold a debrid key, in the key).
  Projectivy diffs cards by link (#521: one link per show = the card never moved on).
- Opening (`screens/launcher_open.dart`) resolves the key again against the active viewer's data
  and opens it like Home: IPTV movie/show page, Media Hub resume, favourite channel full screen.
  Startup's resume-last-channel is skipped when a card opened the app (`openedRecently`).
- Watch Next is sorted by last engagement, which nothing stored: `vesper_launcher_state` keeps
  per card [position, time]; the time moves to now only when the position moved.
- Images that carry a key or login (Jellyfin/Emby `api_key`, Plex token, `username=`) are not
  sent: other apps read the TvProvider. A Media Hub title then uses Cinemeta's background by
  IMDb id (`images.metahub.space/background/medium/<tt>/img`, +679).

## Live row: pictures and freshness
- **Picture:** `LauncherArt.kt` draws each card (640x360 PNG): both logos on the teams' colours
  (darkened), score (not with Sports Trak's Hide scores), clock, LIVE, league, channel; golf /
  racing / fights: league logo + event name. Dart sends `art` + `v` (sha1 of it): the file is
  `files/launcher_art/<v>.png`, drawn once. Logos are downloaded natively, kept in
  `cache/launcher_logos` 30 days (SVG / failures: the abbreviation instead, retried after 30 min).
  The launcher loads it from `LauncherArtProvider` (`content://<package>.launcherart/<v>.png`,
  exported, read only, only `[0-9a-f]+.png` from that folder), the way VLC's TV channels serve
  theirs (`org.videolan.vlc.thumbprovider`, exported). If drawing fails the card uses the
  channel's logo.
- **Link:** `vespertv://launcher/open?k=<key>&v=<picture hash>`: the key stays per game (diffed in
  place), `v` changes with the score so Projectivy (which tells cards apart by link) redraws it.
- **Refresh:** sent with the rest when the app is hidden, then every 3 min while games are on and
  the app is away (`_liveTick`); no games on = a minute after the next start (at most 1 h). On
  screen the app only tells the native side the cards are still current (`liveAlive`).
- **Expiry:** `LauncherLiveExpiry.kt` (AlarmManager, RTC, not a wakeup) empties the row 20 min
  after the last send / liveAlive: if Android kills or freezes the app, no game stays "live" with
  an old score. The next send fills it again.
- Send log: `channels: favourites 12 (+0 ~0 -0); live 3 (+1 ~2 -0) art 3/3`.

## Limits / not done
- IPTV next episode only after an episode played from the show's page here (its queue); a show
  finished elsewhere (Trakt read-back) has no next card.
- Google TV's own home ignores third-party Watch Next unless the app is certified; Projectivy
  on Google TV reads it. Fire OS: works where its TvProvider exists (Projectivy users).
- Launchers refresh on their own schedule (Projectivy about a minute after returning to it).
- Live row: a new channel row is shown by the stock Android TV home only after the viewer allows it
  (only an app's first channel is automatic); in Projectivy the viewer adds it like any app row.
  Games start appearing only while the app's process is alive (warm exit); after Android kills it,
  the row stays empty until the app runs again. Not tested on a device yet.
- Media server titles without an IMDb id have no artwork.

## Send log
`Launcher: {supported: true, watchNext: 7 (+2 ~1 -0), channels: favourites 12 (+0 ~0 -0)}`,
`Launcher: open continue movie`, `Launcher: card cw no longer here`.

## Device results
- 2026-11-08, +678, Projectivy on a Fire TV stick (tester): works with no setup. Watch Next shows
  the episode card (title, season/episode, time left, description) and a movie; the Favourite
  channels row appeared by itself with channel art/logos.
