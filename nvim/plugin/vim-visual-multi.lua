vim.pack.add({ 'https://github.com/mg979/vim-visual-multi' })

vim.cmd([[
  let g:VM_maps = {}
  let g:VM_maps["Goto Prev"] = "\[\["
  let g:VM_maps["Goto Next"] = "\]\]"
  nmap <C-M-n> <Plug>(VM-Select-All)
]])
