local M = {}

local function has_executable(name)
	return vim.fn.executable(name) == 1
end

function M.setup()
	if vim.g.clipboard == nil then
		local is_windows_or_wsl = vim.fn.has("win32") == 1 or vim.env.WSL_DISTRO_NAME ~= nil
		if is_windows_or_wsl and (has_executable("win32yank.exe") or has_executable("win32yank")) then
			vim.g.clipboard = "win32yank"
		end
	end

	vim.opt.clipboard = "unnamedplus"
end

return M
