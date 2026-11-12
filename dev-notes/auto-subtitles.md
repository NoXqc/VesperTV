# Subtitles for live channels (Claude, 2026-11-12, branch `claude/live-subtitles`, unreleased)

Owner: "what can we do to have subtitles for live channels that don't have them" -> "do one and two and your
recommendation"; then "live channel is where we need to work on subtitles, movies have most with our online
subtitle add-on". Stacked on `claude/ai-epg-match` (+739) so the test APK keeps the EPG tool. Test build **+740**.

## 1. Closed captions on Windows / iPhone (mpv)

`configureDesktopStreamPlayer` sets `sub-create-cc-track=yes`: EIA-608 captions inside the video become a
subtitle track (codec `eia_608`) from the start, labelled like Android's CC row. mpv marks that track default and
would show it by itself, so a `stream.track` listener turns it off unless the viewer picked it
(`desktopCaptionsWanted`, set by `setDesktopSubtitle` from the Subtitles menu and Vesper's subtitle command); once
picked it follows zaps. iOS uses the same code (port to `claude/appstore-build` when merging).

## 2. Picture subtitles on Android (DVB, also PGS / VobSub)

Vendored `SubtitleBridge`: image formats are listed (`image: true`) and their bitmap cues are sent as PNG bytes
with position / line / size fractions (each bitmap encoded once, `WeakHashMap`). `mimeOf` reads `codecs` when the
sample MIME is `application/x-media3-cues` (media3 1.4+ parses MKV/MP4 subtitles during extraction: PGS tracks were
listed before and drew nothing). Dart: `SubtitleImage`, `SubtitleCueEvent.images`, `SubtitleOverlay._pictures`
draws them centred where the cue says, at their width in the video (x Subtitle size), at the usual bottom place
(nearly every DVB/PGS cue is there; a top-of-screen cue also shows at the bottom). Teletext subtitles (page 888)
are still not supported (media3 has no decoder).

## 3. Automatic subtitles (beta, Android, live channels only)

- Player > Subtitles > **Automatic subtitles (beta)** (live channels, ARM Android) > Off / English / Français.
  Remembered per channel (`vesper_auto_subtitles`, device-only, 300 channels). Picking a track or Off turns it off.
  Not with Surround passthrough (the sound is never decoded): a message says so.
- Sound: vendored `AudioTap` (CLAUDE.md §9) -> EventChannel `vespertv/audio_tap` -> `AutoSubtitles._onAudio`
  (int16 -> float) -> recognizer isolate (`_listen`). More than ~2 s of sound waiting = new sound dropped and a
  `AutoSubs: this device is behind` line in Send log (a slow box falls back instead of drifting).
- Engine: sherpa-onnx 2.0.1 streaming Zipformer transducer, 2 threads, greedy search, endpoint rules
  (1.2 s silence after speech). Dart bindings vendored in `third_party/sherpa_onnx_dart` (Apache-2.0) **without**
  the platform packages: their native libraries would add ~107 MB to the APK (4 ABIs) and 44 MB to the Windows zip.
  Instead `install()` downloads pub.dev's immutable `sherpa_onnx_android_{arm64,armeabi}-2.0.1.tar.gz` (10.4 /
  9.4 MB), checks the pinned SHA-256, extracts `libonnxruntime.so` + `libsherpa-onnx-c-api.so` into
  `<app support>/auto_subtitles/engine-2.0.1-<abi>/`, chmod 555; `initBindings(dir)` opens onnxruntime first by full
  path (the C API's only non-system dependency) then the C API. x86 boxes: not offered.
- Models from Hugging Face (Apache-2.0): English `csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17`
  (int8 encoder/joiner + float decoder, ~46 MB, LibriSpeech-trained: expect mistakes on TV speech), French
  `shaojieli/sherpa-onnx-streaming-zipformer-fr-2023-04-14` (~130 MB, heavier). Bigger English options exist
  (`...en-2023-06-26` 73 MB; NeMo fast-conformer ~470 MB, too big). `autoSubtitleModels` is plain data: swap there.
- Display: `AutoSubtitles.text` (last finished line + the one being said, ~45 chars each, cleared after 5 s of
  silence), sentence case from the models' capitals, drawn by `SubtitleOverlay` when no other subtitle shows.
- Settings > Playback > Automatic subtitles (beta): what is downloaded + Delete.
- Send log: `AutoSubs:` lines (installed, listening, stopped, behind, errors).

## Risks / to check on a box

1. `dlopen` of downloaded libraries from the app's files folder (expected to work; Android 14's read-only rule
   covered by chmod). If it fails, Send log shows `AutoSubs: engine did not start: ...`; plan B = ship arm64 +
   armv7 libraries in the APK (~+46 MB uncompressed).
2. CPU: English 20M model should run on 2 cores of an S905X4 / Fire Stick 4K; French is ~3x heavier.
3. Accuracy on real TV (news is best, sports commentary over crowd noise worst).

## Test checklist (+740)

- Live channel without CC: Subtitles > Automatic subtitles > English: download dialog with size, progress, then
  words a second or two after speech; zap: stays on for that channel only; Off: stops; Settings row shows size and
  Delete frees it.
- Surround passthrough on: message instead of starting.
- Channel with DVB subtitles (UK / European feed): picture subtitle shows; a Media Hub MKV with PGS shows too.
- Windows: a US channel with CC: Subtitles lists "Closed captions (CC)", off by default, on when picked.
