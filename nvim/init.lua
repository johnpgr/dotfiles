local function feedkeys(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", true)
end

local title_prompt = [[
Generate chat title in filepath-friendly format for:

```
%s
```

Output only the title and nothing else in your response. USE HYPHENS ONLY to separate words.
]]

local is_neovide = vim.g.neovide ~= nil
local is_kitty = os.getenv("TERM") == "xterm-kitty"

vim.g.treesitter_enabled = true
vim.g.icons_enabled = true
-- vim.g.sqlite_clib_path = "c:/sqlite3/sqlite3.dll"

vim.g.c_syntax_for_h = false
vim.g.gruvbox_contrast_dark = "hard"
vim.g.gruvbox_sign_column = "bg0"
vim.g.gruvbox_italicize_comments = 0
vim.g.gruvbox_invert_selection = 0
vim.g.mapleader = " "
vim.o.cursorline = true
vim.o.number = true
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
vim.o.mouse = "nv"
vim.o.smartcase = true
vim.o.breakindent = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.termguicolors = true
vim.o.undofile = true
vim.o.undolevels = 10000
vim.o.scrolloff = 5
vim.o.updatetime = 250
vim.o.timeoutlen = 500
vim.opt.diffopt:append("linematch:60")
vim.opt.fillchars:append({ eob = " " })

---Show attached LSP clients in `[name1, name2]` format.
---Long server names will be modified. For example, `lua-language-server` will be shorten to `lua-ls`
---Returns an empty string if there aren't any attached LSP clients.
---@return string
local function lsp_status()
    local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
    if #attached_clients == 0 then
        return ""
    end
    local names = vim.iter(attached_clients)
        :map(function(client)
            local name = client.name:gsub("language.server", "ls")
            return name
        end)
        :totable()
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

local lsp_floating_preview_original = vim.lsp.util.open_floating_preview
---@diagnostic disable-next-line: duplicate-set-field
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = "single"
    opts.max_width = opts.max_width or 100
    return lsp_floating_preview_original(contents, syntax, opts, ...)
end

vim.diagnostic.config {
    severity_sort = true,
    float = { border = "single", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    virtual_text = {
        source = "if_many",
        spacing = 2,
        format = function(diagnostic)
            local diagnostic_message = {
                [vim.diagnostic.severity.ERROR] = diagnostic.message,
                [vim.diagnostic.severity.WARN] = diagnostic.message,
                [vim.diagnostic.severity.INFO] = diagnostic.message,
                [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
        end,
    },
}

if not is_neovide then
    require "vim._extui".enable {}
end

function _G.get_oil_winbar()
    local result = ""
    -- Get the buffer for the window that's displaying this winbar
    local winid = vim.g.statusline_winid or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winid)

    -- Check if this specific buffer is an Oil buffer
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

    return result
end

---@diagnostic disable-next-line: param-type-mismatch
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    once = true,
    callback = function()
        if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
            vim.g.clipboard = {
                copy = {
                    ["+"] = "win32yank.exe -i --crlf",
                    ["*"] = "win32yank.exe -i --crlf",
                },
                paste = {
                    ["+"] = "win32yank.exe -o --lf",
                    ["*"] = "win32yank.exe -o --lf",
                },
            }
        elseif vim.fn.has("unix") == 1 then
            if vim.fn.executable("xclip") == 1 then
                vim.g.clipboard = {
                    copy = {

                        ["+"] = "xclip -selection clipboard",
                        ["*"] = "xclip -selection clipboard",
                    },
                    paste = {
                        ["+"] = "xclip -selection clipboard -o",
                        ["*"] = "xclip -selection clipboard -o",
                    },
                }
            elseif vim.fn.executable("xsel") == 1 then
                vim.g.clipboard = {
                    copy = {
                        ["+"] = "xsel --clipboard --input",
                        ["*"] = "xsel --clipboard --input",
                    },

                    paste = {
                        ["+"] = "xsel --clipboard --output",
                        ["*"] = "xsel --clipboard --output",
                    },
                }
            end
        end

        vim.opt.clipboard = "unnamedplus"
    end,

    desc = "Slow clipboard fix",
})

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        ---@diagnostic disable-next-line: need-check-nil
        client.server_capabilities.semanticTokensProvider = nil
        vim.lsp.document_color.enable(false, args.buf)
    end,
})

if vim.g.icons_enabled then
    vim.pack.add { { src = "https://github.com/nvim-tree/nvim-web-devicons" } }
end

