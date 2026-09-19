#!/usr/bin/env bash
# Watches this repo's src/ tree and mirrors it into the installed Ghost
# location, so edits made here show up in the live shell without a manual
# `cp -r` / re-install. Personal dev convenience, not part of install.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$REPO_ROOT/src"
DEST_DIR="${GHOST_DEV_SYNC_TARGET:-$HOME/.local/share/serpantinum/src}"

if [ ! -d "$SRC_DIR" ]; then
    echo "error: src dir not found at $SRC_DIR" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"

sync_now() {
    rsync -a --delete "$SRC_DIR/" "$DEST_DIR/"
    echo "[$(date '+%H:%M:%S')] synced $SRC_DIR -> $DEST_DIR"
}

sync_now

inotifywait -mr -q -e modify,create,delete,move,attrib "$SRC_DIR" | while read -r _; do
    # drain any burst of follow-up events (editors fire several per save)
    while read -r -t 0.3 _; do :; done
    sync_now
done
