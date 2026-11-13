return {
	cmd = { "vscode-json-language-server", "--stdio" },
	filetypes = { "json", "jsonc" },
	root_markers = { ".git" },
	init_options = { provideFormatter = true },
	capabilities = require("blink.cmp").get_lsp_capabilities(),
}
