local function pick_files_in_dir(directory, prompt)
    local fd_cmd = vim.fn.executable("fdfind") == 1 and "fdfind" or "fd"

    require("refer.providers.files").files({
        prompt = prompt,
        providers = {
            files = {
                find_command = function(query)
                    local needle = (query or ""):sub(1, 2)
                    return {
                        fd_cmd,
                        "-H",
                        "--type",
                        "f",
                        "--color",
                        "never",
                        "--exclude",
                        ".git",
                        "--exclude",
                        ".jj",
                        "--exclude",
                        "node_modules",
                        "--exclude",
                        ".cache",
                        "--",
                        needle,
                        directory,
                    }
                end,
            },
        },
    })
end

local function escape_grep_string_chars(s)
    return (s:gsub("[%(|%)|\\|%[|%]|%-|%{%}|%?|%+|%*|%^|%$|%.]", {
        ["\\"] = "\\\\",
        ["-"] = "\\-",
        ["("] = "\\(",
        [")"] = "\\)",
        ["["] = "\\[",
        ["]"] = "\\]",
        ["{"] = "\\{",
        ["}"] = "\\}",
        ["?"] = "\\?",
        ["+"] = "\\+",
        ["*"] = "\\*",
        ["^"] = "\\^",
        ["$"] = "\\$",
        ["."] = "\\.",
    }))
end

local function set_search_highlight(query)
    if not query or query == "" then
        return
    end

    vim.opt.hlsearch = true
    vim.fn.setreg("/", "\\V" .. vim.fn.escape(query, "\\"))
end

local function default_live_grep_command(query)
    set_search_highlight(query)
    return { "rg", "--vimgrep", "--smart-case", "--", query }
end

local function list_colorschemes()
    local current = vim.api.nvim_exec2("colorscheme", { output = true }).output
    local colors = { current }
    local seen = { [current] = true }

    for _, color in ipairs(vim.fn.getcompletion("", "color")) do
        if not seen[color] then
            table.insert(colors, color)
            seen[color] = true
        end
    end

    local lazy = package.loaded["lazy.core.util"]
    if lazy and lazy.get_unloaded_rtp then
        local paths = lazy.get_unloaded_rtp("")
        if #paths > 0 then
            local files = vim.fn.globpath(table.concat(paths, ","), "colors/*", true, true)
            for _, file in ipairs(files) do
                local color = vim.fn.fnamemodify(file, ":t:r")
                if color ~= "" and not seen[color] then
                    table.insert(colors, color)
                    seen[color] = true
                end
            end
        end
    end

    return colors, current
end

local function pick_colorschemes()
    local before_background = vim.o.background
    local colors, before_color = list_colorschemes()
    local applied = false

    local function apply_preview(selection)
        if not selection or selection == "" then
            return
        end
        pcall(vim.cmd.colorscheme, selection)
    end

    local function persist_and_apply(selection, builtin)
        if not selection or selection == "" then
            return
        end

        applied = true
        require("colorscheme").persist_colorscheme(selection)
        pcall(vim.cmd.colorscheme, selection)
        if builtin then
            builtin.actions.close()
        end
    end

    require("refer").pick(colors, function(selection)
        persist_and_apply(selection)
    end, {
        prompt = "Change Colorscheme > ",
        on_change = function(query, update_ui_callback)
            local fuzzy = require("refer.fuzzy")
            local matches = fuzzy.filter(colors, query or "", { sorter = "native" })
            update_ui_callback(matches)
            apply_preview(matches[1])
        end,
        keymaps = {
            ["<CR>"] = function(selection, builtin)
                persist_and_apply(selection, builtin)
            end,
            ["<C-n>"] = function(_, builtin)
                builtin.actions.next_item()
                apply_preview(builtin.picker.current_matches[builtin.picker.selected_index])
            end,
            ["<C-p>"] = function(_, builtin)
                builtin.actions.prev_item()
                apply_preview(builtin.picker.current_matches[builtin.picker.selected_index])
            end,
            ["<Down>"] = function(_, builtin)
                builtin.actions.next_item()
                apply_preview(builtin.picker.current_matches[builtin.picker.selected_index])
            end,
            ["<Up>"] = function(_, builtin)
                builtin.actions.prev_item()
                apply_preview(builtin.picker.current_matches[builtin.picker.selected_index])
            end,
        },
        on_close = function()
            if not applied then
                vim.o.background = before_background
                pcall(vim.cmd.colorscheme, before_color)
            end
            vim.cmd("nohlsearch")
        end,
    })
