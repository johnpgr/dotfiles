function upload_latest_screenshot
    set -l latest (ls -t ~/Desktop/Screenshot*.png | head -1)
    set -l remote_path /tmp/(date +%Y%m%d-%H%M%S).png
    ssh joao@desktop-v0i3imc "cat > $remote_path" < $latest; or return
    printf '%s' $remote_path | pbcopy
    echo $remote_path
end
