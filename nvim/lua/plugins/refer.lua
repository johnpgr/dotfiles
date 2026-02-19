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

local uv = vim.uv or vim.loop
local dired_stats_cache = {}
local dired_line_lookup = nil
local dired_name_col_width = 0
local dired_highlight_patch_applied = false
local path_sep = package.config:sub(1, 1)

local function is_path_sep(char)
    return char == "/" or char == "\\"
end

local function ends_with_path_sep(path)
    return is_path_sep(path:sub(-1))
end

local function find_last_path_sep(path)
    for i = #path, 1, -1 do
        if is_path_sep(path:sub(i, i)) then
            return i
        end
    end
    return nil
end

local function ensure_dired_highlight_groups()
    vim.api.nvim_set_hl(0, "ReferDiredDir", { default = true, link = "Directory" })
    vim.api.nvim_set_hl(0, "ReferDiredFile", { default = true, link = "Identifier" })
    vim.api.nvim_set_hl(0, "ReferDiredHidden", { default = true, link = "Comment" })
    vim.api.nvim_set_hl(0, "ReferDiredPermType", { default = true, fg = "#f7768e" })
    vim.api.nvim_set_hl(0, "ReferDiredPermRead", { default = true, fg = "#9ece6a" })
    vim.api.nvim_set_hl(0, "ReferDiredPermWrite", { default = true, fg = "#e0af68" })
    vim.api.nvim_set_hl(0, "ReferDiredPermExec", { default = true, fg = "#f7768e" })
    vim.api.nvim_set_hl(0, "ReferDiredPermOther", { default = true, fg = "#565f89" })
    vim.api.nvim_set_hl(0, "ReferDiredSize", { default = true, link = "Number" })
    vim.api.nvim_set_hl(0, "ReferDiredTime", { default = true, link = "Constant" })
end

local function permission_char_hl(char, index)
    if index == 1 then
        if char == "-" then
            return "ReferDiredPermOther"
        end
        return "ReferDiredPermType"
    end

    if char == "r" then
        return "ReferDiredPermRead"
    end
    if char == "w" then
        return "ReferDiredPermWrite"
    end
    if char == "x" or char == "s" or char == "t" then
        return "ReferDiredPermExec"
    end

    return "ReferDiredPermOther"
end

local function ensure_dired_result_highlight_patch()
    if dired_highlight_patch_applied then
        return
    end

    ensure_dired_highlight_groups()

    local highlight = require("refer.highlight")
    local original_highlight_entry = highlight.highlight_entry

    highlight.highlight_entry = function(buf, ns, line_idx, line, highlight_code, opts)
        local entry = dired_line_lookup and dired_line_lookup[line] or nil
        if not entry then
            return original_highlight_entry(buf, ns, line_idx, line, highlight_code, opts)
        end

        local function set_hl(col, end_col, hl_group, priority)
            if end_col <= col then
                return
            end
            pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_idx, col, {
                end_col = end_col,
                hl_group = hl_group,
                priority = priority or 90,
            })
        end

        local name_hl = entry.is_dir and "ReferDiredDir" or "ReferDiredFile"
        if entry.name:sub(1, 1) == "." then
            name_hl = entry.is_dir and "ReferDiredDir" or "ReferDiredHidden"
        end

        local name_len = #entry.display_name
        local perms_start = dired_name_col_width + 2
        local perms_end = perms_start + #entry.perms
        local size_start = perms_end + 2
        local size_end = size_start + 6
        local mtime_start = size_end + 2
        local mtime_end = mtime_start + #entry.mtime

        set_hl(0, name_len, name_hl, 92)
        for i = 1, #entry.perms do
            local char = entry.perms:sub(i, i)
            local hl = permission_char_hl(char, i)
            set_hl(perms_start + i - 1, perms_start + i, hl, 92)
        end
        set_hl(size_start, size_end, "ReferDiredSize", 92)
        set_hl(mtime_start, mtime_end, "ReferDiredTime", 92)
    end

    dired_highlight_patch_applied = true
end

local function path_join(base, name)
    if ends_with_path_sep(base) then
        return base .. name
    end
    return base .. path_sep .. name
end

local function parse_file_input(input)
    local query = input or ""
    if query == "" then
        return "", vim.fn.getcwd(), ""
    end

    if query == "~" then
        return "~" .. path_sep, vim.fn.expand("~"), ""
    end

    if ends_with_path_sep(query) then
        return query, vim.fn.fnamemodify(query, ":p"), ""
    end

    local sep = find_last_path_sep(query)
    if sep then
        local dir_input = query:sub(1, sep)
        local basename = query:sub(sep + 1)
        return dir_input, vim.fn.fnamemodify(dir_input, ":p"), basename
    end

    return "", vim.fn.getcwd(), query
end

