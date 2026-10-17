# VesperTV

An M3U / Xtream Codes (XC API) IPTV player for Android, with XMLTV EPG
support. Built and tested on Android TV boxes (Formuler), Firesticks, and
phones.

## Download

Grab the latest APK from the [Releases](../../releases) page —
`app-release.apk` works across phones, Android TV boxes, and
Firesticks. Install it directly, or side-load it via
[Downloader](https://amzn.to/2GYuEz9) on Fire TV / Android TV.

## Screenshots

<p align="center">
  <img src="docs/assets/shot-guide.png" width="49%" alt="Timeline guide">
  <img src="docs/assets/shot-live.png" width="49%" alt="Live guide with now/next details">
  <img src="docs/assets/shot-movies.jpg" width="49%" alt="Movies browse with an HD backdrop banner">
  <img src="docs/assets/shot-show-page.jpg" width="49%" alt="TV show page with seasons and episodes">
  <img src="docs/assets/shot-movie-page.jpg" width="49%" alt="Movie page with backdrop and details">
  <img src="docs/assets/shot-expand-catalog.jpg" width="49%" alt="Expanded movie catalog">
  <img src="docs/assets/shot-add.png" width="49%" alt="Add Playlist">
  <img src="docs/assets/shot-group-menu.png" width="49%" alt="Hold Select on a group: expand catalog, favourite, hide">
</p>

### Sports (new in 1.0.3)

<p align="center">
  <img src="docs/assets/shot-sports.jpg" width="49%" alt="Sports: today's games with live scores and the channel each one is on">
  <img src="docs/assets/shot-my-teams.jpg" width="49%" alt="My Teams: record, standing, mini table and the next two weeks of games">
  <img src="docs/assets/shot-standings.png" width="49%" alt="Standings by conference">
  <img src="docs/assets/shot-follow.png" width="49%" alt="Hold OK on a team to follow it">
</p>

- **Scores & schedule** for NHL, NFL, NBA, MLB, WNBA, college football, MLS, Premier League,
  Champions League, LaLiga, Bundesliga, Serie A and Ligue 1 — live scores, records, a day strip
  from yesterday to next week, and a spoiler switch that hides every score.
- **Finds the channel for you:** each game is matched to a channel in *your* playlist (event
  channels, your EPG guide, the broadcasting network). OK on a game starts watching; hold OK to
  pick a different channel and have it remembered for that game or that team.
- **Standings** per conference / league, with streaks, last ten and qualification zones.
- **My Teams:** hold OK on a team in Standings to follow it. Your teams' games get a star and
  come first; My Teams shows each team's record, standing, a mini table and its next two weeks
  of games, one press from the stream.
- No account or API key needed — scores come from ESPN's public data, straight from your device.

## Features

- M3U and Xtream Codes playlist support, with an XMLTV EPG guide
- Live TV, Movies, and TV Shows (series/episodes) catalogs
- Resume playback position, subtitles, skip/seek controls
- Auto-advance to the next episode with an "Up Next" prompt
- Sports tab: live scores, standings, My Teams, and the matching channel in your playlist
- Multiview: two or four streams at once
- Favorites (channels and groups) and group management (hide/show categories)
- Full remote/D-pad navigation on TV boxes and Firesticks, touch-first layout
  on phones
- Theming with selectable palettes, including a black-and-gold "Dark / Gold" look

## Setup

On first launch, add your playlist under Settings — either a direct M3U URL
(with an optional separate EPG URL), or Xtream Codes credentials (server,
username, password).

## Community

Bug reports, suggestions/improvements, or general discussion — join the
[Discord server](https://discord.gg/DDeGDHvFY), or open an issue here on
GitHub. Please also visit us at r/VesperTV

## License and trademarks

The code is free software under the [GPL-3.0](LICENSE). The **VesperTV** name
and logo are trademarks and are **not** covered by the GPL. Forks must use a
different name and icon and run their own pairing/transfer relay instead of
`pair.vespertv.app`. See [TRADEMARKS.md](TRADEMARKS.md).
