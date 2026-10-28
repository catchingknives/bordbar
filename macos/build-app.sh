#!/bin/zsh
# Builds Bordbar.app into dist/. Ad-hoc signed, runs locally.
# `--universal` builds for Apple silicon and Intel (for releases); default is this Mac only.
set -e
cd "$(dirname "$0")"
# Swift 6.4's default build system fails here with "Unknown error parsing property list"
# (Command Line Tools only, no Xcode; 2026-10-27). The native one works, but cannot take
# two --arch flags, so a universal build is two builds joined with lipo.
setopt pipefail
triples=("$(uname -m)-apple-macosx14.0")
[[ "$1" == "--universal" ]] && triples=(arm64-apple-macosx14.0 x86_64-apple-macosx14.0)
bins=()
for triple in $triples; do
    bin=".build/${triple%14.0}/release/Bordbar"
    rm -f "$bin"   # never package a stale binary when the build fails
    swift build -c release --build-system native --triple "$triple" 2>&1 | grep -v "has been deprecated"
    bins+=("$bin")
done
APP="dist/Bordbar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
lipo -create -output "$APP/Contents/MacOS/Bordbar" $bins
# LSUIElement: menu bar only, no Dock icon and no app menu.
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Bordbar</string>
    <key>CFBundleDisplayName</key><string>Bordbar</string>
    <key>CFBundleIdentifier</key><string>local.bordbar</string>
    <key>CFBundleExecutable</key><string>Bordbar</string>
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
