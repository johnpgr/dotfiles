vim.g.emacs_tab = false
vim.g.treesitter_enabled = true
vim.g.icons_enabled = true
vim.g.c_syntax_for_h = true
vim.g.mapleader = " "

vim.o.cursorline = false
vim.o.number = false
vim.o.relativenumber = false
vim.o.confirm = true
vim.o.wrap = false
vim.o.inccommand = "split"
vim.o.swapfile = false
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.list = false
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.signcolumn = "no"
vim.o.foldcolumn = "0"
vim.o.mouse = "nv"
vim.o.breakindent = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.termguicolors = true
vim.o.undofile = true
vim.o.exrc = true
vim.o.secure = true
vim.o.spelllang = "en,pt_br"
vim.opt.clipboard = "unnamedplus"

vim.opt.fillchars = { eob = " " }
vim.opt.diffopt:append("linematch:60")

local is_kitty = os.getenv("TERM") == "xterm-kitty" or os.getenv("TERM") == "xterm-ghostty"

local function jump_to_error_loc()
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

local editorconfig = [[
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

local function find_symbol_by_lang()
    vim.notify("find_symbol_by_lang not configured", vim.log.levels.WARN)
end

local online_lookup_providers = {
    { name = "Google", urls = { "https://google.com/search?q=%s" } },
    { name = "Google Images", urls = { "https://www.google.com/images?q=%s" } },
    { name = "Kagi", urls = { "https://kagi.com/search?q=%s" } },
    { name = "DuckDuckGo", urls = { "https://duckduckgo.com/?q=%s" } },
    { name = "StackOverflow", urls = { "https://stackoverflow.com/search?q=%s" } },
    { name = "StackExchange", urls = { "https://stackexchange.com/search?q=%s" } },
    { name = "GitHub", urls = { "https://github.com/search?ref=simplesearch&q=%s" } },
    { name = "Sourcegraph", urls = { "https://sourcegraph.com/search?q=context:global+%s&patternType=literal" } },
    { name = "DevDocs.io", urls = { "https://devdocs.io/#q=%s" } },
    { name = "MDN", urls = { "https://developer.mozilla.org/en-US/search?q=%s" } },
    { name = "Wikipedia", urls = { "https://wikipedia.org/search-redirect.php?language=en&go=Go&search=%s" } },
    { name = "Youtube", urls = { "https://youtube.com/results?search_query=%s" } },
    { name = "Wolfram Alpha", urls = { "https://wolframalpha.com/input/?i=%s" } },
    { name = "Internet Archive", urls = { "https://web.archive.org/web/*/%s" } },
    { name = "Arch Wiki", urls = { "https://wiki.archlinux.org/index.php?search=%s" } },
    { name = "Arch Packages", urls = { "https://archlinux.org/packages/?q=%s" } },
    { name = "AUR", urls = { "https://aur.archlinux.org/packages?K=%s" } },
    { name = "Rust Docs", urls = { "https://doc.rust-lang.org/std/?search=%s" } },
    { name = "Python Docs", urls = { "https://docs.python.org/3/search.html?q=%s" } },
    { name = "PyPI", urls = { "https://pypi.org/search/?q=%s" } },
    { name = "npm", urls = { "https://www.npmjs.com/search?q=%s" } },
    { name = "Lua Docs", urls = { "https://www.lua.org/manual/5.4/search.html?q=%s" } },
    { name = "Go Docs", urls = { "https://golang.org/search?q=%s" } },
    { name = "pkg.go.dev", urls = { "https://pkg.go.dev/search?q=%s" } },
    { name = "crates.io", urls = { "https://crates.io/search?q=%s" } },
}

local function get_online_search_text()
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "" then
        vim.cmd([[noau normal! "vy]])
        return vim.fn.getreg("v")
    end
    return vim.fn.expand("<cword>")
end

local function url_encode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

local function open_url(url)
    local open_cmd
    if vim.fn.has("mac") == 1 then
        open_cmd = "open"
    elseif vim.fn.has("unix") == 1 then
        open_cmd = "xdg-open"
    elseif vim.fn.has("win32") == 1 then
        open_cmd = "start"
    else
        vim.notify("Unable to determine browser open command", vim.log.levels.ERROR)
        return
    end

    vim.fn.jobstart({ open_cmd, url }, { detach = true })
end

local function select_online_provider(query, on_choice)
    vim.ui.select(online_lookup_providers, {
        prompt = string.format("Search '%s' on:", query),
        format_item = function(item)
            return item.name
        end,
    }, function(choice)
        on_choice(choice)
    end)
end

local function search_online_select()
    local query = get_online_search_text()
    if not query or query == "" then
        vim.notify("No text to search", vim.log.levels.WARN)
        return
    end

    select_online_provider(query, function(provider)
        if not provider then
            return
        end

        local encoded_query = url_encode(query)
        if not encoded_query then
            vim.notify("Failed to encode query", vim.log.levels.ERROR)
            return
        end

        local url = string.format(provider.urls[1], encoded_query)
        vim.notify(string.format("Searching for '%s' on %s", query, provider.name), vim.log.levels.INFO)
        open_url(url)
    end)
end

local theme_uv = vim.uv or vim.loop
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

local initial_theme_state = read_theme_state()
if initial_theme_state then
    vim.o.background = initial_theme_state
    last_applied_mode = initial_theme_state
end

local function current_colorscheme()
    local colors_name = vim.g.colors_name
    if type(colors_name) == "string" and colors_name ~= "" then
        return colors_name
    end

    return nil
end

local sync_theme_state

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
            sync_theme_state({ force = true })
        end)
    end

    return ok
end

sync_theme_state = function(opts)
    return apply_theme_state(read_theme_state(), opts)
end

local function debounce_theme_sync()
    if not theme_uv or not theme_uv.new_timer then
        sync_theme_state()
        return
    end

    if theme_state_timer and theme_state_timer:is_closing() then
        theme_state_timer = nil
    end

    if not theme_state_timer then
        theme_state_timer = theme_uv.new_timer()
    end

    if not theme_state_timer then
        sync_theme_state()
        return
    end

    theme_state_timer:stop()
    theme_state_timer:start(
        100,
        0,
        vim.schedule_wrap(function()
            sync_theme_state()
        end)
    )
end

local function persist_colorscheme(colors_name)
    local f = io.open(colorscheme_file, "w")
    if not f then
        vim.notify("Unable to persist colorscheme", vim.log.levels.WARN)
        return
    end

    f:write(colors_name)
    f:close()
end

local function load_persisted_colorscheme()
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

    sync_theme_state({ force = true })
end

local function apply_theme_state(mode, opts)
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

local function start_theme_state_watcher()
    if theme_state_watcher or not theme_uv or not theme_uv.new_fs_event then
        return false
    end

    theme_state_watcher = theme_uv.new_fs_event()
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

local function stop_theme_state_watcher()
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

local function set_theme(mode)
    return apply_theme_state(mode)
end

local ignored_ls = {
    "opencode",
    "copilot",
}

-- Statusline
local function lsp_status()
    local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
    if #attached_clients == 0 then
        return ""
    end
    local names = vim.iter(attached_clients)
        :filter(function(client)
            return not vim.tbl_contains(ignored_ls, client.name)
        end)
        :map(function(client)
            local name = client.name:gsub("language.server", "ls")
            return name
        end)
        :totable()
    if #names == 0 then
        return ""
    end
    return "[" .. table.concat(names, ", ") .. "]"
end

function _G.statusline()
    return table.concat({
        "%f",
        "%h%w%m%r",
        "%=",
        lsp_status(),
        " %-14(%l,%c%V%)",
        "%P",
    }, " ")
end

vim.o.statusline = "%{%v:lua._G.statusline()%}"

-- CMDLINE AUTOCOMPLETION (see :h cmdline-autocompletion)

-- Core: show a popup menu of suggestions as you type on : / ?
vim.api.nvim_create_autocmd("CmdlineChanged", {
    pattern = { ":", "/", "?" },
    callback = function()
        vim.fn.wildtrigger()
    end,
})

vim.opt.wildmode = "noselect:lastused,full"
vim.opt.wildoptions = "pum"

-- Keep <Up>/<Down> for history when the wildmenu is not active
vim.keymap.set("c", "<Up>", function()
    return vim.fn.wildmenumode() == 1 and [[<C-E><Up>]] or [[<Up>]]
end, { expr = true })

vim.keymap.set("c", "<Down>", function()
    return vim.fn.wildmenumode() == 1 and [[<C-E><Down>]] or [[<Down>]]
end, { expr = true })

-- Smaller popup during search (8 lines), restored on leave
vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = { "/", "?" },
    callback = function()
        vim.opt.pumheight = 8
    end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
    pattern = { "/", "?" },
    callback = function()
        vim.opt.pumheight = vim.go.pumheight
    end,
})

local function can_resize_nvim(direction)
    local current = vim.fn.winnr()
    local directions = (direction == "h" or direction == "l") and { "h", "l" } or { "j", "k" }

    for _, dir in ipairs(directions) do
        if vim.fn.winnr(dir) ~= current then
            return true
        end
    end

    return false
end

local function smart_resize(direction)
    local resize_commands = {
        h = "vertical resize +3",
        j = "resize +3",
        k = "resize -3",
        l = "vertical resize -3",
    }

    if can_resize_nvim(direction) then
        vim.cmd(resize_commands[direction])
    end
end

vim.keymap.set("n", "<leader>w", "<cmd>update<cr>", { desc = "Write" })
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
vim.keymap.set("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlights" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<M-h>", function()
    smart_resize("h")
end, { desc = "Resize split left" })
vim.keymap.set("n", "<M-j>", function()
    smart_resize("j")
end, { desc = "Resize split down" })
vim.keymap.set("n", "<M-k>", function()
    smart_resize("k")
end, { desc = "Resize split up" })
vim.keymap.set("n", "<M-l>", function()
    smart_resize("l")
end, { desc = "Resize split right" })
vim.keymap.set("n", "<leader>I", "<cmd>Inspect<cr>", { desc = "Inspect" })
vim.keymap.set("n", "yig", ":%y<CR>", { desc = "Yank buffer" })
vim.keymap.set("n", "vig", "ggVG", { desc = "Visual select buffer" })
vim.keymap.set("n", "cig", ":%d<CR>i", { desc = "Change buffer" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search result" })
vim.keymap.set("n", "]d", function()
    vim.diagnostic.jump({ count = 1, float = true })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({ count = -1, float = true })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("zz", true, false, true), "n", true)
end, { desc = "Previous diagnostic" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("v", "<", "<gv", { desc = "Decrease indent" })
vim.keymap.set("v", ">", ">gv", { desc = "Increase indent" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
vim.keymap.set("n", "<leader>sl", function()
    search_online_select()
end, { desc = "Search lookup (online search)" })

-- Toggle keybinds
vim.keymap.set("n", "<leader>tl", function()
    if vim.o.number and vim.o.relativenumber then
        vim.o.relativenumber = false
    elseif vim.o.number and not vim.o.relativenumber then
        vim.o.number = false
    else
        vim.o.number = true
        vim.o.relativenumber = true
    end
end, { desc = "Line numbers" })

vim.keymap.set("n", "<leader>tI", function()
    if vim.o.expandtab then
        vim.o.expandtab = false
        vim.notify("Indent style: tabs", vim.log.levels.INFO)
    else
        vim.o.expandtab = true
        vim.notify("Indent style: spaces", vim.log.levels.INFO)
    end
end, { desc = "Indent style" })

vim.keymap.set("n", "<leader>ts", function()
    if vim.o.signcolumn == "no" then
        vim.o.signcolumn = "yes"
    else
        vim.o.signcolumn = "no"
    end
end, { desc = "Sign column" })

vim.keymap.set("n", "<leader>tc", function()
    if vim.o.colorcolumn == "" then
        vim.o.colorcolumn = "80"
    else
        vim.o.colorcolumn = ""
    end
end, { desc = "Color column" })

-- Yank keymaps
vim.keymap.set("n", "<leader>fy", function()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        return
    end
    vim.fn.setreg("+", filepath)
    print("Copied path: " .. filepath)
end, { desc = "Yank filepath" })
vim.keymap.set("n", "<leader>fY", function()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        return
    end
    local relative_path = vim.fn.fnamemodify(filepath, ":~:.")
    vim.fn.setreg("+", relative_path)
    print("Copied path: " .. relative_path)
end, { desc = "Yank filepath from workspace" })

-- Insert keymaps
vim.keymap.set("n", "<leader>if", function()
    local filename = vim.fn.expand("%:t")
    if filename == "" then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, pos[2]) .. filename .. line:sub(pos[2] + 1)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filename })
end, { desc = "File name" })
vim.keymap.set("n", "<leader>iF", function()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        return
    end
    local pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, pos[2]) .. filepath .. line:sub(pos[2] + 1)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #filepath })
end, { desc = "File path" })

vim.keymap.set("n", "<leader>ie", function()
    local editor_config = editorconfig
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1 -- 0-indexed
    local lines = vim.split(editor_config, "\n", { plain = true })
    vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
    if #lines == 1 then
        vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
    else
        vim.api.nvim_win_set_cursor(0, { row + #lines, #lines[#lines] })
    end
end, { desc = "Editorconfig" })

-- LSP keymaps
-- vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })
vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>lf", function()
    require("conform").format({ async = true })
end, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Diagnostic" })
vim.keymap.set("n", "<leader>ll", vim.diagnostic.setqflist, { desc = "Diagnostic List" })

-- Quickfix keymaps
vim.keymap.set("n", "]q", function()
    local qf_list = vim.fn.getqflist()
    local qf_length = #qf_list
    if qf_length == 0 then
        return
    end

    local current_idx = vim.fn.getqflist({ idx = 0 }).idx
    if current_idx >= qf_length then
        vim.cmd("cfirst")
    else
        vim.cmd("cnext")
    end
    vim.cmd("copen")
end, { desc = "Next quickfix item" })

vim.keymap.set("n", "[q", function()
    local qf_list = vim.fn.getqflist()
    local qf_length = #qf_list
    if qf_length == 0 then
        return
    end

    local current_idx = vim.fn.getqflist({ idx = 0 }).idx
    if current_idx <= 1 then
        vim.cmd("clast")
    else
        vim.cmd("cprevious")
    end
    vim.cmd("copen")
end, { desc = "Previous quickfix item" })

vim.keymap.set("n", "]e", function()
    require("compile-mode").next_error()
end, { desc = "Next error" })

vim.keymap.set("n", "[e", function()
    require("compile-mode").prev_error()
end, { desc = "Previous error" })

vim.keymap.set("n", "<leader>m", function()
    if vim.bo.filetype == "oil" then
        vim.g.compilation_directory = require("oil").get_current_dir()
    end
    require("compile-mode").compile()
end, { desc = "Compile" })

vim.keymap.set("n", "<leader>M", function()
    if vim.bo.filetype == "oil" then
        vim.g.compilation_directory = require("oil").get_current_dir()
    end
    require("compile-mode").compile({
        smods = {
            vertical = true,
        },
    })
end, { desc = "Compile (vertical)" })

vim.keymap.set("n", "<leader>r", function()
    require("compile-mode").recompile()
end, { desc = "Recompile" })

vim.keymap.set("n", "<leader>?", function()
    find_symbol_by_lang()
end, { desc = "Search symbols" })

local function dap_view_is_open()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.w[win].dapview_win then
            return true
        end
    end
    return false
end

local function dap_terminal_is_open()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.w[win].dapview_win_term then
            return true
        end
    end
    return false
end

local function dap_ui_is_open()
    return dap_view_is_open() or dap_terminal_is_open()
end

local function clear_dap_virtual_text()
    local ok, virtual_text = pcall(require, "nvim-dap-virtual-text/virtual_text")
    if not ok then
        return
    end
    virtual_text.clear_virtual_text()
    virtual_text.clear_last_frames()
end

local function toggle_disassembly_view()
    local dapview = require("dap-view")

    if not dap_view_is_open() then
        dapview.open()
        dapview.show_view("disassembly")
        return
    end

    if vim.bo.filetype == "dap-disassembly" then
        dapview.show_view("scopes")
        return
    end

    dapview.jump_to_view("disassembly")
end

local function toggle_dbui_tab()
    local function toggle_dbui_tab()
        -- Find a tab that has DBUI open (by filetype or buffer name)
        local dbui_tab = nil
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                local buf = vim.api.nvim_win_get_buf(win)
                local ft = vim.api.nvim_buf_get_option(buf, "filetype")
                local name = vim.api.nvim_buf_get_name(buf) or ""
                if ft == "dbui" or name:match("DBUI") or name:match("dbui") then
                    dbui_tab = tab
                    break
                end
            end
            if dbui_tab then
                break
            end
        end

        if dbui_tab then
            -- Close the tab that contains DBUI
            vim.api.nvim_set_current_tabpage(dbui_tab)
            vim.cmd("tabclose")
        else
            -- Open DBUI in a new tab
            vim.cmd("tabnew")
            vim.cmd("DBUI")
        end
    end
end

local function nav_hunk(direction)
    if vim.wo.diff then
        local key = direction == "next" and "]c" or "[c"
        vim.cmd.normal({ key, bang = true })
        return
    end

    local popup = require("gitsigns.popup")
    popup.close("hunk")

    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative ~= "" then
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_config(w).relative == "" then
                vim.api.nvim_set_current_win(w)
                break
            end
        end
    end

    local gitsigns = require("gitsigns")
    local bufnr = vim.api.nvim_get_current_buf()
    local hunks = gitsigns.get_hunks(bufnr) or {}
    if #hunks == 0 then
        return
    end

    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local target

    if direction == "next" then
        for _, h in ipairs(hunks) do
            if h.added.start > cur then
                target = h.added.start
                break
            end
        end
        if not target then
            target = hunks[1].added.start
        end
    else
        for i = #hunks, 1, -1 do
            if hunks[i].added.start < cur then
                target = hunks[i].added.start
                break
            end
        end
        if not target then
            target = hunks[#hunks].added.start
        end
    end

    target = math.max(1, math.min(target, vim.api.nvim_buf_line_count(bufnr)))
    vim.api.nvim_win_set_cursor(0, { target, 0 })

    vim.schedule(function()
        gitsigns.preview_hunk()
    end)
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
    callback = function()
        vim.bo.filetype = "image"
    end,
})

local image_enabled = is_kitty and #vim.api.nvim_list_uis() > 0
local image_opts = {
    backend = "kitty",
    processor = "magick_cli",
    integrations = {
        markdown = {
            only_render_image_at_cursor = true,
        },
    },
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
}

-- LSP floating window config
local lsp_floating_preview_original = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = "single"
    opts.max_width = opts.max_width or 100
    return lsp_floating_preview_original(contents, syntax, opts, ...)
end

vim.diagnostic.config({
    severity_sort = true,
    float = { border = "single", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
})

vim.lsp.semantic_tokens.enable(false)

local function open_neotree()
    local reveal_file = vim.fn.expand("%:p")
    if reveal_file == "" then
        reveal_file = vim.fn.getcwd()
    else
        local f = io.open(reveal_file, "r")
        if f then
            f:close()
        else
            reveal_file = vim.fn.getcwd()
        end
    end

    require("neo-tree.command").execute({
        action = "focus",
        source = "filesystem",
        position = "left",
        toggle = true,
        reveal_file = reveal_file,
        reveal_force_cwd = true,
    })
end

function _G.get_oil_winbar()
    local result = ""
    local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winid)

    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ~= "oil" then
        return result
    end

    local dir = require("oil").get_current_dir(bufnr)
    if dir then
        dir = dir:len() > 1 and dir:gsub("/$", "") or dir
        result = dir .. ":"
    else
        result = vim.api.nvim_buf_get_name(bufnr)
    end

    return "  " .. result
end

local uv = vim.uv or vim.loop
local dired_stats_cache = {}
local dired_line_lookup = nil
local dired_name_col_width = 0
local dired_highlight_patch_applied = false
local fff_icon_line_lookup = nil
local path_sep = package.config:sub(1, 1)
local set_search_highlight -- forward declaration; defined below
local ensure_dired_result_highlight_patch -- forward declaration; defined below

local fff_state = {
    initialized = false,
    base_path = nil,
    fuzzy = nil,
}

local function ensure_fff()
    if fff_state.initialized then
        return fff_state.fuzzy
    end

    pcall(vim.cmd.packadd, "fff.nvim")

    local ok, fuzzy = pcall(require, "fff.fuzzy")
    if not ok then
        return nil
    end

    local core_ok, core = pcall(require, "fff.core")
    if core_ok and type(core.ensure_initialized) == "function" then
        pcall(core.ensure_initialized)
    else
        pcall(fuzzy.init_db)
        pcall(fuzzy.scan_files)
    end

    fff_state.fuzzy = fuzzy
    fff_state.base_path = vim.fn.getcwd()
    fff_state.initialized = true

    local group = vim.api.nvim_create_augroup("fff_refer", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function(ev)
            local f = ev.file
            if f and f ~= "" and not vim.startswith(f, "term://") then
                pcall(fuzzy.track_access, vim.uv.fs_realpath(f) or f)
            end
        end,
    })

    vim.api.nvim_create_autocmd("DirChanged", {
        group = group,
        callback = function()
            local cwd = vim.fn.getcwd()
            if cwd ~= fff_state.base_path then
                pcall(fuzzy.restart_index_in_path, cwd)
                fff_state.base_path = cwd
            end
        end,
    })

    return fuzzy
end

local function format_fff_line_with_icon(path, text)
    if not vim.g.icons_enabled then
        return text, nil
    end

    local ok, icons = pcall(require, "fff.file_picker.icons")
    if not ok then
        return text, nil
    end

    local name = vim.fn.fnamemodify(path, ":t")
    local ext = vim.fn.fnamemodify(path, ":e")
    local icon, icon_hl = icons.get_icon(name, ext, false)
    if not icon or icon == "" or not icon_hl then
        return text, nil
    end

    return string.format("%s %s", icon, text), {
        icon = icon,
        icon_hl = icon_hl,
    }
end

local function pick_files_fff()
    local fuzzy = ensure_fff()
    if not fuzzy then
        vim.notify("fff backend not available", vim.log.levels.ERROR)
        return
    end
    ensure_dired_result_highlight_patch()

    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file == "" then
        current_file = nil
    end

    local path_lookup = {}

    local refer_util = require("refer.util")
    require("refer").pick({}, function(selection, data)
        refer_util.jump_to_location(selection, data)
    end, {
        prompt = "Files (fff) > ",
        keymaps = {
            ["<CR>"] = "select_entry",
        },
        on_change = function(query, update_ui_callback)
            local ok, result = pcall(fuzzy.fuzzy_search_files, query or "", 4, current_file, 100, 3, 0, 100)

            if not ok or not result then
                update_ui_callback({})
                return
            end

            local items = type(result) == "table" and (result.items or result) or {}
            local lines = {}
            path_lookup = {}
            fff_icon_line_lookup = {}
            for _, item in ipairs(items) do
                local raw_display = item.relative_path or item.path or tostring(item)
                local fullpath = item.path or raw_display
                local display, icon_meta = format_fff_line_with_icon(fullpath, raw_display)
                table.insert(lines, display)
                path_lookup[display] = fullpath
                fff_icon_line_lookup[display] = icon_meta
            end
            update_ui_callback(lines)
        end,
        on_close = function()
            fff_icon_line_lookup = nil
        end,
        parser = function(selection)
            return {
                filename = path_lookup[selection] or selection,
                lnum = 1,
                col = 1,
            }
        end,
    })
end

local function pick_grep_fff(default_text, grep_mode)
    local fuzzy = ensure_fff()
    if not fuzzy then
        vim.notify("fff backend not available", vim.log.levels.ERROR)
        return
    end

    local grep_ok, grep = pcall(require, "fff.grep")
    if not grep_ok then
        vim.notify("fff.grep not available", vim.log.levels.ERROR)
        return
    end
    ensure_dired_result_highlight_patch()

    grep_mode = grep_mode or "plain"
    local match_lookup = {}

    local refer_util = require("refer.util")
    require("refer").pick({}, function(selection, data)
        refer_util.jump_to_location(selection, data)
    end, {
        prompt = "Grep (fff) > ",
        default_text = default_text,
        keymaps = {
            ["<CR>"] = "select_entry",
        },
        on_change = function(query, update_ui_callback)
            if not query or query == "" then
                update_ui_callback({})
                return
            end

            set_search_highlight(query)

            local ok, result = pcall(grep.search, query, 0, 100, nil, grep_mode)

            if not ok or not result then
                update_ui_callback({})
                return
            end

            local items = type(result) == "table" and (result.items or result.matches or result) or {}
            local lines = {}
            match_lookup = {}
            fff_icon_line_lookup = {}
            for _, item in ipairs(items) do
                local path = item.path or item.file or ""
                local lnum = item.line_number or item.lnum or item.line or 1
                local col = item.col or item.column or 1
                local text = item.text or item.content or item.line_content or ""
                local raw_display = string.format("%s:%d:%d: %s", path, lnum, col, vim.trim(text))
                local display, icon_meta = format_fff_line_with_icon(path, raw_display)
                table.insert(lines, display)
                match_lookup[display] = { filename = path, lnum = lnum, col = col }
                fff_icon_line_lookup[display] = icon_meta
            end
            update_ui_callback(lines)
        end,
        on_close = function()
            fff_icon_line_lookup = nil
            vim.cmd("nohlsearch")
        end,
        parser = function(selection)
            local entry = match_lookup[selection]
            if entry then
                return entry
            end
            local file, lnum, col = selection:match("^(.+):(%d+):(%d+):")
            if file then
                return { filename = file, lnum = tonumber(lnum), col = tonumber(col) }
            end
            return nil
        end,
    })
end

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

ensure_dired_result_highlight_patch = function()
    if dired_highlight_patch_applied then
        return
    end

    ensure_dired_highlight_groups()

    local highlight = require("refer.highlight")
    local original_highlight_entry = highlight.highlight_entry

    highlight.highlight_entry = function(buf, ns, line_idx, line, highlight_code, opts)
        local entry = dired_line_lookup and dired_line_lookup[line] or nil
        local icon_meta = fff_icon_line_lookup and fff_icon_line_lookup[line] or nil
        if not entry then
            original_highlight_entry(buf, ns, line_idx, line, highlight_code, opts)
            if icon_meta and icon_meta.icon and icon_meta.icon_hl then
                pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_idx, 0, {
                    end_col = #icon_meta.icon,
                    hl_group = icon_meta.icon_hl,
                    priority = 110,
                })
            end
            return
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
        local line = string.format("%-" .. max_name_len .. "s  %s  %6s  %s", name, entry.perms, entry.size, entry.mtime)
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
            ["<Tab>"] = function(selection, builtin)
                local picker = builtin.picker
                local selected = selection

                if (not selected or selected == "") and type(picker.selected_index) == "number" then
                    selected = picker.current_matches[picker.selected_index]
                end

                if not selected then
                    selected = picker.current_matches[1]
                end

                local entry = selection_lookup[selected]
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
    return (
        s:gsub("[%(|%)|\\|%[|%]|%-|%{%}|%?|%+|%*|%^|%$|%.]", {
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
        })
    )
