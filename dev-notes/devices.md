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
  `HoldToActivate`). `input tap X Y` works for touch targets. **The sidebar "Exit App" row is focusable
  at the bottom — never press Select there by accident.**
- Don't `adb install` when the owner says not to (they sometimes test from a separate box).
- The owner sets the Formuler's theme to **Dark / Gold** on purpose; leave it unless asked.
