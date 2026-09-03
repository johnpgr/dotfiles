[[ $- != *i* ]] && return
eval "$(/home/joao/.local/bin/mise activate bash)"
[ -f ~/.profile ] && . ~/.profile
[ -f /etc/bashrc ] && . /etc/bashrc
command -v fish >/dev/null 2>&1 && exec fish


# Added by Antigravity CLI installer
export PATH="/home/joao/.local/bin:$PATH"
