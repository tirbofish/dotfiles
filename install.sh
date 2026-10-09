#!/bin/sh
# Install this configuration on Arch, Void, Ubuntu, or macOS:
#   curl -fsSL https://raw.githubusercontent.com/tirbofish/dotfiles/main/install.sh | sh
# POSIX bootstrap: when piped (or not under bash), fetch the repository and
# re-run this file with bash on the terminal. Everything after it is bash.
if [ -z "${BASH_VERSION:-}" ] || ! { [ -f "$0" ] && [ -d "$(dirname -- "$0")/hypr" ]; }; then
    set -e
    if [ -f "$0" ] && [ -d "$(dirname -- "$0")/hypr" ]; then
        dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
    else
        [ -t 0 ] || cat >/dev/null # drain the rest of the piped script
        dir="${DOTFILES_DIR:-$HOME/.local/share/tirbofish-dotfiles}"
        if ! command -v git >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1; then
            if command -v xbps-install >/dev/null 2>&1; then sudo xbps-install -Sy git bash
            elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm git bash
            elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y git bash
            else echo "error: install git and bash, then re-run." >&2; exit 1
            fi
        fi
        if [ -d "$dir/.git" ]; then
            git -C "$dir" pull --ff-only
        else
            git clone --depth 1 https://github.com/tirbofish/dotfiles.git "$dir"
        fi
    fi
    if (exec </dev/tty) 2>/dev/null; then
        exec bash "$dir/install.sh" "$@" </dev/tty
    fi
    exec bash "$dir/install.sh" "$@"
fi

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export PATH="$HOME/.local/bin:$PATH"

ASSUME_YES=0
DRY_RUN=0
TERMINAL_ONLY=0
PLATFORM=""
PROFILE=""
BREW=""
YAY=""
BACKUP_ROOT=""
DID_INSTALL=0

# Hardware features, chosen in choose_features (defaults come from detection).
SURFACE=0
NVIDIA=0
BIOMETRIC=0
LAPTOP_POWER=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--terminal-only] [--yes] [--dry-run]
       curl -fsSL https://raw.githubusercontent.com/tirbofish/dotfiles/main/install.sh | sh

Without options, choose the full Hyprland setup or the shared terminal setup
and toggle hardware features (Surface tweaks, NVIDIA, biometric unlock)
interactively. macOS installs only the compatible terminal configuration.
When piped, the repository is cloned to $DOTFILES_DIR
(default ~/.local/share/tirbofish-dotfiles) and linked from there.

  --terminal-only  Skip Linux desktop packages and configuration.
  --yes            Accept default answers.
  --dry-run        Print changes without making them.
  -h, --help       Show this help.
EOF
}

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

run() {
    if (( DRY_RUN )); then
        printf '+'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

ask() {
    local prompt="$1" default="$2" answer=""

    if (( ASSUME_YES )) || [[ ! -t 0 ]]; then
        [[ "$default" == "yes" ]] && return 0
        return 1
    fi

    if [[ "$default" == "yes" ]]; then
        printf '%s [Y/n] ' "$prompt" >&2
    else
        printf '%s [y/N] ' "$prompt" >&2
    fi
    IFS= read -r answer

    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]) return 1 ;;
        "") [[ "$default" == "yes" ]] ;;
        *) warn "Please answer yes or no."; ask "$prompt" "$default" ;;
    esac
}

prompt_default() {
    local prompt="$1" default="$2" answer=""

    if (( ASSUME_YES )) || [[ ! -t 0 ]]; then
        printf '%s' "$default"
        return
    fi

    printf '%s [%s]: ' "$prompt" "$default" >&2
    IFS= read -r answer
    printf '%s' "${answer:-$default}"
}

