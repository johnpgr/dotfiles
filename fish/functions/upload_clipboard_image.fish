function upload_clipboard_image
    set -l remote_path /tmp/clipboard-(date +%Y%m%d-%H%M%S).png
    pngpaste - | ssh joao@desktop-v0i3imc "cat > $remote_path"; or return
    printf '%s' $remote_path | pbcopy
    echo $remote_path
end
