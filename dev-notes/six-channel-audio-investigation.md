# Issue #9 investigation: "6-channel audio not available in FireStick" (Claude, 2026-11-21)

> Written by the reporter (corporate-gadfly) with their own AI tools and contributed with PR #12. The fix
> (Compatibility video honours Surround passthrough) is summarised in CLAUDE.md §9.

Media3 1.9.2's default PCM sink is not stereo-capped. Device logs now show E-AC-3 JOC
six-channel input becoming stereo PCM, while a separate AAC channel initializes six-channel PCM.
A narrowly scoped decoder-routing candidate is built for a same-stream device comparison.
No commit or release was made.

Issue: <https://github.com/NoXqc/VesperTV/issues/9> (`corporate-gadfly`, 2026-11-21). Fire TV
Stick 4K (1st gen), Fire OS 6.7.1.1. Every channel in VesperTV shows **Stereo**; the same URL
(`VIP: TNT SPORTS ULTIMATE`) showed 6-channel audio in a different IPTV player on the *same*
Fire Stick, and in `mpv` on a macOS laptop. Baseline: `4aad7d8e`, 1.0.72+928.

Additional user-provided evidence: VesperTV's macOS Data pool screenshot shows the channel as
`E-AC-3 · 5.1 · 48 kHz · 640 kbps`. This confirms that VesperTV can identify this stream as
5.1 on macOS and makes an Android-specific track-selection, decoding, or output-path difference
more likely. It does not show what the Fire TV or its HDMI sink rendered.

The ARMv7 diagnostic build logged separate TV channels on the connected AFTMM, not the
same stream tested with different decoders:

| Input | Decoder | Initialized output |
|---|---|---|
| E-AC-3 JOC, 6 channels, 48 kHz | `OMX.dolby.eac3.decoder` | PCM16, 2 channels (`0xc`) |
| AAC, 6 channels, 48 kHz | `OMX.google.aac.decoder` | PCM16, 6 channels (`0xfc`) |
| AAC, 2 channels, 44.1 kHz | `OMX.google.aac.decoder` | PCM16, 2 channels (`0xc`) |

All three used passthrough=false, offload=false, tunneling=false. Replaying the `VesperAudio`
trace through an assertion of E-AC-3 six-channel preservation fails. The separate AAC
six-channel source demonstrates that six-channel PCM initialization works on this device;
it is not a same-stream decoder A/B test. This rules out a universal stereo-only PCM sink restriction and
confirms that the Dolby decoding/rendering path supplies a stereo Android track for this
stream. It does not yet distinguish decoder downmixing from renderer channel mapping.
Media3 1.9.2's `MediaCodecAudioRenderer.getMediaFormat` already requests the input channel
count; `onOutputFormatChanged` constructs the sink input from the codec's output format.
The next probe should inspect that decoded format/channel map, or compare the same E-AC-3
stream with a narrowly scoped alternative decoder. Do not globally prefer FFmpeg: that
previously caused AAC/Multiview regressions.

The user reports that the receiver remains in stereo even for the AAC six-channel
AudioTrack. The connection is Fire Stick -> TV -> HDMI ARC/eARC -> receiver; whether the
return link is actually ARC or eARC is not yet established. Android AudioTrack initialization
therefore cannot be treated as proof of discrete six-channel sound at the receiver. Ordinary
ARC cannot carry multichannel linear PCM; eARC can, subject to the TV's supported formats and
output settings. Codec downmixing and the HDMI return path must be investigated separately.

## Verdict

