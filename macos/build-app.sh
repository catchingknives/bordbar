#!/bin/zsh
# Builds IceBar.app into dist/. Ad-hoc signed, runs locally.
set -e
cd "$(dirname "$0")"
# Swift 6.4's default build system fails here with "Unknown error parsing property list"
# (Command Line Tools only, no Xcode; 2026-10-27). The native one works.
setopt pipefail
rm -f .build/release/IceBar   # never package a stale binary when the build fails
swift build -c release --build-system native 2>&1 | grep -v "has been deprecated"
APP="dist/IceBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/IceBar "$APP/Contents/MacOS/IceBar"
# LSUIElement: menu bar only, no Dock icon and no app menu.
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>IceBar</string>
    <key>CFBundleDisplayName</key><string>IceBar</string>
    <key>CFBundleIdentifier</key><string>local.icebar</string>
    <key>CFBundleExecutable</key><string>IceBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
echo "Built $APP"
