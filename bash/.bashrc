command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
[[ $- != *i* ]] && return
[ -f ~/.profile ] && . ~/.profile
[ -f /etc/bashrc ] && . /etc/bashrc
command -v fish >/dev/null 2>&1 && exec fish