detect_platform() {
    case "$(uname -s)" in
        Darwin)
            PLATFORM="macos"
            ;;
        Linux)
            [[ -r /etc/os-release ]] || die "Cannot identify this Linux distribution."
            # shellcheck disable=SC1091
            . /etc/os-release
            case "${ID:-}" in
                arch) PLATFORM="arch" ;;
                void) PLATFORM="void" ;;
                ubuntu) PLATFORM="ubuntu" ;;
                *) die "Supported Linux distributions are Arch, Void, and Ubuntu; found ${ID:-unknown}." ;;
            esac
            ;;
        *)
            die "Unsupported operating system: $(uname -s)."
            ;;
    esac
}

choose_profile() {
    if (( TERMINAL_ONLY )); then
        PROFILE="terminal"
    elif [[ "$PLATFORM" == "macos" ]]; then
        PROFILE="macos"
    elif ask "Install the full Hyprland desktop profile?" "yes"; then
        PROFILE="desktop"
    else
        PROFILE="terminal"
    fi
}

has_nvidia_gpu() {
    local dev
    for dev in /sys/bus/pci/devices/*; do
        [[ "$(cat "$dev/vendor" 2>/dev/null)" == 0x10de &&
            "$(cat "$dev/class" 2>/dev/null)" == 0x03* ]] && return 0
    done
    return 1
}

yes_no() {
    if (( $1 )); then printf yes; else printf no; fi
}

choose_features() {
    local is_surface=0 has_battery=0

    [[ "$PROFILE" == "desktop" ]] || return 0
    grep -qs Surface /sys/class/dmi/id/product_name && is_surface=1
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null && has_battery=1

    log "Hardware features"
    ask "Apply Microsoft Surface tweaks (dock modeset workaround, speaker DSP)?" \
        "$(yes_no "$is_surface")" && SURFACE=1
    if has_nvidia_gpu; then
        printf 'An NVIDIA GPU was detected.\n' >&2
        ask "Install the NVIDIA driver and Hyprland's NVIDIA settings?" yes && NVIDIA=1
    else
        ask "No NVIDIA GPU detected. Configure for NVIDIA anyway?" no && NVIDIA=1
    fi
    ask "Enable Biopass face unlock on the lock screen?" no && BIOMETRIC=1
    if [[ "$PLATFORM" != "void" ]]; then
        ask "Install auto-cpufreq for laptop power management?" \
            "$(yes_no "$has_battery")" && LAPTOP_POWER=1
    fi
    log "Surface: $(yes_no "$SURFACE"), NVIDIA: $(yes_no "$NVIDIA"), biometric: $(yes_no "$BIOMETRIC"), auto-cpufreq: $(yes_no "$LAPTOP_POWER")"
}

ensure_yay() {
    local build_dir

    [[ -n "$YAY" ]] && return
    if command -v yay >/dev/null 2>&1; then
        YAY="$(command -v yay)"
        return
    fi
    ask "Install yay to fetch the AUR packages?" "yes" ||
        die "The selected Arch setup needs yay for AUR packages."

    if (( DRY_RUN )); then
        run git clone https://aur.archlinux.org/yay.git /tmp/yay-build
        log "Would build yay with makepkg."
        YAY="yay"
        return
    fi
    build_dir="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"
    if ! (cd "$build_dir/yay" && makepkg -si --noconfirm); then
        rm -rf "$build_dir"
        die "Unable to build yay."
    fi
    rm -rf "$build_dir"
    YAY="$(command -v yay)" || die "yay was installed but is not on PATH."
}

install_arch_aur() {
    local packages=(grimblast-git snappy-switcher brave-origin-bin)

    (( LAPTOP_POWER )) && packages+=(auto-cpufreq)
    (( BIOMETRIC )) && packages+=(biopass-bin)
    ensure_yay
    run "$YAY" -S --needed --noconfirm "${packages[@]}"
}

install_arch() {
    local packages=(
        base-devel git curl zsh kitty starship fastfetch neovim fzf jq fontconfig
    )

    if [[ "$PROFILE" == "desktop" ]]; then
        packages+=(
            hyprland hyprpm hypridle hyprlock hyprpicker hyprpolkitagent quickshell
            awww dunst mako rofi nautilus mpv
            pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber
            pavucontrol pamixer networkmanager bluez bluez-utils blueman
            brightnessctl playerctl grim slurp swappy wl-clipboard libnotify
            python python-pywal khal vdirsyncer polkit polkit-gnome
            xdg-desktop-portal-hyprland kvantum qt6ct thunar xfconf
            zathura zathura-pdf-poppler waybar papirus-icon-theme
            ttf-jetbrains-mono-nerd cava
        )
    fi

    if [[ "$PROFILE" == "desktop" ]] && (( NVIDIA )); then
        packages+=(nvidia-open-dkms nvidia-utils egl-wayland linux-headers)
    fi

    run sudo pacman -Syu --needed --noconfirm "${packages[@]}"
    if [[ "$PROFILE" == "desktop" ]]; then
        install_arch_aur
        # On AC: performance platform profile (firmware ramps fans early) + turbo.
        (( LAPTOP_POWER )) && run sudo install -Dm644 "$ROOT/auto-cpufreq.conf" /etc/auto-cpufreq.conf
    fi
}

enable_void_service() {
    [[ -d "/etc/sv/$1" ]] || return 0
    [[ -e "/var/service/$1" ]] || run sudo ln -s "/etc/sv/$1" /var/service/
}

add_void_hyprland_repo() {
    local arch conf=/etc/xbps.d/hyprland-void.conf

    [[ -f "$conf" ]] && return
    arch="$(xbps-uhelper arch)"
    [[ "$arch" == *-musl ]] || arch="$arch-glibc"
    case "$arch" in
        x86_64-glibc|x86_64-musl|aarch64-glibc|aarch64-musl) ;;
        *) die "No Hyprland packages exist for $arch." ;;
    esac
    ask "Hyprland is not in Void's official repositories. Add the third-party sofijacom/hyprland-void repository?" yes ||
        die "The desktop profile needs Hyprland >= 0.55."
    run sudo sh -c "echo 'repository=https://raw.githubusercontent.com/sofijacom/hyprland-void/repository-$arch' > $conf"
}

install_jetbrains_nerd_font() {
    local destination="$HOME/.local/share/fonts/JetBrainsMonoNerd"

    compgen -G "$destination/*.ttf" >/dev/null && return
    log "Installing JetBrains Mono Nerd Font"
    run mkdir -p "$destination"
    if (( DRY_RUN )); then
        printf '+ curl -fsSL .../JetBrainsMono.tar.xz | tar -xJ -C %q\n' "$destination"
        return
    fi
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz |
        tar -xJ -C "$destination"
    fc-cache -f "$destination"
}

configure_void_session() {
    local conf_d=/etc/pipewire/pipewire.conf.d file

    # PipeWire on runit: load WirePlumber and the Pulse shim from pipewire itself.
    run sudo mkdir -p "$conf_d"
    for file in /usr/share/examples/wireplumber/10-wireplumber.conf \
        /usr/share/examples/pipewire/20-pipewire-pulse.conf; do
        [[ -e "$conf_d/${file##*/}" ]] || run sudo ln -s "$file" "$conf_d/"
    done

    if ask "Enable the dbus, elogind, polkitd, and bluetoothd services?" yes; then
        for file in dbus elogind polkitd bluetoothd; do
            enable_void_service "$file"
        done
    fi
    if [[ ! -e /var/service/NetworkManager ]] &&
        ask "Switch networking to NetworkManager (disables dhcpcd and wpa_supplicant)?" yes; then
        for file in dhcpcd wpa_supplicant; do
            [[ -L "/var/service/$file" ]] && run sudo rm "/var/service/$file"
        done
        enable_void_service NetworkManager
    fi
}