end

local function option_value_to_text(value)
    if type(value) == "table" then
        return vim.inspect(value)
    end

    local text = tostring(value)
    text = text:gsub("\n", "\\n"):gsub("\t", "\\t")
    return text
end

local function pick_vim_options()
    local options = {}
    for _, option in pairs(vim.api.nvim_get_all_options_info()) do
        local ok, value = pcall(vim.api.nvim_get_option_value, option.name, {})
        if ok then
            table.insert(options, {
                name = option.name,
                type = option.type,
                scope = option.scope,
                value = value,
            })
        end
    end

    table.sort(options, function(left, right)
        return left.name < right.name
    end)

    local entries = {}
    local lookup = {}
    for _, option in ipairs(options) do
        local entry = string.format(
            "%-24s [%s] [%s] %s",
            option.name,
            option.type,
            option.scope,
            option_value_to_text(option.value)
        )
        table.insert(entries, entry)
        lookup[entry] = option
    end

    require("refer").pick(entries, function(selection)
        local option = lookup[selection]
        if not option then
            return
        end

        local esc = ""
        if vim.fn.mode() == "i" then
            esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
        end

        local cmd
        if option.type == "boolean" then
            cmd = string.format("%s:set %s!", esc, option.name)
        else
            cmd = string.format("%s:set %s=%s", esc, option.name, tostring(option.value))
        end

        vim.api.nvim_feedkeys(cmd, "m", true)
    end, {
        prompt = "Options > ",
        keymaps = {
            ["<CR>"] = "select_entry",
        },
    })
end

local function pick_spell_suggestions()
    local cursor_word = vim.fn.expand("<cword>")
    local suggestions = vim.fn.spellsuggest(cursor_word)

    require("refer").pick(suggestions, function(selection)
        if not selection or selection == "" then
            return
        end

        vim.cmd('normal! "_ciw' .. selection)
        vim.cmd("stopinsert")
    end, {
        prompt = "Spelling Suggestions > ",
        keymaps = {
            ["<CR>"] = "select_entry",
        },
    })
end

