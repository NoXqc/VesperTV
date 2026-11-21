#!/usr/bin/env bash
# Apple TV UI tour (tvOS workflow): the app built with
# --dart-define=VESPER_CI_TOUR=true walks its own screens (lib/services/
# ci_tour.dart) and logs "VesperTour: shot <name>" at each stop; this takes
# a screenshot for each one: out/tour-NN-<name>.png. A fresh install (no
# saved data), so the tour seeds its playlist. Also a screenshot every 30 s
# while no stop comes (to see where it got stuck), the whole log in
# out/tour-oslog.log and the app's lines in out/tour-flutter.log.
#   tools/tvos/sim_tour.sh [seconds, default 420]
set -x
limit="${1:-420}"
mkdir -p out
app="$(find build/tvos -type d -name '*.app' -path '*appletvsimulator*' | head -1)"
[ -n "$app" ] || { echo "No simulator .app found"; exit 1; }
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
xcrun simctl uninstall "$udid" "$bundle" 2>/dev/null || true
xcrun simctl install "$udid" "$app"
log=out/tour-oslog.log
: > "$log"
xcrun simctl spawn "$udid" log stream --style compact \
  --predicate 'process == "Runner"' > "$log" 2>&1 &
logpid=$!
sleep 2
xcrun simctl launch --terminate-running-process \
  --stdout="$PWD/out/tour-stdout.log" --stderr="$PWD/out/tour-stderr.log" \
  "$udid" "$bundle"
set +x
n=0
start=$SECONDS
last=$SECONDS
while [ $((SECONDS - start)) -lt "$limit" ]; do
  next="$(grep -o 'VesperTour: shot [A-Za-z0-9_-]*' "$log" | sed -n "$((n + 1))p" | awk '{print $3}')"
  if [ -n "$next" ]; then
    n=$((n + 1))
    xcrun simctl io "$udid" screenshot "out/tour-$(printf %02d $n)-$next.png" >/dev/null 2>&1
    echo "shot $n: $next at $((SECONDS - start)) s"
    last=$SECONDS
    continue
  fi
  grep -q 'VesperTour: done' "$log" && break
  if [ $((SECONDS - last)) -ge 30 ]; then
    xcrun simctl io "$udid" screenshot "out/tour-wait-$((SECONDS - start))s.png" >/dev/null 2>&1
    last=$SECONDS
  fi
  sleep 0.5
done
kill "$logpid" 2>/dev/null || true
grep -h "VesperTour:\|flutter:" "$log" > out/tour-flutter.log || true
find ~/Library/Logs/DiagnosticReports -name 'Runner*' -newer "$app" -exec cp {} out/ \; 2>/dev/null || true
echo "$n screenshots"
exit 0
