return {
	cmd = { "clojure-lsp" },
	filetypes = { "clojure", "edn" },
	root_markers = { "project.clj", "deps.edn", "build.boot", "shadow-cljs.edn", "bb.edn", ".git" },
	capabilities = require("blink.cmp").get_lsp_capabilities(),
}
