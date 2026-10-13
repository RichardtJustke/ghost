#!/usr/bin/env bash

get_compositor_config_dir_name() {
    local comp="$1"
    case "$comp" in
        hyprland) echo "hypr" ;;
        niri) echo "niri" ;;
        sway) echo "sway" ;;
        *) echo "$comp" ;;
    esac
}

backup_compositor_directory() {
    local comp="$1"
    local dir_name
    dir_name=$(get_compositor_config_dir_name "$comp")

    local COMP_DIR="$HOME/.config/$dir_name"
    local BACKUP_BASE="$HOME/.config/${dir_name}_backup"
    local BACKUP_DIR="$BACKUP_BASE/backup_$(date +%Y%m%d_%H%M%S)"

    if [ -d "$COMP_DIR" ] && [ "$(ls -A "$COMP_DIR" 2>/dev/null)" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$COMP_DIR/." "$BACKUP_DIR/" 2>/dev/null || true
    fi
}

backup_compositors() {
    local compositors=("$@")
    for comp in "${compositors[@]}"; do
        backup_compositor_directory "$comp"
    done
}

migrate_legacy() {
    local compositors=("$@")
    pkill -f "settings_watcher.sh" 2>/dev/null || true
    pkill -f "hypr/scripts/quickshell" 2>/dev/null || true

    pm_remove_conflicting_pkg "quickshell-git"

    backup_compositors "${compositors[@]}"

    if [ -f "$HOME/.local/state/imperative-dots-version" ]; then
        mkdir -p "$HOME/.config/hypr_backup"
        mv "$HOME/.local/state/imperative-dots-version" "$HOME/.config/hypr_backup/imperative-dots-version.bak" 2>/dev/null || true
    fi
}

# Installs made before the rename used "serpantinum" for every path, binary
# and state key. Move them over to the "ghost" names so an update keeps the
# user's settings, and leave the old command names as links to the new ones.
migrate_old_names() {
    local old_state="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum"
    local new_state="${XDG_STATE_HOME:-$HOME/.local/state}/ghost"
    local had_old=false

    if command -v serpantinumd &>/dev/null; then
        serpantinumd stop &>/dev/null || true
    fi
    pkill -f "serpantinumd" 2>/dev/null || true
    rm -f /tmp/serpantinumd.pid /tmp/serpantinumd.lock 2>/dev/null || true

    local pair old new
    for pair in \
        "$HOME/.config/serpantinum:$HOME/.config/ghost" \
        "$old_state:$new_state" \
        "$HOME/.local/share/serpantinum:$HOME/.local/share/ghost"; do
        old="${pair%%:*}"
        new="${pair#*:}"
        if [ -d "$old" ] && [ ! -L "$old" ]; then
            had_old=true
            if [ ! -e "$new" ]; then
                mv "$old" "$new"
            else
                rm -rf "$old"
            fi
        fi
    done

    if [ -f "$new_state/version" ]; then
        sed -i 's/^SERPANTINUM_/GHOST_/' "$new_state/version"
        sed -i '/^TELEMETRY_ID=/d; /^ENABLE_TELEMETRY=/d' "$new_state/version"
    fi

    if [ -f "$HOME/.config/ghost/settings.json" ]; then
        sed -i 's#/serpantinum/#/ghost/#g' "$HOME/.config/ghost/settings.json"
    fi

    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/serpantinum-* 2>/dev/null || true

    local bin
    for bin in serpantinum serpantinumd; do
        if [ -L "$HOME/.local/bin/$bin" ] || [ -e "$HOME/.local/bin/$bin" ]; then
            had_old=true
            ln -sfn "$HOME/.local/bin/${bin/serpantinum/ghost}" "$HOME/.local/bin/$bin"
        fi
        if [ -L "/usr/local/bin/$bin" ]; then
            sudo ln -sfn "/usr/local/bin/${bin/serpantinum/ghost}" "/usr/local/bin/$bin" 2>/dev/null || true
        fi
    done

    if [ "$had_old" = true ]; then
        echo "Migrated the previous serpantinum install to the ghost names."
    fi
}
