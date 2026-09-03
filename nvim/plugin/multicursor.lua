-- Native multicursor: add the next word/selection with <C-n>.
-- Neovim already provides Q, [count]Q, {Visual}Q, <C-LeftMouse>, q=, ]C/[C, gQ, and <C-L>.

local ns = vim.api.nvim_create_namespace('nvim.multicursor')

local function set_search(pattern)
  vim.fn.setreg('/', pattern)
  vim.fn.histadd('/', pattern)
  vim.v.searchforward = 1
  vim.o.hlsearch = true
end

local function add_next(pattern, offset)
  if pattern == '' then return end
  if vim.fn.getreg('/') ~= pattern then set_search(pattern) end

  local matches = vim.fn.matchbufline(vim.api.nvim_get_current_buf(), pattern, 1, '$')
  table.sort(matches, function(a, b)
    return a.lnum < b.lnum or (a.lnum == b.lnum and a.byteidx < b.byteidx)
  end)

  offset = offset or 0
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local occupied = { [line .. ':' .. col] = true }
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    occupied[(mark[2] + 1) .. ':' .. mark[3]] = true
  end

  local function place(match)
    local pos = { match.lnum, match.byteidx + offset }
    if occupied[table.concat(pos, ':')] then return false end
    vim.api.nvim_mcursor(0, pos)
    return true
  end

  for _, match in ipairs(matches) do
    local match_col = match.byteidx + offset
    if (match.lnum > line or (match.lnum == line and match_col > col)) and place(match) then return end
  end
  for _, match in ipairs(matches) do
    if place(match) then return end
  end
end

local function add_next_word()
  local word = vim.fn.expand('<cword>')
  if word == '' then return end

  local pattern = '\\V\\<' .. vim.fn.escape(word, '\\') .. '\\>'
  local col = vim.fn.col('.') - 1
  local word_col = vim.fn.searchpos(pattern, 'bcnW')[2] - 1
  local offset = word_col >= 0 and col < word_col + #word and col - word_col or 0
  add_next(pattern, offset)
end

local function add_next_visual()
  local text = table.concat(vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = vim.fn.mode() }), '\n')
  add_next('\\V' .. vim.fn.escape(text, '\\'))
  vim.cmd.normal({ vim.keycode('<Esc>'), bang = true })
end

vim.keymap.set('n', '<C-n>', add_next_word, { desc = 'Multicursor: add next occurrence' })
vim.keymap.set('x', '<C-n>', add_next_visual, { desc = 'Multicursor: add next occurrence (visual)' })