install_void() {
    local nvidia_pkg
    local packages=(
        base-devel git curl zsh kitty starship fastfetch neovim fzf jq fontconfig
        unzip xz
    )

    if [[ "$PROFILE" == "desktop" ]]; then
        add_void_hyprland_repo
        packages+=(
            dbus elogind polkit mesa-dri
            hyprland hypridle hyprlock hyprpicker hyprpolkitagent quickshell
            xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
            awww dunst mako rofi nautilus mpv
            pipewire wireplumber pavucontrol pamixer NetworkManager bluez blueman
            brightnessctl playerctl grim slurp swappy wl-clipboard libnotify
            python3 python3-dbus python3-gobject pywal khal vdirsyncer
            polkit-gnome kvantum qt6ct Thunar xfconf zathura zathura-pdf-poppler
            Waybar papirus-icon-theme nerd-fonts-symbols-ttf cava inotify-tools
        )
        (( BIOMETRIC )) && packages+=(pam-devel)
    fi

    run sudo xbps-install -Syu xbps
    run sudo xbps-install -Syu "${packages[@]}"

    [[ "$PROFILE" == "desktop" ]] || return 0
    if (( NVIDIA )); then
        nvidia_pkg="$(prompt_default "NVIDIA driver package (nvidia: RTX 20/GTX 16 and newer; nvidia580: GTX 10 and older)" nvidia)"
        run sudo xbps-install -Sy void-repo-nonfree
        run sudo xbps-install -Sy linux-headers "$nvidia_pkg"
    fi
    install_jetbrains_nerd_font
    install_grimblast_from_source
    install_snappy_switcher_from_source \
        base-devel pkgconf wayland-protocols wayland-devel cairo-devel pango-devel \
        json-c-devel libxkbcommon-devel glib-devel librsvg-devel
    configure_void_session
}

