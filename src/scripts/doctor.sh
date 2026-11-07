#!/usr/bin/env bash
# ghost doctor: checks runtime dependencies, services and fonts, and prints what is missing.
# Exits 1 when a required item is missing, 0 otherwise.

ok()   { printf '  \e[32m✓\e[0m %s\n' "$1"; }
warn() { printf '  \e[33m!\e[0m %s\n' "$1"; }
bad()  { printf '  \e[31m✗\e[0m %s\n' "$1"; MISSING=$((MISSING + 1)); }
MISSING=0

check_cmds() {
    local level="$1"; shift
    local entry cmd desc
    for entry in "$@"; do
        cmd="${entry%%:*}"; desc="${entry#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            ok "$cmd"
        elif [ "$level" = required ]; then
            bad "$cmd — $desc"
        else
            warn "$cmd — $desc"
        fi
    done
}

echo "Required"
check_cmds required \
    "quickshell:runs the shell" \
    "pw-play:sound effects (pipewire)" \
    "wpctl:volume control (wireplumber)" \
    "matugen:wallpaper-based colors" \
    "jq:JSON parsing in scripts" \
    "wl-copy:clipboard (wl-clipboard)" \
    "cliphist:clipboard history" \
    "nmcli:network popup (networkmanager)" \
    "grim:screenshots and lock screen" \
    "slurp:region selection" \
    "fc-scan:font picker (fontconfig)" \
    "python3:idle and focus helpers"

echo
echo "Optional"
check_cmds optional \
    "bluetoothctl:bluetooth popup" \
    "brightnessctl:brightness keys" \
    "playerctl:media controls" \
    "cava:audio visualizer" \
    "easyeffects:equalizer" \
    "gpu-screen-recorder:screen recording" \
    "wf-recorder:screen recording fallback" \
    "satty:screenshot editor" \
    "ddcutil:external monitor brightness" \
    "powerprofilesctl:power profiles" \
    "wtype:dictation typing at the cursor"

echo
echo "Services"
if pgrep -f "wl-paste.*cliphist" >/dev/null 2>&1; then
    ok "clipboard listener (wl-paste --watch cliphist store)"
else
    bad "clipboard listener not running — add 'wl-paste --type text --watch cliphist store' to your compositor autostart"
fi
if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active --quiet pipewire 2>/dev/null; then ok "pipewire"; else bad "pipewire user service is not active"; fi
    if command -v easyeffects >/dev/null 2>&1; then
        if systemctl --user is-active --quiet easyeffects 2>/dev/null || pgrep -x easyeffects >/dev/null; then
            ok "easyeffects"
        else
            warn "easyeffects is installed but not running — equalizer will not work"
        fi
    fi
fi

if [ -n "$GROQ_API_KEY" ] || [ -s "${XDG_CONFIG_HOME:-$HOME/.config}/ghost/groq_key" ]; then
    ok "Groq API key (dictation)"
else
    warn "no Groq API key — dictation needs ~/.config/ghost/groq_key"
fi

echo
echo "Fonts"
if fc-list 2>/dev/null | grep -qi "Iosevka Nerd Font"; then
    ok "Iosevka Nerd Font"
else
    bad "Iosevka Nerd Font not installed — run the installer again or install ttf-iosevka-nerd"
fi

echo
echo "Session"
if [ -n "$WAYLAND_DISPLAY" ]; then ok "Wayland ($XDG_CURRENT_DESKTOP)"; else bad "not running under Wayland"; fi

echo
if [ "$MISSING" -eq 0 ]; then
    printf '\e[32mEverything required is in place.\e[0m\n'
    exit 0
fi
printf '\e[31m%d required item(s) missing.\e[0m\n' "$MISSING"
exit 1
