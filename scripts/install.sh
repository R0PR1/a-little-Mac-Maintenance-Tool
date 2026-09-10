#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
INSTALL_DIR="${MM_INSTALL_DIR:-$PREFIX/share/mm}"
BIN_DIR="${MM_BIN_DIR:-$PREFIX/bin}"
LINK_CHECKOUT="${MM_LINK_CHECKOUT:-0}"

mm_die() {
    printf 'mm install: %s\n' "$1" >&2
    exit 2
}

mm_required_files() {
    local root="$1"
    local rel
    for rel in bin/mm lib/mm/output.sh lib/mm/utils.sh VERSION launchd/mm.daily.plist.template; do
        [[ -e "$root/$rel" ]] || return 1
    done
}

mm_write_launcher() {
    local dest="$1"
    local root="$2"
    local quoted_root
    quoted_root="$(printf '%q' "$root")"
    cat > "$dest" <<EOF
#!/usr/bin/env bash
set -euo pipefail
MM_ROOT=${quoted_root}
if [[ ! -f "\$MM_ROOT/lib/mm/output.sh" ]]; then
    printf 'mm: incomplete install at %s\\n' "\$MM_ROOT" >&2
    printf 'Reinstall from a clone with: make install\\n' >&2
    exit 2
fi
exec "\$MM_ROOT/bin/mm" "\$@"
EOF
    chmod 755 "$dest"
}

mm_copy_payload() {
    local dest="$1"
    mkdir -p "$dest/bin" "$dest/lib/mm" "$dest/launchd" "$dest/completions"
    cp "$ROOT_DIR/bin/mm" "$dest/bin/mm"
    cp "$ROOT_DIR/lib/mm/"*.sh "$dest/lib/mm/"
    cp "$ROOT_DIR/launchd/"*.template "$dest/launchd/"
    cp "$ROOT_DIR/VERSION" "$dest/VERSION"
    cp "$ROOT_DIR/completions/_mm" "$dest/completions/_mm"
    chmod 755 "$dest/bin/mm"
}

[[ "$INSTALL_DIR" != "/" && "$INSTALL_DIR" != "$HOME" ]] || mm_die "refusing to install into $INSTALL_DIR"
mm_required_files "$ROOT_DIR" || mm_die "source tree at $ROOT_DIR is incomplete"

mkdir -p "$BIN_DIR"

if [[ "$LINK_CHECKOUT" == "1" ]]; then
    INSTALL_DIR="$ROOT_DIR"
else
    mkdir -p "$INSTALL_DIR"
    mm_copy_payload "$INSTALL_DIR"
fi

mm_required_files "$INSTALL_DIR" || mm_die "payload missing after copy to $INSTALL_DIR"
mm_write_launcher "$BIN_DIR/mm" "$INSTALL_DIR"

if ! "$BIN_DIR/mm" version >/dev/null; then
    mm_die "smoke test failed: $BIN_DIR/mm version"
fi

printf 'Installed mm %s\n' "$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION")"
if [[ "$LINK_CHECKOUT" == "1" ]]; then
    printf 'Launcher: %s -> %s (git checkout)\n' "$BIN_DIR/mm" "$INSTALL_DIR"
else
    printf 'Payload:  %s\n' "$INSTALL_DIR"
    printf 'Launcher: %s\n' "$BIN_DIR/mm"
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        printf 'Add %s to your PATH.\n' "$BIN_DIR"
        ;;
esac
