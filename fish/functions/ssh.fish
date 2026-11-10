function ssh --wraps ssh --description 'ssh with a TERM that remote servers recognize'
    # Remote hosts usually lack the xterm-kitty terminfo entry ('xterm-kitty': unknown terminal type).
    if test "$TERM" = xterm-kitty
        TERM=xterm-256color command ssh $argv
    else
        command ssh $argv
    end
end
