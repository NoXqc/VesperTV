#!/usr/bin/env bash
# Packs the release Apple TV build (`flutter-tvos build tvos --release
# --no-codesign`, build/tvos/Release-appletvos/Runner.app) into an .ipa for
# sideloading: atvloadly (Windows / Mac / Docker) or Sideloadly signs it with
# an Apple ID for one paired Apple TV. Left unsigned on purpose: those tools
# replace any signature with their own (dev-notes/apple-tv.md, "Sideloading").
#
# Usage (repo root, macOS runner): bash tools/tvos/package_ipa.sh [out-dir]
# No release build = a note and exit 0 (the artifact step then has no file).
set -euo pipefail

out="${1:-out-ipa}"
app="$(find build/tvos -type d -name 'Runner.app' -path '*Release-appletvos*' -prune 2>/dev/null | head -1 || true)"
if [ -z "$app" ]; then
  echo "No release Apple TV build (build/tvos/Release-appletvos/Runner.app): no .ipa."
  exit 0
fi

plist="$app/Info.plist"
read_key() { /usr/libexec/PlistBuddy -c "Print $1" "$plist" 2>/dev/null || echo unknown; }
bundle_id="$(read_key CFBundleIdentifier)"
version="$(read_key CFBundleShortVersionString)"
build="$(read_key CFBundleVersion)"

work="$(mktemp -d)"
mkdir -p "$work/Payload" "$out"
# ditto keeps the framework symlinks and the extension (PlugIns/TopShelf.appex).
ditto "$app" "$work/Payload/Runner.app"
ipa="$PWD/$out/VesperTV-tvOS-$version-$build.ipa"
rm -f "$ipa"
(cd "$work" && zip -qry -X "$ipa" Payload)
rm -rf "$work"

echo "Sideload .ipa: $out/$(basename "$ipa") ($(du -h "$ipa" | cut -f1))"
echo "  bundle $bundle_id, version $version ($build)"
echo "  extensions: $(ls "$app/PlugIns" 2>/dev/null | tr '\n' ' ' || true)"
