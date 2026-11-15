#!/usr/bin/env bash
# Installs a built Apple TV simulator app, launches it, takes screenshots and
# collects its logs (tvOS workflow). dev-notes/apple-tv.md.
#   tools/tvos/sim_run.sh <name> <seconds...>
# Screenshots out/<name>-<s>s.png at each listed second after launch; the
# app's log goes to out/<name>-oslog.log. The simulator (newest Apple TV 4K,
# created if missing) is booted once and its id kept in out/.sim-udid.
set -x
name="$1"; shift
mkdir -p out
app="$(find build/tvos -type d -name '*.app' -path '*appletvsimulator*' | head -1)"
[ -n "$app" ] || { echo "No simulator .app found"; find build -maxdepth 4 -type d; exit 1; }
bundle="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")"
udid="$(cat out/.sim-udid 2>/dev/null || true)"
if [ -z "$udid" ]; then
  udid="$(xcrun simctl list devices available -j | jq -r '
    [.devices | to_entries[] | select(.key | test("tvOS")) | .value[]
     | select(.name | test("Apple TV 4K"))] | last | .udid // empty')"
  if [ -z "$udid" ]; then
    runtime="$(xcrun simctl list runtimes -j | jq -r '[.runtimes[] | select(.platform == "tvOS" and .isAvailable)] | last | .identifier')"
    type="$(xcrun simctl list devicetypes -j | jq -r '[.devicetypes[] | select(.name | test("Apple TV 4K"))] | last | .identifier')"
    udid="$(xcrun simctl create "Apple TV test" "$type" "$runtime")"
  fi
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  echo "$udid" > out/.sim-udid
fi
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
xcrun simctl install "$udid" "$app"
start="$(date -u '+%Y-%m-%d %H:%M:%S')"
xcrun simctl launch --terminate-running-process \
  --stdout="$PWD/out/$name-stdout.log" --stderr="$PWD/out/$name-stderr.log" \
  "$udid" "$bundle"
last=0
for t in "$@"; do
  sleep $((t - last)); last=$t
  xcrun simctl io "$udid" screenshot "out/$name-${t}s.png"
done
xcrun simctl spawn "$udid" launchctl list | grep -i "$bundle" > "out/$name-running.txt" || echo "not running" > "out/$name-running.txt"
xcrun simctl spawn "$udid" log show --start "$start" --style compact \
  --predicate 'process == "Runner"' > "out/$name-oslog.log" || true
grep -h "flutter:" "out/$name-oslog.log" > "out/$name-flutter.log" || true
find ~/Library/Logs/DiagnosticReports -name 'Runner*' -newer "$app" -exec cp {} out/ \; 2>/dev/null || true
exit 0
