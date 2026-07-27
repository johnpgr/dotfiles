function claude-agy --description "Claude Code using Antigravity"
      env \
          ANTHROPIC_BASE_URL=http://127.0.0.1:8317 \
          ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY" \
          CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
          ANTHROPIC_DEFAULT_OPUS_MODEL=gemini-3.6-flash-high \
          ANTHROPIC_DEFAULT_SONNET_MODEL=gemini-3.6-flash-high \
          ANTHROPIC_DEFAULT_HAIKU_MODEL=gemini-3.1-flash-lite \
          claude --model gemini-3.6-flash-high $argv
end
