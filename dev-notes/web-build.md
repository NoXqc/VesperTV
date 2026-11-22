# VesperTV in the browser (web build): parked plan

Status: **idea, parked** (owner, 2026-11-22: "we'll work on the web build later"). Nothing in the app
has changed for it yet. (`docs/try/` is a separate thing: a hand-written demo page with a fake playlist,
not the app.)

## The ask

uzumaki (Discord, 2026-11-22) asked whether VesperTV can run in a browser, bundled with the Tuliprox UI
"maybe as a plugin". The example was M3U Editor 0.14.6, which serves the **M3U TV** app as a web app
(https://m3ue.sparkison.dev/blog/m3u-tv-in-your-browser/). How M3U TV does it:

- It is a Flutter app compiled to **WebAssembly**, served by M3U Editor at `/m3u-tv/`.
- Settings > TV App > Web App > Install downloads the build from M3U TV's GitHub releases and checks it
  against a published checksum. Updates and rollback are separate from M3U Editor's own updates.
- Live HLS plays with hls.js (Safari plays HLS natively) and live MPEG-TS with mpegts.js. MP4 plays
  directly.
- MKV is repackaged in the browser by Mediabunny, without re-encoding. AC-3, E-AC-3, DTS and TrueHD are
  converted to AAC by FFmpeg compiled to wasm, keeping 5.1. Atmos and DTS:X play as plain surround, and
  7.1 becomes 5.1.
- Posters from sites that block browser requests go through M3U Editor's image proxy.
- Multiview stays on the TV apps.

## Why not a Tuliprox plugin

This was checked against Tuliprox develop 95b9c61 (`docs/src/plugins/custom-ui.md` and `http-routes.md`).

- **Plugin pages** are an `<iframe sandbox="allow-scripts">` with no same-origin access. The CSP is
  `default-src 'none'; script-src 'self'; connect-src 'none'`, so the page can show no `<video>` and
  make no fetch, XHR or WebSocket call. Only some file types are served (html, css, js, json, images,
  fonts, txt). **`.wasm` isn't one of them**, and each file is capped at 16 MiB. A plugin page's
  context never carries stream or catch-up URLs. Tuliprox does this on purpose: it's their security
  model.
- **Plugin HTTP routes** are bounded request and response calls: a 16 MiB body and no streaming. Their
  HTML gets a sandbox CSP.

So a player can't run as a plugin unless the Tuliprox developer changes that model. Don't ask for that.

## What would work

Serve a VesperTV **web build as static files next to Tuliprox, on the same origin**, the way M3U Editor
does it. Same origin is the key:

- The browser reads the playlist, EPG, `player_api` and streams without CORS errors.
- There's no mixed-content block when Tuliprox is served over https.

What to ask the Tuliprox dev for:

- A setting that serves a downloaded web-app folder at a path such as `<web_ui_path>/vesper/`, with
  the right MIME type for `.wasm`.
- No CSP on that path, or one that allows `'wasm-unsafe-eval'` and same-origin `media-src` and
  `connect-src`.
- Optionally, install and update from VesperTV's GitHub releases with a checksum, like M3U Editor.

Until then, nginx in front of Tuliprox can serve the folder for testing.

## What VesperTV needs (checked 2026-11-22 on main 95214f4)

`flutter build web --release` fails at compile time **only on dart:ffi**: 154 errors from the `ffi`
package and these desktop libmpv files:

- `lib/services/desktop_recorder.dart`
- `lib/services/desktop_stream_setup.dart`
- `lib/services/desktop_audio.dart`
- `lib/widgets/desktop_data_pool_card.dart`
- `lib/widgets/desktop_quality_badges.dart`

Putting those behind conditional imports (`if (dart.library.ffi)`) should get it to compile. The real
work starts after that, at runtime:

1. **dart:io.** 62 of 413 files in `lib/` import it directly, and `File`, `HttpClient`, `Platform.*`
   and `Directory` all throw in a browser. This needs a platform layer:
   - `kIsWeb` checks before `Platform.is*`;
   - `package:http` (BrowserClient) instead of `HttpClient`;
   - no file cache, or one in IndexedDB.
2. **Databases.** sqflite has no browser backend, and the catalog DB (`catalog_database.dart`) and the
   EPG DB (`epg_database.dart`) both use it. Candidates are `sqflite_common_ffi_web` (SQLite wasm on
   OPFS/IndexedDB) or drift's web backend. EPG size limits in browser storage are untested.
3. **Player.** Android uses the vendored ExoPlayer and the desktop uses media_kit (libmpv). On the web,
   media_kit uses an HTML `<video>`, which needs hls.js for HLS outside Safari and mpegts.js for
   Xtream `.ts` live. Catch-up and VOD come over HTTP with Range requests.
4. **Codecs.** Browsers don't decode AC-3 or E-AC-3 (most IPTV sports audio), and HEVC support varies by
   browser and GPU. Either convert the audio as M3U TV does (Mediabunny plus FFmpeg wasm, downloaded
   on first use) or ask Tuliprox to serve a transcoded profile.
5. **Left out at first:** Multiview, recordings, downloads, the SMB network folder, launcher rows,
   remote buttons, DRM, pairing by QR, the native surface and passthrough.
6. **Images.** Logos and posters from hosts without CORS need a proxy: Tuliprox's, or the relay's.

## Suggested first slice

Live TV, the Timeline guide, and Movies and TV Shows from **one Tuliprox playlist** (Xtream login).
Keyboard and mouse only, no profiles sync. Then measure:

- compile size (wasm and CanvasKit);
- first-load time;
- guide speed with a real EPG in browser storage;
- which channels fail for codec reasons.

Rough size: weeks, not days. Mostly the dart:io, database and player layers.

## Open questions

- Will the Tuliprox dev add "serve a web app folder at a path"? Would he host it per user (the playlist
  login, see the per-user API spec doc) or for the admin only?
- Should the browser app be a separate build flavour (`--dart-define=VESPER_WEB=true`) that hides
  native-only settings, as `appStoreBuild` does for iOS?
- Should we use Mediabunny and FFmpeg wasm for AC-3, or rely on the server for it?
