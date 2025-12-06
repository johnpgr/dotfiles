local M = {}

-- HoleFill: Complete code at cursor placeholder
function M.hole_fill()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("Buffer has no file", vim.log.levels.ERROR)
        return
    end

    vim.cmd("write")
    local cmd = string.format("holefill \"%s\"", filepath)

    vim.notify("Running HoleFill...", vim.log.levels.INFO)

    vim.fn.jobstart(cmd, {
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                vim.cmd("edit!")
                vim.notify("HoleFill completed!", vim.log.levels.INFO)
            else
                vim.notify("HoleFill failed", vim.log.levels.ERROR)
            end
        end,
    })
end

-- ChatSH: Open terminal with AI chat
function M.chat(model)
    model = model or "o"
    local cmd = string.format("chatsh -%s", model)
    vim.cmd("split | terminal " .. cmd)
    vim.cmd("startinsert")
end

-- Refactor: AI-powered refactoring
function M.refactor(model)
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("Buffer has no file", vim.log.levels.ERROR)
        return
    end

    vim.cmd("write")

    model = model or "o"
    local cmd = string.format("refactor \"%s\" %s", filepath, model)

    vim.cmd("split | terminal " .. cmd)
    vim.cmd("startinsert")
end

-- CommitMsg: Generate commit message from staged changes
function M.commit_message(model)
    model = model or "g"
    local cmd = string.format("commitmsg --%s", model)

    vim.notify("Generating commit message...", vim.log.levels.INFO)

    local stdout_data = {}

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            stdout_data = data
        end,
        on_exit = function(_, exit_code)
            if exit_code == 0 and #stdout_data > 0 then
                local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, stdout_data)
                vim.notify("Commit message generated", vim.log.levels.INFO)
            else
                vim.notify("Failed to generate commit message", vim.log.levels.ERROR)
            end
        end,
    })
end

return M
