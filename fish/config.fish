set fish_greeting

if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end


# Added by Antigravity CLI installer
set -gx PATH "/home/joao/.local/bin" $PATH
