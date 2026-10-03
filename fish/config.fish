set fish_greeting

if test -n "$SSH_CONNECTION"
    set -gx EDITOR vim
else
    set -gx EDITOR nvim
end

if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end
