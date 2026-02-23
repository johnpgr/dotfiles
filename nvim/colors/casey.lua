vim.opt.termguicolors = true
vim.g.colors_name = "casey"

package.loaded["lush_theme.casey"] = nil
require("lush")(require("lush_theme.casey"))
