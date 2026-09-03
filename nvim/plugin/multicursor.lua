-- Native multicursor: only <C-n> (what you actually used from VM)
-- Native already provides Q, [count]Q (1Q = all matches), {Visual}Q, <C-LeftMouse>, q=, ]C/[C, gQ, <C-L>

local mcursor = require('vim._core.mcursor')
local ns = vim.api.nvim_create_namespace('nvim.multicursor')

local function word_pattern(word)
  return '\\V\\<' .. vim.fn.escape(word, '\\') .. '\\>'
end

local function set_search(pat)
  vim.fn.setreg('/', pat)
  vim.fn.histadd('/', pat)
  vim.v.searchforward = 1
  vim.o.hlsearch = true
end

local function has_cursor_at(lnum, bytecol)
  return #vim.api.nvim_buf_get_extmarks(0, ns, { lnum - 1, bytecol }, { lnum - 1, bytecol }, {}) > 0
end

-- Add next occurrence, preserving offset within word (last char stays last char)
local function add_next()
  local word = vim.fn.expand('<cword>')
  if word == '' then return end
  local pat = word_pattern(word)
  if vim.fn.getreg('/') ~= pat then set_search(pat) end
  local matches = vim.fn.matchbufline(0, pat, 1, '$')
  if #matches == 0 then return end
  table.sort(matches, function(a,b) return a.lnum < b.lnum or (a.lnum==b.lnum and a.byteidx < b.byteidx) end)

  local cur = vim.pos.cursor(0)
  local cur_lnum = vim.fn.line('.')
  local cur_col = vim.fn.col('.') - 1
  local line = vim.api.nvim_get_current_line()
  local word_start = cur_col
  do
    local s=0
    while true do
      local a,b = line:find(word, s+1, true)
      if not a then break end
      if cur_col >= a-1 and cur_col <= b-1 then word_start = a-1 break end
      s=b; if s>=#line then break end
    end
  end
  local offset = cur_col - word_start
  if offset<0 then offset=0 elseif offset>=#word then offset=#word-1 end

  local function occupied(m)
    local c = m.byteidx + offset
    return (m.lnum==cur_lnum and c==cur_col) or has_cursor_at(m.lnum, c)
  end

  local next_m
  for _,m in ipairs(matches) do
    if vim.pos(0, m.lnum-1, m.byteidx+offset) > cur then next_m=m break end
  end
  if not next_m then next_m=matches[1] end
  local attempts=0
  while next_m and occupied(next_m) and attempts<#matches do
    local idx=0
    for i,mm in ipairs(matches) do if mm.lnum==next_m.lnum and mm.byteidx==next_m.byteidx then idx=i break end end
    next_m=matches[(idx % #matches)+1]; attempts=attempts+1
  end
  if next_m and not occupied(next_m) then
    vim.api.nvim_mcursor(0, {next_m.lnum, next_m.byteidx+offset})
  end
end

local function add_next_visual()
  local s,e = vim.fn.getpos('v'), vim.fn.getpos('.')
  local text = table.concat(vim.fn.getregion(s,e,{type=vim.fn.mode()}),'\n')
  if text=='' then return end
  local pat = '\\V'..vim.fn.escape(text,'\\')
  if vim.fn.getreg('/')~=pat then set_search(pat) end
  local cur = vim.pos.cursor(0)
  local cur_lnum,cur_col = vim.fn.line('.'), vim.fn.col('.')-1
  local function occupied(m) return (m.lnum==cur_lnum and m.byteidx==cur_col) or has_cursor_at(m.lnum,m.byteidx) end
  local matches = vim.fn.matchbufline(0, pat,1,'$')
  if #matches==0 then return end
  table.sort(matches,function(a,b) return a.lnum<b.lnum or (a.lnum==b.lnum and a.byteidx<b.byteidx) end)
  local nxt
  for _,m in ipairs(matches) do if vim.pos(0,m.lnum-1,m.byteidx)>cur then nxt=m break end end
  if not nxt then nxt=matches[1] end
  local a=0
  while nxt and occupied(nxt) and a<#matches do
    local i=0 for k,mm in ipairs(matches) do if mm.lnum==nxt.lnum and mm.byteidx==nxt.byteidx then i=k break end end
    nxt=matches[(i % #matches)+1]; a=a+1
  end
  if nxt and not occupied(nxt) then vim.api.nvim_mcursor(0,{nxt.lnum,nxt.byteidx}) end
  vim.api.nvim_feedkeys(vim.keycode('<Esc>'),'n',false)
end

vim.keymap.set('n', '<C-n>', add_next, { desc = 'Multicursor: add next occurrence' })
vim.keymap.set('x', '<C-n>', add_next_visual, { desc = 'Multicursor: add next occurrence (visual)' })