end

set_search_highlight = function(query)
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
        persist_colorscheme(selection)
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

        vim.cmd("normal! \"_ciw" .. selection)
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

local function grep_string_with_fff(opts)
    opts = opts or {}
    local word = get_grep_string_query(opts)
    pick_grep_fff(word, opts.use_regex and "regex" or "plain")
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

local function capture_window_local_options(winid)
    if not winid or not vim.api.nvim_win_is_valid(winid) then
        return nil
    end

    local option_names = {
        "number",
        "relativenumber",
        "signcolumn",
        "cursorline",
        "foldcolumn",
        "spell",
        "list",
        "winhighlight",
        "fillchars",
        "statusline",
    }

    local opts = {}
    for _, name in ipairs(option_names) do
        opts[name] = vim.api.nvim_get_option_value(name, { scope = "local", win = winid })
    end

    return opts
end

local function restore_window_local_options(winid, opts)
    if not opts or not winid or not vim.api.nvim_win_is_valid(winid) then
        return
    end

    for name, value in pairs(opts) do
        pcall(vim.api.nvim_set_option_value, name, value, { scope = "local", win = winid })
    end
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

    timer:start(
        0,
        40,
        vim.schedule_wrap(function()
            attempts = attempts + 1
            if apply_once() then
                stop_timer()
            end
        end)
    )
