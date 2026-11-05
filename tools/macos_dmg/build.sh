#!/usr/bin/env bash
# Builds build/dmg/VesperTV-<version>-macos.dmg from the Release app:
# black + gold background, drag-to-Applications layout, gold volume icon.
# Unsigned (no Developer ID yet), see dev-notes/macos-desktop.md.
#
# Usage, from the repo root (after `flutter build macos --release`):
#   tools/macos_dmg/build.sh [path/to/VesperTV.app]
# Needs Python 3 (a private venv with Pillow + dmgbuild is made in build/).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
app="${1:-build/macos/Build/Products/Release/VesperTV.app}"
[ -d "$app" ] || { echo "No app at $app: run flutter build macos --release" >&2; exit 1; }

version="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"
venv="build/.dmg-venv"
if [ ! -x "$venv/bin/dmgbuild" ]; then
  python3 -m venv "$venv"
  "$venv/bin/pip" install -q --upgrade pip
  "$venv/bin/pip" install -q pillow dmgbuild
fi

assets="build/dmg/assets"
"$venv/bin/python" tools/macos_dmg/make_background.py "$assets"

out="build/dmg/VesperTV-$version-macos.dmg"
rm -f "$out"
"$venv/bin/dmgbuild" -s tools/macos_dmg/settings.py \
  -D app="$app" -D assets="$assets" "VesperTV $version" "$out"
hdiutil verify "$out" >/dev/null
echo "$out"
