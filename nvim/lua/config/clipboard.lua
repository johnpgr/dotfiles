local M = {}

local function env_is_set(name)
	local value = vim.env[name]
	return value ~= nil and value ~= ""
end

local function is_ssh_session()
	return env_is_set("SSH_TTY") or env_is_set("SSH_CONNECTION") or env_is_set("SSH_CLIENT")
end

local function has_executable(name)
	return vim.fn.executable(name) == 1
end

function M.setup()
	if vim.g.clipboard == nil then
		if is_ssh_session() then
			vim.g.clipboard = "osc52"
		elseif vim.fn.has("win32") == 1 and (has_executable("win32yank.exe") or has_executable("win32yank")) then
			vim.g.clipboard = "win32yank"
		end
	end

	vim.opt.clipboard = "unnamedplus"
end

return M
