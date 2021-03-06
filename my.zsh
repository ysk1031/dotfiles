setopt hist_ignore_all_dups

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


function peco-github-prs () {
    local pr=$(hub issue 2> /dev/null | grep 'pull' | peco --query "$LBUFFER" | sed -e 's/.*( \(.*\) )$/\1/')
    if [ -n "$pr" ]; then
        BUFFER="open ${pr}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-github-prs
bindkey '^g^p' peco-github-prs


function peco-src () {
  local selected_dir=$(ghq list -p | peco --query "$LBUFFER")
  if [ -n "$selected_dir" ]; then
    BUFFER="cd ${selected_dir}"
    zle accept-line
  fi
  zle clear-screen
}
zle -N peco-src
bindkey '^]' peco-src


alias g='git'
alias gst='git status'
alias gd='git diff'
alias gg='git grep'
alias gb='git branch'
alias gf='git fetch --prune'
alias a='atom'

alias -g B='`git branch -a | peco --prompt "GIT BRANCH>" | head -n 1 | sed -e "s/^\*\s*//g"`'
