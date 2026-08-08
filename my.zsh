# my.zsh - Portable zsh configuration
# Source this file from ~/.zshrc:
#   source ~/src/github.com/ysk1031/dotfiles/my.zsh

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history          # share history across sessions in real time
setopt extended_history       # record timestamp and duration
setopt hist_ignore_all_dups   # drop older duplicates
setopt hist_reduce_blanks     # collapse extra whitespace
setopt hist_verify            # confirm before executing !! expansions

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z} m:{A-Z}={a-z}'

# Completions for mise-managed tools. Requires compinit to have run already,
# which ~/.zshrc does before sourcing this file.
eval "$(bun completions)"
eval "$(uv generate-shell-completion zsh)"

# Aliases - Safety
alias rm='trash'

# Aliases - Git
alias g='git'
alias gst='git status'
alias gd='git diff'
alias gb='git branch'
alias gf='git fetch --prune'

# Aliases - Tools
alias ls='eza'
alias ll='eza -l --group-directories-first'
alias grep='rg'
alias lzd='lazydocker'
alias nv='nvim'
alias tree='eza --tree --level=2 --git-ignore'

# fzf
export FZF_DEFAULT_OPTS="--height=40% --reverse --border"

# Function: History search with fzf (Ctrl+r)
function fzf_select_history() {
  BUFFER=$(fc -l -n 1 | fzf --tac --scheme=history --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle reset-prompt
}
zle -N fzf_select_history
bindkey '^r' fzf_select_history

# Function: ghq repository selector with fzf (Ctrl+])
function fzf-src() {
  local selected_dir=$(ghq list -p | fzf --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle reset-prompt
}
zle -N fzf-src
bindkey '^]' fzf-src

# Function: lazygit with directory change support (Ctrl+g)
function lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
  zle reset-prompt
}
zle -N lg
bindkey '^g' lg

# Function: Claude safety wrapper (blocks --dangerously-skip-permissions)
safety_claude() {
  for arg in "$@"; do
    if [[ "$arg" == "--dangerously-skip-permissions" ]]; then
      echo "Error: --dangerously-skip-permissions option is not allowed." >&2
      return 1
    fi
  done

  command claude "$@"
}
alias claude='safety_claude'
