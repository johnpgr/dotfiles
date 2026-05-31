function ls --wraps=eza --description 'alias ls=eza with sensible defaults'
    eza --icons --group-directories-first $argv
end