APT_MISSING=()

install_ubuntu_candidates() {
    local spec candidate chosen
    local specs=("$@")
    local packages=()
    local choices=()

    for spec in "${specs[@]}"; do
        chosen=""
        IFS='|' read -r -a choices <<< "$spec"
        for candidate in "${choices[@]}"; do
            if apt-cache show "$candidate" >/dev/null 2>&1; then
                chosen="$candidate"
                break
            fi
        done

        if [[ -n "$chosen" ]]; then
            packages+=("$chosen")
        else
            APT_MISSING+=("${choices[0]}")
        fi
    done

    if ((${#packages[@]})); then
        run sudo apt-get install -y "${packages[@]}"
    fi
}

install_grimblast_from_source() {
    local destination="$HOME/.local/bin/grimblast"
    local url="https://raw.githubusercontent.com/hyprwm/contrib/3dcbce715ae8b93107fa8632db15bf976862a573/grimblast/grimblast"

    command -v grimblast >/dev/null 2>&1 && return
    log "Installing Grimblast from the Hyprland contrib repository"
    run mkdir -p "$HOME/.local/bin"
    if (( DRY_RUN )); then
        printf '+ curl -fsSL %q -o %q\n' "$url" "$destination"
        printf '+ chmod 755 %q\n' "$destination"
    else
        curl -fsSL "$url" -o "$destination"
        chmod 755 "$destination"
    fi
}

install_snappy_switcher_from_source() {
    local build_dir

    command -v snappy-switcher >/dev/null 2>&1 && return
    log "Building Snappy Switcher for the current user"
    if [[ "$PLATFORM" == "void" ]]; then
        run sudo xbps-install -Sy "$@"
    else
        install_ubuntu_candidates "$@"
    fi

    if (( DRY_RUN )); then
        printf '+ git clone --depth 1 --branch v4.0.0 %q /tmp/snappy-switcher\n' \
            "https://github.com/OpalAayan/snappy-switcher.git"
        printf '+ make -C /tmp/snappy-switcher PREFIX=%q SYSCONFDIR=%q install\n' \
            "$HOME/.local" "$HOME/.local/etc/xdg"
        return
    fi

    build_dir="$(mktemp -d)"
    git clone --depth 1 --branch v4.0.0 \
        https://github.com/OpalAayan/snappy-switcher.git "$build_dir/snappy-switcher"
    if ! (
        cd "$build_dir/snappy-switcher"
        make PREFIX="$HOME/.local" SYSCONFDIR="$HOME/.local/etc/xdg" install
    ); then
        rm -rf "$build_dir"
        die "Unable to build Snappy Switcher."
    fi
    rm -rf "$build_dir"
}

install_ubuntu() {
    local packages=(
        build-essential git curl zsh kitty starship fastfetch neovim fzf jq
        fontconfig unzip
    )

    run sudo apt-get update
    install_ubuntu_candidates "${packages[@]}"

    if [[ "$PROFILE" != "desktop" ]]; then
        return
    fi

    install_ubuntu_candidates \
        hyprland hypridle hyprlock hyprpicker quickshell awww dunst mako rofi \
        nautilus firefox mpv pipewire pipewire-pulse wireplumber pavucontrol pamixer \
        network-manager bluez bluez-tools blueman rfkill upower brightnessctl \
        playerctl grim slurp swappy wl-clipboard libnotify-bin \
        'pywal|python3-pywal' khal vdirsyncer policykit-1 policykit-1-gnome \
        xdg-desktop-portal-hyprland kvantum qt6ct thunar xfconf zathura \
        zathura-pdf-poppler waybar papirus-icon-theme fonts-jetbrains-mono \
        cava
    (( LAPTOP_POWER )) && install_ubuntu_candidates auto-cpufreq

    (( NVIDIA )) && run sudo ubuntu-drivers install
    install_grimblast_from_source
    install_snappy_switcher_from_source \
        build-essential pkg-config wayland-protocols libwayland-dev \
        libcairo2-dev libpango1.0-dev libjson-c-dev libxkbcommon-dev \
        libglib2.0-dev librsvg2-dev
    (( BIOMETRIC )) && install_ubuntu_candidates libpam0g-dev

    if ((${#APT_MISSING[@]})); then
        warn "No Ubuntu package was found for: ${APT_MISSING[*]}"
    fi
}

brew_path() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s\n' /opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
        printf '%s\n' /usr/local/bin/brew
    fi
}

install_homebrew() {
    local installer

    BREW="$(brew_path || true)"
    [[ -n "$BREW" ]] && return

    ask "Install Homebrew from its official installer?" "yes" ||
        die "Homebrew is required for the macOS profile."

    if (( DRY_RUN )); then
        log "Would download and run Homebrew's official installer."
        BREW="/opt/homebrew/bin/brew"
        return
    fi

    installer="$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")"
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    /bin/bash "$installer"
    rm -f "$installer"

    BREW="$(brew_path || true)"
    [[ -n "$BREW" ]] || die "Homebrew installation did not provide brew on a standard path."
}

configure_homebrew_path() {
    local zprofile="$HOME/.zprofile"
    local brew_bin

    brew_bin="$(dirname -- "$BREW")"
    export PATH="$brew_bin:$PATH"

    grep -Fq '# >>> tirbofish-config homebrew >>>' "$zprofile" 2>/dev/null && return
    run mkdir -p "$(dirname -- "$zprofile")"
    if (( DRY_RUN )); then
        log "Would add Homebrew's bin directory to $zprofile."
        return
    fi

    [[ -s "$zprofile" ]] && printf '\n' >> "$zprofile"
    {
        printf '%s\n' '# >>> tirbofish-config homebrew >>>'
        printf 'export PATH="%s:$PATH"\n' "$brew_bin"
        printf '%s\n' '# <<< tirbofish-config homebrew <<<'
    } >> "$zprofile"
}

install_macos() {
    install_homebrew
    configure_homebrew_path

    run "$BREW" install zsh starship fastfetch neovim fzf jq git mpv
    run "$BREW" install --cask kitty font-jetbrains-mono-nerd-font font-inter font-manrope
}

install_packages() {
    case "$PLATFORM" in
        arch) install_arch ;;
        void) install_void ;;
        ubuntu) install_ubuntu ;;
        macos) install_macos ;;
    esac
    DID_INSTALL=1
}

