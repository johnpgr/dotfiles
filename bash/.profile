# Editor configuration (conditional based on SSH)
if [ -n "$SSH_CONNECTION" ]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

export CARGO_INSTALL_ROOT="$HOME/.local"
export GOBIN="$HOME/.local/bin"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/.cargo/bin"

