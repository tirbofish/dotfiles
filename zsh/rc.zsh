# Shared interactive zsh additions. Keep personal aliases in ~/.zshrc.
[[ $- == *i* ]] || return 0

export PATH="$HOME/.local/bin:$PATH"
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
command -v fastfetch >/dev/null 2>&1 && fastfetch
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
