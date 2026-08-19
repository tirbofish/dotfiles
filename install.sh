#!/usr/bin/env bash
# Install the portable part of this configuration on Arch, Ubuntu, or macOS.
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
BACKUP_ROOT=""
DID_INSTALL=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--terminal-only] [--yes] [--dry-run]

Without options, choose the full Hyprland setup or the shared terminal setup
interactively. macOS installs only the compatible terminal configuration.

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
                ubuntu) PLATFORM="ubuntu" ;;
                *) die "Supported Linux distributions are Arch and Ubuntu; found ${ID:-unknown}." ;;
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

install_arch_aur() {
    local yay_cmd build_dir
    local packages=(auto-cpufreq grimblast-git snappy-switcher)

    if command -v yay >/dev/null 2>&1; then
        yay_cmd="$(command -v yay)"
    else
        ask "Install yay to fetch the Arch-only desktop packages?" "yes" ||
            die "The full Arch profile needs yay for: ${packages[*]}"

        if (( DRY_RUN )); then
            run git clone https://aur.archlinux.org/yay.git /tmp/yay-build
            log "Would build yay with makepkg."
            yay_cmd="yay"
        else
            build_dir="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"
            if ! (cd "$build_dir/yay" && makepkg -si --noconfirm); then
                rm -rf "$build_dir"
                die "Unable to build yay."
            fi
            rm -rf "$build_dir"
            yay_cmd="$(command -v yay)" || die "yay was installed but is not on PATH."
        fi
    fi

    run "$yay_cmd" -S --needed --noconfirm "${packages[@]}"
}

install_arch() {
    local packages=(
        base-devel git curl zsh kitty starship fastfetch neovim fzf jq fontconfig
    )

    if [[ "$PROFILE" == "desktop" ]]; then
        packages+=(
            hyprland hypridle hyprlock hyprpicker hyprpolkitagent quickshell
            awww dunst mako rofi nautilus firefox mpv
            pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber
            pavucontrol pamixer networkmanager bluez bluez-utils blueman
            brightnessctl playerctl grim slurp swappy wl-clipboard libnotify
            python python-pywal khal vdirsyncer polkit polkit-gnome
            xdg-desktop-portal-hyprland kvantum qt6ct thunar xfconf
            zathura zathura-pdf-poppler waybar papirus-icon-theme
            ttf-jetbrains-mono-nerd
        )
    fi

    run sudo pacman -Syu --needed --noconfirm "${packages[@]}"
    if [[ "$PROFILE" == "desktop" ]]; then
        install_arch_aur
    fi
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
    install_ubuntu_candidates \
        build-essential pkg-config wayland-protocols libwayland-dev \
        libcairo2-dev libpango1.0-dev libjson-c-dev libxkbcommon-dev \
        libglib2.0-dev librsvg2-dev

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
        auto-cpufreq

    install_grimblast_from_source
    install_snappy_switcher_from_source

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
            qt6ct pipewire wireplumber snappy-switcher swappy Thunar zathura
            color-schemes mimeapps.list
        )
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

initialize_desktop_runtime() {
    local wallpaper="$CONFIG_HOME/hypr/wallpapers/default-dark.jpg"
    local theme_script="$CONFIG_HOME/hypr/scripts/pywal.sh"

    run mkdir -p "$HOME/.cache/quickshell" "$HOME/.cache/wal" "$STATE_HOME/theme"
    ask "Generate the initial theme from the bundled dark wallpaper?" "yes" || return 0
    run "$theme_script" "$wallpaper" dark
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

    ask "Source the bundled Starship and Fastfetch zsh setup?" "yes" && append_zsh_source
    ask "Make zsh your login shell?" "no" || return 0

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

    if ask "Install the required packages now?" "yes"; then
        install_packages
    else
        warn "Package installation was skipped."
    fi

    if ask "Link this repository into $CONFIG_HOME?" "yes"; then
        link_configurations
        install_bundled_fonts
        ensure_kitty_theme
        [[ "$PROFILE" == "desktop" ]] && initialize_desktop_runtime
    else
        warn "Configuration linking was skipped."
    fi

    configure_zsh
    [[ "$PROFILE" == "desktop" ]] && configure_monitors

    if (( DRY_RUN )); then
        log "Dry run complete."
        return
    fi
    if ! verify_setup; then
        (( DID_INSTALL )) && return 1
    fi

    log "Setup complete. Restart your graphical session for the desktop profile."
}

main "$@"
