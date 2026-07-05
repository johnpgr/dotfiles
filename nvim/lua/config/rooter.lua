local root_names = { ".git", "Makefile", "flake.nix" }
local root_cache = {}

local function find_root(path)
  if not path then
    return nil
  end
  path = vim.fs.dirname(path)
  local root = root_cache[path]
  if root == nil then
    local root_file = vim.fs.find(root_names, { path = path, upward = true })[1]
    if not root_file then
      return nil
    end
    root = vim.fs.dirname(root_file)
    root_cache[path] = root
  end
  return root
end

local function buf_path()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "oil" then
    local ok, dir = pcall(require("oil").get_current_dir, buf)
    return ok and dir or nil
  end
  local path = vim.api.nvim_buf_get_name(buf)
  return path ~= "" and path or nil
end

local function set_root()
  local root = find_root(buf_path())
  if root then
    vim.fn.chdir(root)
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("AutoRoot", {}),
  callback = set_root,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "OilEnter",
  callback = function(ev)
    local path = require("oil").get_current_dir(ev.data.buf)
    local root = find_root(path)
    if root then
      vim.fn.chdir(root)
    end
  end,
})