end

local function build_resume_aware_opts(opts, session, should_restore)
    local picker_opts = vim.deepcopy(opts or {})
    local original_on_close = picker_opts.on_close
    local picker_ref = nil
    local state_to_restore = nil
    local original_win_opts = nil

    if should_restore and session and session.state then
        state_to_restore = vim.deepcopy(session.state)
        picker_opts.default_text = tostring(state_to_restore.input or "")
    end

    picker_opts.on_close = function()
        if session and picker_ref then
            session.state = capture_picker_state(picker_ref)
        end

        if picker_ref and original_win_opts then
            restore_window_local_options(picker_ref.original_win, original_win_opts)
        end

        if original_on_close then
            original_on_close()
        end
    end

    return picker_opts,
        function(picker)
            picker_ref = picker
            if picker and picker.original_win then
                original_win_opts = capture_window_local_options(picker.original_win)
            end
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

local function pick_files_fff_in_dir(dir, prompt)
    local fuzzy = ensure_fff()
    if not fuzzy then
        vim.notify("fff backend not available", vim.log.levels.ERROR)
        return
    end
    ensure_dired_result_highlight_patch()

    local original_path = fff_state.base_path
    pcall(fuzzy.restart_index_in_path, dir)
    fff_state.base_path = dir

    local path_lookup = {}

    local refer_util = require("refer.util")
    require("refer").pick({}, function(selection, data)
        refer_util.jump_to_location(selection, data)
    end, {
        prompt = prompt,
        keymaps = {
            ["<CR>"] = "select_entry",
        },
        on_change = function(query, update_ui_callback)
            local ok, result = pcall(fuzzy.fuzzy_search_files, query or "", 4, nil, 100, 3, 0, 100)
            if not ok or not result then
                update_ui_callback({})
                return
            end
            local items = type(result) == "table" and (result.items or result) or {}
            local lines = {}
            path_lookup = {}
            fff_icon_line_lookup = {}
            for _, item in ipairs(items) do
                local raw_display = item.relative_path or item.path or tostring(item)
                local fullpath = item.path or raw_display
                local display, icon_meta = format_fff_line_with_icon(fullpath, raw_display)
                table.insert(lines, display)
                path_lookup[display] = fullpath
                fff_icon_line_lookup[display] = icon_meta
            end
            update_ui_callback(lines)
        end,
        on_close = function()
            fff_icon_line_lookup = nil
            if original_path then
                pcall(fuzzy.restart_index_in_path, original_path)
                fff_state.base_path = original_path
            end
        end,
        parser = function(selection)
            return {
                filename = path_lookup[selection] or selection,
                lnum = 1,
                col = 1,
            }
        end,
    })
