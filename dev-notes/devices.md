# Test devices & driving the UI over adb

Read when installing to / screenshotting a real box.

## 7. Test devices (adb over LAN)
- Formuler Z11 Pro MAX `10.0.0.46:5555` — **IP changes** with VPN/network toggles/reboots (often
  `192.168.1.46:5555`). Fire Stick `192.168.1.33:5555` (was `10.0.0.94:5555`). This PC is authorized.
- First connect from a new PC pops an "Allow USB/ADB debugging?" dialog on the TV — accept "always".
- Install with `adb install -r` (GUI installers silently fail on the Formuler):
  ```
  adb connect 192.168.1.46:5555
  adb -s 192.168.1.46:5555 install -r build/app/outputs/flutter-apk/app-release.apk
  adb -s 192.168.1.46:5555 shell am start -n com.nox.nox_iptv/.MainActivity
  ```
  Verify: `adb shell pm path com.nox.nox_iptv` then `adb shell sha256sum <path>` vs local build.
- Formuler restrictions: not rooted, app not debuggable → **no logcat of the app, no `run-as`, no
  access to `Android/data`** (scoped storage). Don't plan on log-file instrumentation there.
- "Crashes" on these boxes are usually **ANRs**: `adb shell dumpsys dropbox --print data_app_anr`
  (and `data_app_crash`); `top -H -b -n 1 -p <pid>` shows busy threads.
- Driving the UI over adb for screenshots: `adb exec-out screencap -p > x.png` (video surfaces show
  **black** in screencaps — that's normal while a stream plays). `input keyevent DPAD_*`/`BACK` work.
  **`input keyevent --longpress` does NOT trigger HoldToActivate; use a touch hold instead:**
  `adb shell input swipe X Y X Y 1800` on the item (pointer long-press is supported on
  `HoldToActivate`). `input tap X Y` works for touch targets. The sidebar's bottom row is "Exit VesperTV" (a full exit; it was "Disable and exit",
  which disabled every playlist, until 2026-11-05).
- Don't `adb install` when the owner says not to (they sometimes test from a separate box).
- The owner sets the Formuler's theme to **Dark / Gold** on purpose; leave it unless asked.

## Homatics Box R 4K Plus (owner, 2026-11-11)
`10.0.0.64:5555` (network debugging). Made by SEI Robotics (model `Box R 4K Plus`, device `YYJ`).
Amlogic S905X4 (`sc2`), 4x Cortex-A55 up to 2.0 GHz, 3.5 GB RAM (above the 2.5 GB BufferBudget cap),
26 GB free. Android TV 14 (UKG3.250803.001.8963, patch 2026-04-05), **32-bit userspace only**
(armeabi-v7a, no arm64 ABI). Licences present: Dolby Vision decoders (dvhe / dvav / dav1, c2.amlogic),
Dolby MS12 (AC3/E-AC3/AC-4) and DTS / DTS-HD / DTS:X: the S905X4-K feature set (the variant letter
itself isn't readable without root). AV1, HEVC, VP9 hardware. Connected to the owner's Sony TV on its eARC / 120 Hz port, HDMI signal format Enhanced (Dolby Vision) (EDID:
DV up to 2160p60, HDR10, HLG, no HDR10+). Resolution set by hand to 4K 59.94 (Automatic picked 1080p), colour space YCbCr 4:2:2 12-bit. Google TV launcher disabled (`pm disable-user`), Projectivy is home; VesperTV Favourite channels row shows there.
Good box for Dolby Vision playback tests (the Formuler has no DV decoder).
Vesper AI is the box's assistant (ASSISTANT role, 2026-11-11): the remote's mic button opens the Vesper panel.
