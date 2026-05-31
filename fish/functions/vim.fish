function vim --wraps=vim --description 'system vim wrapper to prevent vendor vi override'
    command vim $argv
end
