local wezterm = require("wezterm")

local M = {}

M.is_windows = wezterm.target_triple:find("windows") ~= nil

function M.default_prog()
    if M.is_windows then
        return {
            "C:\\msys64\\usr\\bin\\bash.exe",
            "-l",
        }
    end

    return { "bash" }
end

function M.default_cwd()
    if M.is_windows then
        return wezterm.home_dir
    end

    return nil
end

function M.environment_variables()
    if M.is_windows then
        return {
            MSYSTEM = "UCRT64",
            CHERE_INVOKING = "enabled_from_arguments",
            MSYS2_PATH_TYPE = "inherit",
            COLORTERM = "truecolor",
            TERM_PROGRAM = "WezTerm",
        }
    end

    return {}
end

function M.window_decorations()
    if M.is_windows then
        return "INTEGRATED_BUTTONS|RESIZE"
    end

    return "TITLE|RESIZE"
end

return M
