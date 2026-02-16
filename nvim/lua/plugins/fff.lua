local function telescope_sized_ratio(max_size, available_size)
    if available_size <= 0 then
        return 1
    end

    local ratio = math.min(max_size, available_size) / available_size

    if max_size == 400 then
        return math.min(ratio, 0.92)
    end

    if max_size == 100 then
        return math.min(ratio, 0.88)
    end

    return ratio
end

local function open_files_in_dir_once(directory)
    local fff = require("fff")
    local current_base_path = require("fff.conf").get().base_path

    if not fff.change_indexing_directory(directory) then
        return
    end

    fff.find_files()

    local ok_picker_ui, picker_ui = pcall(require, "fff.picker_ui")
    if not ok_picker_ui or not picker_ui.state or not picker_ui.state.input_win then
        return
    end

    vim.api.nvim_create_autocmd("WinClosed", {
        once = true,
        pattern = tostring(picker_ui.state.input_win),
        callback = function()
            if current_base_path and current_base_path ~= directory then
                fff.change_indexing_directory(current_base_path)
            end
        end,
    })
end

return {
    "dmtrKovalenko/fff.nvim",
    build = function()
        require("fff.download").download_or_build_binary()
    end,
    opts = {
        prompt = "",
        title = "Find files",
        layout = {
            width = function(terminal_width)
                return telescope_sized_ratio(400, terminal_width)
            end,
            height = function(_, terminal_height)
                return telescope_sized_ratio(100, terminal_height)
            end,
            prompt_position = "top",
            preview_position = function(terminal_width)
                if terminal_width < 160 then
                    return "bottom"
                end

                return "right"
            end,
            preview_size = function(terminal_width)
                if terminal_width < 160 then
                    return 0.35
                end

                return 0.45
            end,
        },
    },
    lazy = false,
    keys = {
        {
            "<leader><space>", -- try it if you didn't it is a banger keybinding for a picker
            function()
                require("fff").find_files()
            end,
            desc = "FFFind files",
        },
        {
            "<leader>/",
            function()
                require("fff").live_grep({
                    grep = {
                        modes = { "fuzzy", "plain" },
                    },
                })
            end,
            desc = "Live fffuzy grep",
        },
        {
            "<leader>fn",
            function()
                open_files_in_dir_once(vim.fn.stdpath("config"))
            end,
            desc = "Browse .config/nvim",
        },
        {
            "<leader>sp",
            function()
                open_files_in_dir_once(vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"))
            end,
            desc = "Search file in plugins",
        },
    },
}