end

local function open_nvim_config_files()
    pick_files_fff_in_dir(vim.fn.stdpath("config"), "Nvim Config Files > ")
end

local function open_lazy_data_files()
    pick_files_fff_in_dir(vim.fn.stdpath("data"), "Data Files > ")
end

local function refer_entry_to_qf_item(candidate, parser)
    local item = { text = candidate }
    if type(parser) ~= "function" then
        return item
    end

    local parsed = parser(candidate)
    if not parsed then
        return item
    end

    if parsed.filename then
        item.filename = parsed.filename
    end
    if parsed.lnum then
        item.lnum = parsed.lnum
    end
    if parsed.col then
        item.col = parsed.col
    end

    if parsed.content then
        item.text = parsed.content
    elseif parsed.filename and parsed.lnum then
        local prefix_col = string.format("%s:%d:%d:", parsed.filename, parsed.lnum, parsed.col or 0)
        local prefix_no_col = string.format("%s:%d:", parsed.filename, parsed.lnum)

        if vim.startswith(candidate, prefix_col) then
            item.text = candidate:sub(#prefix_col + 1)
        elseif vim.startswith(candidate, prefix_no_col) then
            item.text = candidate:sub(#prefix_no_col + 1)
        end
    end

    return item
end

local function send_all_refer_matches_to_qf(_, builtin)
    local picker = builtin and builtin.picker or nil
    local matches = picker and picker.current_matches or {}
    if #matches == 0 then
        return
    end

    local items = {}
    for _, candidate in ipairs(matches) do
        table.insert(items, refer_entry_to_qf_item(candidate, picker.parser))
    end

    local title = picker.opts.prompt or "Refer Selection"
    picker:close()

    pcall(require, "quicker")

    vim.schedule(function()
        vim.fn.setqflist({}, " ", {
            title = title,
            items = items,
        })
        vim.cmd("copen")
    end)
end

vim.filetype.add({
    extension = {
        hlsl = "hlsl",
        m = "objc",
    },
})

vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank()
    end,
})

vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local name = ev.data.spec.name
        local kind = ev.data.kind
        if kind ~= "install" and kind ~= "update" then
            return
        end

        if name == "fff.nvim" then
            pcall(vim.cmd.packadd, name)
            pcall(function()
                require("fff.download").download_or_build_binary()
            end)
        elseif name == "nvim-treesitter" then
            pcall(vim.cmd.packadd, name)
            pcall(vim.cmd, "TSUpdate")
        elseif name == "mason.nvim" then
            pcall(vim.cmd.packadd, name)
            pcall(vim.cmd, "MasonUpdate")
        end
    end,
})

