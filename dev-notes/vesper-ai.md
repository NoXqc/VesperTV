# Vesper AI (Claude, 2026-11-06, branch `claude/vesper-ai`)

Owner: "add an AI assistant; voice from the remote; users bring their own AI
and unlock more; they could even talk to it from their AI app connected as
MCP" (inspired by Lumenia's ChatGPT/Claude MCP connector, r/AndroidTVApps).

## Shape
One tool layer, three front ends:

```
 remote mic / Search mic / typing / phone page ─┐
                                                ├─ VesperAi.ask(text)
                                                │    1. parseVesperCommand  (built-in, free, offline)
                                                │    2. viewer's own AI     (BYO key: Claude / OpenAI-compatible / Gemini)
 Claude / ChatGPT app (MCP connector) ──relay──►└─ McpBridge.handle → VesperToolbox.call(..., remoteApp)
```

- `lib/services/vesper_ai/vesper_tools.dart` — `VesperToolbox` + `vesperTools`:
  search, play, now_playing, player, guide, find_on_tv, open, favorites, recent,
  groups (list/channels/hide/show), sports_today, play_game, game_channel,
  show_message. JSON-Schema objects shared by all providers and MCP. Search
  hands out short refs (`l12`, `m3`, `s7`; games `g4`) kept in memory.
  **Game channels (2026-11-08, `game_channel_tool.dart`):** sports_today takes
  league/day and returns game refs, ESPN networks and `matched_by` (viewer_pick /
  guide / channel_name vs *_guess); groups action channels lists one live group
  with now/next; game_channel saves `SportsChannelPicks.pickForGame` for up to 40
  games with one TV confirm. Manual: vesper_help topic "sports" (never guess
  between numbered feeds; web search, when the AI app has it, only gives the
  network). In-app BYO-key providers have no web search. Open cards pick it up
  on the next Sports Trak rematch.
  **Profiles + parental (2026-11-08, `profiles_tool.dart`):** tools `profiles`
  (list/switch/create/rename/delete) and `parental` (status/allow_groups/
  block_groups/change_pin) over `VesperProfileControl` (app: `AppVesperProfiles`
  in vesper_host.dart). Rules: the AI has the on-screen profile's power, never
  more; on a kids profile every change needs the PIN on the TV; loosening (allow
  groups, delete a kids profile, change PIN) asks the PIN from any profile; the
  PIN only ever goes through the TV's own pad (2 min timeout, `promptForPin(
  timeout:)`), no tool parameter holds it (a test checks), no remove-PIN /
  unrestrict action. Kid allowlists of a non-active viewer:
  `StorageService.get/setShownGroupsFor`. `switchTo(unlocked:)` skips the second
  PIN pad. Manual: vesper_help topic "profiles". Respects visibleChannels / hidden groups /
  restricted viewers (groups refused) / Hide scores / hidden tabs.
- `VesperHost` (`screens/vesper_ai/vesper_host.dart`): plays like a guide pick
  (popUntil first + PlayerScreen / DesktopPlayerScreen), opens sections through
  `GuideKey.openSection` → `TvHomeScreen.openSection` (its own openers: Settings
  PIN, parking, Back to TV), confirms AI-app actions with a dialog (1 min = no).
- `vesper_commands.dart` — EN/FR/ES/IT/DE phrases (Greek mostly via AI), folded
  with `TitleSearch.fold`. Pure function, `test/vesper_commands_test.dart`.
- `vesper_ai.dart` — orchestrator, system prompt, built-in reply sentences
  (`describeResult`), the bottom bubble (`bubble`, `VesperBubbleOverlay`).
  Conversation resets after 10 min idle. Local time goes in the user turn, not
  the system prompt (keeps it cacheable).

## Providers (BYO key, Settings > Vesper AI > Your AI)
- **Claude** (`anthropic_provider.dart`): raw HTTP `POST /v1/messages` (no Dart
  SDK), `anthropic-version: 2026-10-21`, default `claude-opus-5-5`, effort `low`
  (voice wants short/fast), top-level `cache_control`, `fallbacks: "default"` +
  beta `server-side-fallback-2026-07-01` on opus-5*/fable-5-1/sonnet-5-5 only,
  `refusal` stop reason handled, history append-only (thinking blocks returned
  unchanged), all tool_results in one user message, no temperature / thinking
  params, no forced tool_choice.
- **OpenAI-compatible** (`openai_provider.dart`): `{base}/chat/completions`
  function tools; base URL lets OpenRouter/Groq/Mistral/local Ollama/LM Studio
  work (local: no key).
- **Gemini** (`gemini_provider.dart`): `generateContent`, functionDeclarations
  with UPPER-case types, model turns kept verbatim (thought signatures).
- Any failure mid-loop resets the conversation (no dangling tool call).
- Keys: `vesper_ai_provider/model/api_key/base_url` — transferred/synced like
  the TMDB key. "Key from phone" reuses `PhoneLinkScreen(PairingKind.apiKey)`.

## Voice (Android)
- `VoiceBridge.kt`: `SpeechRecognizer` (MethodChannel `vespertv/voice`,
  EventChannel `vespertv/voice/events`), RECORD_AUDIO asked on first use
  (request code 4731), `TextToSpeech` for "Read replies aloud", ACTION_ASSIST /
  VOICE_ASSIST intent filter (assistant launch, `takeAssist` so it's never lost
  or doubled). Manifest: RECORD_AUDIO, microphone `required=false`, `<queries>`
  RecognitionService + TTS_SERVICE.
- Remote key (`voice_key.dart`, main.dart `_onVoiceKey`): KEYCODE_SEARCH
  (browserSearch), ASSIST (launchAssistant), VOICE_ASSIST (0x11000000e7), or a
  key taught in Settings. **Off by default** (it otherwise opens the device's
  assistant). Many systems never pass ASSIST/VOICE_ASSIST to apps; Fire OS keeps
  its Alexa button — unfixable, phone path instead.
- Advanced: `adb shell settings put secure assistant com.nox.nox_iptv/.MainActivity`
  (untested on real boxes; Google TV may ignore it).
- Panel: `screens/vesper_ai/vesper_panel.dart` (route over the current screen;
  Talk / gated text field / Talk from my phone / Close). An action pops it (host
  popUntil first) and the reply goes to the bubble.

## Phone microphone (V2)
- Same Wi-Fi: `PhoneMicServer` serves `assets/vesper_ai/phone.html` at
  `http://<tv-ip>:8931/v/<token>` (token kept per device, stops after 1 h idle);
  POST `/say` → `askFromPhone` (reply to phone + bubble on TV). Plain http, so
  the browser's speech API is blocked: the phone keyboard's own mic is the voice.
