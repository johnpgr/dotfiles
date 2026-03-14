local M = {}

local uv = vim.uv or vim.loop
local colorscheme_file = vim.fn.stdpath("config") .. "/.colorscheme"
local theme_state_file = vim.fs.joinpath(vim.loop.os_homedir(), ".dotfiles", ".theme_state")
local theme_state_dir = vim.fs.dirname(theme_state_file)
local theme_state_name = vim.fs.basename(theme_state_file)

local theme_state_watcher
local theme_state_timer
local last_applied_mode
local theme_apply_in_progress = false
local theme_sync_pending = false

local function close_handle(handle)
    if handle and not handle:is_closing() then
        handle:close()
    end
end

local function read_theme_state()
    local f = io.open(theme_state_file, "r")
    if not f then
        return nil
    end

    local mode = f:read("*all")
    f:close()

    mode = mode and vim.trim(mode) or ""
    if mode == "dark" or mode == "light" then
        return mode
    end

    return nil
end

local function current_colorscheme()
    local colors_name = vim.g.colors_name
    if type(colors_name) == "string" and colors_name ~= "" then
        return colors_name
    end

    return nil
end

local function apply_theme_state_now(mode, opts)
    opts = opts or {}
    if mode ~= "dark" and mode ~= "light" then
        return false
    end

    if theme_apply_in_progress then
        theme_sync_pending = true
        return false
    end

    if mode == last_applied_mode and not opts.force then
        return false
    end

    theme_apply_in_progress = true

    local ok, err = pcall(function()
        vim.o.background = mode

        if opts.reapply_colorscheme ~= false then
            local colors_name = current_colorscheme()
            if colors_name then
                vim.cmd.colorscheme(colors_name)
            end
        end
    end)

    theme_apply_in_progress = false

    if ok then
        last_applied_mode = mode
    else
        vim.notify("Unable to apply theme state: " .. err, vim.log.levels.WARN)
    end

    if theme_sync_pending then
        theme_sync_pending = false
        vim.schedule(function()
            M.sync_theme_state({ force = true })
        end)
    end

    return ok
end

local function debounce_theme_sync()
    if not uv or not uv.new_timer then
        M.sync_theme_state()
        return
    end

    if theme_state_timer and theme_state_timer:is_closing() then
        theme_state_timer = nil
    end

    if not theme_state_timer then
        theme_state_timer = uv.new_timer()
    end

    if not theme_state_timer then
        M.sync_theme_state()
        return
    end

    theme_state_timer:stop()
    theme_state_timer:start(100, 0, vim.schedule_wrap(function()
        M.sync_theme_state()
    end))
end

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

    M.sync_theme_state({ force = true })
end

function M.apply_theme_state(mode, opts)
    if mode ~= "dark" and mode ~= "light" then
        return false
    end

    if vim.in_fast_event() then
        vim.schedule(function()
            apply_theme_state_now(mode, opts)
        end)
        return true
    end

    return apply_theme_state_now(mode, opts)
end

function M.sync_theme_state(opts)
    return M.apply_theme_state(read_theme_state(), opts)
end

function M.start_theme_state_watcher()
    if theme_state_watcher or not uv or not uv.new_fs_event then
        return false
    end

    theme_state_watcher = uv.new_fs_event()
    if not theme_state_watcher then
        return false
    end

    local ok, err = theme_state_watcher:start(theme_state_dir, {}, function(watch_err, filename)
        if watch_err then
            vim.schedule(function()
                vim.notify("Theme watcher error: " .. watch_err, vim.log.levels.WARN)
            end)
            return
        end

        if filename and filename ~= theme_state_name then
            return
        end

        debounce_theme_sync()
    end)

    if not ok then
        close_handle(theme_state_watcher)
        theme_state_watcher = nil
        vim.notify("Unable to start theme watcher: " .. err, vim.log.levels.WARN)
        return false
    end

    return true
end

function M.stop_theme_state_watcher()
    if theme_state_timer then
        theme_state_timer:stop()
        close_handle(theme_state_timer)
        theme_state_timer = nil
    end

    if theme_state_watcher then
        theme_state_watcher:stop()
        close_handle(theme_state_watcher)
        theme_state_watcher = nil
    end
end

function M.set_theme(mode)
    return M.apply_theme_state(mode)
end

return M
