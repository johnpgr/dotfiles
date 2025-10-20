vim.keymap.set("n", "<leader>w", "<cmd>update<cr>", { desc = "Write" })
vim.keymap.set("n", "]t", "<cmd>tabnext<cr>", { desc = "Tab next" })
vim.keymap.set("n", "[t", "<cmd>tabprev<cr>", { desc = "Tab prev" })
vim.keymap.set("n", "<C-q>", "<cmd>quit<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>R", "<cmd>restart<cr>", { desc = "Restart" })
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear highlights" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
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
vim.keymap.set("n", "<C-S-k>", function()
    require("lookup").search_online_select()
end, { desc = "Search online (select provider)" })

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
vim.keymap.set("n", "<leader>iy", function()
    require("yank").open_yank_history()
end, { desc = "Clipboard" })
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
    local editor_config = require("utils").editorconfig
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    row = row - 1  -- 0-indexed
    local lines = vim.split(editor_config, '\n', { plain = true })
    vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
    if #lines == 1 then
        vim.api.nvim_win_set_cursor(0, { row + 1, col + #lines[1] })
    else
        vim.api.nvim_win_set_cursor(0, { row + #lines, #lines[#lines] })
    end
end, { desc = "Editorconfig" })

-- LSP keymaps
vim.keymap.set("n", "gd", function()
    if require("utils").jump_to_error_loc() then
        return
    else
        vim.lsp.buf.definition()
    end
end, { desc = "Goto definition" })

vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
vim.keymap.set("n", "<leader>lf", function()
    require("conform").format()
end, { desc = "Format buffer" })
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Diagnostic" })

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