- Any network: relay page `https://pair.vespertv.app/ai#<link>` (copy
  `tools/pair_relay/ai.html`, test keeps them identical) sends JSON-RPC
  `vesper/say` through the AI link; HTTPS → Web Speech mic button works.
- **VPN on the TV** (owner, 2026-11-07: most IPTV users run one on the box, not the
  phone): the VPN usually catches the replies to the phone, so the same-Wi-Fi page
  never loads. `deviceOnVpn()` (`phone_pairing_service.dart`, IPv4 adapters named
  tun/ppp/wg/ipsec/tap/nordlynx…, `isVpnInterfaceName`, also kept out of
  `privateLanIpv4`) → the dialog opens on the relay code. That code no longer needs
  AI apps: `McpBridge.startPhoneLink()` = phone-only link (secret created if needed,
  polls while the app is shown, ends 1 h after the last `vesper/say`); with AI apps
  off every other method answers "AI apps are off on this TV". Relay unchanged.
  Not yet tried with a real VPN app on a box.

## AI apps over MCP (V3b)
- `tools/pair_relay/ai_link.py` (+ `test_ai_link.py`, 6 tests): `POST /mcp/<secret>`
  Streamable HTTP with JSON answers; relay answers `initialize`/`ping`,
  notifications → 202, forwards the rest to the TV's long-poll
  (`GET /api/ai/poll` 25 s, `POST /api/ai/reply`, header `X-Vesper-Link`,
  app header). Waits 75 s (TV may ask the viewer). TV offline → clear text
  result (`tools/list` from cache). Only sha256(secret) kept; in memory only;
  caps per link/global. `GET /mcp/<secret>` in a browser = help page with Copy.
