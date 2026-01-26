# my.zsh - Portable zsh configuration
# Source this file from ~/.zshrc:
#   source ~/src/github.com/ysk1031/dotfiles/my.zsh

# Options
setopt hist_ignore_all_dups

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

# Function: History search with fzf (Ctrl+r)
function fzf_select_history() {
  local tac
  if which tac > /dev/null; then
    tac="tac"
  else
    tac="tail -r"
  fi
  BUFFER=$(fc -l -n 1 | eval $tac | fzf --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
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
  zle clear-screen
}
zle -N fzf-src
bindkey '^]' fzf-src

# Function: lazygit with directory change support (Ctrl+g)
function lg() {
  export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir

  lazygit "$@"

  if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
    cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
    rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
  fi
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
