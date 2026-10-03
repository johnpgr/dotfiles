# Editor configuration (conditional based on SSH)
if [ -n "$SSH_CONNECTION" ]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

export CARGO_INSTALL_ROOT="$HOME/.local"
export GOBIN="$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.opencode/bin"

[ -f "$HOME/.local/share/bob/env/env.sh" ] && . "$HOME/.local/share/bob/env/env.sh"
. "$HOME/.cargo/env"

# Finish environment setup before .bashrc replaces Bash with Fish.
case $- in
    *i*) [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc" ;;
esac
