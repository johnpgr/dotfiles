--- @module 'compile'
--- Interactive compilation runner for Neovim with .env support and output navigation.
local M = {}

--- @type string|nil
--- The last shell command executed by the user.
M.last_cmd = nil

--- @type string|nil
--- Path to the last .env file used (consumed once per execution).
M.last_env = nil
--- @type integer|nil
--- Handle to the current compile output window, if open.
M.compile_window = nil
M.compile_buffer = nil

--- @param cmd string
--- @return string
local function detect_errorformat(cmd)
    local ft = vim.bo.filetype
    local compiler = nil

    if cmd:match("zig") or ft == "zig" then
        compiler = "zig"
    elseif cmd:match("odin") or ft == "odin" then
        compiler = "odin"
    end

    if compiler and pcall(vim.cmd, "compiler " .. compiler) then
        return vim.bo.errorformat
    end

    return vim.go.errorformat
end

--- @param line string
--- @return string
local function clean_terminal_line(line)
    return (line:gsub("\27%[[0-9;]*m", ""):match("^%s*(.-)%s*$") or line)
end

--- @param buf integer
--- @param efm string
--- @param title string
--- @return integer
local function populate_quickfix(buf, efm, title)
    local lines = vim.tbl_map(clean_terminal_line, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    if #lines == 0 then
        return 0
    end

    vim.fn.setqflist({}, "r", {
        title = title,
        lines = lines,
        efm = efm,
    })

    return #vim.fn.getqflist()
end

--- @param line string
--- @param efm string
--- @return table|nil
local function parse_error_line(line, efm)
    local cleaned = clean_terminal_line(line)

    local file, lnum, col = cleaned:match("([^%s:]+[%w_%-%.\\]+):(%d+):(%d+):")
    if file then
        return {
            filename = file,
            lnum = tonumber(lnum),
            col = tonumber(col),
        }
    end

    local original_qf_state = vim.fn.getqflist({ all = 0 })
    vim.fn.setqflist({}, "r", { lines = { cleaned }, efm = efm })
    local qf_items = vim.fn.getqflist()
    vim.fn.setqflist({}, "r", {
        items = original_qf_state.items,
        title = original_qf_state.title,
    })

    return qf_items[1]
end

--- @param item table
--- @param cwd string
--- @return string|nil
local function resolve_qf_path(item, cwd)
    local path = item.filename
    if (path == nil or path == "") and item.bufnr and item.bufnr > 0 then
        path = vim.api.nvim_buf_get_name(item.bufnr)
    end
    if (path == nil or path == "") and item.module then
        path = item.module
    end
    if path == nil or path == "" then
        return nil
    end

    path = vim.fs.normalize(path)
    if vim.uv.fs_stat(path) then
        return path
    end

    local joined = vim.fs.normalize(vim.fs.joinpath(cwd, path))
    if vim.uv.fs_stat(joined) then
        return joined
    end

    return joined
end

--- @param efm string
--- @param cwd string
--- @param original_window integer
--- @param line string
--- @return nil
local function jump_to_error_line(efm, cwd, original_window, line)
    local item = parse_error_line(line, efm)
    if not item then
        vim.notify("Could not parse error on this line", vim.log.levels.WARN)
        return
    end

    local full_path = resolve_qf_path(item, cwd)
    if not full_path then
        vim.notify("Could not resolve file path on this line", vim.log.levels.WARN)
        return
    end
    if not vim.uv.fs_stat(full_path) then
        vim.notify("File not found: " .. full_path, vim.log.levels.WARN)
        return
    end

    if not vim.api.nvim_win_is_valid(original_window) then
        vim.notify("Original window is no longer valid", vim.log.levels.ERROR)
        return
    end

    local open_to_cmd = "edit +" .. item.lnum .. " " .. vim.fn.fnameescape(full_path)
    if type(item.col) == "number" and item.col > 0 then
        open_to_cmd = open_to_cmd .. " | normal! " .. item.col .. "|"
    end

    vim.fn.win_execute(original_window, open_to_cmd)
    vim.api.nvim_set_current_win(original_window)
end

--- @param target_win integer
--- @param which "next"|"prev"
--- @return nil
local function navigate_quickfix(target_win, which)
    local qf_list = vim.fn.getqflist()
    if #qf_list == 0 then
        return
    end

    if not vim.api.nvim_win_is_valid(target_win) then
        vim.notify("Source window is no longer valid", vim.log.levels.WARN)
        return
    end

    local current_idx = vim.fn.getqflist({ idx = 0 }).idx
    local cmd
    if which == "next" then
        cmd = current_idx >= #qf_list and "cfirst" or "cnext"
    else
        cmd = current_idx <= 1 and "clast" or "cprevious"
    end

    vim.fn.win_execute(target_win, cmd)
    vim.cmd("copen")
end

--- Closes the active compile output window and resets its handle.
--- Does nothing if no compile window is open.
--- @return nil
M.close_compile_window = function()
    if M.compile_buffer and vim.api.nvim_buf_is_valid(M.compile_buffer) then
        vim.api.nvim_buf_delete(M.compile_buffer, { force = true })
    end
    M.compile_buffer = nil

    if M.compile_window and vim.api.nvim_win_is_valid(M.compile_window) then
        vim.api.nvim_win_close(M.compile_window, true)
    end
    M.compile_window = nil
end

--- Prompts the user for a compilation command,
--- then executes the command via `M.executor`.
--- Uses `M.last_cmd` as default in prompts.
--- @return nil
M.command = function()
    local cmd = vim.fn.input('Compile command: ', M.last_cmd or "")

    if cmd == nil or cmd == "" then
        vim.notify("Compilation cancelled", vim.log.levels.WARN)
        return
    end

    M.executor(cmd)
end

--- Re-executes the last compilation command.
--- Shows an error if no prior command exists.
--- @return nil
M.run_last = function()
    if not M.last_cmd then
        vim.notify("No last command to run. Use :Compile first.", vim.log.levels.ERROR)
        return
    end
    M.executor(M.last_cmd)
end

--- Prompts the user for a `.env` file path (defaulting to `./.env`),
--- stores it in `M.last_env`, then invokes `M.command()`.
--- The `.env` file is sourced once during the next execution and then cleared.
--- @return nil
M.with_env = function()
    local env_file = vim.fn.input('Path to .env file: ', M.last_env or vim.fs.joinpath(vim.fn.getcwd(), ".env"), 'file')
    if env_file == nil or env_file == "" then
        vim.notify("Cancelled", vim.log.levels.WARN)
        return
    end
    M.last_env = env_file
    M.command()
end

--- Executes a shell command in the current working directory and streams output
--- to a dedicated scratch window named `[Compile]`.
--- - Closes any existing compile window.
--- - Sources `M.last_env` (if set) before the command and then unsets it.
--- - Supports clickable file paths (e.g., `file:line`) via `<CR>` mapping.
--- - Populates the quickfix list when the command finishes; use `]c` / `[c` to navigate.
--- - Press `q` to close the window.
--- @param cmd string Shell command to execute.
--- @return nil
M.executor = function(cmd)
    if M.compile_window ~= nil then
        M.close_compile_window()
    end

    if not cmd then
        vim.notify("No command to execute", vim.log.levels.ERROR)
        return
    end
    M.last_cmd = cmd

    local original_window = vim.api.nvim_get_current_win()
    local cwd = vim.fn.getcwd()

    local shell_cmd = cmd
    if M.last_env then
        shell_cmd = ". " .. vim.fn.shellescape(M.last_env, false) .. " && " .. cmd
        M.last_env = nil
    end

    local errorformat = detect_errorformat(cmd)

    vim.cmd("botright new")
    M.compile_buffer = vim.api.nvim_get_current_buf()
    M.compile_window = vim.api.nvim_get_current_win()

    vim.fn.termopen({ "sh", "-c", shell_cmd }, {
        cwd = cwd,
        on_exit = function()
            if not M.compile_buffer or not vim.api.nvim_buf_is_valid(M.compile_buffer) then
                return
            end

            populate_quickfix(M.compile_buffer, errorformat, "Compile: " .. cmd)
        end,
    })

    local function jump_from_compile_line()
        if vim.api.nvim_get_mode().mode == "t" then
            vim.cmd.stopinsert()
        end
        jump_to_error_line(
            errorformat,
            cwd,
            original_window,
            vim.api.nvim_get_current_line()
        )
    end

    vim.api.nvim_buf_set_keymap(M.compile_buffer, "n", "<CR>", "", {
        callback = jump_from_compile_line,
        noremap = true,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(M.compile_buffer, "t", "<CR>", "", {
        callback = jump_from_compile_line,
        noremap = true,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(M.compile_buffer, "n", "gq", "", {
        callback = function()
            local count = populate_quickfix(M.compile_buffer, errorformat, "Compile: " .. cmd)
            if count == 0 then
                vim.notify("No parseable errors found", vim.log.levels.WARN)
            end
        end,
        noremap = true,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(M.compile_buffer, "n", "]c", "", {
        callback = function()
            navigate_quickfix(original_window, "next")
        end,
        noremap = true,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(M.compile_buffer, "n", "[c", "", {
        callback = function()
            navigate_quickfix(original_window, "prev")
        end,
        noremap = true,
        silent = true,
    })
    vim.api.nvim_buf_set_keymap(M.compile_buffer, "n", "q", "", {
        callback = function()
            M.close_compile_window()
        end,
        noremap = true,
        silent = true,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = M.compile_buffer,
        once = true,
        callback = function()
            M.compile_window = nil
        end,
    })
end

vim.api.nvim_create_user_command(
    'Compile',
    function(args)
        local fargs = args.fargs
        if #fargs == 0 then
            M.command()
        elseif #fargs == 1 then
            if fargs[1] == "with-env" then
                M.with_env()
            elseif fargs[1] == "last" then
                M.run_last()
            else
                vim.notify("Error: Unknown argument '" .. fargs[1] .. "'", vim.log.levels.ERROR)
            end
        else
            vim.notify("Error: Too many arguments for Compile", vim.log.levels.ERROR)
        end
    end,
    {
        nargs = '*',
        desc = 'Compiles the project (supports with-env, last)',
        complete = function(arglead, _, _)
            local completions = { "with-env", "last" }

            local filtered = {}
            for _, item in ipairs(completions) do
                if vim.startswith(item, arglead) then
                    table.insert(filtered, item)
                end
            end
            return filtered
        end
    }
)
