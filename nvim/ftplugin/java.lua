local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

local config = {
    name = "jdtls",
    cmd = {
        "jdtls",
        "-data", workspace_dir,
        "--jvm-arg=-javaagent:" .. vim.fn.expand("~/.local/share/nvim/mason/packages/jdtls/lombok.jar"),
        "--jvm-arg=--enable-preview",
    },
    root_dir = vim.fs.root(0, {'.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle'}),
    settings = {
        java = {
            configuration = {
                runtimes = {},
            },
            compile = {
                nullAnalysis = {
                    mode = "automatic",
                },
            },
            sources = {
                organizeImports = {
                    starThreshold = 9999,
                    staticStarThreshold = 9999,
                },
            },
            eclipse = {
                downloadSources = true,
            },
            maven = {
                downloadSources = true,
            },
            implementationsCodeLens = {
                enabled = true,
            },
            referencesCodeLens = {
                enabled = true,
            },
            format = {
                enabled = true,
            },
            settings = {
                url = vim.fn.stdpath("config") .. "/jdtls-settings.prefs",
            },
        },
    },
    init_options = {
        bundles = {},
        extendedClientCapabilities = {
            progressReportProvider = false,
        },
    },
    flags = {
        allow_incremental_sync = true,
    },
}

require('jdtls').start_or_attach(config)
