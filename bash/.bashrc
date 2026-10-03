[[ $- != *i* ]] && return
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/opt/mise/bin:/usr/local/opt/mise/bin"
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
[ -f /etc/bashrc ] && . /etc/bashrc
command -v fish >/dev/null 2>&1 && exec fish
. "$HOME/.cargo/env"
