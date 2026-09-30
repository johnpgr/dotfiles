[[ $- != *i* ]] && return
eval "$(/opt/homebrew/opt/mise/bin/mise activate bash)"
[ -f /etc/bashrc ] && . /etc/bashrc
command -v fish >/dev/null 2>&1 && exec fish
. "$HOME/.cargo/env"
