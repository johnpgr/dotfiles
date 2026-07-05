local M = {}

local function ensure_fff()
  return require("config.find").ensure_fff()
end

local function grep_items_to_qf(items)
  local qf_items = {}
  for _, item in ipairs(items or {}) do
    if type(item) == "table" then
      local path = item.path or item.relative_path
      if path and path ~= "" then
        local lnum = tonumber(item.line_number or item.lnum or 1) or 1
        local col = tonumber(item.col)
        if col then col = col + 1 else col = 1 end
        local text = vim.trim(item.line_content or item.text or "")

        table.insert(qf_items, {
          filename = vim.fn.fnamemodify(path, ":p"),
          lnum = lnum,
          col = col,
          text = text,
        })
      end
    end
  end
  return qf_items
end

local function set_qflist(items, title)
  if #items == 0 then
    vim.notify("No results", vim.log.levels.INFO)
    return
  end
  vim.fn.setqflist({}, " ", { items = items, title = title, nr = "$" })
  vim.cmd("copen")
end

--- Run fff grep and send results to quickfix.
---@param query string Search query (literal text)
function M.grep(query)
  if not query or query == "" then return end
  ensure_fff()

  local ok, result = pcall(require("fff.grep").search, query, 0, 100, nil, "plain")
  if not ok or not result or not result.items then
    vim.notify("Grep failed", vim.log.levels.ERROR)
    return
  end

  local items = grep_items_to_qf(result.items)
  set_qflist(items, "Grep: " .. query)
end

--- Grep for the word under cursor or visual selection, send to quickfix.
function M.grep_word()
  local query
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" or mode == "\22" then
    local _, srow, scol = unpack(vim.fn.getpos("v"))
    local _, erow, ecol = unpack(vim.fn.getpos("."))
    if srow > erow or (srow == erow and scol > ecol) then
      srow, erow = erow, srow
      scol, ecol = ecol, scol
    end
    local lines = vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
    query = table.concat(lines, " ")
  elseif mode == "n" then
    query = vim.fn.expand("<cword>")
  end

  if not query or query == "" then return end
  M.grep(query)
end

--- Grep within the current buffer, send to quickfix.
function M.grep_buffer()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("Buffer has no file path", vim.log.levels.WARN)
    return
  end

  local query = vim.fn.input("Grep buffer > ")
  if not query or query == "" then return end

  local output = vim.fn.systemlist({
    "rg", "--line-number", "--column", "--no-heading",
    "--smart-case", "--color=never", "--", query, filepath,
  })
  if vim.v.shell_error > 1 then
    vim.notify("rg failed", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for _, line in ipairs(output) do
    local lnum, col, text = line:match("^(%d+):(%d+):(.*)$")
    if lnum then
      table.insert(items, {
        filename = filepath,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = text or "",
      })
    end
  end

  set_qflist(items, "Grep buffer: " .. query)
end

--- Grep for TODO/FIXME/NOTE comments, send to quickfix.
function M.grep_todos()
  ensure_fff()

  local ok, result = pcall(require("fff.grep").search, [[\b(TODO|FIXME|NOTE):]], 0, 100, nil, "regex")
  if not ok or not result or not result.items then
    vim.notify("Grep failed", vim.log.levels.ERROR)
    return
  end

  local items = grep_items_to_qf(result.items)
  set_qflist(items, "TODO comments")
end

vim.keymap.set("n", "<leader>/", function()
  ensure_fff()
  local query = vim.fn.input("Grep > ")
  M.grep(query)
end, { desc = "Grep" })

vim.keymap.set({ "n", "v" }, "<leader>sw", M.grep_word, { desc = "Grep word/selection" })

vim.keymap.set("n", "<leader>sb", M.grep_buffer, { desc = "Grep buffer" })

vim.keymap.set("n", "<leader>tt", M.grep_todos, { desc = "TODO comments" })

return M
