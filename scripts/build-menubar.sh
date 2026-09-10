#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/macos/MmExtra.swift"
APP_DIR="$ROOT_DIR/macos/build/MmExtra.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
BIN="$MACOS_DIR/mm-extra"
PLIST="$APP_DIR/Contents/Info.plist"

if [[ "$(uname -s)" != 'Darwin' ]]; then
    printf 'mm menubar: build is macOS only (needs AppKit).\n' >&2
    exit 2
fi

if ! command -v swiftc >/dev/null 2>&1; then
    printf 'mm menubar: swiftc not found. Install Xcode Command Line Tools.\n' >&2
    exit 2
fi

if [[ ! -f "$SRC" ]]; then
    printf 'mm menubar: missing %s\n' "$SRC" >&2
    exit 2
fi

mkdir -p "$MACOS_DIR" "$APP_DIR/Contents/Resources"

cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>io.mm.extra</string>
  <key>CFBundleName</key>
  <string>mm</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>mm-extra</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

swiftc -O -parse-as-library -framework AppKit -o "$BIN" "$SRC"
chmod 755 "$BIN"
printf 'Built %s\n' "$APP_DIR"
