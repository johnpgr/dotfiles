function upload_latest_screenshot
    set -l host (pick_ssh_host); or return
    # macOS, GNOME and KDE default screenshot locations.
    set -l screenshots (find ~/Desktop ~/Screenshots ~/Pictures/Screenshots \
        -maxdepth 1 -type f -name 'Screenshot*.png' 2>/dev/null)
    if test (count $screenshots) -eq 0
        echo upload_latest_screenshot: no screenshots found >&2
        return 1
    end
    set -l latest (ls -t $screenshots | head -1)
    set -l remote_path /tmp/(date +%Y%m%d-%H%M%S).png
    ssh $host "cat > $remote_path" < $latest; or return
    printf '%s' $remote_path | copy_clipboard
    echo $remote_path
end
