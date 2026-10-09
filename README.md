# tirbo's dotfiles

Install on Arch, Void, Ubuntu, or macOS (terminal only):

```sh
curl -fsSL https://raw.githubusercontent.com/tirbofish/dotfiles/main/install.sh | sh
```

The installer clones this repo to `~/.local/share/tirbofish-dotfiles`
(override with `DOTFILES_DIR`), links it into `~/.config`, and asks before
each step: desktop or terminal-only, Surface tweaks, NVIDIA (auto-detected),
Biopass face unlock, auto-cpufreq, and the zsh setup (Oh My Zsh +
Powerlevel10k). Hardware choices land in `hypr/features.lua`.

From a checkout, run `./install.sh` (`--dry-run` to preview, `--yes` for
defaults). On Void, Hyprland comes from the third-party
[sofijacom/hyprland-void](https://github.com/sofijacom/hyprland-void) repo;
start it from a TTY with `dbus-run-session start-hyprland`.

Per-machine zsh settings go in `~/.zshrc.local`.
