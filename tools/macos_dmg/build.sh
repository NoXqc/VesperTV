#!/usr/bin/env bash
# Builds build/dmg/VesperTV-<version>-macos.dmg from the Release app:
# black + gold background, drag-to-Applications layout, gold volume icon.
# Unsigned (no Developer ID yet), see dev-notes/macos-desktop.md.
#
# Uses create-dmg (brew install create-dmg): it lays the window out through
# Finder (AppleScript), so the Finder of this macOS writes the layout itself.
# dmgbuild writes .DS_Store directly, and macOS 26 Finder ignored its
# background. Finder needs to be scriptable: the first run may ask to allow
# Terminal to control Finder.
#
# Usage, from the repo root (after `flutter build macos --release`):
#   tools/macos_dmg/build.sh [path/to/VesperTV.app]
# Needs Python 3 (a private venv with Pillow is made in build/).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
app="${1:-build/macos/Build/Products/Release/VesperTV.app}"
[ -d "$app" ] || { echo "No app at $app: run flutter build macos --release" >&2; exit 1; }
command -v create-dmg >/dev/null || { echo "Needs create-dmg: brew install create-dmg" >&2; exit 1; }

version="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
venv="build/.dmg-venv"
if [ ! -x "$venv/bin/python" ] || ! "$venv/bin/python" -c 'import PIL' 2>/dev/null; then
  python3 -m venv "$venv"
  "$venv/bin/pip" install -q --upgrade pip
  "$venv/bin/pip" install -q pillow
fi

# Background: 1x + @2x PNGs combined into one HiDPI TIFF.
assets="build/dmg/assets"
"$venv/bin/python" tools/macos_dmg/make_background.py "$assets"
tiffutil -cathidpicheck "$assets/background.png" "$assets/background@2x.png" \
  -out "$assets/background.tiff" >/dev/null

# create-dmg copies the whole source folder: give it a folder with only the app.
src="build/dmg/src"
rm -rf "$src"
mkdir -p "$src"
ditto "$app" "$src/VesperTV.app"

# Window size and icon positions must match make_background.py.
out="build/dmg/VesperTV-$version-macos.dmg"
rm -f "$out"
create-dmg \
  --volname "VesperTV $version" \
  --volicon "$src/VesperTV.app/Contents/Resources/AppIcon.icns" \
  --background "$assets/background.tiff" \
  --window-pos 200 160 \
  --window-size 660 400 \
  --icon-size 112 \
  --text-size 13 \
  --icon "VesperTV.app" 170 228 \
  --hide-extension "VesperTV.app" \
  --app-drop-link 490 228 \
  --no-internet-enable \
  "$out" "$src" >/dev/null
rm -rf "$src"
hdiutil verify "$out" >/dev/null
echo "$out"
