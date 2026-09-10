#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
INSTALL_DIR="${MM_INSTALL_DIR:-$PREFIX/share/mm}"
BIN_PATH="${MM_BIN_DIR:-$PREFIX/bin}/mm"

rm -f "$BIN_PATH"

if [[ -d "$INSTALL_DIR/.git" ]]; then
    printf 'Left git checkout in place: %s\n' "$INSTALL_DIR"
elif [[ -f "$INSTALL_DIR/bin/mm" && -d "$INSTALL_DIR/lib/mm" ]]; then
    rm -rf "$INSTALL_DIR"
    printf 'Removed %s\n' "$INSTALL_DIR"
elif [[ -e "$INSTALL_DIR" ]]; then
    printf 'Did not remove %s (does not look like an mm install).\n' "$INSTALL_DIR"
fi

printf 'Launcher removed: %s\n' "$BIN_PATH"
printf 'User configuration (~/.config/mm) and logs (~/Library/Logs/mm) were preserved.\n'
printf 'Disable leftover agents with: mm schedule disable daily; mm schedule disable weekly; mm menubar disable\n'
printf '(run that before uninstalling, from the install you are removing.)\n'