backup_existing() {
    local target="$1" name="$2"

    if [[ -z "$BACKUP_ROOT" ]]; then
        BACKUP_ROOT="$HOME/.local/share/tirbofish-config-backups/$(date +%Y%m%d-%H%M%S)"
    fi
    run mkdir -p "$BACKUP_ROOT"
    run mv "$target" "$BACKUP_ROOT/$name"
}

link_item() {
    local name="$1"
    local source="$ROOT/$name"
    local target="$CONFIG_HOME/$name"

    [[ -e "$source" ]] || die "Missing configuration source: $source"
    if [[ -e "$target" && "$source" -ef "$target" ]]; then
        return
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        ask "Replace $target (a backup will be made)?" "no" || {
            warn "Kept existing $target."
            return
        }
        backup_existing "$target" "$name"
    fi

    run ln -s "$source" "$target"
}

link_configurations() {
    local items=(kitty fastfetch nvim starship.toml zsh)

    if [[ "$PROFILE" == "desktop" ]]; then
        items+=(
            hypr hyprpolkitagent quickshell rofi dunst mako waybar Kvantum
            qt6ct wireplumber snappy-switcher Thunar zathura color-schemes
        )
        # Only holds the Surface Laptop 4 speaker filter chain.
        (( SURFACE )) && items+=(pipewire)
    fi

    run mkdir -p "$CONFIG_HOME"
    for item in "${items[@]}"; do
        link_item "$item"
    done
}