local function build_highlight_preview_lines()
    local output = vim.split(vim.fn.execute("highlight"), "\n", { trimempty = true })
    local lines = {}

    for _, line in ipairs(output) do
        if line ~= "" then
            if line:sub(1, 1) == " " and #lines > 0 then
                local continuation = line:match("%s+(.*)") or ""
                lines[#lines] = lines[#lines] .. continuation
            else
                table.insert(lines, line)
            end
        end
    end

    return lines
end

local function pick_highlights()
    local highlight_groups = vim.fn.getcompletion("", "highlight")
    if #highlight_groups == 0 then
        return
    end

    local preview_win = vim.api.nvim_get_current_win()
    local preview_buf = nil
    local preview_lines = build_highlight_preview_lines()
    local preview_line_by_group = {}

    local preview_ns = vim.api.nvim_create_namespace("refer_highlight_preview")
    local preview_cursor_ns = vim.api.nvim_create_namespace("refer_highlight_preview_cursor")
    local results_ns = vim.api.nvim_create_namespace("refer_highlight_results")

    for i, line in ipairs(preview_lines) do
        local group = line:match("^([^ ]+)")
        if group and not preview_line_by_group[group] then
            preview_line_by_group[group] = i
        end
    end

    local function ensure_preview_buffer()
        if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
            return preview_buf
        end

        preview_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[preview_buf].buftype = "nofile"
        vim.bo[preview_buf].bufhidden = "wipe"
        vim.bo[preview_buf].swapfile = false
        vim.bo[preview_buf].filetype = "vim"

        vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, preview_lines)

        for i, line in ipairs(preview_lines) do
            local start_pos = line:find("xxx", 1, true)
            local group = line:match("^([^ ]+)")
            if start_pos and group and vim.fn.hlexists(group) == 1 then
                pcall(vim.api.nvim_buf_set_extmark, preview_buf, preview_ns, i - 1, start_pos - 1, {
                    end_col = start_pos + 2,
                    hl_group = group,
                    priority = 90,
                })
            end
        end

        return preview_buf
    end

    local function highlight_results_buffer()
        local results_buf = nil
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "refer_results" then
                results_buf = buf
                break
            end
        end

        if not results_buf then
            return
        end

        vim.api.nvim_buf_clear_namespace(results_buf, results_ns, 0, -1)
        local lines = vim.api.nvim_buf_get_lines(results_buf, 0, -1, false)
        for i, line in ipairs(lines) do
            if vim.fn.hlexists(line) == 1 then
                pcall(vim.api.nvim_buf_set_extmark, results_buf, results_ns, i - 1, 0, {
                    end_col = #line,
                    hl_group = line,
                    priority = 95,
                })
            end
        end
    end

    local function show_highlight_preview(group, winid)
        if not group or group == "" then
            return
        end

        local target_win = winid
        if not target_win or not vim.api.nvim_win_is_valid(target_win) then
            target_win = preview_win
        end
        if not target_win or not vim.api.nvim_win_is_valid(target_win) then
            return
        end

        local buf = ensure_preview_buffer()
        vim.api.nvim_win_set_buf(target_win, buf)

        local lnum = preview_line_by_group[group] or 1
        pcall(vim.api.nvim_win_set_cursor, target_win, { lnum, 0 })

        vim.api.nvim_buf_clear_namespace(buf, preview_cursor_ns, 0, -1)
        pcall(vim.api.nvim_buf_set_extmark, buf, preview_cursor_ns, lnum - 1, 0, {
            line_hl_group = "Visual",
            priority = 120,
        })

        pcall(vim.api.nvim_win_call, target_win, function()
            vim.cmd("normal! zz")
        end)
    end

    local function after_move(builtin)
        local picker = builtin.picker
        local selection = picker.current_matches[picker.selected_index]
        show_highlight_preview(selection, picker.original_win)
        highlight_results_buffer()
    end

    require("refer").pick(highlight_groups, function(selection)
        if not selection or selection == "" then
            return
        end
        vim.cmd("hi " .. selection)
    end, {
        prompt = "Highlights > ",
        on_change = function(query, update_ui_callback)
            local fuzzy = require("refer.fuzzy")
            local matches = fuzzy.filter(highlight_groups, query or "", { sorter = "native" })
            update_ui_callback(matches)
            vim.schedule(function()
                highlight_results_buffer()
                show_highlight_preview(matches[1], preview_win)
            end)
        end,
        keymaps = {
            ["<CR>"] = "select_entry",
            ["<C-n>"] = function(_, builtin)
                builtin.actions.next_item()
                after_move(builtin)
            end,
            ["<C-p>"] = function(_, builtin)
                builtin.actions.prev_item()
                after_move(builtin)
            end,
            ["<Down>"] = function(_, builtin)
                builtin.actions.next_item()
                after_move(builtin)
            end,
            ["<Up>"] = function(_, builtin)
                builtin.actions.prev_item()
                after_move(builtin)
            end,
        },
        on_close = function()
            vim.cmd("nohlsearch")
            if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
                vim.api.nvim_buf_clear_namespace(preview_buf, preview_cursor_ns, 0, -1)
            end
        end,
    })
end

