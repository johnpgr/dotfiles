vim.pack.add({ 'https://github.com/dmtrKovalenko/fff.nvim' })

if not vim.uv.fs_stat(require('fff.download').get_binary_path()) then
  require('fff.download').download_or_build_binary()
end
