#!/usr/bin/env bash
# Builds Mpv.xcframework (libmpv as one dynamic framework) for Apple TV from
# MPVKit's prebuilt static libraries (LGPL build), for the tvOS media_kit
# video plugin (third_party/media_kit_video_tvos). dev-notes/apple-tv.md.
#
# media_kit loads libmpv through FFI as "Mpv.framework/Mpv" (iOS layout), but
# media-kit's own libmpv builds have no tvOS. MPVKit ships tvOS slices of
# libmpv and every dependency as static xcframeworks; this links them into one
# dylib per slice (device arm64, simulator arm64) that exports mpv_* only.
#
# macOS + Xcode only (the tvOS GitHub workflow). Usage:
#   tools/tvos/build_mpv_framework.sh <output dir>
# Writes <output dir>/Mpv.xcframework. Downloads are cached in
# $MPV_DOWNLOADS (default: <output dir>/.downloads).
set -euo pipefail

OUT="$(cd "${1:?output dir}" && pwd)"
DL="${MPV_DOWNLOADS:-$OUT/.downloads}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DL"

MPVKIT=https://github.com/mpvkit/MPVKit/releases/download/1.0.0
# MPVKit 1.0.0's Package.swift, product "MPVKit" (LGPL): everything _MPVKit and
# _FFmpeg depend on except Libluajit (macOS only).
URLS=(
  "$MPVKIT/Libmpv.xcframework.zip"
  "$MPVKIT/Libavcodec.xcframework.zip"
  "$MPVKIT/Libavdevice.xcframework.zip"
  "$MPVKIT/Libavfilter.xcframework.zip"
  "$MPVKIT/Libavformat.xcframework.zip"
  "$MPVKIT/Libavutil.xcframework.zip"
  "$MPVKIT/Libswresample.xcframework.zip"
  "$MPVKIT/Libswscale.xcframework.zip"
  https://github.com/mpvkit/openssl-build/releases/download/3.3.5/Libcrypto.xcframework.zip
  https://github.com/mpvkit/openssl-build/releases/download/3.3.5/Libssl.xcframework.zip
  https://github.com/mpvkit/gnutls-build/releases/download/3.8.11/gmp.xcframework.zip
  https://github.com/mpvkit/gnutls-build/releases/download/3.8.11/nettle.xcframework.zip
  https://github.com/mpvkit/gnutls-build/releases/download/3.8.11/hogweed.xcframework.zip
  https://github.com/mpvkit/gnutls-build/releases/download/3.8.11/gnutls.xcframework.zip
  https://github.com/mpvkit/libass-build/releases/download/0.17.5/Libunibreak.xcframework.zip
  https://github.com/mpvkit/libass-build/releases/download/0.17.5/Libfreetype.xcframework.zip
  https://github.com/mpvkit/libass-build/releases/download/0.17.5/Libfribidi.xcframework.zip
  https://github.com/mpvkit/libass-build/releases/download/0.17.5/Libharfbuzz.xcframework.zip
  https://github.com/mpvkit/libass-build/releases/download/0.17.5/Libass.xcframework.zip
  https://github.com/mpvkit/libbluray-build/releases/download/1.4.0/Libbluray.xcframework.zip
  https://github.com/mpvkit/libuavs3d-build/releases/download/1.2.1-fix/Libuavs3d.xcframework.zip
  https://github.com/mpvkit/libdovi-build/releases/download/3.3.2/Libdovi.xcframework.zip
  https://github.com/mpvkit/moltenvk-build/releases/download/1.4.2/MoltenVK.xcframework.zip
  https://github.com/mpvkit/libshaderc-build/releases/download/2025.5.0/Libshaderc_combined.xcframework.zip
  https://github.com/mpvkit/lcms2-build/releases/download/2.17.0/lcms2.xcframework.zip
  https://github.com/mpvkit/libplacebo-build/releases/download/7.360.1/Libplacebo.xcframework.zip
  https://github.com/mpvkit/libdav1d-build/releases/download/1.5.3/Libdav1d.xcframework.zip
  https://github.com/mpvkit/libuchardet-build/releases/download/0.0.8/Libuchardet.xcframework.zip
)

