function ls --wraps=eza --description 'alias ls=eza with sensible defaults'
    eza --group-directories-first $argv
end