- nginx: `/mcp/` (90 s) and `/api/ai/` (40 s) locations added to
  `nginx-pair.conf`. **Not deployed yet** — needs the owner's OK (§2: back up,
  `nginx -t`, reload).
- `McpBridge` (Dart): link secret per device (`vesper_ai_dev_link_secret`,
  never transferred/synced/backed up), poll only while the app is shown
  (AppLifecycleListener onHide/onShow), `tools/call` as `VesperCaller.remoteApp`
  (play/open/hide/show confirmed on the TV unless "Ask on the TV first" is off).
- Claude: Settings > Connectors > Add custom connector (authless URL).
  ChatGPT: developer-mode connector, no auth. Secret-in-URL = the credential;
  Reset makes a new one. Not checked yet: whether either app insists on OAuth.

## Voice search tuning (Claude, 2026-11-06, unreleased; user report)
"TSN 1" heard as "TSN one" found nothing and played Sportsnet One (the old
`rankByName` used TitleSearch: every word *anywhere* in the joined name, and
spor**tsn**et holds "tsn"); hidden channels still played; wanted all-TSN /
CBS east+west lists, "open PPV", the English feed of a game.
- `rankByName` (vesper_tools.dart): `spokenTokens` (fold, "tsn1" -> "tsn 1",
  EN/FR/ES/IT/DE number words -> digits, "t s n" -> "tsn"), a leading
  provider tag ("CA: ", "US| ", "[UK]") ignored for scoring, tiers exact /
  starts / in a row / all words / word prefixes, then piece-of-word matches
  only when nothing better matches. Cheap TitleSearch gate first (350k lists).
- `_play` refuses a live channel no longer in `visibleChannels` (a ref from
  an earlier search outlived Hide channel: the likely cause of the report).
- Phrases (vesper_commands.dart): "show me all TSN" / "every CBS channel" /
  "toutes les chaines TSN" -> search page (east+west words dropped); "open
  PPV" / "go to the Live Events category" -> `open` section `group`
  (`VesperToolbox.findLiveGroup` + `_groupSynonyms`, else the search page;
  TV side `TvHomeScreen._openLiveGroup`, like a touch pick); "the English feed
  of the Habs game" / "... in french" -> `play_game` `language`
  (`vesperChannelLanguage`: RDS/TVA/FR tags = fr, country tags else) and
  `list: true` for every feed.
- Search page: Live TV (and M3U Movies/Shows) matches sorted by
  `TitleSearch.rank`, playlist order within a rank (TSN before Sportsnet).