install_bundled_fonts() {
    local font destination

    if [[ "$PLATFORM" == "macos" ]]; then
        destination="$HOME/Library/Fonts"
    else
        destination="$HOME/.local/share/fonts/CMU-Typewriter"
    fi

    run mkdir -p "$destination"
    for font in "$ROOT"/kitty/Typewriter\ Variable/*.ttf; do
        [[ -f "$font" ]] || continue
        run install -m 644 "$font" "$destination/$(basename -- "$font")"
    done

    if command -v fc-cache >/dev/null 2>&1; then
        run fc-cache -f "$destination"
    fi
}

ensure_kitty_theme() {
    local state_file="$STATE_HOME/theme/kitty_theme.conf"
    local theme="$CONFIG_HOME/kitty/themes/everforest.conf"

    [[ -e "$state_file" || -L "$state_file" ]] && return
    run mkdir -p "$(dirname -- "$state_file")"
    run ln -s "$theme" "$state_file"
}

write_features() {
    local file="$ROOT/hypr/features.lua"
    local surface=false nvidia=false

    (( SURFACE )) && surface=true
    (( NVIDIA )) && nvidia=true
    if (( DRY_RUN )); then
        log "Would write $file (surface = $surface, nvidia = $nvidia)."
        return
    fi
    printf -- '-- Written by install.sh; re-run it or edit to toggle.\nreturn { surface = %s, nvidia = %s }\n' \
        "$surface" "$nvidia" > "$file"
}

configure_nvidia() {
    (( NVIDIA )) || return 0
    # KMS is required for Hyprland; fbdev gives a native-resolution console.
    run sudo sh -c "echo 'options nvidia_drm modeset=1 fbdev=1' > /etc/modprobe.d/nvidia-drm.conf"
}

configure_biometric() {
    local pam_module

    if (( ! BIOMETRIC )); then
        [[ -f /etc/pam.d/hyprlock-biopass ]] &&
            warn "Biopass is still enabled; delete /etc/pam.d/hyprlock-biopass to turn it off."
        return 0
    fi
    pam_module="$(compgen -G '/usr/lib*/security/libbiopass_pam.so' | head -n 1 || true)"
    if [[ -z "$pam_module" ]] && (( ! DRY_RUN )); then
        warn "libbiopass_pam.so is not installed (Arch: biopass-bin from the AUR); biometric unlock was skipped."
        return 0
    fi
    run cc -O2 -o "$ROOT/hypr/scripts/hyprlock-biopass-auth" "$ROOT/hypr/scripts/hyprlock-biopass-auth.c" -lpam
    run sudo install -m 644 "$ROOT/hypr/pam.d/hyprlock-biopass" /etc/pam.d/hyprlock-biopass
}

