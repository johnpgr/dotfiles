-- Custom blink.cmp source for opencode context placeholders
-- Provides autocomplete for @this, @buffer, @buffers, etc.

local M = {}

-- Define all opencode context placeholders
local contexts = {
    { label = "@this", description = "Operator range or visual selection if any, else cursor position" },
    { label = "@buffer", description = "Current buffer" },
    { label = "@buffers", description = "Open buffers" },
    { label = "@visible", description = "Visible text" },
    { label = "@diagnostics", description = "Current buffer diagnostics" },
    { label = "@quickfix", description = "Quickfix list" },
    { label = "@diff", description = "Git diff" },
    { label = "@marks", description = "Global marks" },
    { label = "@grapple", description = "grapple.nvim tags" },
}

---@class blink.cmp.Source
local source = {}

function source.new()
    return setmetatable({}, { __index = source })
end

function source:get_completions(ctx, callback)
    local items = {}
    local Kind = require("blink.cmp.types").CompletionItemKind

    for _, ctx_item in ipairs(contexts) do
        table.insert(items, {
            label = ctx_item.label,
            kind = Kind.Variable,
            documentation = ctx_item.description,
            insertText = ctx_item.label,
        })
    end

    callback({
        items = items,
        is_incomplete_forward = false,
        is_incomplete_backward = false,
    })
end

function source:should_show_completions(ctx, config)
    -- Only show in DressingInput buffers
    if vim.bo.filetype ~= "DressingInput" then
        return false
    end
    
    -- Check if we're triggered by "@" character
    local trigger_char = ctx.trigger.character
    if trigger_char == "@" then
        return true
    end
    
    -- Show if we're typing after "@"
    local line = ctx.line
    local col = ctx.cursor[2]
    local before_cursor = line:sub(1, col)
    
    -- Match @ followed by word characters
    if before_cursor:match("@%w*$") then
        return true
    end
    
    return false
end

function source:get_trigger_characters()
    return { "@" }
end

M.new = source.new

return M