- Game feeds: "which channels have the Habs game" / "quelle chaine passe le
  match du Canadien" -> `play_game` `list: true`, bubble = first game's
  channels (6 names max, each once, language marked when not the app's).
  `VesperAi._feeds` remembers them 20 min: "play it on RDS" / "mets-le sur
  RDS" (`play_feed`, not a tool) plays the best-named one, ties in list
  order (= preferred copy), else the channel by name. Order = Sports Trak
  `orderMatches` (saved pick, evidence, preferred playlist, countries,
  quality; distinct copies first) then the asked language, or the viewer's
  Preferred audio language (a saved pick stays first then). Questions
  (what / which / is / quel...) never become a "play the X game" team.
- Tests: `vesper_search_test.dart`, `vesper_voice_tools_test.dart`. Group
  opening not checked on a box yet (focus lands like a touch pick).

## Playlist editor tool + help (Claude, 2026-11-06, unreleased)
Owner: "hide every channel without EPG, remove all CA affixes, add channel A as
fallback to channel B" from Claude, with an API doc the AI can read, and undo.
- `playlist_editor` (`vesper_ai/playlist_editor_tool.dart`, a `part` of
  vesper_tools.dart): writes the same `PlaylistEdits` layer as the editor page
  (`session.saveEdits`), never the provider list, live channels only. Actions:
  list, find_channels (ids `playlistId::rawId`, search refs work too),
  hide_no_guide (one-time snapshot; refused while the guide loads / none loaded,
  a playlist with zero guide matches is skipped), hide_dead (existing probe
  results only, never runs tests), hide/show_channels, add/remove_rule,
  rename, rename_group, add/remove_fallback, set_option, undo. `preview: true`
  on any change = effect counts + examples, nothing saved. A hide rule that
  would hide a whole playlist is refused. AI apps confirm on the TV (localized
  `{what}` built from counts); restricted viewers refused.
- **Undo** (`services/playlist_edits_diff.dart`): every change stores an
  `EditsDiff` (before/after per field; probes excluded) in `AiEditLog`
  (30 newest, ~1.5 MB cap, key `vesper_ai_dev_editor_undo` per viewer,
  device-only). `revert` only restores a part still as the AI left it, so a
  later hand edit in the editor page is kept (reported as `kept`). The plan
  re-runs after the TV confirm on the edits as they are then.
- `vesper_help` (`vesper_ai/vesper_help.dart`): topics overview /
  playlist_editor, served by the app so it matches the installed version.
  The tool description, the in-app system prompt and the relay `INSTRUCTIONS`
  point the AI to it. **Relay sentence not deployed** (tool descriptions alone
  already say it). `test/playlist_editor_ai_test.dart` fails if an action is
  missing from the manual, and checks the manual's CA-affix regex.
- Not done: a persistent "no guide" rule (new channels), running stream tests
  over MCP (connection limits), Movies/Shows.

## Settings tool (Claude, 2026-11-08, branch `claude/ai-settings`, unreleased)
Owner: tell Claude over MCP to turn settings on or off and delete histories.
- `settings` (`vesper_ai/settings_tool.dart`, a `part` of vesper_tools.dart):
  actions list [section], get key, set key+value or `changes` [{key, value}]
  (one TV confirm for all), clear what, update_guide (`EpgService.refreshAll`,
  not awaited). 53 curated settings in `_aiSettings` (switch / choice /
  number, each with its Settings title for the confirm and an `about` for the
  model); Android-only ones are left out on a computer (`isDesktopTarget`).
  Startup ones say "applies at the next app start".
- **Never exposed (on purpose):** Ask on the TV first, AI keys / apps / voice
  key, the PIN, profiles, playlists, layout mode and the video troubleshooting
  switches (native surface, Compatibility video, green flicker fix). An AI
  app must not be able to switch off its own confirmations.
- clear: searches_and_channels / movies_and_shows (the two Settings > General >
  History actions), media_hub (new `ArchiveService.clearHistory`, passed in as
  `VesperToolbox.clearHubHistory`), watch_list, all_history (not the watch
  list). Confirm text reuses the History titles.
- AI apps confirm set and clear on the TV (localized "{setting}: turn on" /
  choice names); Kids profiles can list but not set or clear. The Ask on the
  TV first subtitle now names settings and history (5 languages).
- `test/vesper_settings_tool_test.dart` (8 tests, incl. every TV text
  translated in fr/de/es/it/el). Remote guide row + Discord guide.json rebuilt.
- Not done: built-in (no-AI) phrases like "turn off skip intro"; clearing the
  EPG / catalog cache; "update content" (the catalog sync has its own screen).

## Media Hub tool + playback (Claude, 2026-11-09, uncommitted on main)
Discord request (Kal-el23): let ChatGPT check quality, pick the best link, switch sources, control playback.
- `media_hub_tool.dart` (part of vesper_tools): actions search (title refs `h…`), episodes, sources (a title +
  season/episode, or what is playing: source, `video` from `archiveStreamFormats`, `audio` from the labels
  (`hubStreamAudio`), `size_gb`, `ready` (false = `[TB download]` / ⏳: plays a "being downloaded" clip), `playing`,
  `best` = `hubBestStream`: the viewer's Media Hub playback prefs (`ArchivePlaybackPreferences.ranked`, largest
  file when that's on), never a download/trailer), play (title ref; `best` true = best stream, else the app's usual
  choice/picker; stream ref `o…`; show + season/episode with the aired episodes as the Next queue; a show alone
  opens its page), switch (`next` / `best` / stream ref, same position via `PlaybackService.replaceStream`, which
  the source drawer now uses too). Stream URLs never go to the model (they carry debrid keys).
- `VesperHub` interface; app side `screens/vesper_ai/vesper_hub.dart` (`AppVesperHub`: `ArchiveService.searchRows`,
  `meta`, `streams`, `playArchiveTitle(chosen:)`, `openArchiveSeries`). `PlaybackService.hubSources` = the full-screen
  player's `ArchivePlaybackSources` (set/cleared by PlayerScreen). Play waits up to 20 s for the stream to start
  (`mediaHubStartWait`).
- now_playing: `stream` for a Media Hub title, `error_on_tv`, and `quality: true` = picture, HDR, audio, measured
  bitrate (two StatsBridge samples 1.5 s apart), buffer, buffering, dropped frames (opt-in: the built-in "what's on"
  stays instant).
- player: next_episode / previous_episode (+ channel up/down during a show), built-in phrases in 5 languages.
- player: audio_tracks / audio_track (language code or name, or track number; commentary skipped) and subtitles /
  subtitle (language, track number, "off", "cc"; not in the file = first match from the subtitle add-ons, like the
  picker's online languages). Same steps as the player's buttons, remembered for the show (AudioTrackPreferences,
  rememberForSeries). `vesper_ai/player_tracks.dart`, `test/vesper_player_tracks_test.dart`. Android only (the
  player tool says "not on Windows yet"). No built-in phrases yet. AI apps: reconnect the connector.
- Media Hub picks streams in the viewer's language (`services/stream_languages.dart`; sources list `languages` /
  `multi_audio`).
- System prompt: Media Hub when asked or when the playlists lack a title; play best; buffering = switch next.
- Tests: `test/vesper_media_hub_tool_test.dart` (8). Not device-tested; Android only for switch/quality (Windows
  plays titles but has no switch). AI apps must reconnect the connector to see the new tool.

## Not done / next
- **Several TVs** (owner, 2026-11-06: test as is): today one connector per TV (each TV has its own link; name them
  "VesperTV Living room" etc. in the AI app). Parked idea: one shared link via Sync, TV names, relay routes by
  name, optional `tv` argument + a list-TVs tool, default = the TV that's on / used last.
- Real-device tests: which key each remote sends (Formuler, Shield, Onn, Fire
  Stick), SpeechRecognizer on the Formuler, relay deploy + a real Claude/ChatGPT
  connector session.
- Windows: no voice; player/now_playing tools say "not on Windows yet".
- No episode picking for IPTV shows (series → show page); Media Hub shows take season + episode (media_hub).
- Remote tips (`docs/remote.html`), help index, website and README documentation
  prepared on `codex/vesper-ai-docs` (Codex, 2026-11-06; pending merge/publish).
- Public privacy docs distinguish built-in parsing, direct Your AI requests and
  relay/MCP traffic, including tool metadata, temporary in-memory relay queues,
  provider/app policies and the device speech-service caveat.