vim.pack.add({
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/nvim-tree/nvim-web-devicons",
    "https://github.com/mbbill/undotree",
    "https://github.com/mg979/vim-visual-multi",
    "https://github.com/johmsalas/text-case.nvim",
    "https://github.com/tpope/vim-abolish",
    "https://github.com/tpope/vim-dispatch",
    "https://github.com/nvim-mini/mini.align",
    { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1") },
    "https://github.com/L3MON4D3/LuaSnip",
    "https://github.com/rafamadriz/friendly-snippets",
    "https://github.com/xzbdmw/colorful-menu.nvim",
    { src = "https://github.com/ej-shafran/compile-mode.nvim", version = "nightly" },
    { src = "https://github.com/m00qek/baleia.nvim", version = "v1.3.0" },
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/zbirenbaum/copilot.lua",
    "https://github.com/vyfor/cord.nvim",
    "https://github.com/mfussenegger/nvim-dap",
    "https://github.com/theHamsta/nvim-dap-virtual-text",
    "https://github.com/jay-babu/mason-nvim-dap.nvim",
    "https://github.com/igorlfs/nvim-dap-view",
    "https://github.com/Jorenar/nvim-dap-disasm",
    "https://github.com/tpope/vim-dadbod",
    "https://github.com/kristijanhusak/vim-dadbod-completion",
    "https://github.com/kristijanhusak/vim-dadbod-ui",
    "https://github.com/dmtrKovalenko/fff.nvim",
    "https://github.com/lewis6991/gitsigns.nvim",
    "https://github.com/NeogitOrg/neogit",
    "https://github.com/sindrets/diffview.nvim",
    "https://github.com/3rd/image.nvim",
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
    "https://github.com/folke/lazydev.nvim",
    "https://github.com/mfussenegger/nvim-jdtls",
    "https://github.com/yioneko/nvim-vtsls",
    { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = "v3.x" },
    "https://github.com/MunifTanjim/nui.nvim",
    "https://github.com/stevearc/oil.nvim",
    "https://github.com/stevearc/quicker.nvim",
    "https://github.com/juniorsundar/refer.nvim",
    "https://github.com/nvim-treesitter/nvim-treesitter",
    "https://github.com/folke/which-key.nvim",
    "https://github.com/xiyaowong/transparent.nvim",
}, { load = true, confirm = false })

vim.cmd([[
let g:VM_maps = {}
let g:VM_maps["Goto Prev"] = "\[\["
let g:VM_maps["Goto Next"] = "\]\]"
nmap <C-M-n> <Plug>(VM-Select-All)
]])

require("textcase").setup({
    prefix = "tc",
})

require("mini.align").setup({
    mappings = {
        start = "ga",
        start_with_preview = "gA",
    },
})

local function has_words_before()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 then
        return false
    end
    local line = vim.api.nvim_get_current_line()
    return line:sub(col, col):match("%s") == nil
end

local function toggle_menu(cmp)
    if not require("blink.cmp").is_visible() then
        cmp.show()
    else
        cmp.hide()
    end
end

-- Custom insert_next without can_select check
local function custom_insert_next(cmp)
    if not cmp.is_active() then
        return cmp.show_and_insert()
    end
    -- if not require('blink.cmp.completion.list').can_select({ auto_insert = true }) then return end
    vim.schedule(function()
        require("blink.cmp.completion.list").select_next({ auto_insert = true })
    end)
    return true
end

-- Custom insert_prev without can_select check
local function custom_insert_prev(cmp)
    if not cmp.is_active() then
        return cmp.show_and_insert()
    end
    -- if not require('blink.cmp.completion.list').can_select({ auto_insert = true }) then return end
    vim.schedule(function()
        require("blink.cmp.completion.list").select_prev({ auto_insert = true })
    end)
    return true
end

local function emacs_tab(cmp)
    if require("blink.cmp").is_visible() then
        return cmp.select_and_accept()
    elseif has_words_before() then
        return custom_insert_next(cmp)
    end
end

local function accept_copilot_suggestion()
    local ok, copilot_suggestion = pcall(require, "copilot.suggestion")
    if not ok or not copilot_suggestion.is_visible() then
        return false
    end

    copilot_suggestion.accept()
    return true
end

local function tab_action(cmp)
    if vim.g.emacs_tab == true then
        return emacs_tab(cmp)
    end

    if accept_copilot_suggestion() then
        return true
    end

    if require("blink.cmp").is_visible() then
        return cmp.accept()
    end
end

local columns = {}

if not vim.g.icons_enabled then
    columns = { { "label", gap = 1 }, { "source_name" } }
else
    columns = { { "kind_icon" }, { "label", gap = 1 }, { "source_name" } }
end

require("blink.cmp").setup({
    appearance = {
        kind_icons = {
            Text = "",
            Method = "",
            Function = "",
            Constructor = "",
            Field = "",
            Variable = "",
            Class = "",
            Interface = "",
            Module = "",
            Property = "",
            Unit = "",
            Value = "",
            Enum = "",
            Keyword = "",
            Snippet = "",
            Color = "",
            File = "",
            Reference = "",
            Folder = "",
            EnumMember = "",
            Constant = "",
            Struct = "",
            Event = "",
            Operator = "",
            TypeParameter = "",
        },
    },
    keymap = {
        preset = "none",
        ["<C-space>"] = { toggle_menu },
        ["<CR>"] = {
            "fallback",
        },
        ["<Tab>"] = {
            tab_action,
            "snippet_forward",
            "fallback",
        },
        ["<S-Tab>"] = { custom_insert_prev },
        ["<C-y>"] = { "accept", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
    },
    snippets = {
        preset = "luasnip",
    },
    sources = {
        default = { "lazydev", "lsp", "buffer", "snippets", "path" },
        providers = {
            dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
            lazydev = {
                name = "LazyDev",
                module = "lazydev.integrations.blink",
                -- make lazydev completions top priority (see `:h blink.cmp`)
                score_offset = 100,
            },
        },
        per_filetype = {
            sql = { "snippets", "dadbod", "buffer" },
            ["copilot-chat"] = { "snippets" },
            DressingInput = { "buffer", "path" },
        },
    },
    completion = {
        list = {
            selection = {
                preselect = vim.g.emacs_tab ~= true,
            },
            cycle = { from_top = false },
        },
        menu = {
            auto_show = vim.g.emacs_tab ~= true,
            max_height = 20,
            draw = {
                columns = columns,
                components = {
                    source_name = {
                        text = function(ctx)
                            return "[" .. ctx.source_name .. "]"
                        end,
                    },
                    label = {
                        text = function(ctx)
                            return require("colorful-menu").blink_components_text(ctx)
                        end,
                        highlight = function(ctx)
                            return require("colorful-menu").blink_components_highlight(ctx)
                        end,
                    },
                },
            },
        },
        documentation = {
            auto_show = true,
            auto_show_delay_ms = 250,
            window = { border = "single" },
        },
    },
    cmdline = {
        enabled = false,
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
})

require("colorful-menu").setup({})

local compile_mode = require("compile-mode")
vim.g.compile_mode = {
    default_command = "",
    input_word_completion = true,
    baleia_setup = true,
    bang_expansion = true,
    error_regexp_table = {
        nodejs = {
            regex = "^\\s\\+at .\\+ (\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\))$",
            filename = 1,
            row = 2,
            col = 3,
            priority = 2,
        },
        typescript = {
            regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
            filename = 1,
            row = 2,
            col = 3,
        },
        typescript_new = {
            regex = "^\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\) - error TS[1-9][0-9]*:",
            filename = 1,
            row = 2,
            col = 3,
        },
        gradlew = {
            regex = "^e:\\s\\+file://\\(.\\+\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
            filename = 1,
            row = 2,
            col = 3,
        },
        ls_lint = {
            regex = "\\v^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} (.+) failed for rules: .+$",
            filename = 1,
        },
        sass = {
            regex = "\\s\\+\\(.\\+\\) \\(\\d\\+\\):\\(\\d\\+\\)  .*$",
            filename = 1,
            row = 2,
            col = 3,
            type = compile_mode.level.WARNING,
        },
        kotlin = {
            regex = "^\\%(e\\|w\\): file://\\(.*\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
            filename = 1,
            row = 2,
            col = 3,
        },
        rust = {
            regex = "^\\s*-->\\s\\+\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)$",
            filename = 1,
            row = 2,
            col = 3,
            priority = 2,
        },
        odin = {
            regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)) Error:",
            filename = 1,
            row = 2,
            col = 3,
        },
    },
}

require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua", lsp_format = "fallback" },
        python = { "isort", "black", lsp_format = "fallback" },
        rust = { "rustfmt", lsp_format = "fallback" },
        html = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        css = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        json = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        javascript = { "oxfmt", lsp_format = "fallback" },
        javascriptreact = { "oxfmt", lsp_format = "fallback" },
        typescript = { "oxfmt", lsp_format = "fallback" },
        typescriptreact = { "oxfmt", lsp_format = "fallback" },
        astro = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        c = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
        cpp = { "clang-format", stop_after_first = true, lsp_format = "fallback" },
        odin = { lsp_format = "fallback" },
    },
})

