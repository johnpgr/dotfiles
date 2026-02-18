local M = {}

local colorscheme_file = vim.fn.stdpath("config") .. "/.colorscheme"

---@param colors_name string
function M.persist_colorscheme(colors_name)
    local f = io.open(colorscheme_file, "w")
    if not f then
        vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
        return
    end

    f:write(colors_name)
    f:close()
end

-- Load persisted colorscheme
function M.load_persisted_colorscheme()
    local f = io.open(colorscheme_file, "r")
    if f then
        local persisted = f:read("*all")
        f:close()

        persisted = persisted and vim.trim(persisted) or ""
        if persisted ~= "" then
            local ok = pcall(vim.cmd.colorscheme, persisted)
            if ok then
                vim.api.nvim_exec_autocmds("ColorScheme", { pattern = persisted })
            end
        end
    end

    -- Check system state file (managed by monitor_theme.py)
    local state_file = vim.fs.joinpath(vim.loop.os_homedir(), ".dotfiles", ".theme_state")
    f = io.open(state_file, "r")
    if f then
        local mode = f:read("*all")
        f:close()
        if mode then
            mode = string.gsub(mode, "\n", "")
            mode = string.gsub(mode, "%s+", "") -- trim whitespace

            if mode == "dark" or mode == "light" then
                vim.o.background = mode
            end
        end
    end

end

function M.set_theme(mode)
    vim.schedule(function()
        if mode == "dark" or mode == "light" then
            vim.o.background = mode
        end
    end)
end

return M
