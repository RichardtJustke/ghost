#!/usr/bin/env bash

# Optional, opt-in layer on top of the regular serpantinum shell install.
# Installs a full personal desktop setup: GPU/bluetooth drivers, essential
# tools, dev tools, apps and gaming packages. Off by default (OPT_PERSONAL_SETUP),
# enabled from the installer menu. Never runs for someone who doesn't ask for it.

PERSONAL_ESSENTIALS_PACMAN=(
    "git" "openssh" "github-cli" "tailscale" "base-devel"
)

PERSONAL_TERMINAL_PACMAN=(
    "btop" "neovim" "obsidian" "discord" "retroarch"
)

PERSONAL_AUDIO_PACMAN=(
    "pwvucontrol" "pipewire-jack"
)

PERSONAL_EDITORS_PACMAN=(
    "code"
)

PERSONAL_DEV_AUR=(
    "visual-studio-code-insiders-bin" "vscodium-bin" "android-studio"
    "arduino-ide-bin" "bun-bin" "ollama" "opencode-bin"
)

PERSONAL_APPS_AUR=(
    "antigravity-bin" "bruno-bin" "dbeaver-ce" "notion-app-electron"
    "waydroid" "zen-browser-bin" "google-chrome" "yazi"
    "jetbrains-toolbox" "notesnook-bin" "onlyoffice-bin" "spotify"
)

PERSONAL_GAMING_AUR=(
    "heroic-games-launcher-bin" "sober" "mcpelauncher-manifest"
    "protonup-qt" "protontricks" "gamemode"
)

PERSONAL_FLATPAK_PKGS=(
    "com.valvesoftware.Steam"
)

# Failures are appended to the shared FAILED_PKGS array (declared in deps.sh)
# so they show up in the installer's completion screen and telemetry.

personal_safe_jobs() {
    local jobs=$(( $(nproc) / 2 ))
    [[ $jobs -lt 1 ]] && jobs=1
    [[ $jobs -gt 4 ]] && jobs=4
    echo "$jobs"
}

personal_install_list() {
    local title="$1"
    shift
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0

    echo -e "\n\e[36m[ INFO ]\e[0m $title"
    local safe_jobs
    safe_jobs=$(personal_safe_jobs)

    for pkg in "${pkgs[@]}"; do
        if pacman -Qq "$pkg" &>/dev/null; then
            echo -e "  \e[2m- $pkg ($(t "installer.personal.already_installed"))\e[0m"
            continue
        fi
        echo -e "  \e[34m::\e[0m $pkg"
        if install_pkg "$pkg" "$safe_jobs"; then
            echo -e "  \e[32m✓\e[0m $pkg"
        else
            echo -e "  \e[31m✗\e[0m $pkg"
            FAILED_PKGS+=("$pkg")
        fi
    done
}

personal_setup_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        sudo pacman -S --needed --noconfirm flatpak >/dev/null 2>&1
    fi
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1

    for pkg in "${PERSONAL_FLATPAK_PKGS[@]}"; do
        if flatpak info "$pkg" &>/dev/null; then
            echo -e "  \e[2m- $pkg (already installed)\e[0m"
            continue
        fi
        echo -e "  \e[34m::\e[0m $pkg (flatpak)"
        if flatpak install -y flathub "$pkg" >/dev/null 2>&1; then
            echo -e "  \e[32m✓\e[0m $pkg"
        else
            echo -e "  \e[31m✗\e[0m $pkg"
            FAILED_PKGS+=("$pkg")
        fi
    done
}

