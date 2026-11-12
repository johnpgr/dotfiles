set fish_greeting

# pinentry-curses needs the controlling terminal; WSL has no graphical prompt.
if status is-interactive
    set -gx GPG_TTY (tty)
end

if test -n "$SSH_CONNECTION"
    set -gx EDITOR vim
else
    set -gx EDITOR nvim
end

if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end


# Added by Antigravity CLI installer
set -gx PATH $HOME/.local/bin $PATH
