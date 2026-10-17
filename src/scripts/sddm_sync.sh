#!/usr/bin/env bash
# Mirrors the current wallpaper, matugen colors and avatar into a directory the
# SDDM theme reads at the login screen. The installer creates that directory
# (owned by the user, world-readable); when it isn't there this is a no-op.

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

DEST="${GHOST_SDDM_DIR:-/var/lib/ghost-sddm}"
[ -d "$DEST" ] && [ -w "$DEST" ] || exit 0

WALLPAPER="$QS_CACHE_DIR/wallpaper/current_wallpaper.png"
COLORS="$QS_STATE_DIR/qs_colors.json"

if [ -f "$WALLPAPER" ] && ! cmp -s "$WALLPAPER" "$DEST/wallpaper.png"; then
    cp -f "$WALLPAPER" "$DEST/wallpaper.png.tmp" && mv -f "$DEST/wallpaper.png.tmp" "$DEST/wallpaper.png"
fi

avatar=""
if [ -f "$QS_SETTINGS" ]; then
    avatar="$(jq -r '.general.avatarPath // empty' "$QS_SETTINGS" 2>/dev/null)"
fi
if [ -n "$avatar" ] && [ -f "$avatar" ]; then
    cmp -s "$avatar" "$DEST/avatar.png" || cp -f "$avatar" "$DEST/avatar.png"
else
    rm -f "$DEST/avatar.png"
fi

if [ -f "$COLORS" ]; then
    jq -r '
        "import QtQuick\n\nItem {\n" +
        "    property color accent: \"\(.blue // "#a8c7fa")\"\n" +
        "    property color base: \"\(.base // "#0b0b0d")\"\n" +
        "    property color surface: \"\(.surface0 // "#1b1b1f")\"\n" +
        "    property color text: \"\(.text // "#ececf0")\"\n" +
        "    property color subtext: \"\(.subtext0 // "#9b9ba5")\"\n" +
        "    property color crust: \"\(.crust // "#0b0b0d")\"\n" +
        "    property color danger: \"\(.red // "#f2a7a7")\"\n" +
        "    property color warn: \"\(.yellow // "#e8c27a")\"\n" +
        "}"
    ' "$COLORS" > "$DEST/Colors.qml.tmp" 2>/dev/null && mv -f "$DEST/Colors.qml.tmp" "$DEST/Colors.qml"
fi

chmod 644 "$DEST"/* 2>/dev/null || true
