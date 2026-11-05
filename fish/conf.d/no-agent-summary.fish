# Suppress Claude Code agent_summary side-queries (https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce).
set -l preload "--preload=$HOME/.local/share/no-agent-summary.js"
if not string match -q -- "*$preload*" "$BUN_OPTIONS"
    set -gx BUN_OPTIONS (string trim -- "$BUN_OPTIONS $preload")
end
