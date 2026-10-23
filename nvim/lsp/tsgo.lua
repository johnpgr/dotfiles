return {
	cmd = function(dispatchers, config)
		local root = config.root_dir or vim.fn.getcwd()
		local bin = vim.fs.joinpath(root, "node_modules", ".bin", "tsc")
		return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
	end,
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = {
		{ "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock", "bun.lockb" },
		{ "tsconfig.json", "jsconfig.json", "package.json" },
		".git",
	},
	capabilities = require("blink.cmp").get_lsp_capabilities(),
}
