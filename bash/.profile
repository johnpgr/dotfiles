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

# Suppress Claude Code agent_summary side-queries (https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce).
case " ${BUN_OPTIONS-} " in
    *" --preload=$HOME/.local/share/no-agent-summary.js "*) ;;
    *) export BUN_OPTIONS="${BUN_OPTIONS:+$BUN_OPTIONS }--preload=$HOME/.local/share/no-agent-summary.js" ;;
esac

# Finish environment setup before .bashrc replaces Bash with Fish.
case $- in
    *i*) [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc" ;;
esac


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"
