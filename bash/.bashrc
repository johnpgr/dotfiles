[[ $- != *i* ]] && return
[ -f ~/.profile ] && . ~/.profile
[ -f /etc/bashrc ] && . /etc/bashrc
command -v fish >/dev/null 2>&1 && exec fish

# opencode
export PATH=/home/joao/.opencode/bin:$PATH


# Added by Antigravity CLI installer
export PATH="/home/joao/.local/bin:$PATH"
