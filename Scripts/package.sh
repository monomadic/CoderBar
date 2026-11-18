#!/bin/zsh
# Package existing release binaries. Use build.sh to compile and package together.
set -euo pipefail
cd "$(dirname "$0")/.."

OPEN_APP=0
INSTALL_APP=0
for arg in "$@"; do
    case "$arg" in
        --open) OPEN_APP=1 ;;
        --install) INSTALL_APP=1 ;;
        -h|--help)
            echo "Usage: zsh Scripts/package.sh [--install] [--open]"
            echo "Package release binaries into dist/CoderBar.app and a ZIP."
            echo "--install  Copy to /Applications/CoderBar.app (quit CoderBar first)."
            echo "--open     Launch the installed copy with --install, otherwise dist."
            exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done
for binary in coder-bar coder-bar-hook coder-bar-ctl; do
    if [[ ! -x ".build/release/$binary" ]]; then
        echo "Missing release binary: $binary. Run zsh Scripts/build.sh first." >&2
        exit 1
    fi
done
if (( INSTALL_APP )) && pgrep -x coder-bar >/dev/null; then
    echo "Quit CoderBar before installing, then run this command again." >&2
    exit 1
fi

VERSION="${CODERBAR_VERSION:-0.5.5}"
BUILD_NUMBER="${CODERBAR_BUILD_NUMBER:-1}"

if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "Invalid CODERBAR_VERSION: $VERSION (expected MAJOR.MINOR.PATCH)" >&2
    exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ '^[1-9][0-9]*$' ]]; then
    echo "Invalid CODERBAR_BUILD_NUMBER: $BUILD_NUMBER (expected a positive integer)" >&2
    exit 1
fi

DIST=dist
rm -rf "$DIST/CoderBar.app"
mkdir -p "$DIST/CoderBar.app/Contents/MacOS" \
         "$DIST/CoderBar.app/Contents/Resources" \
         "$DIST/CoderBar.app/Contents/Library/LaunchServices" \
         "$DIST/bin"

BIN=.build/release
cp "$BIN/coder-bar" "$DIST/CoderBar.app/Contents/MacOS/"
cp "$BIN/coder-bar-hook" "$BIN/coder-bar-ctl" "$DIST/CoderBar.app/Contents/MacOS/"
mkdir -p "$DIST/bin"
cp "$BIN/coder-bar-hook" "$BIN/coder-bar-ctl" "$DIST/bin/"

cp Resources/ChatGPT.png "$DIST/CoderBar.app/Contents/Resources/ChatGPT.png"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp Resources/AppIcon.icns "$DIST/CoderBar.app/Contents/Resources/AppIcon.icns"

cat > "$DIST/CoderBar.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>coder-bar</string>
	<key>CFBundleIdentifier</key>
	<string>dev.coderbar.app</string>
	<key>CFBundleName</key>
	<string>CoderBar</string>
	<key>CFBundleDisplayName</key>
	<string>CoderBar</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>LSUIElement</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>CoderBar brings your terminal to the front when you click a session or notification.</string>
	<key>NSUserNotificationUsageDescription</key>
	<string>CoderBar shows notifications when an agent needs your attention.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --entitlements "$SCRIPT_DIR/Entitlements.plist" \
    "$DIST/CoderBar.app"
codesign -dv "$DIST/CoderBar.app" 2>&1 | grep -E "Signature|Identifier|Runtime" || true

codesign --verify --deep --strict "$DIST/CoderBar.app"
# Finder custom icons preserve the wrapper silhouette on macOS Tahoe.
# Apply after strict verification: Finder metadata is rejected by --strict,
# but ordinary signature verification still validates the signed bundle.
/usr/bin/osascript -l JavaScript "$SCRIPT_DIR/set-app-icon.js" "$PWD/$DIST/CoderBar.app"
codesign --verify --deep "$DIST/CoderBar.app"
ZIP="$DIST/CoderBar-$VERSION-macos.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$DIST/CoderBar.app" "$ZIP"
echo "Packaged: $DIST/CoderBar.app and $ZIP"

LAUNCH_APP="$PWD/$DIST/CoderBar.app"
if (( INSTALL_APP )); then
    LAUNCH_APP=/Applications/CoderBar.app
    ditto "$DIST/CoderBar.app" "$LAUNCH_APP"
    /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/set-app-icon.js" "$LAUNCH_APP"
    codesign --verify --deep "$LAUNCH_APP"
    touch "$LAUNCH_APP"
    echo "Installed: $LAUNCH_APP"
fi
if (( OPEN_APP )); then
    open "$LAUNCH_APP"
fi