require("copilot").setup({
    suggestion = {
        enabled = true,
        auto_trigger = true,
        hide_during_completion = true,
        debounce = 75,
        trigger_on_accept = true,
        keymap = {
            accept = "<M-l>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
        },
    },
})

require("cord").setup({})
require("dap-view").setup({
    winbar = {
        controls = {
            enabled = false,
        },
        sections = {
            "scopes",
            "threads",
            "breakpoints",
            "watches",
            "disassembly",
            "repl",
        },
        default_section = "scopes",
        show_keymap_hints = false,
        base_sections = {
            scopes = { label = "[S]copes", keymap = "S" },
            threads = { label = "[T]hreads", keymap = "T" },
            breakpoints = { label = "[B]reakpoints", keymap = "B" },
            watches = { label = "[W]atches", keymap = "W" },
            repl = { label = "[R]EPL", keymap = "R" },
        },
    },
    windows = {
        size = 0.4,
        position = "left",
        terminal = {
            size = 0.3,
            position = "below",
            hide = {},
        },
    },
    -- We manage open/close via nvim-dap listeners below.
    auto_toggle = false,
    switchbuf = "usetab,uselast",
})
require("dap-disasm").setup({
    dapui_register = false,
    dapview_register = true,
    dapview = {
        keymap = "D",
        label = "[D]isassembly",
        short_label = "Disasm [D]",
    },
    sign = "DapStopped",
    ins_before_memref = 24,
    ins_after_memref = 24,
    columns = {
        "address",
        "instructionBytes",
        "instruction",
    },
})
local dap = require("dap")

-- Migration note:
-- nvim-dap-ui was intentionally replaced by nvim-dap-view because
-- dap-ui has no native disassembly section and does not support
-- registering arbitrary custom panes. Disassembly in DAP uses the
-- `disassemble` request, so we wire nvim-dap-disasm into nvim-dap-view.
--
-- lldb-dap supports disassembly and instruction-level features, so
-- this setup gives an IDE-like source + assembly workflow.
--
-- How to use:
-- - <leader>du toggles the debug UI
-- - <leader>dD toggles the disassembly section
-- - <leader>dr opens REPL
-- - Console/program output goes to nvim-dap terminal and REPL

vim.fn.sign_define("DapBreakpoint", {
    text = "●",
    texthl = "DiagnosticError",
    linehl = "",
    numhl = "",
})
vim.fn.sign_define("DapStopped", {
    text = ">",
    texthl = "DiagnosticWarn",
    linehl = "",
    numhl = "",
})
vim.fn.sign_define("DapBreakpointRejected", {
    text = "R",
    texthl = "DiagnosticInfo",
    linehl = "",
    numhl = "",
})

require("nvim-dap-virtual-text").setup({
    commented = true,
})

require("mason-nvim-dap").setup({
    ensure_installed = { "kotlin" },
    automatic_installation = true,
})

local function open_dap_view_once()
    if dap_view_is_open() then
        return
    end
    require("dap-view").open()
end

local function close_dap_view_if_idle()
    vim.defer_fn(function()
        if next(dap.sessions()) ~= nil then
            return
        end
        if not dap_ui_is_open() then
            return
        end
        require("dap-view").close(true)
    end, 20)
end

local function clear_dap_state_if_idle()
    vim.defer_fn(function()
        if next(dap.sessions()) ~= nil then
            return
        end
        clear_dap_virtual_text()
    end, 20)
end

dap.listeners.after.event_initialized["dapview_auto_open"] = open_dap_view_once
dap.listeners.after.event_terminated["dapview_auto_close"] = close_dap_view_if_idle
dap.listeners.after.event_exited["dapview_auto_close"] = close_dap_view_if_idle
dap.listeners.after.event_terminated["dap_virtual_text_cleanup"] = clear_dap_state_if_idle
dap.listeners.after.event_exited["dap_virtual_text_cleanup"] = clear_dap_state_if_idle
dap.listeners.after.disconnect["dap_virtual_text_cleanup"] = clear_dap_state_if_idle

-- Force disassembly refresh whenever execution stops, so the view
-- follows the current instruction pointer after each step/continue.
dap.listeners.after.event_stopped["dap_disasm_refresh"] = function()
    pcall(require("dap-disasm").refresh)
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "dap-float",
    callback = function(ev)
        vim.keymap.set("n", "q", "<cmd>bdelete!<cr>", { buffer = ev.buf, silent = true })
    end,
})

local lldb_dap_path = vim.fn.exepath("lldb-dap")
if lldb_dap_path == "" then
    lldb_dap_path = "lldb-dap"
end

dap.adapters.lldb = {
    type = "executable",
    command = lldb_dap_path,
    name = "lldb",
}

local kotlin_adapter_path = vim.fn.exepath("kotlin-debug-adapter")
if kotlin_adapter_path == "" then
    kotlin_adapter_path = "kotlin-debug-adapter"
end

dap.adapters.kotlin = {
    type = "executable",
    command = kotlin_adapter_path,
    args = { "--interpreter=vscode" },
}

local lldb_launch = {
    name = "Launch (lldb-dap)",
    type = "lldb",
    request = "launch",
    console = "integratedTerminal",
    program = function()
        local path = vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        if path == "" then
            return dap.ABORT
        end
        return vim.fn.fnamemodify(path, ":p")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    args = {},
}

local lldb_attach = {
    name = "Attach (lldb-dap)",
    type = "lldb",
    request = "attach",
    pid = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
}

local kotlin_launch = {
    name = "Launch Kotlin",
    type = "kotlin",
    request = "launch",
    projectRoot = "${workspaceFolder}",
    mainClass = function()
        local main_class = vim.fn.input("Main class (e.g. com.example.MainKt): ")
        if main_class == "" then
            return dap.ABORT
        end
        return main_class
    end,
}

local kotlin_attach = {
    name = "Attach Kotlin (:5005)",
    type = "kotlin",
    request = "attach",
    projectRoot = "${workspaceFolder}",
    hostName = "localhost",
    port = 5005,
    timeout = 2000,
}

dap.configurations.c = { lldb_launch, lldb_attach }
dap.configurations.cpp = { lldb_launch, lldb_attach }
dap.configurations.rust = { lldb_launch, lldb_attach }
dap.configurations.odin = { lldb_launch, lldb_attach }
dap.configurations.kotlin = { kotlin_launch, kotlin_attach }

require("gitsigns").setup({
    attach_to_untracked = true,
    preview_config = {
        border = "single",
        focusable = false,
    },
})

require("neogit").setup({
    graph_style = is_kitty and "kitty" or "ascii",
    commit_editor = {
        kind = "vsplit",
        show_staged_diff = false,
    },
    console_timeout = 5000,
    auto_show_console = false,
})

require("diffview").setup({
    view = {
        merge_tool = {
            layout = "diff3_mixed",
            disable_diagnostics = true,
            winbar_info = true,
        },
    },
})

if image_enabled then
    require("image").setup(image_opts)
end
local kotlin_root_markers = {
    "settings.gradle.kts",
    "settings.gradle",
    "build.gradle.kts",
    "build.gradle",
    "pom.xml",
    "workspace.json",
    ".git",
}

vim.lsp.config("kotlin_lsp", {
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if fname == "" then
            on_dir(vim.uv.cwd())
            return
        end

        local real_fname = vim.uv.fs_realpath(fname)
        local root = vim.fs.root(real_fname or fname, kotlin_root_markers)
        if not root and real_fname then
            root = vim.fs.root(fname, kotlin_root_markers)
        end

        on_dir(root or vim.fs.dirname(real_fname or fname) or vim.uv.cwd())
    end,
})

