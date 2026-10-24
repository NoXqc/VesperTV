# Frozen zap frame and spinner (Codex, local +435)

Owner requested a frozen current-channel picture with a small spinning circle in
place of the +434 logo on every transition. No GitHub release authorised.

## Evidence and limits

- +434 owner test: green gone, logo seen between all channel transitions.
- LOG-A44B6U (+433): no solid-green rejection; copies completed 180-224 ms after
  zap on several samples despite intended 80 ms cap. Some source loads were 4-5 s;
  one separate transition failed HTTP 404. No video-surface destruction recorded.
- PixelCopy success is not image validation. Zeroed YUV can appear as dark green,
  below +433's bright-green-only filter. Actual green origin remains unproven.
- A test cannot prove the Formuler's 4K video plane is capturable. If stable
  snapshots are still unusable, the safe logo fallback remains; never claim the
  underlying Realtek decoder or HDMI signal is fixed.

## Implementation

- Formuler exact existing target only: after first frame, wait 250 ms, request a
  720px-max snapshot via PixelCopy Surface overload on a lazy HandlerThread.
  Next snapshot 1.5 s later; one request in flight, one cached bitmap. New zaps
  never wait for a request, callback, image conversion or timer.
- Validate 144 sampled pixels off the UI thread: reject blank/transparent and
  near-uniform green including ~0,135,0. This is a narrow heuristic, not proof
  all corrupted pictures can be detected. False rejection only uses fallback.
- Cache expires after 2.5 s. A generation token discards captures from before a
  zap, detach, hide or disposal. Cache replacement/expiry/clear releases owned
  bitmaps; displayed bitmaps are left to GC after RenderThread stops using them.
- Up to roughly three 720x405 RGBA snapshots at peak (cache, in-flight, displayed),
  about 3.4 MiB for a 16:9 picture. Never saves/exports a frame or logs pixels.
- Stop retrying after three unusable captures on one channel; reset on next zap.
  Only log capture status changes, not every successful periodic capture.
- Display cached frame with centered white indeterminate spinner in fullscreen
  and guide. Spinner shrinks for the preview. Logo + spinner if no usable frame.
  Fast repeated zaps retain the outgoing valid picture until a new frame arrives.
- First-frame/error/timeout/hide/disposal clears cover and spinner. Worker quits
  on plugin disposal. Decoder, HDR, reuse and native surface ownership unchanged.
- Other devices keep the existing per-zap capture, with the spinner added.

API reference: [Android PixelCopy Surface overload](https://developer.android.com/reference/android/view/PixelCopy).

## Verification and acceptance

Native tests cover cache expiry/ownership, blank and dark-green rejection,
textured green preservation, immediate zap, rapid zaps, stale callback rejection,
retry cap, and first-frame clearing. Standard analyze/Flutter tests still required.

Owner acceptance: allow a channel to play briefly, then zap in fullscreen and
with guide open, across 1080p / 4K SDR / HDR; fast repeated CH+/CH-; backing out
while loading. Send log if logo or green persists. Inspect warmCapture and
zapCapture: cached-frame use versus rejected/unavailable capture.
