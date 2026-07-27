vim.pack.add({ 'https://github.com/Bekaboo/dropbar.nvim' })

local icons = {
	enable = vim.g.icons_enabled,
}

if not vim.g.icons_enabled then
	icons.ui = {
		bar = { separator = ' > ', extends = '…' },
		menu = { separator = ' ', indicator = '>' },
	}
end

require('dropbar').setup({ icons = icons })
