# emx - Launch Emacs GUI via VcXsrv (X11) instead of WSLg.
#
# Why: WSLg's Weston advertises a fixed key-repeat delay (400ms,
# microsoft/wslg#1384) that can't be tuned. A real X server honors
# `xset r rate`, so held-key repeat starts as fast as you set it.
#
# Prereqs (one time, Windows side):
#   1. Install VcXsrv.
#   2. Run: vcxsrv.exe :1 -ac -multiwindow -clipboard
#      (display :1 avoids clashing with WSLg's :0; save via XLaunch,
#       optionally autostart through shell:startup)
#
# Prereqs (one time, Linux side):
#   sudo dnf install emacs-gtk+x11 xset
#
# Notes:
#   - Uses 127.0.0.1 because .wslconfig sets networkingMode=Mirrored.
#     On NAT mode use the host IP from /etc/resolv.conf instead.
#   - Prefers emacs-gtk+x11 over pgtk: a pgtk daemon exits if the X
#     connection ever drops (documented GTK3 limitation), while the
#     gtk+x11 build survives VcXsrv restarts.
#   - Frames are served by a dedicated "x11" daemon, separate from any
#     WSLg daemon you run, so the two never fight over displays.
function emx --description "Launch Emacs GUI via VcXsrv X11 (tunable key repeat)"
    set -l display 127.0.0.1:1
    set -l port 6001 # display :1 -> TCP 6000+1
    set -l emacs_bin emacs-gtk+x11

    # 1. Is VcXsrv actually up?
    if not timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null
        echo "emx: VcXsrv :1 not reachable at $display." >&2
        echo "emx: Start it on Windows first: vcxsrv.exe :1 -ac -multiwindow -clipboard" >&2
        return 1
    end

    if not command -v $emacs_bin >/dev/null
        echo "emx: $emacs_bin not installed; run: sudo dnf install emacs-gtk+x11" >&2
        echo "emx: falling back to pgtk-on-X (fragile, may exit if X drops)." >&2
        set emacs_bin emacs
    end

    set -lx DISPLAY $display
    set -lx GDK_BACKEND x11 # no-op for gtk+x11, required for pgtk fallback

    # 2. Tune key repeat on the X server (the whole point of this).
    # Override anytime: set -Ux EMX_REPEAT_DELAY 175; set -Ux EMX_REPEAT_RATE 60
    test -n "$EMX_REPEAT_DELAY"; or set EMX_REPEAT_DELAY 175
    test -n "$EMX_REPEAT_RATE"; or set EMX_REPEAT_RATE 60
    if command -v xset >/dev/null
        xset r rate $EMX_REPEAT_DELAY $EMX_REPEAT_RATE 2>/dev/null
    else
        echo "emx: xset not found; repeat untuned. Install: sudo dnf install xset" >&2
    end

    # 3. Reuse (or start) the dedicated daemon, then open a frame.
    if not emacsclient -s x11 -e t >/dev/null 2>&1
        $emacs_bin --daemon=x11 2>/dev/null; or return 1
        # Daemon takes seconds to boot Doom; wait for its socket.
        for i in (seq 1 60)
            emacsclient -s x11 -e t >/dev/null 2>&1; and break
            sleep 1
        end
    end
    emacsclient -s x11 -e t >/dev/null 2>&1; or begin
        echo "emx: x11 daemon failed to come up." >&2
        return 1
    end

    # 4. Open the frame detached, but surface real errors.
    set -l err (mktemp)
    emacsclient -s x11 -c $argv 2>$err &
    sleep 3
    if test -s $err
        echo "emx: frame failed to open:" >&2
        cat $err >&2
    end
    rm -f $err
    disown
end