local function input_up_one_level(input)
    local query = input or ""
    if query == "" then
        return ""
    end

    if query == "~" then
        return "~" .. path_sep
    end

    if query == "/" or query == "\\" then
        return query:sub(1, 1)
    end
    if query:match("^%a:[/\\]?$") then
        return query:sub(1, 2) .. path_sep
    end

    while #query > 1 and ends_with_path_sep(query) do
        if query:match("^%a:[/\\]$") then
            return query:sub(1, 2) .. path_sep
        end
        query = query:sub(1, -2)
    end

    local sep = find_last_path_sep(query)
    if not sep then
        return ""
    end

    if sep == 1 and is_path_sep(query:sub(1, 1)) then
        return query:sub(1, 1)
    end

    return query:sub(1, sep)
end

local function format_filesize(size)
    local bytes = tonumber(size) or 0
    if bytes < 1024 then
        return tostring(bytes)
    end

    local units = { "k", "m", "g", "t", "p" }
    local value = bytes
    for _, unit in ipairs(units) do
        value = value / 1024
        if value < 1024 then
            local rounded = math.floor(value + 0.5)
            if math.abs(value - rounded) < 0.05 then
                return string.format("%d%s", rounded, unit)
            end
            return string.format("%.1f%s", value, unit)
        end
    end

    return string.format("%.1fp", value)
end

local function format_mtime(mtime_sec)
    if not mtime_sec then
        return ""
    end

    local now = os.time()
    local delta = now - mtime_sec
    if delta < 0 then
        delta = 0
    end

    if delta < 60 then
        return "just now"
    end
    if delta < 3600 then
        return string.format("%d mins ago", math.floor(delta / 60))
    end
    if delta < 86400 then
        return string.format("%d hours ago", math.floor(delta / 3600))
    end
    if delta < 86400 * 7 then
        return string.format("%d days ago", math.floor(delta / 86400))
    end
    if delta < 86400 * 180 then
        return os.date("%b %d %H:%M", mtime_sec)
    end
    return os.date("%Y %b %d", mtime_sec)
end

local function filetype_prefix(entry_type)
    if entry_type == "directory" then
        return "d"
    end
    if entry_type == "link" then
        return "l"
    end
    if entry_type == "socket" then
        return "s"
    end
    if entry_type == "fifo" then
        return "p"
    end
    if entry_type == "char" then
        return "c"
    end
    if entry_type == "block" then
        return "b"
    end
    return "-"
end

local function scan_directory_with_stats(directory)
    local cache = dired_stats_cache[directory]
    local now_ms = uv.now()
    if cache and (now_ms - cache.timestamp_ms) < 500 then
        return cache.entries
    end

    local handle = uv.fs_scandir(directory)
    if not handle then
        return {}
    end

    local entries = {}
    while true do
        local name, entry_type = uv.fs_scandir_next(handle)
        if not name then
            break
        end

        local fullpath = path_join(directory, name)
        local stat = uv.fs_stat(fullpath) or {}
        local resolved_type = stat.type or entry_type
        local is_dir = resolved_type == "directory"
        local display_name = is_dir and (name .. path_sep) or name

        local perms = vim.fn.getfperm(fullpath)
        if perms == "" then
            perms = "---------"
        end

        table.insert(entries, {
            name = name,
            display_name = display_name,
            fullpath = fullpath,
            is_dir = is_dir,
            perms = filetype_prefix(resolved_type) .. perms,
            size = format_filesize(stat.size),
            mtime = format_mtime(stat.mtime and stat.mtime.sec),
        })
    end

    table.sort(entries, function(left, right)
        if left.is_dir ~= right.is_dir then
            return left.is_dir and not right.is_dir
        end
        return left.name:lower() < right.name:lower()
    end)

    dired_stats_cache[directory] = {
        timestamp_ms = now_ms,
        entries = entries,
    }

    return entries
end

local function build_file_results(entries, filter_query, show_hidden)
    local by_name = {}
    local names = {}
    for _, entry in ipairs(entries) do
        if show_hidden or entry.name:sub(1, 1) ~= "." then
            by_name[entry.display_name] = entry
            table.insert(names, entry.display_name)
        end
    end

    local fuzzy = require("refer.fuzzy")
    local ordered_names = fuzzy.filter(names, filter_query or "", { sorter = "native" })

    local max_name_len = 0
    for _, name in ipairs(ordered_names) do
        if #name > max_name_len then
            max_name_len = #name
        end
    end
    if max_name_len < 14 then
        max_name_len = 14
    end

    local lines = {}
    local lookup = {}
    for _, name in ipairs(ordered_names) do
        local entry = by_name[name]
        local line = string.format(
            "%-" .. max_name_len .. "s  %s  %6s  %s",
            name,
            entry.perms,
            entry.size,
            entry.mtime
        )
        table.insert(lines, line)
        lookup[line] = entry
    end

    return lines, lookup, max_name_len