initialize_desktop_runtime() {
    local wallpaper="$CONFIG_HOME/hypr/wallpapers/default-dark.jpg"
    local theme_script="$CONFIG_HOME/hypr/scripts/pywal.sh"

    run mkdir -p "$HOME/.cache/quickshell" "$HOME/.cache/wal" "$STATE_HOME/theme"
    ask "Generate the initial theme from the bundled dark wallpaper?" "yes" || return 0
    run "$theme_script" "$wallpaper" dark
}

install_oh_my_zsh() {
    local omz="$HOME/.oh-my-zsh"
    local p10k="$omz/custom/themes/powerlevel10k"

    [[ -d "$omz" ]] || run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
    [[ -d "$p10k" ]] || run git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$p10k"
}

append_zsh_source() {
    local zshrc="$HOME/.zshrc"

    grep -Fq '# >>> tirbofish-config zsh >>>' "$zshrc" 2>/dev/null && return
    if (( DRY_RUN )); then
        log "Would source $CONFIG_HOME/zsh/rc.zsh from $zshrc."
        return
    fi

    [[ -s "$zshrc" ]] && printf '\n' >> "$zshrc"
    cat >> "$zshrc" <<'EOF'
# >>> tirbofish-config zsh >>>
[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/rc.zsh" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/rc.zsh"
# <<< tirbofish-config zsh <<<
EOF
}

configure_zsh() {
    local zsh_path

    if ask "Install your zsh setup (Oh My Zsh, Powerlevel10k, Fastfetch, aliases)?" "yes"; then
        install_oh_my_zsh
        append_zsh_source
    fi
    ask "Make zsh your login shell?" "yes" || return 0

    zsh_path="$(command -v zsh)" || {
        warn "zsh is not installed, so the login shell was not changed."
        return
    }
    [[ "${SHELL:-}" == "$zsh_path" ]] && return
    grep -Fxq "$zsh_path" /etc/shells 2>/dev/null || {
        warn "$zsh_path is not listed in /etc/shells; leaving the login shell unchanged."
        return
    }
    run chsh -s "$zsh_path"
}

monitor_default() {
    local field="$1" fallback="$2" value=""

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        value="$(hyprctl -j monitors 2>/dev/null |
            jq -r --arg field "$field" '.[] | select(.focused) | .[$field] // empty' |
            head -n 1 || true)"
    fi
    printf '%s' "${value:-$fallback}"
}

