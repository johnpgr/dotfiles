local M = {}

local cache = {}
local package_cache = {}

local function shell(cmd)
	local out = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return out
end

local function trim(s)
	return s and (s:gsub("%s+$", "")) or nil
end

local function ensure_extracted(archive_path)
	if vim.fn.filereadable(archive_path) ~= 1 then
		return nil
	end

	local name = vim.fs.basename(archive_path):gsub("%.%w+$", "")
	local dest = vim.fs.joinpath(vim.fn.stdpath("cache"), "stdlib-src", name)
	local complete = vim.fs.joinpath(dest, ".stdlib-extracted")
	if vim.fn.filereadable(complete) == 1 then
		return dest
	end
	if vim.fn.executable("unzip") ~= 1 then
		vim.notify("stdlib: `unzip` not found, cannot extract " .. archive_path, vim.log.levels.WARN)
		return nil
	end

	if vim.fn.isdirectory(dest) == 1 then
		vim.fn.delete(dest, "rf")
	end
	vim.fn.mkdir(dest, "p")
	vim.fn.system({ "unzip", "-oq", archive_path, "-d", dest })
	if vim.v.shell_error ~= 0 then
		vim.fn.delete(dest, "rf")
		vim.notify("stdlib: failed to extract " .. archive_path, vim.log.levels.ERROR)
		return nil
	end
	if vim.fn.writefile({}, complete) ~= 0 then
		vim.fn.delete(dest, "rf")
		vim.notify("stdlib: failed to finalize extraction of " .. archive_path, vim.log.levels.ERROR)
		return nil
	end
	return dest
end

local function resolve_path(path)
	if not path or path == "" then
		return nil
	end
	if path:match("%.jar$") or path:match("%.zip$") then
		return ensure_extracted(path)
	end
	return vim.fn.isdirectory(path) == 1 and path or nil
end

local function venv_python()
	local venv = vim.env.VIRTUAL_ENV
	if not venv then
		local bufname = vim.api.nvim_buf_get_name(0)
		local start = bufname ~= "" and vim.fs.dirname(bufname) or vim.uv.cwd()
		venv = vim.fs.find(".venv", { upward = true, path = start, type = "directory" })[1]
		if not venv then
			local cfg = vim.fs.find("pyvenv.cfg", { upward = true, path = start })[1]
			venv = cfg and vim.fs.dirname(cfg) or nil
		end
	end
	if not venv then
		return nil
	end

	local python = vim.fs.joinpath(venv, "bin", "python3")
	return vim.fn.executable(python) == 1 and python or nil
end

local resolvers = {
	go = function()
		if vim.fn.executable("go") ~= 1 then
			return nil
		end
		local root = trim(shell("go env GOROOT"))
		return root and vim.fs.joinpath(root, "src") or nil
	end,
	zig = function()
		if vim.fn.executable("zig") ~= 1 then
			return nil
		end
		local out = shell("zig env")
		return out and out:match('%.std_dir = "(.-)"') or nil
	end,
	odin = function()
		if vim.fn.executable("odin") ~= 1 then
			return nil
		end
		return trim(shell("odin root"))
	end,
	rust = function()
		if vim.fn.executable("rustc") ~= 1 then
			return nil
		end
		local sysroot = trim(shell("rustc --print sysroot"))
		return sysroot and vim.fs.joinpath(sysroot, "lib", "rustlib", "src", "rust", "library") or nil
	end,
	python = function()
		local python = venv_python() or (vim.fn.executable("python3") == 1 and "python3" or nil)
		if not python then
			return nil
		end
		local out = shell({ python, "-c", "import sysconfig; print(sysconfig.get_path('stdlib'))" })
		return trim(out)
	end,
	typescript = function()
		return vim.fs.joinpath(vim.uv.cwd(), "node_modules", "typescript", "lib")
	end,
}

local package_resolvers = {
	python = function()
		local python = venv_python()
		if not python then
			return nil
		end
		local out = shell({ python, "-c", "import sysconfig; print(sysconfig.get_path('purelib'))" })
		return trim(out)
	end,
	node = function()
		return vim.fs.joinpath(vim.uv.cwd(), "node_modules")
	end,
	rust = function()
		local cargo_home = vim.env.CARGO_HOME or vim.fs.joinpath(vim.fn.expand("~"), ".cargo")
		return vim.fs.joinpath(cargo_home, "registry", "src")
	end,
}

M.languages = {
	go = { name = "Go", resolver = resolvers.go, global = "go_stdlib_path" },
	zig = { name = "Zig", resolver = resolvers.zig, global = "zig_stdlib_path" },
	odin = { name = "Odin", resolver = resolvers.odin, global = "odin_stdlib_path" },
	rust = { name = "Rust", resolver = resolvers.rust, global = "rust_stdlib_path" },
	python = { name = "Python", resolver = resolvers.python, global = "python_stdlib_path" },
	typescript = { name = "TypeScript", resolver = resolvers.typescript, global = "typescript_stdlib_path" },
	typescriptreact = { name = "TypeScript", resolver = resolvers.typescript, global = "typescript_stdlib_path" },
	c3 = { name = "C3", global = "c3_stdlib_path", default = "/opt/c3/lib/std" },
	java = { name = "Java", global = "java_stdlib_path", default = "/opt/jdk-27/lib/src.zip" },
	kotlin = { name = "Kotlin", global = "kotlin_stdlib_path", default = "/opt/kotlinc/lib/kotlin-stdlib-sources.jar" },
}

M.packages = {
	python = { name = "Python packages", resolver = package_resolvers.python, global = "python_packages_path" },
	javascript = { name = "JavaScript packages", resolver = package_resolvers.node, global = "node_packages_path" },
	javascriptreact = { name = "JavaScript packages", resolver = package_resolvers.node, global = "node_packages_path" },
	typescript = { name = "TypeScript packages", resolver = package_resolvers.node, global = "node_packages_path" },
	typescriptreact = { name = "TypeScript packages", resolver = package_resolvers.node, global = "node_packages_path" },
	rust = { name = "Rust crates", resolver = package_resolvers.rust, global = "rust_packages_path" },
}

function M.name_for(filetype)
	local lang = M.languages[filetype]
	return lang and lang.name or filetype
end

local function path_for(entries, paths, filetype)
	local lang = entries[filetype]
	if not lang then
		return nil
	end

	local key = filetype .. "\0" .. vim.uv.cwd()
	if paths[key] then
		return paths[key]
	end

	local candidate = vim.g[lang.global]
	if not candidate and lang.resolver then
		local ok, result = pcall(lang.resolver)
		candidate = ok and result or nil
	end
	candidate = candidate or lang.default

	local resolved = resolve_path(candidate)
	if resolved then
		paths[key] = resolved
	end
	return resolved
end

function M.path_for(filetype)
	return path_for(M.languages, cache, filetype)
end

function M.package_name_for(filetype)
	local lang = M.packages[filetype]
	return lang and lang.name or filetype
end

function M.package_path_for(filetype)
	return path_for(M.packages, package_cache, filetype)
end

function M.current()
	local filetype = vim.bo.filetype
	local path = M.path_for(filetype)
	if not path then
		vim.notify("stdlib: no path resolved for filetype '" .. filetype .. "'", vim.log.levels.WARN)
	end
	return path
end

function M.current_packages()
	local filetype = vim.bo.filetype
	local path = M.package_path_for(filetype)
	if not path then
		vim.notify("packages: no path resolved for filetype '" .. filetype .. "'", vim.log.levels.WARN)
	end
	return path
end

return M
