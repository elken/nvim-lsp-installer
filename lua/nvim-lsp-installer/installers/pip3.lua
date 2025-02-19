local path = require "nvim-lsp-installer.path"
local Data = require "nvim-lsp-installer.data"
local installers = require "nvim-lsp-installer.installers"
local std = require "nvim-lsp-installer.installers.std"
local platform = require "nvim-lsp-installer.platform"
local process = require "nvim-lsp-installer.process"
local settings = require "nvim-lsp-installer.settings"

local M = {}

local REL_INSTALL_DIR = "venv"

---@param python_executable string
---@param packages string[]
local function create_installer(python_executable, packages)
    return installers.pipe {
        std.ensure_executables {
            {
                python_executable,
                ("%s was not found in path. Refer to https://www.python.org/downloads/."):format(python_executable),
            },
        },
        ---@type ServerInstallerFunction
        function(_, callback, context)
            local pkgs = Data.list_copy(packages or {})
            local c = process.chain {
                cwd = context.install_dir,
                stdio_sink = context.stdio_sink,
            }

            c.run(python_executable, { "-m", "venv", REL_INSTALL_DIR })
            if context.requested_server_version then
                -- The "head" package is the recipient for the requested version. It's.. by design... don't ask.
                pkgs[1] = ("%s==%s"):format(pkgs[1], context.requested_server_version)
            end

            local install_command = { "-m", "pip", "install", "-U" }
            vim.list_extend(install_command, settings.current.pip.install_args)
            c.run(M.executable(context.install_dir, "python"), vim.list_extend(install_command, pkgs))

            c.spawn(callback)
        end,
    }
end

---@param packages string[] @The pip packages to install. The first item in this list will be the recipient of the server version, should the user request a specific one.
function M.packages(packages)
    local py3 = create_installer("python3", packages)
    local py = create_installer("python", packages)
    return installers.first_successful(platform.is_win and { py, py3 } or { py3, py }) -- see https://github.com/williamboman/nvim-lsp-installer/issues/128
end

---@param root_dir string @The directory to resolve the executable from.
---@param executable string
function M.executable(root_dir, executable)
    return path.concat { root_dir, REL_INSTALL_DIR, platform.is_win and "Scripts" or "bin", executable }
end

return M
