function copy_clipboard --description "Copy stdin text to the system clipboard (macOS and Linux)"
    if command -q pbcopy
        command pbcopy
    else if command -q wl-copy
        command wl-copy
    else if command -q xclip
        command xclip -selection clipboard
    else if command -q xsel
        command xsel --clipboard --input
    else
        echo copy_clipboard: no clipboard tool found, install pbcopy, wl-clipboard, xclip or xsel >&2
        return 1
    end
end
