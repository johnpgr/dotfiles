function clipboard_png --description "Write the clipboard image to stdout as PNG (macOS and Linux)"
    if command -q pngpaste
        command pngpaste - # macOS; exits 1 when the clipboard holds no image
        return $status
    end
    if command -q wl-paste
        command wl-paste --type image/png # Wayland
        return $status
    end
    if command -q xclip
        command xclip -selection clipboard -t image/png -o # X11
        return $status
    end
    echo clipboard_png: no clipboard image tool found >&2
    return 1
end
