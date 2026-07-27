function claude-codex --description "Claude Code using an OpenAI Codex subscription"
    env \
        ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
        ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY" \
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
        ANTHROPIC_DEFAULT_OPUS_MODEL=gpt-5.6-sol \
        ANTHROPIC_DEFAULT_SONNET_MODEL=gpt-5.6-terra \
        ANTHROPIC_DEFAULT_HAIKU_MODEL=gpt-5.6-luna \
        claude --model gpt-5.6-sol --effort high $argv
end
