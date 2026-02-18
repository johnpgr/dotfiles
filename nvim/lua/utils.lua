local M = {}

M.is_neovide = vim.g.neovide ~= nil
M.is_kitty = os.getenv("TERM") == "xterm-kitty" or os.getenv("TERM") == "xterm-ghostty" or os.getenv("TERM") == "wezterm"

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
