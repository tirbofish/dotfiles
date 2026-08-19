# Configuration setup

Run the installer from this directory:

```bash
./install.sh
```

It installs the full Hyprland profile on Arch or Ubuntu by default, links the
portable configuration with backups for conflicts, installs the bundled Kitty
font, and optionally configures monitors. Use `--terminal-only` for just
Kitty, Neovim, Fastfetch, Starship, and zsh; `--dry-run --yes` previews the
default path.

On macOS it bootstraps Homebrew, installs Kitty plus the shared terminal tools
and fonts, and links only macOS-compatible configuration. Hyprland, QuickShell,
and Linux desktop themes are intentionally skipped there.

The Ubuntu desktop profile requires its package sources to provide Hyprland
0.55+ and QuickShell; unavailable packages are reported explicitly.

| Shortcut | Action |
| --- | --- |
| `Super` + `Ctrl` + `Shift` + Arrow | Swap the focused Hyprland window with its neighbor |

The installer never links browser, account, or generated application state. Enter weather
credentials through the QuickShell settings panel; they remain local to the
machine.