personal_setup_drivers() {
    local init_sys="generic"
    if declare -f detect_init_system >/dev/null; then
        init_sys=$(detect_init_system)
    fi

    local gpu_info
    gpu_info=$(lspci 2>/dev/null | grep -iE "vga|3d|display")

    local driver_pkgs=()
    if echo "$gpu_info" | grep -qi "intel"; then
        driver_pkgs+=("mesa" "vulkan-intel" "intel-media-driver" "intel-gpu-tools" "libva-intel-driver" "lib32-mesa" "lib32-vulkan-intel")
    elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
        driver_pkgs+=("mesa" "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau" "lib32-mesa" "lib32-vulkan-radeon" "lib32-mesa-vdpau")
    elif echo "$gpu_info" | grep -qi "nvidia"; then
        driver_pkgs+=("nvidia" "nvidia-utils" "nvidia-settings" "lib32-nvidia-utils" "cuda")
    fi

    local bt_found=0
    if lsusb 2>/dev/null | grep -qi "bluetooth" || lspci 2>/dev/null | grep -qi "bluetooth"; then
        driver_pkgs+=("bluez" "bluez-utils" "blueman")
        bt_found=1
    fi

    personal_install_list "$(t "installer.personal.drivers")" "${driver_pkgs[@]}"

    if declare -f enable_user_service >/dev/null; then
        enable_user_service "pipewire" "$init_sys"
        enable_user_service "wireplumber" "$init_sys"
    fi
    if [ "$bt_found" -eq 1 ] && declare -f enable_system_service >/dev/null; then
        enable_system_service "bluetooth" "$init_sys"
    fi

    if echo "$gpu_info" | grep -qi "intel"; then
        local va_line='export LIBVA_DRIVER_NAME=iHD'
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
            if [ -f "$rc" ] && ! grep -q "LIBVA_DRIVER_NAME" "$rc"; then
                { echo ""; echo "# Intel VA driver"; echo "$va_line"; } >> "$rc"
            fi
        done
    fi
}

personal_setup_post_install() {
    local init_sys="generic"
    if declare -f detect_init_system >/dev/null; then
        init_sys=$(detect_init_system)
    fi

    if command -v tailscaled &>/dev/null && declare -f enable_system_service >/dev/null; then
        enable_system_service "tailscaled" "$init_sys"
    fi

    if command -v ollama &>/dev/null && declare -f enable_system_service >/dev/null; then
        enable_system_service "ollama" "$init_sys"
    fi

    if command -v waydroid &>/dev/null; then
        sudo waydroid init >/dev/null 2>&1 || true
    fi

    if command -v bun &>/dev/null || [ -d "$HOME/.bun" ]; then
        local bun_line='export BUN_INSTALL="$HOME/.bun" && export PATH="$BUN_INSTALL/bin:$PATH"'
        for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
            if [ -f "$rc" ] && ! grep -q "BUN_INSTALL" "$rc"; then
                { echo ""; echo "# Bun"; echo "$bun_line"; } >> "$rc"
            fi
        done
    fi

    if getent group gamemode >/dev/null 2>&1; then
        sudo usermod -aG gamemode "$USER" >/dev/null 2>&1 || true
    fi

    if pacman -Qq arduino-ide-bin &>/dev/null; then
        sudo usermod -aG uucp "$USER" >/dev/null 2>&1 || true
    fi

    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q >/dev/null 2>&1 || true
    fi
}

install_personal_setup() {
    if [ "$OPT_PERSONAL_SETUP" != true ]; then
        return 0
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.personal.title")"

    if declare -f enable_multilib >/dev/null; then
        enable_multilib
    fi

    personal_setup_drivers
    personal_install_list "$(t "installer.personal.essentials")" "${PERSONAL_ESSENTIALS_PACMAN[@]}"
    personal_install_list "$(t "installer.personal.terminal")" "${PERSONAL_TERMINAL_PACMAN[@]}"
    personal_install_list "$(t "installer.personal.audio")" "${PERSONAL_AUDIO_PACMAN[@]}"
    personal_install_list "$(t "installer.personal.editors")" "${PERSONAL_EDITORS_PACMAN[@]}"
    personal_install_list "$(t "installer.personal.dev")" "${PERSONAL_DEV_AUR[@]}"
    personal_install_list "$(t "installer.personal.apps")" "${PERSONAL_APPS_AUR[@]}"
    personal_install_list "$(t "installer.personal.gaming")" "${PERSONAL_GAMING_AUR[@]}"

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.personal.flatpak")"
    personal_setup_flatpak

    personal_setup_post_install

    if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
        echo -e "\n\e[33m$(t "installer.personal.failed_count" "count=${#FAILED_PKGS[@]}")\e[0m"
        for fp in "${FAILED_PKGS[@]}"; do
            echo -e "  - \e[33m$fp\e[0m"
        done
    else
        echo -e "\n\e[32m$(t "installer.personal.done")\e[0m"
    fi
}
