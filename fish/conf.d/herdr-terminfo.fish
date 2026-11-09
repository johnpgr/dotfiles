if set -q HERDR_ENV; and test "$TERM" = xterm-256color; and test -d "$HOME/.local/share/herdr/terminfo"
    set -gx TERMINFO "$HOME/.local/share/herdr/terminfo"
end
