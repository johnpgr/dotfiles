local function java_stdlib()
	local java = vim.fn.exepath("java")
	if java == "" then
		vim.notify("Java is not on PATH", vim.log.levels.WARN)
		return
	end

	local result = vim.system({ java, "-XshowSettings:properties", "-version" }, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify(vim.trim(result.stderr or "Could not read java.home"), vim.log.levels.WARN)
		return
	end

	local home = (result.stderr or ""):match("java%.home%s*=%s*([^\r\n]+)")
	if not home then
		vim.notify("Could not find java.home in Java's settings", vim.log.levels.WARN)
		return
	end

	local archive = vim.fs.joinpath(vim.trim(home), "lib", "src.zip")
	local stat = vim.uv.fs_stat(archive)
	if not stat then
		vim.notify(
			"Java sources are missing: " .. archive .. ". Install your JDK's source package.",
			vim.log.levels.WARN
		)
		return
	end

	local key = vim.fn.sha256(archive .. ":" .. stat.size .. ":" .. stat.mtime.sec .. ":" .. stat.mtime.nsec)
	local root = vim.fs.joinpath(vim.fn.stdpath("cache"), "java-stdlib", key)
	local complete = vim.fs.joinpath(root, ".extracted")
	if vim.uv.fs_stat(complete) then
		return root
	end

	local unzip = vim.fn.exepath("unzip")
	if unzip == "" then
		vim.notify("Install unzip to extract Java's source archive", vim.log.levels.WARN)
		return
	end

	vim.fn.mkdir(root, "p")
	result = vim.system({ unzip, "-oq", archive, "-d", root }, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify(vim.trim(result.stderr or "Could not extract Java's sources"), vim.log.levels.WARN)
		return
	end

	vim.fn.writefile({}, complete)
	return root
end

vim.keymap.set("n", "<leader>fJ", function()
	local path = java_stdlib()
	if path then
		require("fff").find_files({ cwd = path, resume = true, resume_key = "java-stdlib:" .. path })
	end
end, { buffer = true, desc = "Find Java stdlib files" })

vim.keymap.set("n", "<leader>sJ", function()
	local path = java_stdlib()
	if path then
		require("fff").live_grep({ cwd = path, resume = true, resume_key = "java-stdlib-grep:" .. path })
	end
end, { buffer = true, desc = "Search Java stdlib" })

vim.keymap.set("n", "<leader>oJ", function()
	local path = java_stdlib()
	if path then
		require("oil").open(path)
	end
end, { buffer = true, desc = "Browse Java stdlib with Oil" })

vim.keymap.set("x", "<leader>!", ":!google-java-format --assume-filename=% - ", {
	buffer = true,
	desc = "Filter selection through google-java-format",
})
