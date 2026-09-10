#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${MM_INSTALL_DIR:-$HOME/.local/share/mm}"
BIN_PATH="${MM_BIN_DIR:-$HOME/.local/bin}/mm"

rm -f "$BIN_PATH"
rm -rf "$INSTALL_DIR"
printf 'mm removed. User configuration (~/.config/mm) and logs (~/Library/Logs/mm) were preserved.\n'
printf 'Disable leftover agents with: mm schedule disable daily; mm schedule disable weekly\n'
printf '(run that before uninstalling, from the install you are removing.)\n'
