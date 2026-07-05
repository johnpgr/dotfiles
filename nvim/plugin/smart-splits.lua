-- smart-splits's plugin/ scripts fail in headless mode (/dev/fd/2 not available).
if #vim.api.nvim_list_uis() > 0 then
  local function find_plugin_dir(name)
    for _, packpath in ipairs(vim.opt.packpath:get()) do
      local dir = vim.fs.joinpath(packpath, 'pack', 'core', 'opt', name)
      if vim.uv.fs_stat(dir) then
        return dir
      end
      dir = vim.fs.joinpath(packpath, 'pack', 'core', 'start', name)
      if vim.uv.fs_stat(dir) then
        return dir
      end
    end
    return nil
  end

  local is_windows = vim.fn.has('win32') == 1

  vim.pack.add({
    {
      src = 'https://github.com/johnpgr/smart-splits.nvim',
      version = 'perf/async-wezterm-cli',
    },
  })

  if not is_windows then
    local sentinel = vim.fn.stdpath('cache') .. '/.smart-splits-kittens-installed'
    if not vim.uv.fs_stat(sentinel) then
      local plugin_dir = find_plugin_dir('smart-splits.nvim')
      if plugin_dir then
        local script = vim.fs.joinpath(plugin_dir, 'kitty', 'install-kittens.bash')
        if vim.uv.fs_stat(script) then
          local ok = vim.fn.system({ 'bash', script })
          if vim.v.shell_error == 0 then
            vim.uv.fs_write(sentinel, '')
          end
        end
      end
    end
  end

  require('smart-splits').setup({ at_edge = 'stop' })
end
