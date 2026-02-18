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

local patch_fff_responsive_preview_overlap

local function open_files_in_dir_once(directory)
    patch_fff_responsive_preview_overlap()
    local fff = require("fff")
    local current_base_path = require("fff.conf").get().base_path

    if not fff.change_indexing_directory(directory) then
        return
    end

    local is_responsive = vim.o.columns < 160
    local preview_size = is_responsive and 0.35 or 0.45
    local preview_position = is_responsive and "bottom" or "right"
    fff.find_files({
        prompt = "",
        title = "Find files",
        layout = {
            width = telescope_sized_ratio(400, vim.o.columns),
            height = telescope_sized_ratio(100, vim.o.lines),
            prompt_position = "top",
            preview_position = preview_position,
            preview_size = preview_size,
        },
    })

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

patch_fff_responsive_preview_overlap = function()
    local ok_picker_ui, picker_ui = pcall(require, "fff.picker_ui")
    if not ok_picker_ui or type(picker_ui) ~= "table" then
        return
    end

    if picker_ui._responsive_preview_overlap_patch then
        return
    end

    local original_calculate_layout_dimensions = picker_ui.calculate_layout_dimensions
    if type(original_calculate_layout_dimensions) ~= "function" then
        return
    end

    picker_ui.calculate_layout_dimensions = function(cfg)
        local layout = original_calculate_layout_dimensions(cfg)

        if cfg and cfg.preview_position == "bottom" and layout and layout.preview then
            local min_row_from_list = (layout.list_row or 0) + (layout.list_height or 0) + 2
            local min_row_from_input = (layout.input_row or 0) + 3
            local min_preview_row = math.max(min_row_from_list, min_row_from_input)

            if type(layout.preview.row) == "number" and layout.preview.row < min_preview_row then
                layout.preview.row = min_preview_row
            end
        end

        return layout
    end

    picker_ui._responsive_preview_overlap_patch = true
end

return {
    "dmtrKovalenko/fff.nvim",
    enabled = false,
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
    config = function(_, opts)
        patch_fff_responsive_preview_overlap()
        require("fff").setup(opts)
    end,
    lazy = false,
    keys = {
        {
            "<leader><space>",
            function()
                patch_fff_responsive_preview_overlap()
                local is_responsive = vim.o.columns < 160
                local preview_size = is_responsive and 0.35 or 0.45
                local preview_position = is_responsive and "bottom" or "right"
                require("fff").find_files({
                    prompt = "",
                    title = "Find files",
                    layout = {
                        width = telescope_sized_ratio(400, vim.o.columns),
                        height = telescope_sized_ratio(100, vim.o.lines),
                        prompt_position = "top",
                        preview_position = preview_position,
                        preview_size = preview_size,
                    },
                })
            end,
            desc = "FFFind files",
        },
        {
            "<leader>/",
            function()
                patch_fff_responsive_preview_overlap()
                local is_responsive = vim.o.columns < 160
                local preview_size = is_responsive and 0.35 or 0.45
                local preview_position = is_responsive and "bottom" or "right"
                require("fff").live_grep({
                    prompt = "",
                    title = "Live Grep",
                    layout = {
                        width = telescope_sized_ratio(400, vim.o.columns),
                        height = telescope_sized_ratio(100, vim.o.lines),
                        prompt_position = "top",
                        preview_position = preview_position,
                        preview_size = preview_size,
                    },
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