vim.lsp.config("asm_lsp", {
    filetypes = { "asm", "vmasm" },
    root_dir = function(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if fname == "" then
            on_dir(vim.uv.cwd())
            return
        end

        local root = vim.fs.root(fname, { ".asm-lsp.toml", ".git" })
        on_dir(root or vim.fs.dirname(fname) or vim.uv.cwd())
    end,
    get_language_id = function(_, filetype)
        if filetype == "dap-disassembly" then
            return "asm"
        end
        return filetype
    end,
    single_file_support = true,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "dap-disassembly",
    callback = function(args)
        if vim.fn.executable("asm-lsp") ~= 1 then
            return
        end

        vim.lsp.start({
            name = "asm_lsp",
            cmd = { "asm-lsp" },
            root_dir = vim.uv.cwd(),
            single_file_support = true,
            workspace_required = false,
            get_language_id = function()
                return "asm"
            end,
        }, {
            bufnr = args.buf,
            silent = true,
            reuse_client = function(client, config)
                return client.name == config.name and client.config.root_dir == config.root_dir
            end,
        })
    end,
})

vim.lsp.enable({
    "lua_ls",
    "vtsls",
    "clangd",
    "html",
    "cssls",
    "jsonls",
    "basedpyright",
    "zls",
    -- "tailwindcss",
    "dartls",
    "glsl_analyzer",
    "kotlin_lsp",
    "astro",
    "rust_analyzer",
    "sqlls",
    "oxlint",
    "ols",
    "asm_lsp",
})
require("mason").setup({})
require("lazydev").setup({
    library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
})
require("lspconfig.configs").vtsls = require("vtsls").lspconfig

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or client.name ~= "vtsls" then
            return
        end

        local items = {
            {
                name = "restart_tsserver",
                desc = "Does not restart vtsls itself, but restarts the underlying tsserver.",
            },
            {
                name = "open_tsserver_log",
                desc = "It will open prompt if logging has not been enabled.",
            },
            { name = "reload_projects", desc = "Reload tsserver projects for the workspace." },
            {
                name = "select_ts_version",
                desc = "Select version of ts either from workspace or global.",
            },
            { name = "goto_project_config", desc = "Open tsconfig.json." },
            { name = "goto_source_definition", desc = "Go to the source definition instead of typings." },
            { name = "file_references", desc = "Show references of the current file." },
            {
                name = "rename_file",
                desc = "Rename the current file and update all the related paths in the project.",
            },
            { name = "organize_imports", desc = "Organize imports in the current file." },
            { name = "sort_imports", desc = "Sort imports in the current file." },
            { name = "remove_unused_imports", desc = "Remove unused imports from the current file." },
            { name = "fix_all", desc = "Apply all available code fixes." },
            { name = "remove_unused", desc = "Remove unused variables and symbols." },
            { name = "add_missing_imports", desc = "Add missing imports for unresolved symbols." },
            { name = "source_actions", desc = "Pick applicable source actions (same as above)" },
        }

        vim.keymap.set("n", "<leader>lt", function()
            vim.ui.select(items, {
                prompt = "TypeScript LSP actions",
                format_item = function(entry)
                    return string.format("%-24s %s", entry.name, entry.desc or "")
                end,
            }, function(selection)
                if not selection or not selection.name then
                    return
                end

                vim.cmd("VtsExec " .. selection.name)
            end)
        end, { desc = "Typescript LSP actions (vtsls)", buffer = args.buf })
    end,
})
---@module "neo-tree"
---@type neotree.Config?
local opts = {
    enable_git_status = false,
    enable_diagnostics = false,
    filesystem = {
        follow_current_file = {
            enabled = true,
            leave_dirs_open = false,
        },
    },
    window = {
        width = 30,
    },
}

if not vim.g.icons_enabled then
    opts.default_component_configs = {
        indent = {
            with_expanders = true,
            expander_collapsed = ">",
            expander_expanded = "v",
        },
    }

    -- Drop the file/folder icon component entirely (no extra padding)
    opts.renderers = {
        directory = {
            { "indent" },
            { "name" },
        },
        file = {
            { "indent" },
            { "name" },
        },
    }
end

require("neo-tree").setup(opts)
local permission_hlgroups = {
    ["-"] = "NonText",
    ["r"] = "DiagnosticSignWarn",
    ["w"] = "DiagnosticSignError",
    ["x"] = "DiagnosticSignOk",
}

local function oil_action_run_cmd_on_file()
    local oil = require("oil")
    local entry = oil.get_cursor_entry()
    local cwd = oil.get_current_dir()

    if not entry then
        return
    end

    vim.ui.input({ prompt = "Enter command: " }, function(cmd)
        if not cmd then
            return
        end

        local full_path = cwd .. entry.name

        local function show_terminal(cmd_array)
            vim.cmd("botright new")
            vim.fn.jobstart(cmd_array, {
                on_exit = function(_, code)
                    if code ~= 0 then
                        vim.notify("Command exited with code: " .. code, vim.log.levels.WARN)
                    end
                end,
                term = true,
            })
            vim.cmd("startinsert")
        end

        if cmd and cmd ~= "" then
            local command_string = cmd .. " " .. vim.fn.shellescape(full_path)
            show_terminal({ "sh", "-c", command_string })
        else
            local stat = vim.uv.fs_stat(full_path)
            if stat and stat.type == "file" then
                if bit.band(stat.mode, tonumber("100", 8)) > 0 then
                    show_terminal({ full_path })
                else
                    vim.ui.select({ "Yes", "No" }, {
                        prompt = "File is not executable. Make it executable and run?",
                    }, function(choice)
                        if choice == "Yes" then
                            local chmod_res = vim.system({ "chmod", "+x", full_path }):wait()
                            if chmod_res.code == 0 then
                                vim.notify("Made file executable: " .. entry.name)
                                show_terminal({ full_path })
                            else
                                vim.notify("Failed to make file executable: " .. entry.name, vim.log.levels.ERROR)
                            end
                        else
                            vim.notify("Aborted execution of: " .. entry.name)
                        end
                    end)
                end
            else
                vim.notify("Not a valid file: " .. entry.name, vim.log.levels.WARN)
            end
        end
    end)
end

require("oil").setup({
    lsp_file_methods = {
        enabled = vim.version().minor ~= 12,
    },
    columns = {
        {
            "permissions",
            highlight = function(permission_str)
                local hls = {}
                for i = 1, #permission_str do
                    local char = permission_str:sub(i, i)
                    table.insert(hls, { permission_hlgroups[char], i - 1, i })
                end
                return hls
            end,
        },
        { "size", highlight = "Special" },
        { "mtime", highlight = "Number" },
        {
            "icon",
            add_padding = false,
        },
    },
    skip_confirm_for_simple_edits = true,
    view_options = {
        show_hidden = true,
        is_always_hidden = function(name, _)
            return name == ".." or name == "../"
        end,
    },
    keymaps = {
        ["q"] = "actions.close",
        ["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
        ["?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<F1>"] = oil_action_run_cmd_on_file,
        ["<F5>"] = "actions.refresh",
        ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["-"] = { "actions.parent", mode = "n" },
        ["<Left>"] = { "actions.parent", mode = "n" },
        ["<Right>"] = { "actions.select", mode = "n" },
        ["H"] = "actions.toggle_hidden",
    },
    confirmation = {
        border = "single",
    },
    win_options = {
        winbar = "%!v:lua.get_oil_winbar()",
        signcolumn = "no",
        -- number = false,
        -- relativenumber = false,
    },
    use_default_keymaps = false,
    watch_for_changes = true,
    constrain_cursor = "name",
})

require("quicker").setup({
    keys = {
        {
            ">",
            function()
                require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
            end,
            desc = "Expand quickfix context",
        },
        {
            "<",
            function()
                require("quicker").collapse()
            end,
            desc = "Collapse quickfix context",
        },
    },
})

require("refer").setup({
    on_close = function()
        vim.cmd("nohlsearch")
    end,
    providers = {
        grep = {
            grep_command = default_live_grep_command,
        },
    },
    keymaps = {
        ["<C-q>"] = send_all_refer_matches_to_qf,
    },
})

require("refer").setup_ui_select()
ensure_refer_picker_resume_patch()
require("luasnip.loaders.from_vscode").lazy_load()
require("luasnip").setup({})
require("nvim-treesitter.install").prefer_git = true

---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
    ensure_installed = {
        "go",
        "lua",
        "python",
        "rust",
        "tsx",
        "javascript",
        "typescript",
        "vimdoc",
        "vim",
        "v",
        "markdown",
        "kotlin",
    },
    auto_install = true,
    highlight = {
        enable = true,
        disable = function(_, buf)
            local max_filesize = 1024 * 1024
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
                return true
            end
        end,
    },
    indent = { enable = false },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = "vv",
            node_incremental = "vv",
        },
    },
})

local ts_start = vim.treesitter.start
if not vim.g.treesitter_enabled then
    local allowed_langs = {
        markdown = true,
        javascript = true,
        typescript = true,
        tsx = true,
    }

    local filetype_to_lang = {
        markdown = "markdown",
        javascript = "javascript",
        typescript = "typescript",
        javascriptreact = "tsx",
        typescriptreact = "tsx",
    }

    local function resolve_lang(bufnr, lang)
        if lang and allowed_langs[lang] then
            return lang
        end

        local filetype = vim.bo[bufnr].filetype
        return filetype_to_lang[filetype]
    end

    ---@diagnostic disable-next-line: duplicate-set-field
    vim.treesitter.start = function(bufnr, lang)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        local bufname = vim.api.nvim_buf_get_name(bufnr)

        if bufname == "" then
            return ts_start(bufnr, lang)
        end

        local resolved_lang = resolve_lang(bufnr, lang)
        if resolved_lang then
            return ts_start(bufnr, lang or resolved_lang)
        end
    end
