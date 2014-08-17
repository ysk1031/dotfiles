autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs
zstyle ':chpwd:*' recent-dirs-max 500
zstyle ':chpwd:*' recent-dirs-default yes
zstyle ':completion:*' recent-dirs-insert both

setopt hist_ignore_all_dups

# gh
eval "$(gh alias -s)"

alias a='atom'
alias r='rails'
alias ao='RAILS_ENV=aono'
alias gsl='git stash list'
alias gd='git diff'
alias gb='git branch -a'
alias gg='git grep'
alias gf='git fetch --prune'
alias vg='vagrant'
alias -g B='`git branch -a | peco | sed -e "s/^\*[ ]*//g"`'

# peco
function peco_select_history() {
  local tac
  if which tac > /dev/null; then
    tac="tac"
  else
    tac="tail -r"
  fi
  BUFFER=$(fc -l -n 1 | eval $tac | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N peco_select_history
bindkey '^r' peco_select_history

function peco_cdr() {
  local selected_dir=$(cdr -l | awk '{ print $2 }' | peco)
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco_cdr
bindkey '^xb' peco_cdr

function peco-src () {
  local selected_dir=$(ghq list --full-path | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src

function cdgem() {
  local gem_name=$(bundle list | sed -e 's/^ *\* *//g' | peco | cut -d \  -f 1)
  if [ -n "$gem_name" ]; then
    local gem_dir=$(bundle show ${gem_name})
    echo "cd to ${gem_dir}"
    cd ${gem_dir}
  fi
}
