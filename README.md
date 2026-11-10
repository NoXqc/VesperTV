# VesperTV

A free, open-source **universal media player** for Android TV boxes, Fire TV
sticks, phones and Windows 10/11 PCs:

- **Live IPTV** from your own M3U playlist or Xtream Codes (XC API) login, with
  an XMLTV TV guide, catch-up, recording and Multiview
- **Custom REST add-ons** in the Media Hub (any source following the
  catalog/stream add-on format)
- **Your own Jellyfin, Emby or Plex server** — its movie and TV libraries in the Media Hub
- **Trakt and Simkl** watch tracking, and **Sports Trak** live scores matched to
  the channels in your playlist
- **Vesper AI**: type or speak what you want to watch

No ads, no tracking, no account. VesperTV ships no content: you bring the sources.
Built and tested on Android TV boxes (Formuler), Fire TV sticks, phones and Windows. It also runs on
Linux, including the **Steam Deck**.

> **Android gets new features first.** Windows caught up in **1.0.61**; the Linux build (beta) is on
> **1.0.63**.

## Download

Grab the latest release from the [Releases](../../releases) page or
[vespertv.app](https://vespertv.app):

- **Android** (phones, Android TV boxes, Fire TV): `app-release.apk`, installed
  directly or side-loaded with [Downloader](https://amzn.to/2GYuEz9) — code **1760256** (or type `vespertv.app/apk`).
  Later updates install from **Settings > Check for updates**.
- **Windows 10/11 (64-bit)**: `VesperTV-windows-x64.zip` from the
  [latest release](../../releases/latest) — unzip, then run `VesperTV.exe`.
- **Linux (beta, x64)**: `VesperTV-1.0.63-702-linux-x64.tar.gz` from the
  [1.0.63 release](../../releases/tag/1.0.63). **Works on the Steam Deck** (SteamOS) and on
  Ubuntu 24.04+ / Linux Mint 22+. It needs the system libmpv (`sudo apt install libmpv2`); on a
  Steam Deck, run it in Desktop Mode inside an Ubuntu 24.04 [distrobox](https://distrobox.it/).
  Extract, then run `./vespertv`. No automatic updates on Linux yet.
- **macOS (community build, unsigned)**: built automatically from `main` by the
  [macOS build](../../actions/workflows/macos-build.yml) workflow — open the latest
  run and download `VesperTV-macos-dmg` (needs a GitHub sign-in). It is not signed
  or notarized: after the first blocked launch, open System Settings > Privacy &
  Security > Open Anyway.

## Screenshots

<p align="center">
  <img src="docs/assets/shot-home.jpg" width="49%" alt="Home: the focused live channel with its programme, a small live player at the top right, and rows of favourite channels and new movies">
  <img src="docs/assets/shot-player-options.jpg" width="49%" alt="The full-screen player with its options row: channels, stream info, recent, reload, subtitles, audio sync, buffer, Multiview, fill and search">
  <img src="docs/assets/shot-guide.png" width="49%" alt="Timeline guide">
  <img src="docs/assets/shot-live.png" width="49%" alt="Live guide with now/next details">
  <img src="docs/assets/shot-movies.jpg" width="49%" alt="Movies browse with an HD backdrop banner">
  <img src="docs/assets/shot-show-page.jpg" width="49%" alt="TV show page with seasons and episodes">
  <img src="docs/assets/shot-movie-page.jpg" width="49%" alt="Movie page with backdrop and details">
  <img src="docs/assets/shot-add.png" width="49%" alt="Add Playlist">
  <img src="docs/assets/shot-group-menu.png" width="49%" alt="Hold Select on a group: expand catalog, favourite, hide">
  <img src="docs/assets/shot-multiview.jpg" width="49%" alt="Multiview 1 + 3: one big screen with the sound, three small ones beside it">
</p>

### Sports Mode (beta) and profiles

<p align="center">
  <img src="docs/assets/shot-sports-mode-rail.jpg" width="49%" alt="Sports Mode home: a rail of leagues, today's games and My Teams">
  <img src="docs/assets/shot-sports-mode-feed.jpg" width="49%" alt="Sports Mode with a game playing beside the feed of today's games">
  <img src="docs/assets/shot-sports-mode-livetv.jpg" width="49%" alt="Live TV inside Sports Mode: channel groups beside the game page">
  <img src="docs/assets/shot-sports-mode-channels.jpg" width="49%" alt="A see-through channel list over Sports Mode">
  <img src="docs/assets/shot-profiles.jpg" width="49%" alt="Who is watching: profile cards with photos, one with a PIN lock">
</p>

### Playlist editor (test flight)

<p align="center">
  <img src="docs/assets/shot-playlist-editor.jpg" width="49%" alt="Playlist editor in a browser: rename channels, guide links, fallbacks and stream test results">
  <img src="docs/assets/shot-playlist-editor-dupes.jpg" width="49%" alt="Playlist editor Duplicates tab: keep the best copy of each channel, the others become fallbacks">
</p>

### Downloads and the network folder (next release)

<p align="center">
  <img src="docs/assets/shot-downloads.jpg" width="49%" alt="Recording and download settings: margins, space, a download speed limit, a suggested overnight start, and where to save">
  <img src="docs/assets/shot-network-folder.jpg" width="49%" alt="Network folder: record and download to a shared folder on a computer or NAS">
</p>

## Sports Trak

<p align="center">
  <img src="docs/assets/shot-sports.jpg" width="49%" alt="Sports: today's games with live scores and the channel each one is on">
  <img src="docs/assets/shot-sports-guide.jpg" width="49%" alt="Sports Trak's Guide layout: a game playing beside the matchup, and the day's games as a list with their channels">
  <img src="docs/assets/shot-my-teams.jpg" width="49%" alt="My Teams: record, standing, mini table and the next two weeks of games">
  <img src="docs/assets/shot-standings.png" width="49%" alt="Standings by conference">
  <img src="docs/assets/shot-follow.png" width="49%" alt="Hold OK on a team to follow it">
</p>

- **Scores & schedule** for NHL, NFL, NBA, MLB, WNBA, college football, MLS, Premier League,
  Champions League, LaLiga, Bundesliga, Serie A and Ligue 1 — plus a League manager with 70+
  more (college basketball, hockey and soccer, AHL, ECHL, QMJHL, CFL, rugby, cricket, PDC darts,
  golf, tennis, UFC, boxing, WWE, AEW, F1, NASCAR…) — live scores, records, a day strip from
  yesterday to next week, and a spoiler switch that hides every score.
- **Finds the channel for you:** each game is matched to a channel in *your* playlist (event
  channels, your EPG guide, the broadcasting network). OK on a game starts watching; hold OK to
  pick a different channel and have it remembered for that game or that team. Set preferred
  channel countries or a preferred playlist.
- **Live stats** over the stream: box scores, scorers, injuries, team stats and standings.
- **Standings** per conference / league, with streaks, last ten and qualification zones, and
  team ranks beside team names.
- **My Teams:** hold OK on a team in Standings to follow it. Your teams' games get a star and
  come first; My Teams shows each team's record, standing, a mini table and its next two weeks
  of games. Hold a team for its full season **Schedule** calendar.
- **Reminders and goal alerts:** a reminder from 15 minutes to a week before a game, and a
  goal popup (with the scorer, and a follow-up when a goal is overturned) for your teams, one
  match or a whole league. **Phone notifications** arrive even when the app is closed.
- **Sports Mode (beta):** a sports-first home with a rail of leagues, the day's games beside a
  big player, and Live TV inside it.
- **Guide** layout (a TV-guide list of the day's games), Large / Medium / Small game cards, a
  **Networks** page of sports channels, Play in Multiview, a Watch game button when a reminded
  game starts, and optional betting lines (display only).
- No account or API key needed — scores come from ESPN's and TheSportsDB's public data,
  straight from your device.

## Features

### Playlists and live TV

- **M3U / M3U8 and Xtream Codes** playlists, as many as you want side by side, each switched
  on or off on its own. Big M3U playlists (movies and series) load in the background into the
  same catalog as Xtream, and an Xtream `get.php` link is read through its Xtream login.
- **XMLTV guide**, plus your own guide links per playlist and channel logos from your guide sources.
- **Stays connected:** backup server addresses, reconnects mid-stream, an **automatic backup
  copy** (another FHD/HD copy, or the same channel on another playlist) when a channel fails,
  a **Live buffer** for short server dropouts, and an HLS stream format option.
- **Timeline and Live guide**, with full-screen video behind a see-through guide (adjustable
  transparency), compact rows and Expand. The remote's Guide/EPG button opens it.
- **Catch-up TV on Android**: replay earlier programmes from the Timeline guide,
  watch from the start, pause/resume live TV and jump back to live — on channels
  where your provider offers catch-up. [Controls and setup](https://vespertv.app/remote.html#Live%20TV)
- **Recording (Android):** record a live channel or a Sports Trak game, schedule from the
  Channel schedule (or set a reminder), auto-record a team, to the box's storage or USB/SD
  (or, in the next release, a network folder).
- **Your channels, your way:** favourite channels and groups (across playlists, your own order
  or A-Z), your own groups, move and rename channels, hide groups and channels, sort groups,
  Recent channels, and an opt-in **Recently added** group.
- A **Real 4K** tag on channels that really play at 2160p.

### Player

- **TV controls:** OK shows the player bar with the channel's info card and a programme timeline;
  Down opens a row of options (channel list, schedule, recall, watch from the start, reload,
  audio, subtitles, audio sync, buffer, Multiview, sources, stream info, fill screen, search).
  With nothing on screen, Up/Down change channel; Right flips to the last channel.
- **Audio sync** (±5 s), optional surround/Dolby Atmos passthrough, preferred audio and subtitle
  languages, subtitle sizes and live closed captions.
- **Badges** for HD / FHD / 4K, frame rate, HDR and Atmos, and a **Data pool** with the stream's
  resolution, codecs, bitrate, HDR and dropped frames.
- **Match frame rate and resolution** (Android, opt-in).
- Resume where you stopped, **Up Next** for the next episode, and **Skip intro / recap / credits**
  buttons where timings are known (Android).
- **Multiview:** two, four, or 1 + 3 with Swap mode, with **Live now** (games on right now and
  every channel found for each) and **Sports** shortcuts in the channel picker.
- **Side panel** (Left in the full-screen live player): Last channels, My Teams and Live now.
  Next release: a **This game** tab lists every other channel showing the game you're watching.
- Phone picture-in-picture and a touch lock.

### Movies and TV shows

- Poster rows over an HD backdrop, and an **expanded catalog** grid that remembers its sort.
- Title pages with a **Trailer** (and optional automatic trailers), a **Watch list** button, and
  with your own TMDB key: cast portraits, actor credits, collections and More like this.
- **Notify me** on a show: a **New episodes** row on Home and an Android notification, even with
  the app closed.
- Continue watching, Watch list rows, mark a whole season watched, and the next episode's air date.
- **Downloads (next release, Android):** download a movie, an episode or a whole season to watch
  offline. It suggests tonight at 2:00, at a speed that looks like someone watching, and saves to
  the box or to a **network folder** (a shared folder on a computer or NAS), where a tablet can
  copy it before a trip.

### Media Hub

- **Films and series** from REST add-ons you add, and from your own Jellyfin / Emby / Plex
  server (Plex uses a sign-in code approved on plex.tv/link). Paste many add-on links at once,
  or **import your add-ons from Stremio** with a code.
- **Live TV add-ons** get their own Live TV section and play like live channels.
- A **source picker** that fills in as each add-on answers, with format, file size and subtitle
  count; playback preferences per profile (auto-play, preferred source and audio language,
  maximum quality, prefer SDR); switch files mid-playback, and resume on the same file.
- **Trakt & Simkl:** sign in with a code on the TV; what you watch is scrobbled, watched episodes
  get their checkmark, and your watchlist and Continue watching become rows (with files found on
  your own servers).
- Favourites, Continue watching and Upcoming episodes rows, a Watch list page, **Customize** to
  show / hide / pin / move / rename rows, custom poster services, and an **Other** filter that
  keeps custom or adult add-ons apart.

### Vesper AI (Android)

Built-in voice and typed commands, your phone as a microphone, and optional bring-your-own AI
or AI apps. [See below](#vesper-ai).

### Profiles, Home and startup

- **Viewer profiles** with photos and an optional PIN, and **Kids profiles** limited to the
  groups you allow. Each keeps its own favourites, history, Media Hub, colours and guide layout.
  Optional **Who's watching** at launch.
- **Home:** Continue watching, Recent channels, New episodes, Watch list and today's games,
  with a small player for live channels on TV boxes. Next release: a bigger live channel card and
  your own Home wallpaper (optionally behind Who's watching too).
- **Open on** the tab you choose, resume the last channel, fast startup, and catalog updates on
  your schedule (every hour to every few days), optionally in the background.

### Your setup on every device

- **Sync** your setup and watch progress across up to **3 devices per sync**, with no account.
  Each 16-digit link code works once for one device and expires after 10 minutes; every code
  and the recovery code share the same device limit. Everything is encrypted on your device.
  Stop syncing to free a slot, or an unused device frees it after 30 days. Reset removes the old
  encrypted server copy and device slots; every other device must be linked again. Save the
  new recovery code. [Sync guide](https://vespertv.app/remote.html#Sync)
- **Transfer** your whole setup to another device (same Wi-Fi or over the internet), and
  **Backup & restore** (it can also import M3U files and add-on lists from USB).
- **Playlist editor (test flight):** clean up your playlists from your phone or PC — rename
  channels, change logos, rules that survive updates (remove `US| ` from every name, hide `PPV`),
  hide lower-quality copies, rename / merge / reorder groups, fallback channels, link channels to
  the guide, combine playlists, and an optional stream test. Your provider's playlist is never
  changed, and every change can be undone.
- **From phone:** type keys, links and server logins on your phone instead of the remote.
- A built-in **updater**, **Send log** for bug reports, and a [remote tips](https://vespertv.app/remote.html) page.

### Look, languages and access

- Full remote/D-pad navigation on TV boxes and Firesticks, a touch-first layout on phones, and
  mouse and keyboard on Windows.
- Colour themes (Platinum, Rosé, Neon Purple, Neon Green, Aqua, Red, Blue and a black-and-gold
  **Dark / Gold**), with an optional glass **Refined finish**.
- English, French, Spanish, Italian, Greek and German.
- Works with TalkBack and the phone's largest text and display sizes.

## Vesper AI

Open **Vesper** in the side menu, the microphone in Search, or **Settings →
Vesper AI → Talk to Vesper now**. Type or say "play TSN 1", "pause", "what's on
TSN 1", "open the movies", "today's games" or "help". Built-in commands are
free and parsed on your device, with no AI account or API key, in English,
French, Spanish, Italian and German. They use the sources you already have;
VesperTV supplies no channels or films.

**Talk from my phone** shows a QR code. On the same Wi-Fi, type or use your
phone keyboard's microphone. This also works around Fire TV keeping its Alexa
button for the system. Remote voice support depends on the device and speech
service; it is off by default under **Settings → Vesper AI**, and **Teach it
your remote's button** learns a button it doesn't pick up. Vesper can add titles
to your **Watch list** (on Home, Movies, TV Shows and the Media Hub); hold OK on
a saved item to remove it.

For more flexible requests, **Your AI** accepts Claude, an OpenAI-compatible
service (including a local compatible server), or Gemini using your own model
and API key where required. Provider usage charges may apply. **AI apps → Let
AI apps control VesperTV** supplies a private MCP connector address for a
compatible AI app. A Claude connector has been tested; other clients still need
testing. Use one connector per TV and leave VesperTV open on that TV. Your AI
and AI apps can also **change settings** (playback, startup, language and
theme, the guide, tabs, Sports Trak), **clear history** (searches and channels,
Continue Watching, Media Hub, the watch list) and reload the guide; the AI
settings, PIN, profiles and playlists are never changed that way. **Ask on
the TV first** defaults on for starting titles, hiding/showing groups,
changing settings and clearing history or the watch list; other tool actions
can run without a dialog. Keep the address private; **Reset the address**
invalidates the old link.

**Privacy:** with Your AI set to None, typed commands are handled without an
AI provider. When enabled, Your AI can handle unrecognized requests and failed
built-in commands. With Your AI, your request, conversation and tool results
(including channel/title names, guide listings, group names and watch-list
notes) go directly to that provider, without the VesperTV relay. For linked
MCP apps and the optional relay phone page, requests and tool replies pass
through the relay. It holds that traffic temporarily in memory and does not
save conversation history. Your provider or AI app applies its own data policies. Voice input
uses the TV or phone speech service; it is not guaranteed to be processed
locally. [Full guide and current limits](https://vespertv.app/remote.html#Vesper%20AI).

## Setup

On first launch, add your playlist under Settings — either a direct M3U URL
(with an optional separate EPG URL), or Xtream Codes credentials (server,
username, password). Add-ons and Jellyfin / Emby / Plex servers are added from the
Media Hub (Settings > Media Hub sources, or **Connect Jellyfin / Emby / Plex**).

## Community

Bug reports, suggestions/improvements, or general discussion — join the
[Discord server](https://discord.gg/VPQ849NPV), or open an issue here on
GitHub. Please also visit us at r/VesperTV

VesperTV is free and always will be. If you'd like to help with the server and
development costs, you can [donate on Liberapay](https://liberapay.com/NoXQc/donate)
(optional, it unlocks nothing: everyone gets the same app).

## Credits

- Movie and TV artwork and data may come from [TMDB](https://www.themoviedb.org/). This
  product uses the TMDB API but is not endorsed or certified by TMDB.
- Watch tracking is powered by [Trakt](https://trakt.tv) and [Simkl](https://simkl.com).
  VesperTV is not affiliated with or endorsed by either.
- Sports scores and schedules come from ESPN's public data and [TheSportsDB](https://www.thesportsdb.com/).
- Skip intro / credits timings come from [IntroDB](https://introdb.app).
- The macOS build was contributed by [gmtherien](https://github.com/gmtherien).

## License and trademarks

The code is free software under the [GPL-3.0](LICENSE). The **VesperTV** name
and logo are trademarks and are **not** covered by the GPL. Forks must use a
different name and icon and run their own pairing/transfer relay instead of
`pair.vespertv.app`. See [TRADEMARKS.md](TRADEMARKS.md).