end

local wk = require("which-key")
wk.setup({
    icons = { mappings = false },
    win = {
        border = "single",
        height = { min = 4, max = 10 },
    },
})
wk.add({
    { "<leader>f", group = "file" },
    { "<leader>s", group = "search" },
    { "<leader>g", group = "git" },
    { "<leader>gl", group = "list" },
    { "<leader>h", group = "hunk" },
    { "<leader>l", group = "lsp" },
    { "<leader>t", group = "toggle" },
    { "<leader>i", group = "insert" },
    { "<leader>d", group = "debug" },
    { "<leader>c", group = "opencode" },
})

vim.keymap.set("n", "<leader>tu", "<cmd>UndotreeToggle<cr>", { desc = "Undotree" })

vim.keymap.set("n", "<F1>", function()
    require("dap.ui.widgets").hover()
end, { desc = "DAP Hover" })
vim.keymap.set("n", "<F5>", function()
    require("dap").continue()
end, { desc = "DAP continue" })
vim.keymap.set("n", "<F10>", function()
    require("dap").step_over()
end, { desc = "DAP step over" })
vim.keymap.set("n", "<F11>", function()
    require("dap").step_into()
end, { desc = "DAP step into" })
vim.keymap.set("n", "<F12>", function()
    require("dap").step_out()
end, { desc = "DAP step out" })
vim.keymap.set("n", "<leader>dd", function()
    require("dap").toggle_breakpoint()
end, { desc = "Toggle breakpoint" })
vim.keymap.set("n", "<leader>dB", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Conditional breakpoint" })
vim.keymap.set("n", "<leader>dc", function()
    require("dap").continue()
end, { desc = "Continue" })
vim.keymap.set("n", "<leader>dl", function()
    require("dap").run_last()
end, { desc = "Run last" })
vim.keymap.set("n", "<leader>do", function()
    require("dap").step_over()
end, { desc = "Step over" })
vim.keymap.set("n", "<leader>di", function()
    require("dap").step_into()
end, { desc = "Step into" })
vim.keymap.set("n", "<leader>dO", function()
    require("dap").step_out()
end, { desc = "Step out" })
vim.keymap.set("n", "<leader>dp", function()
    require("dap").pause()
end, { desc = "Pause" })
vim.keymap.set("n", "<leader>ds", function()
    clear_dap_virtual_text()
    require("dap").terminate()
    require("dap").disconnect()
    require("dap").close()
end, { desc = "Stop" })
vim.keymap.set("n", "<leader>du", function()
    local dapview = require("dap-view")
    if dap_ui_is_open() then
        dapview.close(true)
        return
    end
    dapview.open()
end, { desc = "Toggle debug UI" })
vim.keymap.set("n", "<leader>dD", toggle_disassembly_view, { desc = "Toggle disassembly view" })
vim.keymap.set("n", "<leader>dw", function()
    require("dap-view").add_expr()
end, { desc = "Add watch expression" })

vim.keymap.set("n", "<leader>ub", toggle_dbui_tab, { desc = "DBUI" })
vim.keymap.set("n", "<leader>ua", "<cmd>DBUIAddConnection<cr>", { desc = "Add new connection" })

vim.keymap.set("n", "]h", function()
    nav_hunk("next")
end, { desc = "Next hunk" })
vim.keymap.set("n", "[h", function()
    nav_hunk("prev")
end, { desc = "Previous hunk" })
vim.keymap.set("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>gB", "<cmd>Gitsigns blame<cr>", { desc = "Git blame" })
vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
vim.keymap.set("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame inline" })
vim.keymap.set("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", { desc = "Preview hunk inline" })
vim.keymap.set("n", "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", { desc = "Toggle word diff" })
vim.keymap.set("n", "<M-g>", function()
    require("neogit").open({ kind = "replace" })
end, { desc = "Git status" })
vim.keymap.set("n", "<leader>gg", function()
    require("neogit").open({ kind = "replace" })
end, { desc = "Git status" })
vim.keymap.set("n", "<leader>gc", function()
    require("neogit.buffers.commit_view").new("HEAD"):open("replace")
end, { desc = "Git commit" })
vim.keymap.set("n", "<leader>gb", "<cmd>Neogit branch<cr>", { desc = "Git branch" })
vim.keymap.set("n", "<leader>gL", "<cmd>NeogitLogCurrent<cr>", { desc = "Git log" })
vim.keymap.set("n", "<leader>gD", ":DiffviewOpen ", { desc = "Git DiffView" })
vim.keymap.set("n", "<leader>gh", function()
    vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
end, { desc = "Git file history (Current)" })
vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>", { desc = "Git file history (All)" })

vim.keymap.set("n", "<leader>b", open_neotree, { desc = "Explorer" })
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Explore" })
vim.keymap.set("n", "<leader>q", function()
    require("quicker").toggle()
end, { desc = "Quickfix list" })

vim.keymap.set("n", "<M-x>", function()
    run_and_remember_picker(open_refer_commands)
end, { desc = "commands" })
vim.keymap.set("n", "<leader><space>", function()
    run_and_remember_picker(open_refer_files)
end, { desc = "Find Files" })
vim.keymap.set("n", "<leader>sc", function()
    run_and_remember_picker(pick_colorschemes)
end, { desc = "Search colorscheme" })
vim.keymap.set("n", "<leader>ff", function()
    run_and_remember_picker(pick_files_fff)
end, { desc = "Find file (fff)" })
vim.keymap.set("n", "<leader>so", function()
    run_and_remember_picker(pick_vim_options)
end, { desc = "Search option" })
vim.keymap.set("n", "<leader>ss", function()
    run_and_remember_picker(pick_spell_suggestions)
end, { desc = "Search spelling suggestion" })
vim.keymap.set("n", "<leader>sH", function()
    run_and_remember_picker(pick_highlights)
end, { desc = "Search highlight group" })
vim.keymap.set("n", "<leader>fn", function()
    run_and_remember_picker(open_nvim_config_files)
end, { desc = "Find neovim config files" })
vim.keymap.set("n", "<leader>fp", function()
    run_and_remember_picker(open_lazy_data_files)
end, { desc = "Find data files" })
vim.keymap.set("n", "<leader>,", function()
    run_and_remember_picker(open_refer_buffers)
end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>/", function()
    run_and_remember_picker(pick_grep_fff)
end, { desc = "Grep (fff)" })
vim.keymap.set("n", "<leader>sb", function()
    run_and_remember_picker(live_grep_current_buffer)
end, { desc = "Search buffer" })
vim.keymap.set("n", "<leader>sh", function()
    run_and_remember_picker(pick_help_tags)
end, { desc = "Search help" })
vim.keymap.set({ "n", "v" }, "<leader>sw", function()
    run_and_remember_picker(grep_string_with_fff)
end, { desc = "Search word with grep" })
vim.keymap.set("n", "<leader>'", resume_last_picker, { desc = "Resume last search" })
vim.keymap.set("n", "gd", function()
    run_and_remember_picker(open_refer_definitions)
end, { desc = "Go to definitions" })
vim.keymap.set("n", "gr", function()
    run_and_remember_picker(open_refer_references)
end, { desc = "Go to references" })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
        local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

        local config = {
            name = "jdtls",
            cmd = {
                "jdtls",
                "-data",
                workspace_dir,
                "--jvm-arg=-javaagent:" .. vim.fn.expand("~/.local/share/nvim/mason/packages/jdtls/lombok.jar"),
                "--jvm-arg=--enable-preview",
            },
            root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
            settings = {
                java = {
                    configuration = {
                        runtimes = {},
                    },
                    compile = {
                        nullAnalysis = {
                            mode = "automatic",
                        },
                    },
                    sources = {
                        organizeImports = {
                            starThreshold = 9999,
                            staticStarThreshold = 9999,
                        },
                    },
                    eclipse = {
                        downloadSources = true,
                    },
                    maven = {
                        downloadSources = true,
                    },
                    implementationsCodeLens = {
                        enabled = true,
                    },
                    referencesCodeLens = {
                        enabled = true,
                    },
                    format = {
                        enabled = true,
                    },
                    settings = {
                        url = vim.fn.stdpath("config") .. "/jdtls-settings.prefs",
                    },
                },
            },
            init_options = {
                bundles = {},
                extendedClientCapabilities = {
                    progressReportProvider = false,
                },
            },
            flags = {
                allow_incremental_sync = true,
            },
        }

        require("jdtls").start_or_attach(config)
    end,
})
