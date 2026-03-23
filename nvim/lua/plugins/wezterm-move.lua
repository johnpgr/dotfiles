local wezterm_directions = {
    h = "Left",
    j = "Down",
    k = "Up",
    l = "Right",
}

local function wezterm_cli_bin()
    if vim.fn.executable("wezterm.exe") == 1 then
        return "wezterm.exe"
    end

    return "wezterm"
end

local function activate_wezterm_pane(direction)
    vim.fn.system({
        wezterm_cli_bin(),
        "cli",
        "activate-pane-direction",
        wezterm_directions[direction],
    })

    if vim.v.shell_error ~= 0 then
        vim.notify("Unable to move to WezTerm pane", vim.log.levels.WARN)
    end
end

local function is_nvim_border(direction)
    return vim.fn.winnr() == vim.fn.winnr("1" .. direction)
end

local function is_nvim_float()
    return vim.api.nvim_win_get_config(0).relative ~= ""
end

local function move_within_nvim(direction)
    vim.cmd(string.format("%dwincmd %s", vim.v.count1, direction))
end

local function smart_move(direction)
    if vim.fn.getcmdwintype() ~= "" then
        return
    end

    local is_border = is_nvim_border(direction)
    if is_nvim_float() or is_border then
        activate_wezterm_pane(direction)
        return
    end

    move_within_nvim(direction)
end

return {
    "letieu/wezterm-move.nvim",
    lazy = true,
    config = function()
        require("wezterm-move").move = smart_move
    end,
    keys = {
        {
            "<C-h>",
            function()
                require("wezterm-move").move("h")
            end,
            desc = "Move left",
        },
        {
            "<C-j>",
            function()
                require("wezterm-move").move("j")
            end,
            desc = "Move down",
        },
        {
            "<C-k>",
            function()
                require("wezterm-move").move("k")
            end,
            desc = "Move up",
        },
        {
            "<C-l>",
            function()
                require("wezterm-move").move("l")
            end,
            desc = "Move right",
        },
    },
}
