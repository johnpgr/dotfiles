vim.opt.termguicolors = true
vim.g.colors_name = "handmade"

package.loaded["lush_theme.handmade"] = nil
require("lush")(require("lush_theme.handmade"))