-- PLUGINS
vim.pack.add {
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/farmergreg/vim-lastplace" },
    { src = "https://github.com/vague2k/vague.nvim" },
    { src = "https://github.com/NeogitOrg/neogit" },
    { src = "https://github.com/sindrets/diffview.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },
    { src = "https://github.com/aserowy/tmux.nvim" },
    { src = "https://github.com/mbbill/undotree" },
    { src = "https://github.com/hedyhli/outline.nvim" },
    { src = "https://github.com/mg979/vim-visual-multi" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/JoosepAlviste/nvim-ts-context-commentstring" },
    { src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim" },
    { src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" },
    { src = "https://github.com/nvim-telescope/telescope.nvim" },
    { src = "https://github.com/johnpgr/telescope-file-browser.nvim",
        version = "absolute-path-prompt-prefix" },
    { src = "https://github.com/nvim-telescope/telescope-symbols.nvim" },
    { src = "https://github.com/nvim-telescope/telescope-github.nvim" },
    { src = "https://github.com/echasnovski/mini.comment" },
    { src = "https://github.com/folke/which-key.nvim" },
    { src = "https://github.com/morhetz/gruvbox" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/L3MON4D3/LuaSnip" },
    { src = "https://github.com/saghen/blink.cmp" },
    { src = "https://github.com/rafamadriz/friendly-snippets" },
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/stevearc/quicker.nvim" },
    { src = "https://github.com/johmsalas/text-case.nvim" },
    { src = "https://github.com/stevearc/overseer.nvim" },
    { src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
    { src = "https://github.com/CopilotC-Nvim/CopilotChat.nvim" },
    { src = "https://github.com/3rd/image.nvim" },
    { src = "https://github.com/kkharji/sqlite.lua" },
    { src = "https://github.com/stevearc/conform.nvim" },
    { src = "https://github.com/folke/lazydev.nvim" },
    { src = "https://github.com/tpope/vim-dadbod" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-completion" },
    { src = "https://github.com/kristijanhusak/vim-dadbod-ui" },
}

require "nvim-treesitter.configs".setup {
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
    highlight = { enable = true, disable = function(_, buf)
        local max_filesize = 1024 * 1024
        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
            return true
        end
    end
    },
    indent = { enable = true },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = "vv",
            node_incremental = "vv",
        },
    },
}

local ts_start = vim.treesitter.start
if not vim.g.treesitter_enabled then
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.treesitter.start = function(bufnr, lang)
        if lang ~= "markdown" then
            return
        end

        return ts_start(bufnr, lang)
    end
end

require "gitsigns".setup {
    signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
    },
    attach_to_untracked = true,
    preview_config = {
        border = "single",
    },
}

require "diffview".setup {}

if not is_neovide then
    require "tmux".setup {
        copy_sync = {
            enable = false,
        },
    }
end

local function has_words_before()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 then
        return false
    end
    local line = vim.api.nvim_get_current_line()
    return line:sub(col, col):match("%s") == nil
end

local blink = require "blink.cmp"

local function toggle_menu(cmp)
    if not blink.is_visible() then
        cmp.show()
    else
        cmp.hide()
    end
end

blink.setup {
    keymap = {
        preset = "default",
        ["<C-space>"] = { toggle_menu },
        ["<Tab>"] = {
            function(cmp)
                if blink.is_visible() then
                    return cmp.select_and_accept()
                elseif has_words_before() then
                    return cmp.insert_next()
                end
            end,
            'snippet_forward',
            'fallback'
        },
        ["<S-Tab>"] = { "insert_prev" },
    },
    snippets = {
        preset = "luasnip",
    },
    sources = {
        default = { "lazydev", 'lsp', 'buffer', 'snippets', 'path' },
        providers = {
            dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
            lazydev = {
                name = "LazyDev",
                module = "lazydev.integrations.blink",
                -- make lazydev completions top priority (see `:h blink.cmp`)
                score_offset = 100,
            },
            lsp = {
                name = 'LSP',
                module = 'blink.cmp.sources.lsp',
                transform_items = function(_, items)
                    return vim.tbl_filter(function(item)
                        return item.kind ~= require('blink.cmp.types').CompletionItemKind.Keyword
                    end, items)
                end,
            },
        },
        per_filetype = {
            sql = { "snippets", "dadbod", "buffer" },
            ["copilot-chat"] = { "snippets" }
        },
    },
    completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        menu = {
            auto_show = false,
            max_height = 20,
            draw = {
                columns = {
                    { "label", "label_description" },
                    { "kind" }
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
        completion = {
            menu = { auto_show = false, draw = {
                columns = {
                    { "label", "label_description" },
                },
            } }
        },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
}

require "conform".setup {
    formatters_by_ft = {
        lua = { lsp_format = "fallback" },
        -- Conform will run multiple formatters sequentially
        python = { "isort", "black" },
        -- You can customize some of the format options for the filetype (:help conform.format)
        rust = { "rustfmt", lsp_format = "fallback" },
        -- Conform will run the first available formatter
        html = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        css = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        json = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        javascript = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        typescript = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true, lsp_format = "fallback" },
    },
}

require "mini.comment".setup {
    options = {
        custom_commentstring = function()
            return require("ts_context_commentstring.internal").calculate_commentstring()
                or vim.bo.commentstring
        end,
    },
    mappings = {
        comment_line = "gcc",
        comment_visual = "gc",
    },
}


local wk = require "which-key"
wk.setup {
    icons = { mappings = false },
    win = {
        border = "single",
        height = { min = 4, max = 10 },
    }
}

wk.add {
    { "<leader>f",  group = "file" },
    { "<leader>s",  group = "search" },
    { "<leader>g",  group = "git" },
    { "<leader>gl", group = "list" },
    { "<leader>h",  group = "hunk" },
    { "<leader>c",  group = "copilot" },
    { "<leader>l",  group = "lsp" },
    { "<leader>t",  group = "toggle" },
    { "<leader>ld", group = "diagnostics" },
    { "<leader>i",  group = "insert" },
    { "<leader>d",  group = "db" },
}

require "mason".setup {}

local quicker = require "quicker"
quicker.setup {
    keys = {
        {
            ">",
            function()
                quicker.expand({ before = 2, after = 2, add_to_existing = true })
            end,
            desc = "Expand quickfix context",
        },
        {
            "<",
            function()
                quicker.collapse()
            end,
            desc = "Collapse quickfix context",
        },
    },
}

require "textcase".setup {
    prefix = "tc",
    substitude_command_name = "S",
}

require "ibl".setup {
    indent = { char = "│" },
    enabled = false,
    scope = { enabled = false },
}

local function oil_action_run_cmd_on_file()
    local oil = require("oil")
    local entry = oil.get_cursor_entry()
    local cwd = oil.get_current_dir()

    if not entry then
        return
    end

    vim.ui.input(
        { prompt = "Enter command: " },
        function(cmd)
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
                                    vim.notify(
                                        "Failed to make file executable: " .. entry.name,
                                        vim.log.levels.ERROR
                                    )
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
        end
    )
end

local permission_hlgroups = {
    ["-"] = "NonText",
    ["r"] = "DiagnosticSignWarn",
    ["w"] = "DiagnosticSignError",
    ["x"] = "DiagnosticSignOk",
}

require "oil".setup {
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
        { "size",  highlight = "Special" },
        { "mtime", highlight = "Number" },
        {
            "icon",
            add_padding = false,
        },
    },
    skip_confirm_for_simple_edits = true,
    keymaps = {
        ["q"] = "actions.close",
        ["<RightMouse>"] = "<LeftMouse><cmd>lua require('oil.actions').select.callback()<CR>",
        ["?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<F5>"] = "actions.refresh",
        ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
        ["-"] = { "actions.parent", mode = "n" },
        ["h"] = { "actions.parent", mode = "n" },
        ["l"] = { "actions.select", mode = "n" },
        ["<Left>"] = { "actions.parent", mode = "n" },
        ["<Right>"] = { "actions.select", mode = "n" },
        ["H"] = "actions.toggle_hidden",
        ["<F1>"] = oil_action_run_cmd_on_file,
    },
    confirmation = {
        border = "single",
    },
    win_options = {
        winbar = "%!v:lua.get_oil_winbar()",
        number = false,
        relativenumber = false,
        signcolumn = "no",
    },
    use_default_keymaps = false,
    watch_for_changes = true,
    constrain_cursor = "name",
}

require "vague".setup {
    transparent = false,
    bold = false,
    italic = false,
}

require "outline".setup { outline_window = { position = "left" } }

require "overseer".setup {
    task_list = {
        min_width = { 60, 0.25 },
        bindings = {
            ["R"] = "<cmd>OverseerQuickAction restart<cr>",
            ["D"] = "<cmd>OverseerQuickAction dispose<cr>",
            ["W"] = "<cmd>OverseerQuickAction watch<cr>",
            ["S"] = "<cmd>OverseerQuickAction stop<cr>",
            ["<C-l>"] = false,
            ["<C-h>"] = false,
            ["<C-k>"] = false,
            ["<C-j>"] = false,
        },
    },
}

if is_kitty then
    require "image".setup {
        integrations = {
            markdown = {
                only_render_image_at_cursor = true,
            }
        },
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.bmp" },
    }
end

local default_picker_config = {
    borderchars = {
        { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
        prompt = { "─", "│", " ", "│", '┌', '┐', "│", "│" },
        results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
        preview = { '─', '│', '─', '│', '┌', '┐', '┘', '└' },
    },
    theme = "dropdown",
    previewer = false,
    layout_config = {
        width = 0.5,
    },
    results_title = false,
}
local telescope = require "telescope"
local telescope_builtin = require "telescope.builtin"
local telescope_themes = require "telescope.themes"
local telescope_actions = require "telescope.actions"
local telescope_action_state = require "telescope.actions.state"
local telescope_utils = require "telescope.utils"

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
local function fuzzy_find_current_buffer()
    local original_win = vim.api.nvim_get_current_win()
    local original_bufnr = vim.api.nvim_get_current_buf()

    local action_state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local opts = vim.tbl_extend("force", default_picker_config, {
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

                        vim.cmd("normal! m'")
                        vim.api.nvim_win_set_cursor(original_win, { selection.lnum, col })

                        if vim.api.nvim_win_is_valid(original_win) then
                            vim.api.nvim_win_call(original_win, function()
                                vim.cmd("normal! zz")
                            end)
                        end
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
    telescope_builtin.current_buffer_fuzzy_find(opts)
end

local function persist_colorscheme(bufnr)
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local selection = action_state.get_selected_entry()
    local new = selection.value

    actions.close(bufnr)
    local ok = pcall(vim.cmd.colorscheme, new)
    if ok then
        local sqlite = require("sqlite.db")
        local tbl = require("sqlite.tbl")
        local config_uri = vim.fn.stdpath("data") .. "/nvim_config.db"

        local colorscheme_tbl = tbl("colorscheme", {
            id = { "integer", primary = true },
            name = { "text", required = true, unique = true },
            updated_at = { "integer", default = sqlite.lib.strftime("%s", "now") },
        })

        sqlite({
            uri = config_uri,
            colorscheme = colorscheme_tbl,
        })

        local existing = colorscheme_tbl:get({ where = { name = new }, limit = 1 })
        if #existing > 0 then
            colorscheme_tbl:update({
                where = { id = existing[1].id },
                set = { updated_at = os.time() }
            })
        else
            colorscheme_tbl:insert({ name = new, updated_at = os.time() })
        end
    end
end

local function load_persisted_colorscheme()
    local sqlite = require("sqlite.db")
    local tbl = require("sqlite.tbl")
    local config_uri = vim.fn.stdpath("data") .. "/nvim_config.db"

    local colorscheme_tbl = tbl("colorscheme", {
        id = { "integer", primary = true },
        name = { "text", required = true, unique = true },
        updated_at = { "integer", default = sqlite.lib.strftime("%s", "now") },
    })

    sqlite({
        uri = config_uri,
        colorscheme = colorscheme_tbl,
    })

    local recent = colorscheme_tbl:get({
        order_by = { desc = "updated_at" },
        limit = 1
    })

    if #recent > 0 then
        pcall(vim.cmd.colorscheme, recent[1].name)
        vim.cmd [[
            " hi Normal guibg=none
            " hi StatusLine guibg=none
            " hi StatusLineNC guibg=none

            hi! link MsgSeparator WinSeparator
            hi Operator guibg=none
            hi MatchParen guifg=bg
            hi WinBar guibg=none
            hi WinBarNC guibg=none
            hi NormalFloat guibg=none
            hi FloatBorder guibg=none
            hi MiniPickPrompt guibg=none
        ]]
    end
end

vim.api.nvim_create_autocmd("VimEnter", {
    callback = load_persisted_colorscheme,
    once = true,
})

telescope.setup {
    defaults = {
        mappings = {
            i = {
                ["<C-q>"] = function(bufnr)
                    telescope_actions.send_to_qflist(bufnr)
                    vim.cmd("copen")
                end,
                ["<Esc>"] = telescope_actions.close
            },
        },
    },
    extensions = {
        file_browser = vim.tbl_extend("force", default_picker_config, {
            path = "%:p:h",
            prompt_path = true,
            git_status = false,
            hide_parent_dir = true,
            grouped = true,
            dir_icon = vim.g.icons_enabled and "" or " ",
            dir_icon_hl = "Directory",
            prompt_title = "Find Files",
            mappings = {
                i = {
                    ["<Tab>"] = function(bufnr)
                        local fb_actions = require("telescope").extensions.file_browser.actions
                        local entry = telescope_action_state.get_selected_entry()
                        local entry_path = entry.Path

                        if entry_path:is_dir() then
                            fb_actions.open_dir(bufnr, nil, entry.path)
                        else
                            local picker = telescope_action_state.get_current_picker(bufnr)
                            picker:set_prompt(entry.ordinal)
                        end
                    end,
                    ["<C-w>"] = require("telescope").extensions.file_browser.actions.backspace
                },
            },
        }),
        fzf = {},
        ["ui-select"] = {
            telescope_themes.get_dropdown(default_picker_config),
        },
    },
    pickers = {
        buffers = vim.tbl_extend("force", default_picker_config, {
            mappings = {
                i = {
                    ["<C-d>"] = telescope_actions.delete_buffer + telescope_actions.move_to_top,
                },
            },
        }),
        find_files = default_picker_config,
        live_grep = default_picker_config,
        vim_options = default_picker_config,
        highlights = vim.tbl_extend("force", default_picker_config, {
            previewer = true,
        }),
        oldfiles = default_picker_config,
        help_tags = default_picker_config,
        commands = default_picker_config,
        colorscheme = vim.tbl_extend("force", default_picker_config, {
            enable_preview = true,
            mappings = {
                n = {
                    ["<CR>"] = persist_colorscheme,
                },
                i = {
                    ["<CR>"] = persist_colorscheme,
                }
            },
        }),
        spell_suggest = default_picker_config,
        reloader = default_picker_config,
        current_buffer_fuzzy_find = default_picker_config,
        symbols = default_picker_config,
    },
}

telescope.load_extension("ui-select")
telescope.load_extension("fzf")
telescope.load_extension("file_browser")
telescope.load_extension("gh")

local copilot_chat = require "CopilotChat"
copilot_chat.setup {
    callback = function(res)
        if vim.g.chat_title then
            vim.defer_fn(function()
                copilot_chat.save(vim.g.chat_title)
            end, 100)
            return
        end

        copilot_chat.ask(title_prompt:format(res.content), {
            headless = true,
            model = "gpt-4.1",
            callback = function(res2)
                vim.g.chat_title = vim.trim(res2.content)
                copilot_chat.save(vim.g.chat_title)
            end
        })
    end,
    model = "gpt-4.1",
    chat_autocomplete = true,
    mappings = {
        complete = {
            insert = "",
        },
        reset = {
            normal = "",
            insert = "",
        }
    },
}

local luasnip = require("luasnip")
luasnip.setup {}
local snippet = luasnip.snippet
local text_node = luasnip.text_node

local function get_working_directory_files()
    local files = {}
    local handle = io.popen("rg --files")
    if handle then
        for file in handle:lines() do
            local trigger = vim.fn.fnamemodify(file, ":t:r")
            files[#files + 1] = {
                trigger = trigger,
                path = "> #file:" .. file,
            }
        end
        handle:close()
    end
    return files
end

vim.api.nvim_create_autocmd("WinEnter", {
    pattern = "copilot-chat",
    callback = function()
        vim.opt_local.foldcolumn = "0"
        vim.opt_local.number = false
        vim.opt_local.cursorline = false

        local snippets = {}
        for _, file_info in ipairs(get_working_directory_files()) do
            snippets[#snippets + 1] = snippet(file_info.trigger, { text_node(file_info.path) })
        end

        require("luasnip.session.snippet_collection").clear_snippets("copilot-chat")
        luasnip.add_snippets("copilot-chat", snippets)
        vim.treesitter.start()
    end
})

require "neogit".setup {
    graph_style = is_kitty and "kitty" or "ascii",
    commit_editor = {
        kind = "vsplit",
        show_staged_diff = false,
    },
    console_timeout = 5000,
    auto_show_console = false,
}
require "lazydev".setup {
    library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
}

vim.lsp.enable {
    "lua_ls",
    "vtsls",
    "jdtls",
    "clangd",
    "html",
    "jsonls",
    "pyright",
    "zls",
    "tailwindcss",
    "dartls",
    "glsl_analyzer",
    "kotlin_language_server",
}

vim.filetype.add({
    extension = {
        hlsl = "hlsl",
        m = "objc",
    }
})


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

local function parse_history_path(file)
    return vim.fn.fnamemodify(file, ":t:r")
end

local function format_display_name(filename)
    filename = filename:gsub("%.%w+$", "")
    return filename:gsub("%-", " "):gsub("^%w", string.upper)
end

local function find_chat_history()
    telescope_builtin.find_files({
        prompt_title = "CopilotChat History",
        cwd = copilot_chat.config.history_path,
        hidden = true,
        follow = true,
        layout_config = {
            height = 0.3,
        },
        find_command = { "rg", "--files", "--sortr=modified" },
        entry_maker = function(entry)
            local full_path = copilot_chat.config.history_path .. "/" .. entry
            ---@diagnostic disable-next-line: undefined-field
            local stat = vim.loop.fs_stat(full_path)
            local mtime = stat and stat.mtime.sec or 0
            local display_time = stat and os.date("%d-%m-%Y %H:%M", mtime) or "Unknown"
            local display_name = format_display_name(entry)
            return {
                value = entry,
                display = string.format("%s | %s", display_time, display_name),
                ordinal = string.format("%s %s", display_time, display_name),
                path = entry,
                index = -mtime,
            }
        end,
        attach_mappings = function(prompt_bufnr, map)
            telescope_actions.select_default:replace(function()
                telescope_actions.close(prompt_bufnr)
                local selection = telescope_action_state.get_selected_entry()
                local path = selection.value
                local parsed = parse_history_path(path)
                vim.g.chat_title = parsed
                copilot_chat.load(parsed)
                copilot_chat.open()
            end)

            local function delete_history()
                local selection = telescope_action_state.get_selected_entry()
                if not selection then
                    return
                end

                local full_path = copilot_chat.config.history_path .. "/" .. selection.value

                -- Confirm deletion
                vim.ui.select({ "Yes", "No" }, {
                    prompt = "Delete chat history: " .. format_display_name(selection.value) .. "?",
                    telescope = { layout_config = { width = 0.3, height = 0.3 } },
                }, function(choice)
                    if choice == "Yes" then
                        vim.fn.delete(full_path)
                        find_chat_history()
                    end
                end)
            end

            map("i", "<C-d>", delete_history)
            map("n", "D", delete_history)
            return true
        end,
    })
end

vim.keymap.set("n", "<C-q>", "<cmd>quit<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>R", "<cmd>restart<cr>", { desc = "Restart" })
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlights" })
vim.keymap.set("n", "<leader>I", "<cmd>Inspect<cr>", { desc = "Inspect" })
vim.keymap.set("n", "yig", ":%y<CR>", { desc = "Yank buffer" })
vim.keymap.set("n", "vig", "ggVG", { desc = "Visual select buffer" })
vim.keymap.set("n", "cig", ":%d<CR>i", { desc = "Change buffer" })

if not is_neovide then
    vim.keymap.set("n", "<C-k>", require("tmux").move_top, { desc = "Move to tmux top" })
    vim.keymap.set("n", "<C-l>", require("tmux").move_right, { desc = "Move to tmux right" })
    vim.keymap.set("n", "<C-j>", require("tmux").move_bottom, { desc = "Move to tmux bottom" })
    vim.keymap.set("n", "<C-h>", require("tmux").move_left, { desc = "Move to tmux left" })
    vim.keymap.set("n", "<A-k>", require("tmux").resize_top, { desc = "Resize tmux top" })
    vim.keymap.set("n", "<A-l>", require("tmux").resize_right, { desc = "Resize tmux right" })
    vim.keymap.set("n", "<A-j>", require("tmux").resize_bottom, { desc = "Resize tmux bottom" })
    vim.keymap.set("n", "<A-h>", require("tmux").resize_left, { desc = "Resize tmux left" })
else
    vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move window top" })
    vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move window right" })
    vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move window bottom" })
    vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move window left" })
    vim.keymap.set("n", "<A-k>", "2<C-w>+", { desc = "Resize window top" })
    vim.keymap.set("n", "<A-l>", "5<C-w><", { desc = "Resize window right" })
    vim.keymap.set("n", "<A-j>", "2<C-w>-", { desc = "Resize window bottom" })
    vim.keymap.set("n", "<A-h>", "5<C-w>>", { desc = "Resize window left" })
end

-- Toggle keybinds
vim.keymap.set("n", "<leader>tu", "<cmd>UndotreeToggle<cr>", { desc = "Undotree" })
vim.keymap.set("n", "<leader>to", "<cmd>Outline<cr>", { desc = "Outline view" })
vim.keymap.set("n", "<leader>ti", "<cmd>IBLToggle<cr>", { desc = "Indent guides" })
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

-- Telescope keybinds
vim.keymap.set("n", "<leader>sc", "<cmd>Telescope colorscheme<cr>", { desc = "Search colorscheme" })
vim.keymap.set("n", "<leader>sh", "<cmd>Telescope help_tags<cr>", { desc = "Search help" })
vim.keymap.set("n", "<leader>sH", "<cmd>Telescope highlights<cr>", { desc = "Search highlight group" })
vim.keymap.set("n", "<leader>sd", function()
    telescope_builtin.live_grep {
        cwd = telescope_utils.buffer_dir()
    }
end, { desc = "Search current directory" })
vim.keymap.set("n", "<leader>/", telescope_builtin.live_grep, { desc = "Search workspace" })
vim.keymap.set("n", "<leader><space>", telescope_builtin.find_files, { desc = "Find file in workspace" })
vim.keymap.set("n", "<leader>sf", function() telescope_builtin.find_files { cwd = telescope_utils.buffer_dir() } end,
    { desc = "Search file" })
vim.keymap.set("n", "<leader>so", telescope_builtin.vim_options, { desc = "Search option" })
vim.keymap.set("n", "<leader>fn",
    function() telescope.extensions.file_browser.file_browser { path = vim.fn.stdpath("config") } end,
    { desc = "Browse .config/nvim" })
vim.keymap.set("n", "<leader>ff", telescope.extensions.file_browser.file_browser, { desc = "Find file" })
vim.keymap.set("n", "<leader>.", telescope.extensions.file_browser.file_browser, { desc = "Find file" })
vim.keymap.set("n", "<leader>fw",
    function() telescope.extensions.file_browser.file_browser { path = vim.fn.getcwd() } end,
    { desc = "Find file in workspace" })
vim.keymap.set("n", "<leader>fr", function() telescope_builtin.oldfiles { prompt_title = "Recent files" } end,
    { desc = "Recent files" })
vim.keymap.set("n", "<leader>fR",
    function() telescope_builtin.oldfiles { only_cwd = true, prompt_title = "Recent files in workspace" } end,
    { desc = "Recent files in workspace" })

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

vim.keymap.set("n", "<leader>sb", fuzzy_find_current_buffer, { desc = "Search buffer" })
vim.keymap.set("n", "<leader>sB", function() telescope_builtin.live_grep { grep_open_files = true } end,
    { desc = "Search buffer" })
vim.keymap.set("n", "<leader>ss", telescope_builtin.spell_suggest, { desc = "Search spelling suggestion" })
vim.keymap.set("n", "<leader>,",
    function() telescope_builtin.buffers { prompt_title = "Open workspace buffers", only_cwd = true } end,
    { desc = "Switch workspace buffers" })
vim.keymap.set("n", "<leader><", function() telescope_builtin.buffers { prompt_title = "Open buffers" } end,
    { desc = "Switch buffers" })
vim.keymap.set("n", "<leader>'", telescope_builtin.resume, { desc = "Resume last search" })
vim.keymap.set("n", "<leader>is", telescope_builtin.symbols, { desc = "Symbols" })
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

local sqlite = require "sqlite.db"
local tbl = require "sqlite.tbl"
local yank_uri = vim.fn.stdpath("data") .. "/yank_history_v2.db"
local strftime = sqlite.lib.strftime

--[[ Data shapes ---------------------------------------------

---@class YankEntry
---@field id number: unique id
---@field content string: yanked content
---@field created_at number: when it was first yanked
---@field last_used_at number: when it was last used
---@field usage_count number: how many times it was used
---@field line_count number: number of lines in content
---@field char_count number: number of characters

--]]

-- Construct the database schema
---@type sqlite_tbl
local entries = tbl("yank_entries", {
    id = true, -- same as { type = "integer", required = true, primary = true }
    content = { "text", required = true },
    created_at = { "integer", default = strftime("%s", "now") },
    last_used_at = { "integer", default = strftime("%s", "now") },
    usage_count = { "integer", default = 0 },
    line_count = { "integer", default = 1 },
    char_count = { "integer", default = 0 },
})

---@type sqlite_db
local YankDB = sqlite {
    uri = yank_uri,
    etries = entries,
    opts = {},
}

---Add a yank entry
---@param content string
function entries:add(content)
    if not content or content == "" or content == "\n" then return end

    local lines = vim.split(content, "\n", { plain = true })
    local line_count = #lines
    local char_count = #content
    local created_at = os.time()

    -- Check if exact content exists in recent entries
    local existing = entries:get {
        where = { content = content },
        limit = 1
    }

    if #existing > 0 then
        -- Update existing entry
        local entry = existing[1]
        if (created_at - entry.created_at) < 300 then
            -- Too recent, skip
            return entry.id
        else
            -- Update last_used_at and usage_count
            entries:update {
                where = { id = entry.id },
                set = {
                    last_used_at = created_at,
                    usage_count = entry.usage_count + 1
                }
            }
            return entry.id
        end
    else
        -- Insert new entry
        local id = entries:insert {
            content = content,
            created_at = created_at,
            last_used_at = created_at,
            usage_count = 0,
            line_count = line_count,
            char_count = char_count,
        }

        -- Keep only last 100 entries
        local total_count = entries:count()
        if total_count > 100 then
            local oldest = entries:get {
                order_by = { asc = "created_at" },
                limit = total_count - 100
            }

            for _, entry in ipairs(oldest) do
                entries:remove { id = entry.id }
            end
        end

        return id
    end
end

---Get all yank entries with time-weighted scoring
function entries:get_with_score(q)
    local items = entries:get(q or {})
    local current_time = os.time()

    -- Add scoring to each item
    for _, entry in ipairs(items) do
        -- Calculate age bonus (newer entries get higher scores)
        local age_hours = (current_time - entry.created_at) / 3600
        local age_bonus = math.max(0, 100 - age_hours)

        -- Calculate usage score based on usage_count and recency
        local usage_score = entry.usage_count * 10

        -- Bonus for recently used items
        local last_used_hours = (current_time - entry.last_used_at) / 3600
        local recency_bonus = math.max(0, 50 - last_used_hours)

        -- Combine all scores
        entry.score = age_bonus + usage_score + recency_bonus
    end

    -- Sort by combined score (highest first)
    table.sort(items, function(a, b)
        return (a.score or 0) > (b.score or 0)
    end)

    return items
end

---Record usage of a yank entry
---@param id number
function entries:use(id)
    local current_time = os.time()
    local entry = entries:get { where = { id = id }, limit = 1 }[1]

    if entry then
        entries:update {
            where = { id = id },
            set = {
                last_used_at = current_time,
                usage_count = entry.usage_count + 1
            }
        }
    end
end

---Delete a yank entry
---@param id number
function entries:delete_entry(id)
    return entries:remove { id = id }
end

local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })

-- Hook into yank operations
vim.api.nvim_create_autocmd("TextYankPost", {
    group = highlight_group,
    callback = function()
        vim.highlight.on_yank()

        -- Save to database
        local content = vim.fn.getreg('"')
        if content and content ~= "" then
            pcall(function() entries:add(content) end)
        end
    end,
    pattern = "*",
})

vim.keymap.set("n", "<leader>iy", function()
    local origin_buf = vim.api.nvim_get_current_buf()
    local origin_win = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(origin_win)
    local row, col = cursor[1], cursor[2]
    local ns = vim.api.nvim_create_namespace("YankHistoryPreview")

    local function clear_preview()
        if vim.api.nvim_buf_is_loaded(origin_buf) then
            vim.api.nvim_buf_clear_namespace(origin_buf, ns, 0, -1)
        end
    end

    local function open_yank_history()
        -- Move data fetching inside this function so it's refreshed each time
        local history = entries:get_with_score {
            order_by = { desc = "created_at" },
            limit = 100
        }

        if #history == 0 then
            vim.notify("No yank history found", vim.log.levels.WARN)
            return
        end

        -- Convert to format expected by telescope
        local registers = {}
        for i, entry in ipairs(history) do
            local display_content = entry.content:gsub("\n", "\\n")
            if #display_content > 80 then
                display_content = display_content:sub(1, 80) .. "..."
            end

            local time_str = os.date("%H:%M", entry.created_at)
            local usage_info = entry.usage_count and entry.usage_count > 0 and
                string.format(" (used %dx)", entry.usage_count) or ""
            local display = string.format("[%s]%s %s", time_str, usage_info, display_content)

            table.insert(registers, {
                content = entry.content,
                display = display,
                timestamp = entry.created_at,
                line_count = entry.line_count or 1,
                id = entry.id,
                score = entry.score or 0
            })
        end

        require("telescope.pickers").new(
            telescope_themes.get_dropdown(vim.tbl_extend("force", default_picker_config, {
                prompt_title = "Clipboard history",
            })), {
                finder = require("telescope.finders").new_table({
                    results = registers,
                    entry_maker = function(entry)
                        return {
                            value = entry.content,
                            display = entry.display,
                            ordinal = entry.display,
                            entry = entry,
                        }
                    end,
                }),
                sorter = require("telescope.config").values.generic_sorter({}),
                attach_mappings = function(prompt_bufnr, map)
                    local actions = require("telescope.actions")

                    local function update_preview()
                        if not vim.api.nvim_buf_is_loaded(origin_buf) then return end
                        clear_preview()
                        local sel = telescope_action_state.get_selected_entry()
                        if not sel or not sel.value then return end
                        local content = sel.value
                        if type(content) ~= "string" then return end
                        local lines = vim.split(content, "\n", { plain = true })
                        if #lines == 0 then return end

                        if #lines == 1 then
                            vim.api.nvim_buf_set_extmark(origin_buf, ns, row - 1, col, {
                                virt_text = { { lines[1], "Comment" } },
                                virt_text_pos = "inline",
                                hl_mode = "combine",
                            })
                        else
                            local virt_lines = {}
                            for i = 2, #lines do
                                virt_lines[#virt_lines + 1] = { { lines[i], "Comment" } }
                            end
                            vim.api.nvim_buf_set_extmark(origin_buf, ns, row - 1, col, {
                                virt_text = { { lines[1], "Comment" } },
                                virt_text_pos = "inline",
                                virt_lines = virt_lines,
                                hl_mode = "combine",
                            })
                        end
                    end

                    local function move_next()
                        actions.move_selection_next(prompt_bufnr)
                        update_preview()
                    end
                    local function move_prev()
                        actions.move_selection_previous(prompt_bufnr)
                        update_preview()
                    end

                    map("i", "<Down>", move_next)
                    map("i", "<C-n>", move_next)
                    map("i", "<Up>", move_prev)
                    map("i", "<C-p>", move_prev)
                    map("n", "j", move_next)
                    map("n", "k", move_prev)

                    -- Add delete mapping
                    local function delete_entry()
                        local selection = telescope_action_state.get_selected_entry()
                        if not selection or not selection.entry.id then return end

                        entries:delete_entry(selection.entry.id)
                        move_next()
                        actions.close(prompt_bufnr)
                        open_yank_history()
                    end

                    map("i", "<C-d>", delete_entry)
                    map("n", "D", delete_entry)

                    vim.defer_fn(update_preview, 20)

                    actions.select_default:replace(function()
                        clear_preview()
                        actions.close(prompt_bufnr)
                        local selection = telescope_action_state.get_selected_entry()
                        if selection then
                            local content = selection.value
                            local lines = vim.split(content, "\n")
                            local cur = vim.api.nvim_win_get_cursor(0)
                            local r, c = cur[1], cur[2]

                            -- Record usage
                            entries:use(selection.entry.id)

                            if #lines == 1 then
                                local current_line = vim.api.nvim_get_current_line()
                                local new_line = current_line:sub(1, c) .. content .. current_line:sub(c + 1)
                                vim.api.nvim_set_current_line(new_line)
                                vim.api.nvim_win_set_cursor(0, { r, c + #content })
                            else
                                local current_line = vim.api.nvim_get_current_line()
                                local before = current_line:sub(1, c)
                                local after = current_line:sub(c + 1)

                                lines[1] = before .. lines[1]
                                lines[#lines] = lines[#lines] .. after

                                vim.api.nvim_buf_set_lines(0, r - 1, r, false, lines)
                                vim.api.nvim_win_set_cursor(0, { r + #lines - 1, #lines[#lines] - #after })
                            end
                        end
                    end)

                    -- Clear preview when the picker buffer is wiped
                    vim.api.nvim_create_autocmd("BufWipeout", {
                        buffer = prompt_bufnr,
                        once = true,
                        callback = clear_preview,
                    })

                    return true
                end,
            }):find()
    end

    open_yank_history()
end, { desc = "Clipboard" })

vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Explore" })
vim.keymap.set("n", "n", "nzz", { desc = "Next search result" })
vim.keymap.set("n", "]d", function()
    vim.diagnostic.jump({ count = 1, float = true })
    feedkeys("zz")
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({ count = -1, float = true })
    feedkeys("zz")
end, { desc = "Previous diagnostic" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("v", "<", "<gv", { desc = "Decrease indent" })
vim.keymap.set("v", ">", ">gv", { desc = "Increase indent" })
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
vim.keymap.set("n", "gd", function()
    if jump_to_error_loc() then
        return
    else
        vim.lsp.buf.definition()
    end
end, { desc = "Goto definition" })
vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>lf", require("conform").format, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ldf", vim.diagnostic.open_float, { desc = "Floating diagnostic" })
vim.keymap.set("n", "<leader>ldl", vim.diagnostic.setqflist, { desc = "Diagnostic list" })

vim.keymap.set("n", "<leader>q", quicker.toggle, { desc = "Quickfix list" })

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

vim.keymap.set("n", "]h", function()
    if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
    else
        vim.cmd("Gitsigns next_hunk")
    end
end, { desc = "Next hunk" })

vim.keymap.set("n", "[h", function()
    if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
    else
        vim.cmd("Gitsigns prev_hunk")
    end
end, { desc = "Previous hunk" })
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
vim.keymap.set("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
vim.keymap.set({ "n", "v" }, "<leader>hs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
vim.keymap.set("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<cr>", { desc = "Undo stage hunk" })
vim.keymap.set("n", "<leader>gB", "<cmd>Gitsigns blame<cr>", { desc = "Git blame" })
vim.keymap.set("n", "<leader>gD", ":DiffviewOpen ", { desc = "Git DiffView" })
vim.keymap.set("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Git diff" })
vim.keymap.set("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle blame inline" })
vim.keymap.set("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
vim.keymap.set("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<cr>", { desc = "Preview hunk inline" })
vim.keymap.set("n", "<leader>hd", "<cmd>Gitsigns toggle_word_diff<cr>", { desc = "Toggle word diff" })
vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot chat" })
vim.keymap.set("n", "<leader>cp", "<cmd>CopilotChatPrompts<cr>", { desc = "Copilot chat prompts" })
vim.keymap.set("n", "<leader>cx", function()
    vim.g.chat_title = nil
    copilot_chat.reset()
end, { desc = "Copilot chat reset" })
vim.keymap.set("n", "<leader>ch", find_chat_history, { desc = "Copilot chat history" })
vim.keymap.set("n", "<M-g>", function() require("neogit").open { kind = "replace" } end, { desc = "Git status" })
vim.keymap.set("n", "<leader>gg", function() require("neogit").open { kind = "replace" } end, { desc = "Git status" })
vim.keymap.set("n", "<leader>gc", function() require("neogit.buffers.commit_view").new("HEAD"):open("replace") end,
    { desc = "Git commit" })
vim.keymap.set("n", "<leader>gb", "<cmd>Neogit branch<cr>", { desc = "Git branch" })
vim.keymap.set("n", "<leader>gL", "<cmd>NeogitLogCurrent<cr>", { desc = "Git log" })
vim.keymap.set("n", "<leader>gli", function()
    telescope.extensions.gh.issues(telescope_themes.get_dropdown(default_picker_config))
end, { desc = "List issues" })
vim.keymap.set("n", "<leader>glp", function()
    telescope.extensions.gh.pull_request(telescope_themes.get_dropdown(default_picker_config))
end, { desc = "List pull requests" })
vim.keymap.set("n", "<leader>glg", function()
    telescope.extensions.gh.gist(telescope_themes.get_dropdown(default_picker_config))
end, { desc = "List gists" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory<cr>", { desc = "Git file history" })

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "<F1>", "<cmd>OverseerRun<cr>", { desc = "Run task" })
vim.keymap.set("n", "<F2>", "<cmd>OverseerToggle bottom<cr>", { desc = "Task list (bottom)" })
vim.keymap.set("n", "<F3>", "<cmd>OverseerToggle right<cr>", { desc = "Task list (right)" })
vim.keymap.set("n", "<A-r>", "<cmd>OverseerQuickAction restart<cr>", { desc = "Restart last task" })
vim.keymap.set("n", "<F5>", "<cmd>OverseerQuickAction restart<cr>", { desc = "Restart last task" })

vim.keymap.set("n", "<leader>db", function()
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
        if dbui_tab then break end
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
end, { desc = "DBUI" })
vim.keymap.set("n", "<leader>da", "<cmd>DBUIAddConnection<cr>", { desc = "Add new connection" })

-- Create a Neovim command to call the align_text function
vim.api.nvim_create_user_command("Align", function(opts)
    -- Function to align text based on a given token
    local function align_text(token, lines)
        local max_pos = 0

        -- Find the maximum position of the token in any line
        for _, line in ipairs(lines) do
            local pos = line:find(token)
            if pos and pos > max_pos then
                max_pos = pos
            end
        end

        -- Align each line based on the token position
        local aligned_lines = {}
        for _, line in ipairs(lines) do
            local pos = line:find(token)
            if pos then
                local spaces_to_add = max_pos - pos
                local aligned_line = line:sub(1, pos - 1) .. string.rep(" ", spaces_to_add) .. line:sub(pos)
                table.insert(aligned_lines, aligned_line)
            else
                table.insert(aligned_lines, line)
            end
        end

        return aligned_lines
    end

    local token = opts.args
    if #token ~= 1 then
        print("Error: Token must be a single character.")
        return
    end
    local start_line = opts.line1
    local end_line = opts.line2
    local lines = vim.fn.getline(start_line, end_line)
    local aligned_lines = align_text(token, lines)
    vim.fn.setline(start_line, aligned_lines)
end, {
    nargs = 1,
    range = true,
    complete = function()
        return {}
    end,
})

if is_neovide then
    vim.o.guifont = "BigBlueTerm437 Nerd Font:h14"
    vim.g.neovide_floating_shadow = false
    vim.g.neovide_position_animation_length = 0
    vim.g.neovide_cursor_animation_length = 0.00
    vim.g.neovide_cursor_trail_size = 0
    vim.g.neovide_cursor_animate_in_insert_mode = false
    vim.g.neovide_cursor_animate_command_line = false
    vim.g.neovide_scroll_animation_far_lines = 0
    vim.g.neovide_scroll_animation_length = 0.00

    vim.keymap.set("n", "<C-=>", function()
        vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * 1.1
    end, { desc = "Increase Neovide scale factor" })

    vim.keymap.set("n", "<C-->", function()
        vim.g.neovide_scale_factor = vim.g.neovide_scale_factor / 1.1
    end, { desc = "Decrease Neovide scale factor" })

    if vim.g.neovide then
        vim.keymap.set("v", "<C-S-c>", '"+y')         -- Copy
        vim.keymap.set("n", "<C-S-v>", '"+P')         -- Paste normal mode
        vim.keymap.set("v", "<C-S-v>", '"+P')         -- Paste visual mode
        vim.keymap.set("c", "<C-S-v>", "<C-R>+")      -- Paste command mode
        vim.keymap.set("i", "<C-S-v>", '<ESC>l"+Pli') -- Paste insert mode
    end

    vim.api.nvim_set_keymap("", "<C-S-v>", "+p<CR>", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("!", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("t", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
    vim.api.nvim_set_keymap("v", "<C-S-v>", "<C-R>+", { noremap = true, silent = true })
end

vim.cmd [[
    let g:VM_maps = {}
    let g:VM_maps["Goto Prev"] = "\[\["
    let g:VM_maps["Goto Next"] = "\]\]"
    nmap <C-M-n> <Plug>(VM-Select-All)
]]

vim.keymap.set("n", "<M-c>", "viwo<Esc>~wl", { desc = "Capitalize first letter of word under cursor" })