for url in "${URLS[@]}"; do
  zip="$DL/$(basename "$url")"
  [ -s "$zip" ] || curl -fsSL --retry 3 -o "$zip" "$url"
  unzip -q -o "$zip" -d "$WORK/xc"
done

# The static library of one xcframework slice: <slice>/<Name>.framework/<Name>
# or <slice>/<lib>.a.
slice_lib() { # <xcframework> <device|simulator>
  local xc="$1" kind="$2" dir
  for dir in "$xc"/tvos-*; do
    [ -d "$dir" ] || continue
    case "$dir" in
      *simulator*) [ "$kind" = simulator ] || continue ;;
      *) [ "$kind" = device ] || continue ;;
    esac
    local fw
    fw="$(find "$dir" -maxdepth 1 -name '*.framework' | head -1)"
    if [ -n "$fw" ]; then
      echo "$fw/$(basename "$fw" .framework)"
    else
      find "$dir" -maxdepth 1 -name '*.a' | head -1
    fi
    return
  done
}

link_slice() { # <device|simulator>
  local kind="$1" sdk target libmpv=""
  local others=()
  if [ "$kind" = device ]; then
    sdk=appletvos; target=arm64-apple-tvos15.0
  else
    sdk=appletvsimulator; target=arm64-apple-tvos15.0-simulator
  fi
  for xc in "$WORK"/xc/*.xcframework; do
    lib="$(slice_lib "$xc" "$kind")"
    if [ -z "$lib" ]; then
      echo "warning: $(basename "$xc") has no tvOS $kind slice" >&2
      continue
    fi
    case "$(basename "$xc")" in
      Libmpv.xcframework) libmpv="$lib" ;;
      *) others+=("$lib") ;;
    esac
  done
  [ -n "$libmpv" ] || { echo "error: no tvOS $kind libmpv" >&2; exit 1; }

  local fw="$WORK/$kind/Mpv.framework"
  mkdir -p "$fw"
  # -force_load: every mpv_* symbol, even the ones nothing here references.
  # The rest is pulled in only as libmpv needs it. Only mpv_* is exported.
  xcrun -sdk "$sdk" clang -dynamiclib -target "$target" \
    -isysroot "$(xcrun -sdk "$sdk" --show-sdk-path)" \
    -install_name @rpath/Mpv.framework/Mpv \
    -Wl,-headerpad_max_install_names -Wl,-dead_strip \
    -Wl,-force_load,"$libmpv" "${others[@]}" \
    -Wl,-exported_symbol,'_mpv_*' \
    -framework AVFoundation -framework AudioToolbox -framework CoreAudio \
    -framework CoreFoundation -framework CoreGraphics -framework CoreMedia \
    -framework CoreText -framework CoreVideo -framework Foundation \
    -framework IOSurface -framework Metal -framework OpenGLES \
    -framework QuartzCore -framework Security -framework UIKit \
    -framework VideoToolbox \
    -lbz2 -liconv -lexpat -lresolv -lxml2 -lz -lc++ \
    -o "$fw/Mpv"

  local platform=AppleTVOS
  [ "$kind" = simulator ] && platform=AppleTVSimulator
  cat > "$fw/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>Mpv</string>
  <key>CFBundleIdentifier</key><string>app.vespertv.player.Mpv</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Mpv</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>0.41.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>MinimumOSVersion</key><string>15.0</string>
</dict>
</plist>
EOF
  echo "$kind: $(du -h "$fw/Mpv" | cut -f1) $(xcrun nm -gU "$fw/Mpv" | grep -c ' _mpv_') mpv_* symbols"
}

link_slice device
link_slice simulator

rm -rf "$OUT/Mpv.xcframework"
xcodebuild -create-xcframework \
  -framework "$WORK/device/Mpv.framework" \
  -framework "$WORK/simulator/Mpv.framework" \
  -output "$OUT/Mpv.xcframework"
echo "Wrote $OUT/Mpv.xcframework"
