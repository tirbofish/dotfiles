# Shared interactive zsh setup: Oh My Zsh + Powerlevel10k (Starship if OMZ is
# missing). Per-machine aliases and secrets go in ~/.zshrc.local.
[[ $- == *i* ]] || return 0

# Console output must run before Powerlevel10k's instant prompt preamble.
command -v fastfetch >/dev/null 2>&1 && fastfetch

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
  plugins=(git)
  source "$ZSH/oh-my-zsh.sh"
  if [[ -r ~/.p10k.zsh ]]; then source ~/.p10k.zsh; else source "$ZSH_CONFIG_DIR/p10k.zsh"; fi
elif command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
  eval "$(starship init zsh)"
fi

alias cls="clear" # im too used to windows
[[ -r "$HOME/.espressif/tools/activate_idf_v6.0.2.sh" ]] &&
  alias get_idf="source $HOME/.espressif/tools/activate_idf_v6.0.2.sh"

# Toolchains, each only when installed.
[[ -r "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
[[ -d "$HOME/.bun" ]] && export BUN_INSTALL="$HOME/.bun" PATH="$HOME/.bun/bin:$PATH"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
[[ -d "$HOME/Android/Sdk" ]] && export ANDROID_HOME="$HOME/Android/Sdk" &&
  export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
[[ -d "$HOME/.local/share/pnpm" ]] && export PNPM_HOME="$HOME/.local/share/pnpm" &&
  export PATH="$PNPM_HOME/bin:$PATH"
[[ -d "$HOME/.lmstudio/bin" ]] && export PATH="$PATH:$HOME/.lmstudio/bin"
if [[ -d "$HOME/.grok/bin" ]]; then
  export PATH="$HOME/.grok/bin:$PATH"
  fpath=(~/.grok/completions/zsh $fpath)
  autoload -Uz compinit && compinit -C
fi
[[ -x /home/linuxbrew/.linuxbrew/bin/brew ]] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Proton Pass as the SSH agent.
if command -v pass-cli >/dev/null 2>&1; then
  pass-cli ssh-agent daemon start >/dev/null 2>&1 &!
  export SSH_AUTH_SOCK="$HOME/.ssh/proton-pass-agent.sock"
fi

[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
true