configure_monitors() {
    local config="$CONFIG_HOME/hypr/hyprland.lua"
    local blocks output_name mode position scale bitdepth another
    local default_output default_scale output

    ask "Configure Hyprland monitor defaults now?" "no" || return 0
    [[ -f "$config" ]] || {
        warn "Cannot find $config; monitor configuration was skipped."
        return
    }
    grep -Fq -- '-- BEGIN installer-managed monitors' "$config" ||
        die "The monitor markers are missing from $config."

    if (( DRY_RUN )); then
        log "Would prompt for monitor settings and update $config."
        return
    fi

    default_output="$(monitor_default name eDP-1)"
    default_scale="$(monitor_default scale 1)"
    blocks="$(mktemp "${TMPDIR:-/tmp}/hypr-monitors.XXXXXX")"

    while :; do
        output_name="$(prompt_default "Monitor output" "$default_output")"
        mode="$(prompt_default "Mode (preferred or WIDTHxHEIGHT@HZ)" preferred)"
        position="$(prompt_default "Position (auto or XxY)" auto)"
        scale="$(prompt_default "Scale" "$default_scale")"
        bitdepth="$(prompt_default "Bit depth" 8)"

        if [[ ! "$output_name" =~ ^[A-Za-z0-9._-]+$ ]] ||
            [[ ! "$mode" =~ ^(preferred|[0-9]+x[0-9]+(@[0-9]+([.][0-9]+)?)?)$ ]] ||
            [[ ! "$position" =~ ^(auto|-?[0-9]+x-?[0-9]+)$ ]] ||
            [[ ! "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
            [[ ! "$bitdepth" =~ ^(8|10)$ ]]; then
            warn "Invalid monitor values. Try again."
            continue
        fi

        cat >> "$blocks" <<EOF
hl.monitor({
    output   = "$output_name",
    mode     = "$mode",
    position = "$position",
    scale    = $scale,
    bitdepth = $bitdepth
})

EOF
        ask "Add another monitor?" "no" || break
        default_output="HDMI-A-1"
        default_scale="1"
    done

    output="$(mktemp "${TMPDIR:-/tmp}/hypr-config.XXXXXX")"
    awk -v blocks="$blocks" '
        /-- BEGIN installer-managed monitors/ {
            print
            while ((getline line < blocks) > 0) print line
            close(blocks)
            replacing = 1
            next
        }
        /-- END installer-managed monitors/ {
            replacing = 0
            print
            next
        }
        !replacing { print }
    ' "$config" > "$output"
    mv "$output" "$config"
    rm -f "$blocks"
}

hyprland_supports_lua_config() {
    local version major rest minor

    version="$(hyprctl version 2>/dev/null | awk '/^Hyprland / { print $2; exit }')"
    version="${version#v}"
    major="${version%%.*}"
    rest="${version#*.}"
    minor="${rest%%.*}"
    [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
    (( major > 0 || minor >= 55 ))
}

verify_setup() {
    local command
    local missing=()
    local required=(zsh starship fastfetch nvim git)

    if [[ "$PLATFORM" == "macos" ]]; then
        if ! command -v kitty >/dev/null 2>&1 &&
            [[ ! -d /Applications/kitty.app && ! -d "$HOME/Applications/kitty.app" ]]; then
            missing+=(kitty)
        fi
    else
        required+=(kitty)
    fi

    if [[ "$PROFILE" == "desktop" ]]; then
        required+=(
            hyprctl hypridle hyprlock hyprpicker qs awww dunst rofi mpv
            pamixer brightnessctl playerctl grimblast swappy wal snappy-switcher
            nmcli bluetoothctl wpctl pw-dump jq khal vdirsyncer
        )
    fi

    for command in "${required[@]}"; do
        command -v "$command" >/dev/null 2>&1 || missing+=("$command")
    done

    if [[ "$PROFILE" == "desktop" ]] && ! hyprland_supports_lua_config; then
        missing+=("Hyprland >= 0.55")
    fi

    if ((${#missing[@]})); then
        warn "Missing required tools: ${missing[*]}"
        return 1
    fi
    if [[ "$PROFILE" == "desktop" ]] && ! command -v auto-cpufreq >/dev/null 2>&1; then
        warn "auto-cpufreq is unavailable; the CPU governor control in QuickShell will be disabled."
    fi
}

main() {
    while (($#)); do
        case "$1" in
            --terminal-only) TERMINAL_ONLY=1 ;;
            --yes) ASSUME_YES=1 ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; return 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done

    [[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Run this installer as your normal user, not root."
    detect_platform
    choose_profile
    log "Selected $PROFILE profile for $PLATFORM."
    choose_features

    if ask "Install the required packages now?" "yes"; then
        install_packages
    else
        warn "Package installation was skipped."
    fi

    if ask "Link this repository into $CONFIG_HOME?" "yes"; then
        link_configurations
        install_bundled_fonts
        ensure_kitty_theme
        if [[ "$PROFILE" == "desktop" ]]; then
            write_features
            initialize_desktop_runtime
        fi
    else
        warn "Configuration linking was skipped."
    fi

    configure_zsh
    if [[ "$PROFILE" == "desktop" ]]; then
        configure_nvidia
        configure_biometric
        configure_monitors
    fi

    if (( DRY_RUN )); then
        log "Dry run complete."
        return
    fi
    if ! verify_setup; then
        (( DID_INSTALL )) && return 1
    fi

    log "Setup complete. Restart your graphical session for the desktop profile."
    if [[ "$PROFILE" == "desktop" && "$PLATFORM" == "void" ]]; then
        printf 'On Void, reboot, then log in on a TTY and run: dbus-run-session start-hyprland\n'
    fi
    (( NVIDIA )) && printf 'Reboot to load the NVIDIA driver with modesetting.\n'
    true
}

main "$@"
