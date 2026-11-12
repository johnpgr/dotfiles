function claude-ds --description "Run Claude Code against the DeepSeek API (V4.1 Flash)"
    set -l key (pass show api/deepseek 2>/dev/null)
    or begin
        echo "claude-ds: cannot read api/deepseek from pass" >&2
        return 1
    end

    # DeepSeek recommends max, but max spent most of a routine review-fix task thinking.
    set -l effort high
    set -q CLAUDE_CODE_EFFORT_LEVEL; and set effort $CLAUDE_CODE_EFFORT_LEVEL

    env -u ANTHROPIC_API_KEY \
        ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic \
        ANTHROPIC_AUTH_TOKEN=$key \
        ANTHROPIC_MODEL='deepseek-flash[1m]' \
        ANTHROPIC_DEFAULT_OPUS_MODEL='deepseek-flash[1m]' \
        ANTHROPIC_DEFAULT_SONNET_MODEL='deepseek-flash[1m]' \
        ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-flash \
        CLAUDE_CODE_SUBAGENT_MODEL=deepseek-flash \
        CLAUDE_CODE_EFFORT_LEVEL=$effort \
        CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432 \
        claude --dangerously-skip-permissions \
        --append-system-prompt "When several edits or reads do not depend on each other, issue them as parallel tool calls in one response instead of one per turn." \
        $argv
end
