vim.pack.add({ 'https://github.com/feakuru/mypy.nvim' })

local mypy_mod = require('mypy')
mypy_mod.setup()

local mypy_cache = {}

local function get_mypy_context(buf_path)
  local root = vim.fs.root(buf_path, { '.venv', 'pyproject.toml', 'mypy.ini', '.mypy.ini', 'setup.cfg', 'setup.py' })
    or vim.fs.root(buf_path, { '.git' })
    or vim.fn.getcwd()

  if mypy_cache[root] then
    return mypy_cache[root]
  end

  local venv_mypy = vim.fs.joinpath(root, '.venv', 'bin', 'mypy')
  local cmd = vim.fn.executable(venv_mypy) == 1 and venv_mypy or 'mypy'

  mypy_cache[root] = { cmd = cmd, cwd = root }
  return mypy_cache[root]
end

mypy_mod.typecheck_current_buffer = function()
  if not mypy_mod.enabled then
    vim.diagnostic.reset(mypy_mod.namespace, 0)
    return
  end
  local buf_num = vim.api.nvim_get_current_buf()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' then
    return
  end

  local mypy_context = get_mypy_context(buf_path)
  local cmd = { mypy_context.cmd, '--show-error-end', '--follow-imports=silent' }
  for w in string.gmatch(mypy_mod.extra_args, '%S+') do
    table.insert(cmd, w)
  end
  table.insert(cmd, buf_path)

  pcall(vim.system, cmd, { cwd = mypy_context.cwd }, function(out)
    if out.code ~= 0 then
      local diagnostics = {}
      for line_from, col_from, line_to, col_to, severity, message in
        string.gmatch(out.stdout, '(%d+):(%d+):(%d+):(%d+): (%a+): ([^\n]+)')
      do
        table.insert(diagnostics, {
          lnum = tonumber(line_from) - 1,
          col = tonumber(col_from) - 1,
          end_lnum = tonumber(line_to) - 1,
          end_col = tonumber(col_to) - 1,
          message = 'mypy: ' .. message,
          severity = mypy_mod.severities[severity],
        })
      end
      vim.schedule(function()
        vim.diagnostic.set(mypy_mod.namespace, buf_num, diagnostics)
      end)
    else
      vim.schedule(function()
        vim.diagnostic.reset(mypy_mod.namespace, buf_num)
      end)
    end
  end)
end

vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufEnter' }, {
  group = vim.api.nvim_create_augroup('MypyNvim', { clear = true }),
  pattern = { '*.py', '*.pyi' },
  callback = function()
    mypy_mod.typecheck_current_buffer()
  end,
})

vim.api.nvim_create_user_command('MypyDebug', function()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == '' then
    print('mypy.nvim: current buffer has no file path')
    return
  end

  local mypy_context = get_mypy_context(buf_path)
  print(vim.inspect({
    buf_path = buf_path,
    cwd = mypy_context.cwd,
    cmd = mypy_context.cmd,
    cmd_executable = vim.fn.executable(mypy_context.cmd) == 1,
    extra_args = mypy_mod.extra_args,
  }))
end, { desc = 'Show resolved mypy command info' })