end

local function replace_input_tail(input, new_tail)
    local query = input or ""
    local sep = find_last_path_sep(query)
    if sep then
        return query:sub(1, sep) .. new_tail
    end
    return new_tail
end

local function pick_files_consult_dired_style()
    ensure_dired_result_highlight_patch()

    local initial_dir = vim.fn.getcwd()
    if vim.bo.filetype == "oil" then
        local ok, oil = pcall(require, "oil")
        if ok and type(oil.get_current_dir) == "function" then
            local oil_dir = oil.get_current_dir()
            if type(oil_dir) == "string" and oil_dir ~= "" then
                initial_dir = oil_dir
            end
        end
    elseif vim.bo.buftype == "" then
        local buffer_path = vim.api.nvim_buf_get_name(0)
        if buffer_path ~= "" then
            local buffer_dir = vim.fn.fnamemodify(buffer_path, ":p:h")
            if type(buffer_dir) == "string" and buffer_dir ~= "" then
                initial_dir = buffer_dir
            end
        end
    end

    local default_text = vim.fn.fnamemodify(initial_dir, ":~")
    if not ends_with_path_sep(default_text) then
        default_text = default_text .. path_sep
    end

    local selection_lookup = {}
    local show_hidden = false

    require("refer").pick({}, nil, {
        prompt = "Find file: ",
        default_text = default_text,
        min_height = 8,
        on_change = function(query, update_ui_callback)
            local _, abs_dir, basename_filter = parse_file_input(query)
            local entries = scan_directory_with_stats(abs_dir)
            local results, lookup, name_col_width = build_file_results(entries, basename_filter, show_hidden)
            selection_lookup = lookup
            dired_line_lookup = lookup
            dired_name_col_width = name_col_width
            update_ui_callback(results)
        end,
        on_close = function()
            dired_line_lookup = nil
            dired_name_col_width = 0
        end,
        parser = function(selection)
            local entry = selection_lookup[selection]
            if entry and not entry.is_dir then
                return {
                    filename = entry.fullpath,
                    lnum = 1,
                    col = 1,
                }
            end
            return nil
        end,
        keymaps = {
            ["<Tab>"] = function(_, builtin)
                local first = builtin.picker.current_matches[1]
                if not first then
                    return
                end

                local entry = selection_lookup[first]
                if not entry then
                    return
                end

                local new_input = replace_input_tail(vim.api.nvim_get_current_line(), entry.display_name)
                builtin.picker.ui:update_input({ new_input })
                builtin.actions.refresh()
            end,
            ["<CR>"] = function(selection, builtin)
                local entry = selection and selection_lookup[selection] or nil
                if entry then
                    if entry.is_dir then
                        local new_input = replace_input_tail(vim.api.nvim_get_current_line(), entry.display_name)
                        builtin.picker.ui:update_input({ new_input })
                        builtin.actions.refresh()
                        return
                    end

                    builtin.actions.close()
                    vim.cmd("edit " .. vim.fn.fnameescape(entry.fullpath))
                    return
                end

                local raw_input = vim.api.nvim_get_current_line()
                if raw_input ~= "" then
                    builtin.actions.close()
                    vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.fnamemodify(raw_input, ":p")))
                end
            end,
            ["<C-w>"] = function(_, builtin)
                local new_input = input_up_one_level(vim.api.nvim_get_current_line())
                builtin.picker.ui:update_input({ new_input })
                builtin.actions.refresh()
            end,
            ["<C-BS>"] = function(_, builtin)
                local new_input = input_up_one_level(vim.api.nvim_get_current_line())
                builtin.picker.ui:update_input({ new_input })
                builtin.actions.refresh()
            end,
            ["<C-Backspace>"] = function(_, builtin)
                local new_input = input_up_one_level(vim.api.nvim_get_current_line())
                builtin.picker.ui:update_input({ new_input })
                builtin.actions.refresh()
            end,
            ["<C-h>"] = function(_, builtin)
                show_hidden = not show_hidden
                vim.notify(
                    show_hidden and "Refer files: hidden files enabled" or "Refer files: hidden files hidden",
                    vim.log.levels.INFO
                )
                builtin.actions.refresh()
            end,
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

local last_picker_session = nil
local active_picker_session = nil
local active_session_should_restore = false
local refer_picker_resume_patch_applied = false

local function get_picker_input_text(picker)
    if not picker or not picker.input_buf or not vim.api.nvim_buf_is_valid(picker.input_buf) then
        return ""
    end

    local lines = vim.api.nvim_buf_get_lines(picker.input_buf, 0, 1, false)
    return lines[1] or ""
end

local function capture_picker_state(picker)
    local state = {
        input = get_picker_input_text(picker),
        selected_index = nil,
        selected_value = nil,
        marked = {},
    }

    if type(picker.selected_index) == "number" then
        state.selected_index = picker.selected_index
    end

    if type(picker.current_matches) == "table" and type(state.selected_index) == "number" then
        state.selected_value = picker.current_matches[state.selected_index]
    end

    if type(picker.marked) == "table" then
        for item, is_marked in pairs(picker.marked) do
            if is_marked then
                state.marked[item] = true
            end
        end
    end

    return state
end

local function restore_picker_state(picker, state)
    if not picker or type(state) ~= "table" then
        return
    end

    local target_input = tostring(state.input or "")
    local needs_selection_restore = state.selected_value ~= nil or type(state.selected_index) == "number"
    local attempts = 0
    local max_attempts = 40
    local timer = uv.new_timer()
    if not timer then
        return
    end

    local function stop_timer()
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
    end

    local function apply_once()
        if not picker.input_buf or not vim.api.nvim_buf_is_valid(picker.input_buf) then
            return true
        end

        if get_picker_input_text(picker) ~= target_input then
            return true
        end

        if type(state.marked) == "table" then
            picker.marked = vim.deepcopy(state.marked)
        end

        local matches = type(picker.current_matches) == "table" and picker.current_matches or {}
        local target_index = nil

        if state.selected_value ~= nil then
            for idx, value in ipairs(matches) do
                if value == state.selected_value then
                    target_index = idx
                    break
                end
            end
        end

        if not target_index and type(state.selected_index) == "number" then
            if state.selected_index >= 1 and state.selected_index <= #matches then
                target_index = state.selected_index
            end
        end

        if target_index then
            picker.selected_index = target_index
        end

        if picker.render then
            picker:render()
        end

        if not needs_selection_restore then
            return true
        end

        return target_index ~= nil or attempts >= max_attempts
    end

    timer:start(0, 40, vim.schedule_wrap(function()
        attempts = attempts + 1
        if apply_once() then
            stop_timer()
        end
    end))
end

local function build_resume_aware_opts(opts, session, should_restore)
    local picker_opts = vim.deepcopy(opts or {})
    local original_on_close = picker_opts.on_close
    local picker_ref = nil
    local state_to_restore = nil

    if should_restore and session and session.state then
        state_to_restore = vim.deepcopy(session.state)
        picker_opts.default_text = tostring(state_to_restore.input or "")
    end

    picker_opts.on_close = function()
        if session and picker_ref then
            session.state = capture_picker_state(picker_ref)
        end

        if original_on_close then
            original_on_close()
        end
    end

    return picker_opts, function(picker)
        picker_ref = picker
        if state_to_restore then
            restore_picker_state(picker, state_to_restore)
        end
    end
end

local function ensure_refer_picker_resume_patch()
    if refer_picker_resume_patch_applied then
        return
    end

    local ok, refer = pcall(require, "refer")
    if not ok then
        return
    end

    if type(refer.pick) ~= "function" or type(refer.pick_async) ~= "function" then
        return
    end

    local original_pick = refer.pick
    local original_pick_async = refer.pick_async

    refer.pick = function(items_or_provider, on_select, opts)
        local session = active_picker_session
        if not session then
            return original_pick(items_or_provider, on_select, opts)
        end

        local picker_opts, on_created = build_resume_aware_opts(opts, session, active_session_should_restore)
        local picker = original_pick(items_or_provider, on_select, picker_opts)
        on_created(picker)
        return picker
    end

    refer.pick_async = function(command_generator, on_select, opts)
        local session = active_picker_session
        if not session then
            return original_pick_async(command_generator, on_select, opts)
        end

        local picker_opts, on_created = build_resume_aware_opts(opts, session, active_session_should_restore)
        local picker = original_pick_async(command_generator, on_select, picker_opts)
        on_created(picker)
        return picker
    end

    refer_picker_resume_patch_applied = true
end

local function run_picker_session(session, should_restore)
    ensure_refer_picker_resume_patch()

    active_picker_session = session
    active_session_should_restore = should_restore == true

    local ok, result = pcall(session.runner)

    active_picker_session = nil
    active_session_should_restore = false

    if not ok then
        error(result)
    end

    return result
end

local function run_and_remember_picker(runner)
    last_picker_session = {
        runner = runner,
        state = nil,
    }
    return run_picker_session(last_picker_session, false)
end

local function resume_last_picker()
    if not last_picker_session then
        vim.notify("No picker to resume", vim.log.levels.INFO)
        return
    end

    return run_picker_session(last_picker_session, true)
end

local function open_refer_commands()
    vim.cmd("Refer Commands")
end

local function open_refer_files()
    pick_files_consult_dired_style()
end

local function open_refer_files_default()
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
        ensure_refer_picker_resume_patch()
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
            "<leader>ff",
            function()
                run_and_remember_picker(open_refer_files_default)
            end,
            desc = "Find file"
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
