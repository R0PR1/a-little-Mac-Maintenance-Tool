#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${MM_INSTALL_DIR:-$HOME/.local/share/mm}"
BIN_DIR="${MM_BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' --exclude '.tmp' "$ROOT_DIR/" "$INSTALL_DIR/"
else
    tar -C "$ROOT_DIR" --exclude '.git' --exclude '.tmp' -cf - . | tar -C "$INSTALL_DIR" -xf -
fi

ln -sfn "$INSTALL_DIR/bin/mm" "$BIN_DIR/mm"
chmod 755 "$INSTALL_DIR/bin/mm"

printf 'Installed mm to %s\n' "$INSTALL_DIR"
printf 'Command: %s/mm\n' "$BIN_DIR"
printf 'Ensure %s is in your PATH.\n' "$BIN_DIR"
