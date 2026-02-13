local M = {}

M.config_db_uri = vim.fn.stdpath("data") .. "/nvim_config.db"
M.is_neovide = vim.g.neovide ~= nil
M.is_kitty = os.getenv("TERM") == "xterm-kitty" or os.getenv("TERM") == "xterm-ghostty" or os.getenv("TERM") == "wezterm"

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
        borderchars = {
            { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
            prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
            results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
            preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
        },
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

    require("telescope.builtin").current_buffer_fuzzy_find(opts)
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

function M.find_symbol_by_lang()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local conf = require("telescope.config").values

    local languages = {
        "Javascript/Typescript",
        "Rust",
        "Python",
        "Lua",
        "C++",
    }

    local symbol_kinds = {
        "functions",
        "interfaces",
        "classes",
        "variables",
        "any",
    }

    local lang_configs = {
        ["Javascript/Typescript"] = {
            glob = "*.{js,ts,jsx,tsx}",
            symbols = {
                functions = "(function\\s+|const\\s+\\w+\\s*=\\s*.*=>)",
                interfaces = "interface\\s+\\w+",
                classes = "class\\s+\\w+",
                variables = "(const|let|var)\\s+\\w+",
                any = "",
            },
        },
        ["Rust"] = {
            glob = "*.rs",
            symbols = {
                functions = "fn\\s+\\w+",
                interfaces = "trait\\s+\\w+",
                classes = "(struct|enum|union)\\s+\\w+",
                variables = "let\\s+(mut\\s+)?\\w+",
                any = "",
            },
        },
        ["Python"] = {
            glob = "*.py",
            symbols = {
                functions = "def\\s+\\w+",
                interfaces = "class\\s+\\w+",
                classes = "class\\s+\\w+",
                variables = "\\w+\\s*=\\s*",
                any = "",
            },
        },
        ["Lua"] = {
            glob = "*.lua",
            symbols = {
                functions = "function\\s+\\w+",
                interfaces = "---@class\\s+\\w+",
                classes = "---@class\\s+\\w+",
                variables = "local\\s+\\w+",
                any = "",
            },
        },
        ["C++"] = {
            glob = "*.{cpp,h,hpp,cc,c}",
            symbols = {
                functions = "\\w+\\s+\\w+\\(",
                interfaces = "class\\s+\\w+",
                classes = "class\\s+\\w+",
                variables = "(int|float|double|char|auto|bool)\\s+\\w+",
                any = "",
            },
        },
    }

    pickers
        .new({}, {
            prompt_title = "Select Symbol Kind",
            finder = finders.new_table({
                results = symbol_kinds,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    local selected_symbol = selection[1]

                    pickers
                        .new({}, {
                            prompt_title = "Select Language",
                            finder = finders.new_table({
                                results = languages,
                            }),
                            sorter = conf.generic_sorter({}),
                            attach_mappings = function(prompt_bufnr_lang, map_lang)
                                actions.select_default:replace(function()
                                    actions.close(prompt_bufnr_lang)
                                    local lang_selection = action_state.get_selected_entry()
                                    local selected_lang = lang_selection[1]

                                    local config = lang_configs[selected_lang]
                                    local pattern = config.symbols[selected_symbol] or ""
                                    local glob = config.glob

                                    M.live_multi_grep({
                                        symbol_pattern = pattern,
                                        file_pattern = glob,
                                        prompt_title = "Searching " .. selected_lang .. " " .. selected_symbol,
                                    })
                                end)
                                return true
                            end,
                        })
                        :find()
                end)
                return true
            end,
        })
        :find()
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
            local args = { "rg" }

            if opts.symbol_pattern then
                -- Use PCRE2 for lookarounds to simulate AND logic (Symbol Definition AND User Query)
                table.insert(args, "-P")

                local pattern = "^(?=.*" .. opts.symbol_pattern .. ")"
                if prompt and prompt ~= "" then
                    pattern = pattern .. "(?=.*" .. prompt .. ")"
                end

                table.insert(args, "-e")
                table.insert(args, pattern)

                if opts.file_pattern then
                    table.insert(args, "-g")
                    table.insert(args, opts.file_pattern)
                end
            else
                if not prompt or prompt == "" then
                    return nil
                end

                local pieces = vim.split(prompt, "  ")

                if pieces[1] then
                    table.insert(args, "-e")
                    table.insert(args, pieces[1])
                end

                if pieces[2] then
                    table.insert(args, "-g")
                    table.insert(args, pieces[2])
                end
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
            prompt_title = opts.prompt_title or "Live grep",
            sorter = sorters.empty(),
        })
        :find()
end

M.editorconfig = [[
# EditorConfig is awesome: https://editorconfig.org

# top-most EditorConfig file
root = true

# Unix-style newlines with a newline ending every file
[*]
end_of_line = lf
insert_final_newline = true

# Matches multiple files with brace expansion notation
# Set default charset
[*.{js,py}]
charset = utf-8

# 4 space indentation
[*.py]
indent_style = space
indent_size = 4

# Tab indentation (no size specified)
[Makefile]
indent_style = tab

# Indentation override for all JS under lib directory
[lib/**.js]
indent_style = space
indent_size = 2

# Matches the exact files either package.json or .travis.yml
[{package.json,.travis.yml}]
indent_style = space
indent_size = 2
]]

return M