The report is **credible and consistent with VesperTV's own current, deliberate audio
architecture** — it is not obviously a stream problem (the user cross-checked the same URL in
two other players). VesperTV already ships the building blocks for 5.1/Atmos audio
(software+hardware AC-3/E-AC-3/DTS decode, an Atmos detector, and an opt-in "Surround
passthrough" HDMI-bitstream toggle), but that toggle **defaults to off**, applies **only to the
main/full-screen player** (never Multiview), and even when on, actual multichannel output is
still bounded by what Android and the connected HDMI sink negotiate — no app can force 6-channel
output irrespective of the device. The single lowest-risk, already-shipped thing to try on the
reporter's box is **Settings → Interface → Audio → "Surround passthrough (Dolby Atmos)"**; beyond
that, a real fix needs on-device diagnosis (see "What's unresolved" below) before any code change.

## (a) Decoding/playing 5.1 input — supported, independent of the toggle

VesperTV vendors a patched `video_player_android` 2.12.2 (`third_party/video_player_android`,
wired through `dependency_overrides` in `pubspec.yaml:149-150`) specifically to decode AC-3/E-AC-3
5.1 on boxes with no licensed hardware Dolby decoder, via the Jellyfin media3 FFmpeg extension in
`EXTENSION_RENDERER_MODE_ON` (`CLAUDE.md:148-154`, `git log` `7851fa91` "Fix Android AC3/E-AC3
silent audio"). This decode path is unrelated to the passthrough setting: it runs whether
passthrough is on or off, and simply turns a 5.1/Atmos elementary stream into PCM.

`MatroskaAtmos.java` (`third_party/video_player_android/.../MatroskaAtmos.java:1-45`) further
detects Dolby Atmos (E-AC-3 JOC / TrueHD 16-channel) inside Matroska containers for Media Hub,
confirming 5.1/Atmos *detection and decode* is an active, maintained area of the codebase.

## (b) Pass-through of multichannel/Atmos audio to HDMI — exists, off by default, main player only

`AudioPassthrough.java` (full file; `third_party/video_player_android/.../AudioPassthrough.java`)
exposes a `MethodChannel` (`vespertv/audio`, `setPassthrough`) backing a static flag read once per
player creation. The main platform-view player's `buildAudioSink`
(`third_party/video_player_android/.../platformview/PlatformViewVideoPlayer.java:100-162`) reads
that flag:

```java
final boolean passthrough = AudioPassthrough.isEnabled();
...
if (passthrough) {
  return ... new DefaultAudioSink.Builder(context)...   // gets a real Context
}
return ... new DefaultAudioSink.Builder()...            // no Context — the default, always
```

The comment directly above (lines ~100-123) states the deliberate trade-off: giving
`DefaultAudioSink` a real `Context` lets media3 auto-detect genuine HDMI passthrough capability,
but once AC-3/E-AC-3 becomes passthrough-eligible, `setVolume()` becomes a no-op for that track —
the compressed bitstream goes straight to the receiver — which is "a well-documented ExoPlayer
limitation". Because simultaneous player instances (Multiview, mini-player) need working
per-instance volume/mute, every `AudioSink` is built **without** a `Context` by default, and the
opt-in toggle restores the `Context` **only for the main/full-screen player**; texture players
(Multiview, Compatibility video) "never pass through" (same file, and
`lib/services/desktop_stream_setup.dart:171`, `lib/screens/multiview_screen.dart:125`).

Dart side: `lib/services/app_preferences.dart:246-304` ("Off since 2026-10-07 for every player
because passthrough audio ignores the app's volume"), `lib/services/storage_service.dart:732-735`
(`vesper_audio_passthrough`, default `false`), `lib/utils/constants.dart:366-368`,
`lib/services/playback_service.dart:1220-1239` (invokes `setPassthrough`), and the user-facing
toggle in `lib/screens/settings/settings_catalog.dart:833-840`:

> "Sends Dolby Digital, Dolby Atmos and DTS sound to your soundbar or receiver untouched (HDMI
> passthrough), so it can play Atmos. Off: this device turns that sound into plain stereo/5.1
> first, so Atmos is lost. … Multiview always uses plain sound…"

Git history: the context-less-by-default fix landed `24f7bcdf` (2026-10-07, "fix audio bleed
without cutting AC3"); the opt-in toggle landed `cb254d5a` (2026-10-22, "Settings > Interface >
Audio: opt-in surround passthrough (Dolby Atmos)"). **Neither change is called out in any
`dev-notes/releases/*.md` file** (checked all of them; `1.0.57`–`1.0.59` only mention the
**ATMOS badge**, not the passthrough toggle) — it shipped silently inside a numbered build between
1.0.34 and 1.0.72, so an issue reporter has no way to know the setting exists from the release
notes. `CLAUDE.md:202-205` still labels `AudioPassthrough.java` "Unreleased" even though it is
present and wired up in the current `HEAD` (1.0.72+928) tree — that note itself appears stale,
not evidence the feature is actually absent from shipped builds.

Upstream confirmation that this Context-gating is real media3 behavior, not a VesperTV-only
assumption (`androidx/media`, the canonical AndroidX Media3/ExoPlayer repo):

- `DefaultAudioSink.java`, `Builder()` (no-arg, deprecated) vs `Builder(Context)`: the no-arg
  builder's Javadoc states verbatim — "These audio capabilities are only used in the absence of a
  Context. In the case when the Context is null and the audioCapabilities is not set … **the
  default capabilities (no encoded audio passthrough support) should be assumed.**"
- `AudioCapabilities.java`: Media3 1.9.2 defines a default PCM profile with a maximum of 10
  channels and no encoded surround formats. This means the context-less sink excludes encoded
  passthrough but is not capped at stereo PCM.
- `AudioTrackAudioOutputProvider.java`: a context-bound `AudioCapabilitiesReceiver` (which
  registers for `AudioManager.ACTION_HDMI_AUDIO_PLUG` and reads `AudioDeviceInfo`/EDID via
  `SpeakerLayoutUtil`) is only constructed `if (... && context != null)` — this is the exact
  mechanism VesperTV's comment is describing.
- Amazon's own Fire TV docs independently corroborate that encoded/multichannel capability is
  sink-dependent and must be re-queried on HDMI reconnect:
  <https://developer.amazon.com/docs/fire-tv/handling-hdmi-events.html> — "It is possible that
  playback was started after the Fire TV was connected to a Dolby Atmos capable Audio-video
  receiver, and the HDMI cable was unplugged … and then reconnected to a PCM-only capable
  television", and <https://developer.amazon.com/docs/fire-tv/media-players.html>, which
  recommends Fire TV apps use "the Amazon port of ExoPlayer" (VesperTV uses the Google/AndroidX
  one via `video_player_android`, not Amazon's fork — a possible but unconfirmed source of
  device-specific quirks on Fire TV specifically).

**Important nuance found in the app's own text:** the in-app help string says passthrough *off*
still produces "plain stereo**/5.1**" (not only stereo) — i.e., VesperTV's authors' own stated
expectation is that plain (non-passthrough) decoded 5.1 PCM already works in the default
configuration for at least some sources, and that the passthrough toggle is mainly about
preserving the *Atmos/DTS object/bitstream* rather than about unlocking 6-channel PCM output at
all. This matters for root-causing the Stereo-only report below.

## (c) App-generated / upmixed 5.1 output — not implemented, not a reasonable fix for this report

VesperTV has no code path that synthesizes surround channels from a stereo source (no "upmix"
logic was found anywhere in `lib/` or `third_party/`). Android does let an app construct an
`AudioTrack`/`AudioFormat` with a 5.1 channel mask and write manually up-mixed PCM into it
(`CHANNEL_OUT_5POINT1` exists on
<https://developer.android.com/reference/android/media/AudioFormat>), but whether that is
actually rendered as discrete 5.1, vs. downmixed again by the OS/HAL back to what the sink
reports supporting, is still gated by the same sink-capability negotiation described in (d) below.
This would be a large, speculative, unsupported-by-upstream feature to build for a problem the
reporter did not actually describe (their complaint is that a *genuine* 5.1 source isn't preserved,
not that stereo sources lack synthetic surround) — out of scope.

## (d) Can an app guarantee 6-channel output? — No, bounded by device/EDID negotiation

- `AudioTrack.isDirectPlaybackSupported(AudioFormat, AudioAttributes)`
  (<https://developer.android.com/reference/android/media/AudioTrack>, deprecated API 33+ in
  favor of `AudioManager#getDirectPlaybackSupport`) — Android's own doc: "Checking for direct
  support can help the app select the representation of audio content that most closely matches
  **the capabilities of the device and peripherals (e.g. A/V receiver) connected to it**." This is
  a query API, not a force/override API.
- Every fallback branch in media3's `SpeakerLayoutUtil.getLoudspeakerLayoutChannelMasks()`
  terminates in stereo ("last resort") when EDID/Short-Audio-Descriptor data is unavailable or
  unreadable — there is no "force N channels" parameter in its public surface.
- The one real override that exists is **OS-level, not app-level**: `AudioCapabilities.java`
  reads `Settings.Global` keys `use_external_surround_sound_flag` /
  `external_surround_sound_enabled` (the Android TV system "Surround sound" setting some
  boxes expose in Display & Sound) to force-enable AC-3/E-AC-3/DTS encodings regardless of EDID.
  A third-party app cannot reliably set this without system/device-owner privileges; a user *can*
  on devices that expose it (worth asking the reporter to check Fire OS's own Display & Sound /
  surround-sound system setting, separate from VesperTV's own toggle).
- No canonical "Supporting Surround Sound Playback" doc page could be found on
  `developer.android.com` or `source.android.com` (multiple guessed URLs 404'd) — flagged as
  unverified rather than asserted; the conclusion above rests on the source-code and reference-doc
  citations, not on a single prose spec page.

## What's unresolved (needs device evidence)

The in-app **Stereo** label comes from the decoded `Format.channelCount` reported by the native
player (`third_party/video_player_android/.../VideoPlayer.java:582`,
`lib/widgets/data_pool_card.dart:219-224` maps `6 → '5.1'`, `2 → 'Stereo'`), i.e. the selected
input `Format.channelCount`, not a measurement of what the receiver rendered. Two externally
verified players show 6 channels for the same URL, but the issue report does not include VesperTV's
selected format, decoder, or initialized Android `AudioTrack` configuration. Source reading alone
cannot determine where this specific stream becomes two-channel:
- The selected input track might report two channels, or a decoder may output fewer channels than
  advertised. Media3 1.9.2 supports decoding multichannel PCM in the current passthrough-off sink,
  so a simple stereo sink cap is not the explanation.
- It could be specific to this Fire TV Stick 4K (1st gen) / Fire OS 6.7.1.1 combination (older
  Mediatek/Amazon silicon, 1st-gen 4K stick), independent of VesperTV's own architecture.
- The reporter should be asked to: (1) try **Settings → Interface → Audio → Surround passthrough
  (Dolby Atmos)** and reload the channel — this is already shipped and is the cheapest test; (2)
  confirm whether they're on the main full-screen player (not Multiview, which never changes
  behavior); (3) check Fire OS's own system-level surround-sound setting if present; (4) report
  back whether the Data pool / stream-info badge still reads "Stereo" with passthrough on.

## Feasibility / scope of any reasonable implementation

- **No forced output-channel change is justified.** The current passthrough-off sink supports
  multichannel PCM, and the existing Stereo/5.1 label describes the selected input format rather
  than the receiver's measured output.
- A diagnostic `VesperAudio` log records the selected input format, decoder identity, and
  initialized Android `AudioTrack` channel mask, without URLs, channel names, or credentials.
  Read it with `adb logcat -s VesperAudio`. Input=2 points toward the source/track selection;
  input=6/output=2 points toward decoder output configuration; input=6/output=6 means Android
  created a six-channel track but does not prove what the HDMI receiver rendered.
- The diagnostic APK is `build/app/outputs/flutter-apk/app-debug.apk` (`com.nox.nox_iptv.debug`,
  ARMv7). It installs alongside the production app and does not replace its data.
- Enabling passthrough by default, or extending it to Multiview, is **not** a safe small change:
  it was deliberately scoped to the main player only because of the documented `setVolume()`
  no-op/audio-bleed regression (`24f7bcdf`, `2c50dc1a`) — any change here needs to preserve that
  constraint.
- A release-notes mention of the existing "Surround passthrough (Dolby Atmos)" setting (it has
  none today, per the grep above) would at least make the already-shipped, lowest-risk fix
  discoverable to users hitting this exact report.

## Candidate build after device logs

`FireTvAudioDecoderSelector` excludes only `OMX.dolby.eac3.decoder`, only on Amazon AFTMM
running Android API 25, only for E-AC-3/JOC with passthrough off. The existing FFmpeg renderer
can then decode the stream to PCM when no other platform decoder remains. AAC, AC-3, video,
other models/Android versions, secure/tunneled queries and passthrough retain stock selection.
The workaround requires FFmpeg support for the format; if unavailable, it logs a warning and
keeps the existing decoder. It is wired into both player factories because Compatibility video
and Multiview use the texture factory. Multiview retains PCM volume/mute; the next candidate
extends opt-in passthrough to the main Compatibility player.

The selector regressions failed before filtering was implemented and pass afterward, including
guard and alternative-decoder ordering cases. They test routing, not the vendor decoder's real
output: Robolectric cannot reproduce the Fire TV's Dolby decoder or HDMI return link.
The original same-stream device comparison remains required before claiming a fix.

Candidate APK: `build/app/outputs/flutter-apk/app-debug.apk`, package
`com.nox.nox_iptv.debug`, version `1.0.72-audio-test+929`, with ARMv7 Flutter and FFmpeg libraries.
Signature verification passes. SHA-256:
`fe579f958d0861f617ca64a3b1e26b6ede4ebbce0b1d12534e5bd7f5f3f43452`.
This updated the prior side-by-side debug app, not the production app. The user installed and
tested it; the results follow below.

For the next comparison, play the exact E-AC-3 channel that previously logged input=6/output=2,
with passthrough still off. `VesperAudio` should show the skipped Dolby decoder, an FFmpeg
decoder, and PCM output=6. Also check audible sound, volume/mute and an AAC channel.
Receiver stereo over ordinary ARC may remain even if PCM output=6; that is a separate limit.
Passthrough-on playback should retain the existing encoded-output path, but requires device
testing with the TV/receiver's supported formats and settings.

The user's +929 test confirms the candidate selects `ffmpegLavc60.3.100-eac3` for the
E-AC-3 JOC six-channel input and initializes six-channel PCM16 (`0xfc`, 48 kHz).
The receiver still indicates stereo. The decoder-routing change therefore resolves the
observed Android track downmix, but does not establish end-to-end surround playback.
The TV/ARC/eARC path and receiver settings remain unverified. A direct Fire Stick ->
receiver HDMI comparison would remove the TV's audio return path from the test.

The subsequent passthrough-on trace still skips the Dolby decoder and outputs PCM16.
The diagnostic's `passthrough` field reads the global requested setting, not the actual sink
capability. The texture factory deliberately constructs a PCM-only sink and a selector with
passthrough=false regardless of that setting. Compatibility video is default-on on Android 7
and older, matching this API25 device. This is consistent with the reported trace; confirm the
active video mode before testing encoded output. Do not enable passthrough for all texture
players: Multiview depends on reliable per-player PCM volume/mute.

## Compatibility passthrough candidate (+930)

The user approved extending the existing opt-in passthrough setting to the main Compatibility
player. `AndroidVideoPlayerOptions.allowEncodedAudio` carries per-player permission through the
typed Pigeon creation message. Main `streamController` calls permit it; Multiview explicitly
denies it. Unmarked texture callers remain PCM-only, and native tile creation denies it as an
additional guard. Platform-view behavior and video composition defaults are unchanged.

The texture factory now uses a context-bound sink only when both permission and the global
setting are on. Its decoder selector uses that same captured effective policy. Thus enabling
passthrough no longer leaves Compatibility video silently on the PCM-only/FFmpeg routing path.
Capability detection may still choose PCM if encoded output is unsupported.

`VesperAudio` distinguishes `player=texture/platform`, `requestedPassthrough`, and
`effectivePassthrough`. The effective flag describes the sink's permission to negotiate encoded
output, not proof of bitstream playback; the initialized output's `encoding` is the evidence.
PCM16 is 2; E-AC-3 is 6 and E-AC-3 JOC is 18.

The existing full-screen-to-Multiview handover must not retain a passthrough-capable sink:
the native per-player query blocks that handover, so the normal stop/reconnect path creates a
PCM-only tile. No global setting is changed. An already PCM-only player can still be handed over.

Regressions went red for lost per-texture permission and for the actual texture factory choosing
the no-context sink when both permission and setting were on. They pass with the fix, including
all four permission/setting combinations. Dart tests cover creation-message serialization,
preservation of existing options, and the Multiview handover guard. Existing targeted main and
texture player tests and Multiview tests pass; Flutter analyze remains at 16 info issues.
These checks do not simulate the Fire TV's codec or HDMI receiver.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, ARMv7,
`com.nox.nox_iptv.debug`, `1.0.72-audio-test+930`. Built with Java 21 and
`cd android && ./gradlew assembleDebug -Ptarget-platform=android-arm`.
Version, debug signature and ARMv7 Flutter/FFmpeg libraries verified. SHA-256:
`e733a707963d2e82a3af83217e299ae2865b069f53813354270cbf6a8f7f2c18`.
Not installed by the agent. No production app replacement, commit, push or release.

The user's +930 physical test confirms six-channel receiver output with passthrough enabled:

```text
player=texture requestedPassthrough=true effectivePassthrough=true
input mime=audio/eac3-joc codecs=null channels=6 sampleRate=48000
output channels=6 channelMask=0xfc encoding=6 sampleRate=48000 offload=false tunneling=false
```

The user reports the receiver switched to six channels on the same connection.
`encoding=6` confirms encoded E-AC-3 rather than PCM16. The hidden, default-on Compatibility
path ignoring the passthrough toggle was the confirmed application-side blocker for this
E-AC-3 receiver symptom. This establishes surround playback, not Atmos object rendering.
It does not establish six-channel AAC/PCM delivery over the TV's audio return link.
Physical stereo/six-channel AAC and Multiview audio switching/mute checks remain outstanding;
automated routing, sink and handover regressions pass.

## Diagnostic cleanup

Cleanup after the successful +930 device test: temporary `VesperAudio` input, decoder,
output and player-mode logs, the routine decoder-routing log, and the log-only test were
removed. The FFmpeg-unavailable warning remains as operational failure reporting.
The passthrough fix, per-player handover query and behavioral regressions remain intact.
The existing +930 APK still contains diagnostics; no replacement APK was built for cleanup.

## Passthrough-only comparison (+932)

This candidate removes the AFTMM decoder selector and its tests. Both factories use stock
Media3 decoder selection again, with the existing FFmpeg extension still available. The
Compatibility passthrough fix and Multiview mute protection are unchanged. The user
confirmed that the receiver still switched to six channels on +932 with passthrough
enabled. The decoder workaround is not needed for that result. With passthrough off,
the stock Dolby decoder may again produce stereo PCM on this Fire Stick.

## Sources

- Issue: <https://github.com/NoXqc/VesperTV/issues/9>
- Repo (baseline `4aad7d8e`, 1.0.72+928): `third_party/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/AudioPassthrough.java`,
  `.../platformview/PlatformViewVideoPlayer.java:80-162`, `.../MatroskaAtmos.java:1-45`,
  `.../VideoPlayer.java:582`; `lib/services/app_preferences.dart:246-304`,
  `lib/services/storage_service.dart:732-735`, `lib/services/playback_service.dart:1220-1239`,
  `lib/utils/constants.dart:366-368`, `lib/screens/settings/settings_catalog.dart:825-840`,
  `lib/widgets/data_pool_card.dart:219-224`, `lib/services/desktop_stream_setup.dart:171`,
  `lib/screens/multiview_screen.dart:125`, `pubspec.yaml:46-150`, `CLAUDE.md:148-216`.
- Git: `7851fa91`, `24f7bcdf` (2026-10-07), `cb254d5a` (2026-10-22), `2c50dc1a` (2026-11-05);
  `dev-notes/releases/1.0.57.md`–`1.0.72.md` (checked for any passthrough mention — none besides
  the unrelated ATMOS badge in `1.0.57`–`1.0.59`).
- AndroidX Media3/ExoPlayer (`androidx/media` v1.9.2, matching the plugin dependency):
  `libraries/exoplayer/src/main/java/androidx/media3/exoplayer/audio/AudioCapabilities.java`,
  `DefaultAudioSink.java`, `AudioTrackAudioOutputProvider.java`, `SpeakerLayoutUtil.java`,
  `MediaCodecAudioRenderer.java`.
- Android reference docs: <https://developer.android.com/reference/android/media/AudioTrack>,
  <https://developer.android.com/reference/android/media/AudioFormat>.
- Fire TV developer docs: <https://developer.amazon.com/docs/fire-tv/media-players.html>,
  <https://developer.amazon.com/docs/fire-tv/handling-hdmi-events.html>.
