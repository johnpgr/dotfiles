function upload_clipboard_image
    set -l host (pick_ssh_host); or return
    set -l remote_path /tmp/clipboard-(date +%Y%m%d-%H%M%S).png
    clipboard_png | ssh $host "cat > $remote_path"; or return
    printf '%s' $remote_path | copy_clipboard
    echo $remote_path
end
