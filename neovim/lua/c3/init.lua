local M = {}

M.config = {
	format_on_save = false,
	format_cmd = "c3fmt",
	lsp_cmd = "c3lsp",
	highlighting = {
		enable_treesitter = true,
	}
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local function install_and_get_formatter()
	local cmd = M.config.format_cmd
	if vim.fn.executable(cmd) == 1 then return cmd end

	local bin_dir = vim.fn.stdpath("data") .. "/c3-fmt"
	local bin_path = bin_dir .. "/c3fmt"
	if vim.fn.has("win32") == 1 then bin_path = bin_path .. ".exe" end

	if vim.fn.filereadable(bin_path) == 1 then return bin_path end

	if vim.fn.executable("curl") == 1 then
		vim.notify("Downloading c3fmt from GitHub...", vim.log.levels.INFO)
		vim.fn.mkdir(bin_dir, "p")
		local os = vim.fn.has("mac") == 1 and "macos" or (vim.fn.has("win32") == 1 and "windows.exe" or "linux")

		local url = string.format("https://github.com/lmichaudel/c3fmt/releases/latest/download/c3fmt-%s", os)

		vim.fn.system({ "curl", "-sL", url, "-o", bin_path })
		if vim.v.shell_error == 0 then
			if vim.fn.has("win32") == 0 then vim.fn.system({ "chmod", "+x", bin_path }) end
			vim.notify("c3fmt installed successfully!", vim.log.levels.INFO)
			return bin_path
		end
	end
	return nil
end

function M.format()
	local cmd_path = install_and_get_formatter()
	if cmd_path then
		local view = vim.fn.winsaveview()
		vim.cmd('silent! write')
		vim.fn.system({ cmd_path, vim.api.nvim_buf_get_name(0) })
		vim.cmd('silent! edit!')
		if view then
			vim.fn.winrestview(view)
		end
	else
		vim.notify("c3fmt not found and auto-install failed.", vim.log.levels.WARN)
	end
end

local function install_and_get_lsp()
	local cmd = M.config.lsp_cmd
	if vim.fn.executable(cmd) == 1 then return cmd end

	local lsp_dir = vim.fn.stdpath("data") .. "/c3-lsp"
	local bin_path = lsp_dir .. "/lsp"
	if vim.fn.has("win32") == 1 then bin_path = bin_path .. ".exe" end

	if vim.fn.filereadable(bin_path) == 1 then return bin_path end

	local has_unzip = vim.fn.executable("unzip") == 1
	local has_tar = vim.fn.executable("tar") == 1
	local has_curl = vim.fn.executable("curl") == 1

	if has_curl and (has_unzip or has_tar) then
		vim.notify("Downloading C3 LSP from GitHub...", vim.log.levels.INFO)
		vim.fn.mkdir(lsp_dir, "p")
		local os = vim.fn.has("mac") == 1 and "macos" or (vim.fn.has("win32") == 1 and "windows" or "linux")
		local arch = vim.uv.os_uname().machine
		arch = (arch:match("arm") or arch:match("aarch64")) and "aarch64" or "x86_64"

		local url = string.format("https://github.com/tonis2/lsp/releases/latest/download/c3-lsp-%s-%s.zip", os, arch)
		local zip_path = lsp_dir .. "/lsp.zip"

		vim.fn.system({ "curl", "-sL", url, "-o", zip_path })
		if vim.v.shell_error == 0 then
			if has_unzip then
				vim.fn.system({ "unzip", "-o", zip_path, "-d", lsp_dir })
			else
				vim.fn.system({ "tar", "-xf", zip_path, "-C", lsp_dir })
			end
			vim.fn.delete(zip_path)
			if vim.fn.has("win32") == 0 then vim.fn.system({ "chmod", "+x", bin_path }) end
			vim.notify("C3 LSP installed successfully!", vim.log.levels.INFO)
			return bin_path
		end
	end
	return nil
end

function M.start_lsp(bufnr)
	local cmd_path = install_and_get_lsp()
	if not cmd_path then return end

	local root_dir = vim.fs.dirname(vim.fs.find({'project.json', '.git'}, { upward = true })[1]) or vim.fn.getcwd()

	local has_lspconfig, lspconfig = pcall(require, "lspconfig")
	if has_lspconfig then
		if not lspconfig.c3_lsp then
			local configs_ok, configs = pcall(require, "lspconfig.configs")
			if configs_ok and configs then
				configs.c3_lsp = {
					default_config = {
						cmd = { cmd_path },
						filetypes = { "c3" },
						root_dir = root_dir,
						settings = {},
					},
				}
			end
		end
		if lspconfig.c3_lsp then
				pcall(function() lspconfig.c3_lsp.setup({}) end)
		end
	else
		pcall(function()
			vim.lsp.start({
				name = "c3lsp",
				cmd = { cmd_path },
				root_dir = root_dir,
				workspace_folders = {
					{
						name = vim.fs.basename(root_dir) or "c3_project",
						uri = vim.uri_from_fname(root_dir),
					}
				}
			}, { bufnr = bufnr })
		end)
	end
end

local function check_treesitter_parser()
	if M.config.highlighting.enable_treesitter == false then
		return false
	end

	local ts_ok, ts = pcall(require, "vim.treesitter")
	if not ts_ok then return false end

	local has_parser = pcall(function() ts.language.inspect("c3") end)
	if has_parser then return true end

	local nvim_ts_ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if nvim_ts_ok then
		local parser_configs = parsers.get_parser_configs()
		if not parser_configs.c3 then
			parser_configs.c3 = {
				install_info = {
					url = "https://github.com/c3lang/tree-sitter-c3",
					files = { "src/parser.c", "src/scanner.c" },
					branch = "main",
				},
				filetype = "c3",
			}
		end

		local install_mod_ok, install_mod = pcall(require, "nvim-treesitter.install")
		if install_mod_ok and install_mod.ensure_installed then
			install_mod.ensure_installed({ "c3" })
			return true
		end
	end

	-- Auto-compile fallback for platforms with cc and git available
	local parser_path = vim.fn.stdpath("data") .. "/c3-parser"
	local so_path = parser_path .. "/c3.so"

	if vim.fn.filereadable(so_path) == 1 then
		pcall(function() ts.language.add("c3", { path = so_path }) end)
		return true
	end

	local compiler
	for _, cmd in ipairs({ "cc", "gcc", "clang", "zig cc" }) do
		local exec_name = string.match(cmd, "^([^ ]+)")
		if vim.fn.executable(exec_name) == 1 then
			compiler = cmd
			break
		end
	end

	if vim.fn.executable("git") == 1 and compiler then
		vim.notify("Auto-installing tree-sitter-c3 parser fallback...", vim.log.levels.INFO)

		-- Securely remove directory using Neovim API instead of raw rm
		vim.fn.delete(parser_path, "rf")

		vim.fn.jobstart(string.format(
			"git clone --depth 1 https://github.com/c3lang/tree-sitter-c3 '%s' && cd '%s' && %s -fPIC -shared src/parser.c src/scanner.c -I src -o c3.so",
			parser_path, parser_path, compiler
		), {
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.schedule(function()
						pcall(function() ts.language.add("c3", { path = so_path }) end)
						vim.notify("c3 tree-sitter parser installed successfully. Reopen buffer to apply.", vim.log.levels.INFO)
					end)
				else
					vim.notify("Failed to compile c3 tree-sitter parser fallback", vim.log.levels.WARN)
				end
			end
		})
		return false
	end

	return false
end

function M.setup_highlighting()
	-- Always enable basic syntax as a fallback or base layer
	vim.cmd([[syntax enable]])
	vim.cmd([[runtime! syntax/c3.vim]])

	-- Try to start tree-sitter for buffer
	local has_ts = check_treesitter_parser()
	if has_ts then
		pcall(function() vim.treesitter.start(0, "c3") end)
	end
end

return M
