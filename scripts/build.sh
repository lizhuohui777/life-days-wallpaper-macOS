#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-}"
[[ "$MODE" == "" || "$MODE" == "--app-only" ]] || { print -u2 'Usage: scripts/build.sh [--app-only]'; exit 2; }
APP="$PWD/dist/人生天数壁纸.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
CACHE="$(mktemp -d "${TMPDIR:-/private/tmp/}daywallpaper-build.XXXXXX")"
trap 'rm -rf "$CACHE"' EXIT
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cp Sources/WallpaperApp.swift "$CACHE/main.swift"
for ARCH in arm64 x86_64; do
  /usr/bin/swiftc -target "$ARCH-apple-macos13.0" -module-cache-path "$CACHE/modules" Sources/Shared.swift "$CACHE/main.swift" -o "$CACHE/app-$ARCH"
done
cp Sources/DayWallpaper.swift "$CACHE/main.swift"
for ARCH in arm64 x86_64; do
  /usr/bin/swiftc -target "$ARCH-apple-macos13.0" -module-cache-path "$CACHE/modules" Sources/Shared.swift "$CACHE/main.swift" -o "$CACHE/worker-$ARCH"
done
/usr/bin/lipo -create "$CACHE/app-arm64" "$CACHE/app-x86_64" -output "$APP/Contents/MacOS/DayWallpaperApp"
/usr/bin/lipo -create "$CACHE/worker-arm64" "$CACHE/worker-x86_64" -output "$APP/Contents/Resources/day-wallpaper"
if [[ -f Resources/background.jpg ]]; then
  cp Resources/background.jpg "$APP/Contents/Resources/background.jpg"
else
  /usr/bin/swift -module-cache-path "$CACHE/modules" scripts/make_example_background.swift "$APP/Contents/Resources/background.jpg"
fi
/usr/bin/swift -module-cache-path "$CACHE/modules" scripts/make_icon.swift "$CACHE/AppIcon.iconset"
/usr/bin/iconutil -c icns "$CACHE/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/DayWallpaperApp" "$APP/Contents/Resources/day-wallpaper"
/usr/bin/codesign --force --sign - "$APP/Contents/Resources/day-wallpaper"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
[[ "$MODE" == "--app-only" ]] && exit 0
mkdir -p "$CACHE/image"
cp -R "$APP" "$CACHE/image/"
cp Resources/使用说明.txt "$CACHE/image/"
cp LICENSE NOTICE "$CACHE/image/"
ln -s /Applications "$CACHE/image/Applications"
/usr/bin/hdiutil create -volname '人生天数壁纸' -srcfolder "$CACHE/image" -ov -format UDZO "dist/人生天数壁纸-$VERSION.dmg"
