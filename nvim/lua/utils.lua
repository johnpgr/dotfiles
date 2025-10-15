local M = {}

M.config_db_uri = vim.fn.stdpath("data") .. "/nvim_config.db"
M.is_neovide = vim.g.neovide ~= nil
M.is_kitty = os.getenv("TERM") == "xterm-kitty"

-- Fuzzy find within the current buffer with live preview navigation
--
-- This function provides an enhanced telescope fuzzy finder for the current buffer that:
-- - Automatically jumps to selected lines as you navigate through results
-- - Centers the cursor on the target line when jumping
-- - Updates the search register (/) with the current search term for highlighting
-- - Supports sending results to quickfix list with <C-q>
-- - Uses exact matching instead of fuzzy matching for more precise results
--
-- Key features:
-- - Live preview: Cursor jumps to lines as you move through search results
-- - Search term highlighting: Automatically sets hlsearch with current query
-- - Safe navigation: Validates line numbers and cursor positions before jumping
-- - Quickfix integration: Send all matching results to quickfix list
-- - Mark integration: Sets a mark (') before jumping to preserve jump history
--
-- Keybindings:
-- - <Down>/<C-n>/j: Move to next result and jump to line
-- - <Up>/<C-p>/k: Move to previous result and jump to line
-- - <CR>: Jump to selected line and close picker
-- - <C-q>: Send all results to quickfix list and open it
function M.fuzzy_find_current_buffer()
    local original_win = vim.api.nvim_get_current_win()
    local original_bufnr = vim.api.nvim_get_current_buf()

    local action_state = require("telescope.actions.state")
    local actions = require("telescope.actions")
    local themes = require("telescope.themes")

    local opts = themes.get_ivy({
        previewer = false,
        borderchars = { " ", " ", " ", " ", " ", " ", " ", " " },
        layout_config = {
            height = 12,
        },
        results_title = false,
        fuzzy = false,
        exact = true,
        attach_mappings = function(prompt_bufnr, map)
            local function jump_to_selection()
                local selection = action_state.get_selected_entry()
                if selection and selection.lnum then
                    local line_count = vim.api.nvim_buf_line_count(original_bufnr)

                    if selection.lnum > 0 and selection.lnum <= line_count then
                        local line = vim.api.nvim_buf_get_lines(
                            original_bufnr,
                            selection.lnum - 1,
                            selection.lnum,
                            false
                        )[1] or ""
                        local col = math.min(selection.col or 0, #line)

                        vim.schedule(function()
                            if vim.api.nvim_win_is_valid(original_win) then
                                vim.api.nvim_win_call(original_win, function()
                                    vim.cmd("normal! m'")
                                    vim.api.nvim_win_set_cursor(original_win, { selection.lnum, col })
                                    vim.cmd("normal! zz")
                                end)
                            end
                        end)
                    end
                end
            end

            actions.select_default:replace(function()
                jump_to_selection()
                actions.close(prompt_bufnr)
            end)

            local move_selection_next = function()
                actions.move_selection_next(prompt_bufnr)
                jump_to_selection()
            end

            local move_selection_previous = function()
                actions.move_selection_previous(prompt_bufnr)
                jump_to_selection()
            end

            map("i", "<Down>", move_selection_next)
            map("i", "<C-n>", move_selection_next)
            map("i", "<Up>", move_selection_previous)
            map("i", "<C-p>", move_selection_previous)

            map("n", "j", move_selection_next)
            map("n", "k", move_selection_previous)

            map("i", "<C-q>", function()
                actions.send_to_qflist(prompt_bufnr)
                vim.cmd("copen")
            end)

            map("n", "<C-q>", function()
                actions.send_to_qflist(prompt_bufnr)
                vim.cmd("copen")
            end)

            return true
        end,
        on_input_filter_cb = function(prompt)
            if prompt and #prompt > 0 then
                vim.fn.setreg("/", prompt)
                vim.cmd("let v:hlsearch=1")
            end
            return prompt
        end,
    })

    local utils = require "telescope.utils"
    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local conf = require("telescope.config").values
    local make_entry = require "telescope.make_entry"

    opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

    -- All actions are on the current buffer
    local filename = vim.api.nvim_buf_get_name(opts.bufnr)
    local filetype = vim.api.nvim_buf_get_option(opts.bufnr, "filetype")

    local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
    local lines_with_numbers = {}

    for lnum, line in ipairs(lines) do
        table.insert(lines_with_numbers, {
            lnum = lnum,
            bufnr = opts.bufnr,
            filename = filename,
            text = line,
        })
    end

    opts.results_ts_highlight = vim.F.if_nil(opts.results_ts_highlight, true)
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    if opts.results_ts_highlight and lang and utils.has_ts_parser(lang) then
        local parser = vim.treesitter.get_parser(opts.bufnr, lang)
        local query = vim.treesitter.query.get(lang, "highlights")
        local root = parser:parse()[1]:root()

        local line_highlights = setmetatable({}, {
            __index = function(t, k)
                local obj = {}
                rawset(t, k, obj)
                return obj
            end,
        })

        for id, node in query:iter_captures(root, opts.bufnr, 0, -1) do
            local hl = "@" .. query.captures[id]
            if hl and type(hl) ~= "number" then
                local row1, col1, row2, col2 = node:range()

                if row1 == row2 then
                    local row = row1 + 1

                    for index = col1, col2 do
                        line_highlights[row][index] = hl
                    end
                else
                    local row = row1 + 1
                    for index = col1, #lines[row] do
                        line_highlights[row][index] = hl
                    end

                    while row < row2 + 1 do
                        row = row + 1

                        for index = 0, #(lines[row] or {}) do
                            line_highlights[row][index] = hl
                        end
                    end
                end
            end
        end

        opts.line_highlights = line_highlights
    end

    local picker = pickers.new(opts, {
        prompt_title = "Current Buffer Fuzzy",
        finder = finders.new_table({
            results = lines_with_numbers,
            entry_maker = opts.entry_maker or make_entry.gen_from_buffer_lines(opts),
        }),
        sorter = conf.generic_sorter(opts),
        previewer = conf.grep_previewer(opts),
        attach_mappings = function()
            actions.select_default:replace(function(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if not selection then
                    utils.__warn_no_selection("builtin.current_buffer_fuzzy_find")
                    return
                end
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                local searched_for = require("telescope.actions.state").get_current_line()

                ---@type number[] | {start:number, end:number?, highlight:string?}[]
                local highlights = current_picker.sorter:highlighter(searched_for, selection.ordinal) or {}
                highlights = vim.tbl_map(function(hl)
                    if type(hl) == "table" and hl.start then
                        return hl.start
                    elseif type(hl) == "number" then
                        return hl
                    end
                    error("Invalid higlighter fn")
                end, highlights)

                local first_col = 0
                if #highlights > 0 then
                    first_col = math.min(unpack(highlights)) - 1
                end

                actions.close(prompt_bufnr)
                vim.schedule(function()
                    vim.cmd("normal! m'")
                    vim.api.nvim_win_set_cursor(0, { selection.lnum, first_col })
                end)
            end)

            return true
        end,
    })

    if picker.layout_config.flip_columns then
        picker.layout_config.flip_columns = nil
    end

    picker:find()
end

function M.jump_to_error_loc()
    local line = vim.fn.getline(".")
    local file, lnum, col = string.match(line, "([^:]+):(%d+):(%d+)")

    if not (file and lnum and col) then
        return false
    end

    if vim.fn.filereadable(file) ~= 1 then
        vim.notify("File not found: " .. file, vim.log.levels.ERROR)
        return false
    end

    lnum = tonumber(lnum)
    col = tonumber(col)

    local bufnr = vim.fn.bufnr(vim.fn.fnamemodify(file, ":p"))
    local win_id = nil

    if bufnr ~= -1 then
        local wins = vim.fn.getbufinfo(bufnr)[1].windows
        if #wins > 0 then
            win_id = wins[1]
        end
    end

    if win_id then
        vim.fn.win_gotoid(win_id)
    else
        local window_above = vim.fn.winnr("#")

        if window_above ~= 0 then
            vim.cmd("wincmd k")
            vim.cmd("edit " .. file)
        else
            vim.cmd("topleft split " .. file)
        end
    end

    vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
    vim.cmd("normal! zz")

    return true
end

function M.live_multi_grep(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or vim.uv.cwd()

    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local make_entry = require("telescope.make_entry")
    local sorters = require("telescope.sorters")
    local config = require("telescope.config").values

    local finder = finders.new_async_job({
        command_generator = function(prompt)
            if not prompt or prompt == "" then
                return nil
            end

            local pieces = vim.split(prompt, "  ")
            local args = { "rg" }

            if pieces[1] then
                table.insert(args, "-e")
                table.insert(args, pieces[1])
            end

            if pieces[2] then
                table.insert(args, "-g")
                table.insert(args, pieces[2])
            end

            ---@diagnostic disable-next-line: deprecated
            return vim.tbl_flatten({
                args,
                { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
            })
        end,
        entry_maker = make_entry.gen_from_vimgrep(opts),
        cwd = opts.cwd,
    })

    pickers
        .new(opts, {
            previewer = config.grep_previewer(opts),
            debounce = 100,
            finder = finder,
            prompt_title = "Live grep",
            sorter = sorters.empty(),
        })
        :find()
end

return M