local function live_grep_current_buffer()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("Current buffer has no file path", vim.log.levels.WARN)
        return
    end

    require("refer.providers.files").live_grep({
        prompt = "Go to line > ",
        providers = {
            grep = {
                grep_command = function(query)
                    set_search_highlight(query)
                    return {
                        "rg",
                        "--line-number",
                        "--no-heading",
                        "--smart-case",
                        "--no-filename",
                        "--field-match-separator= ",
                        "--",
                        query,
                        filepath,
                    }
                end,
            },
        },
        parser = function(selection)
            local lnum, content = selection:match("^(%d+)%s(.*)$")
            if not lnum then
                return nil
            end

            return {
                filename = filepath,
                lnum = tonumber(lnum),
                col = 1,
                content = content,
            }
        end,
    })
end

local function get_grep_string_query(opts)
    opts = opts or {}

    local word
    local visual = vim.fn.mode() == "v"

    if visual then
        local saved_reg = vim.fn.getreg("v")
        vim.cmd([[noautocmd sil norm! "vy]])
        local selection = vim.fn.getreg("v")
        vim.fn.setreg("v", saved_reg)
        word = vim.F.if_nil(opts.search, selection)
    else
        word = vim.F.if_nil(opts.search, vim.fn.expand("<cword>"))
    end

    return tostring(word)
end

local function grep_string_with_refer(opts)
    opts = opts or {}
    local word = get_grep_string_query(opts)

    require("refer.providers.files").live_grep({
        prompt = "Find Word (" .. word:gsub("\n", "\\n") .. ") > ",
        default_text = word,
        min_query_len = 0,
        providers = {
            grep = {
                grep_command = function(query)
                    set_search_highlight(query)
                    local search = opts.use_regex and query or escape_grep_string_chars(query)

                    if search == "" then
                        return { "rg", "--vimgrep", "--smart-case", "-v", "--", "^[[:space:]]*$" }
                    end

                    return { "rg", "--vimgrep", "--smart-case", "--", search }
                end,
            },
        },
    })
end

local function pick_help_tags()
    local langs = vim.split(vim.o.helplang, ",", { trimempty = true })
    if not vim.tbl_contains(langs, "en") then
        table.insert(langs, "en")
    end

    local langs_map = {}
    for _, lang in ipairs(langs) do
        langs_map[lang] = true
    end

    local tag_files = {}
    local function add_tag_file(lang, file)
        if not langs_map[lang] then
            return
        end

        if not tag_files[lang] then
            tag_files[lang] = {}
        end
        table.insert(tag_files[lang], file)
    end

    local help_files = {}

    local rtp = vim.o.runtimepath
    local lazy = package.loaded["lazy.core.util"]
    if lazy and lazy.get_unloaded_rtp then
        local paths = lazy.get_unloaded_rtp("")
        if #paths > 0 then
            rtp = rtp .. "," .. table.concat(paths, ",")
        end
    end

    local all_files = vim.fn.globpath(rtp, "doc/*", true, true)
    for _, fullpath in ipairs(all_files) do
        local file = vim.fs.basename(fullpath)
        if file == "tags" then
            add_tag_file("en", fullpath)
        elseif file:match("^tags%-..$") then
            add_tag_file(file:sub(-2), fullpath)
        else
            help_files[file] = fullpath
        end
    end

    local tags = {}
    local lookup = {}
    local tags_map = {}

    for _, lang in ipairs(langs) do
        for _, file in ipairs(tag_files[lang] or {}) do
            for _, line in ipairs(vim.fn.readfile(file)) do
                if not line:match("^!_TAG_") then
                    local fields = vim.split(line, "\t", { trimempty = true })
                    if #fields == 3 and not tags_map[fields[1]] then
                        if fields[1] ~= "help-tags" or fields[2] ~= "tags" then
                            table.insert(tags, fields[1])
                            lookup[fields[1]] = fields[1] .. "@" .. lang
                            tags_map[fields[1]] = true
                        end
                    end
                end
            end
        end
    end

    if #tags == 0 then
        return
    end

    require("refer").pick(tags, function(selection)
        if not selection or selection == "" then
            return
        end

        local value = lookup[selection] or selection
        vim.cmd("help " .. vim.fn.fnameescape(value))
    end, {
        prompt = "Help > ",
        keymaps = {
            ["<CR>"] = "select_entry",
        },
    })
end

local last_picker_runner = nil

local function run_and_remember_picker(runner)
    last_picker_runner = runner
    return runner()
end

local function resume_last_picker()
    if not last_picker_runner then
        vim.notify("No picker to resume", vim.log.levels.INFO)
        return
    end

    return last_picker_runner()
end

local function open_refer_commands()
    vim.cmd("Refer Commands")
end

local function open_refer_files()
    vim.cmd("Refer Files")
end

local function open_refer_oldfiles()
    vim.cmd("Refer OldFiles")
end

local function open_refer_buffers()
    vim.cmd("Refer Buffers")
end

local function open_refer_grep()
    vim.cmd("Refer Grep")
end

local function open_refer_definitions()
    vim.cmd("Refer Definitions")
end

local function open_refer_references()
    vim.cmd("Refer References")
end

local function open_nvim_config_files()
    pick_files_in_dir(vim.fn.stdpath("config"), "Nvim Config Files > ")
end

local function open_lazy_data_files()
    pick_files_in_dir(vim.fn.stdpath("data") .. "/lazy", "Lazy Data Files > ")
end

return {
    "juniorsundar/refer.nvim",
    config = function()
        require("refer").setup({
            on_close = function()
                vim.cmd("nohlsearch")
            end,
            providers = {
                grep = {
                    grep_command = default_live_grep_command,
                },
            },
        })

        require("refer").setup_ui_select()
    end,
    keys = {
        {
            "<M-x>",
            function()
                run_and_remember_picker(open_refer_commands)
            end,
            desc = "commands"
        },
        {
            "<leader><space>",
            function()
                run_and_remember_picker(open_refer_files)
            end,
            desc = "Find Files"
        },
        {
            "<leader>sc",
            function()
                run_and_remember_picker(pick_colorschemes)
            end,
            desc = "Search colorscheme"
        },
        {
            "<leader>so",
            function()
                run_and_remember_picker(pick_vim_options)
            end,
            desc = "Search option"
        },
        {
            "<leader>ss",
            function()
                run_and_remember_picker(pick_spell_suggestions)
            end,
            desc = "Search spelling suggestion"
        },
        {
            "<leader>sH",
            function()
                run_and_remember_picker(pick_highlights)
            end,
            desc = "Search highlight group"
        },
        {
            "<leader>fr",
            function()
                run_and_remember_picker(open_refer_oldfiles)
            end,
            desc = "Old files"
        },
        {
            "<leader>fn",
            function()
                run_and_remember_picker(open_nvim_config_files)
            end,
            desc = "Find neovim config files"
        },
        {
            "<leader>fp",
            function()
                run_and_remember_picker(open_lazy_data_files)
            end,
            desc = "Find lazy data files"
        },
        {
            "<leader>,",
            function()
                run_and_remember_picker(open_refer_buffers)
            end,
            desc = "Buffers"
        },
        {
            "<leader>/",
            function()
                run_and_remember_picker(open_refer_grep)
            end,
            desc = "Grep"
        },
        {
            "<leader>sb",
            function()
                run_and_remember_picker(live_grep_current_buffer)
            end,
            desc = "Search buffer"
        },
        {
            "<leader>sh",
            function()
                run_and_remember_picker(pick_help_tags)
            end,
            desc = "Search help"
        },
        {
            "<leader>sw",
            function()
                run_and_remember_picker(grep_string_with_refer)
            end,
            mode = { "n", "v" },
            desc = "Search word with grep"
        },
        {
            "<leader>'",
            resume_last_picker,
            desc = "Resume last search"
        },
        {
            "gd",
            function()
                run_and_remember_picker(open_refer_definitions)
            end,
            desc = "Go to definitions"
        },
        {
            "gr",
            function()
                run_and_remember_picker(open_refer_references)
            end,
            desc = "Go to references"
        },
    }
}
