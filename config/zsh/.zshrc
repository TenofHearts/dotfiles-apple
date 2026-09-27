# Adapted from TenofHearts/dotfiles for macOS.
typeset -U path
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt AUTO_CD INTERACTIVE_COMMENTS
autoload -Uz compinit
compinit
bindkey -e
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=long
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,pcpu,tty,time,comm'

autoload -Uz colors
colors
PROMPT='%F{green}%n@%m%f %F{blue}%~%f %# '
export CLICOLOR=1
alias ll='ls -lAhG'
alias la='ls -AlG'
alias l='ls -CFG'
alias cls='clear'

if (( $+commands[git] )); then
  alias g='git'
  alias ga='git add'
  alias gc='git commit'
  alias gca='git commit -a'
  alias gpu='git push'
  alias gpl='git pull'
  alias glg='git log --graph --decorate'
fi

if (( $+commands[uv] )); then
  eval "$(uv generate-shell-completion zsh)"
  (( $+commands[uvx] )) && eval "$(uvx --generate-shell-completion zsh)"
  alias uva='uv add'
  alias uvr='uv run'
  uvac() {
    if [[ -r .venv/bin/activate ]]; then
      source .venv/bin/activate
    else
      print -u2 -- 'No readable .venv/bin/activate in the current directory.'
      return 1
    fi
  }
  # --bare avoids generating main.py, without deleting any existing files.
  uvi() { uv init --bare --no-readme --vcs none "$@"; }
fi

export EDITOR=vim
export VISUAL=vim
export HOMEBREW_BUNDLE_FILE="$HOME/.Brewfile"

# Local proxy, matching the original setup. Override in ~/.zshrc.local.
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
export all_proxy=http://127.0.0.1:7897

if (( $+commands[oh-my-posh] )) && [[ -r ~/.config/oh-my-posh/theme.omp.json ]]; then
  export VIRTUAL_ENV_DISABLE_PROMPT=1
  eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/theme.omp.json")"
fi

_dotfiles_brew_prefix=${HOMEBREW_PREFIX:-/opt/homebrew}
[[ -d $_dotfiles_brew_prefix ]] || _dotfiles_brew_prefix=/usr/local
if [[ -r $_dotfiles_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source "$_dotfiles_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local

# Display the original welcome artwork only in an interactive terminal.
if [[ -o interactive && -t 1 && ${DOTFILES_WELCOME:-1} == 1 ]] &&
   (( $+commands[fortune] && $+commands[cowsay] )) &&
   [[ -r ~/.config/cowsay/stegosaurus_and_cat.cow ]]; then
  if (( $+commands[lolcat] )); then
    fortune | cowsay -f "$HOME/.config/cowsay/stegosaurus_and_cat.cow" | lolcat
  else
    fortune | cowsay -f "$HOME/.config/cowsay/stegosaurus_and_cat.cow"
  fi
fi

# Highlighting must be loaded after widgets and other plugins.
if [[ -r $_dotfiles_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source "$_dotfiles_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=114'
  ZSH_HIGHLIGHT_STYLES[command]='fg=114'
  ZSH_HIGHLIGHT_STYLES[path]='fg=182'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=114'
  ZSH_HIGHLIGHT_STYLES[function]='fg=067'
  ZSH_HIGHLIGHT_STYLES[precommand]='fg=035,bold'
fi
unset _dotfiles_brew_prefix
