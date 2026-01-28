return {
    "ej-shafran/compile-mode.nvim",
    -- you can just use the latest version:
    -- branch = "latest",
    -- or the most up-to-date updates:
    branch = "nightly",
    dependencies = {
        "nvim-lua/plenary.nvim",
        -- if you want to enable coloring of ANSI escape codes in
        -- compilation output, add:
        { "m00qek/baleia.nvim", tag = "v1.3.0" },
    },
    config = function()
        local compile_mode = require("compile-mode")
        ---@type CompileModeOpts
        vim.g.compile_mode = {
            default_command = "",
            -- if you use something like `nvim-cmp` or `blink.cmp` for completion,
            -- set this to fix tab completion in command mode:
            input_word_completion = true,

            -- to add ANSI escape code support, add:
            baleia_setup = true,

            -- to make `:Compile` replace special characters (e.g. `%`) in
            -- the command (and behave more like `:!`), add:
            bang_expansion = true,

            error_regexp_table = {
                nodejs = {
                    regex = "^\\s\\+at .\\+ (\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\))$",
                    filename = 1,
                    row = 2,
                    col = 3,
                    priority = 2,
                },
                typescript = {
                    regex = "^\\(.\\+\\)(\\([1-9][0-9]*\\),\\([1-9][0-9]*\\)): error TS[1-9][0-9]*:",
                    filename = 1,
                    row = 2,
                    col = 3,
                },
                typescript_new = {
                    regex = "^\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\) - error TS[1-9][0-9]*:",
                    filename = 1,
                    row = 2,
                    col = 3,
                },
                gradlew = {
                    regex = "^e:\\s\\+file://\\(.\\+\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
                    filename = 1,
                    row = 2,
                    col = 3,
                },
                ls_lint = {
                    regex = "\\v^\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} (.+) failed for rules: .+$",
                    filename = 1,
                },
                sass = {
                    regex = "\\s\\+\\(.\\+\\) \\(\\d\\+\\):\\(\\d\\+\\)  .*$",
                    filename = 1,
                    row = 2,
                    col = 3,
                    type = compile_mode.level.WARNING,
                },
                kotlin = {
                    regex = "^\\%(e\\|w\\): file://\\(.*\\):\\(\\d\\+\\):\\(\\d\\+\\) ",
                    filename = 1,
                    row = 2,
                    col = 3,
                },
                rust = {
                    regex = "^\\s*-->\\s\\+\\(.\\+\\):\\([1-9][0-9]*\\):\\([1-9][0-9]*\\)$",
                    filename = 1,
                    row = 2,
                    col = 3,
                    priority = 2,
                },
            },
        }
    end,
}
