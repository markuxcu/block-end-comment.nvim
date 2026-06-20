-- lua/block_end_comment/init.lua
-- Main entry point for the block_end_comment Neovim plugin.
--
-- Commands
--   :BlockComment        – add a closing comment to the } / end on the cursor line
--   :BlockCommentRemove  – remove a previously added closing comment
--
-- Default keymaps (disable with keymaps = false in setup)
--   <leader>}  – add comment
--   <leader>{  – remove comment

local M = {}
local parser = require("block_end_comment.parser")

-- ──────────────────────────────────────────────────────────────────────────────
-- Defaults
-- ──────────────────────────────────────────────────────────────────────────────

local defaults = {
	-- Comment templates per filetype.
	-- %s is replaced by the label returned by the parser.
	comment_style = {
		cpp = "// end %s",
		c = "// end %s",
		rust = "// end %s",
		zig = "// end %s",
		java = "// end %s",
		javascript = "// end %s",
		javascriptreact = "// end %s",
		typescript = "// end %s",
		typescriptreact = "// end %s",
		go = "// end %s",
		lua = "-- end %s",
		python = "# end %s",
		nim = "# end %s",
	},

	-- Automatically add comment when leaving insert mode on a closing line.
	-- Disabled by default to avoid surprising behaviour.
	auto_insert = false,

	-- Set to false to skip default keymaps.
	keymaps = true,

	-- Minimum number of lines a block must span before a comment is added.
	-- Avoids noise on tiny single-line blocks.
	min_block_lines = 3,
}

local config = {}

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────

-- Returns the comment prefix string for the current buffer (e.g. "//", "--", "#")
local function comment_prefix(ft)
	local tpl = config.comment_style[ft]
	if not tpl then
		return nil
	end
	-- Extract everything before the %s (and trim trailing space)
	return tpl:match("^(.-)%s*%%s") or tpl
end

-- Pattern that matches a comment we previously inserted.
-- We match "  } // end …"  or  "  end  -- end …"  etc.
-- Returns a Lua pattern string.
local function our_comment_pattern(ft)
	local prefix = comment_prefix(ft)
	if not prefix then
		return nil
	end
	-- Escape magic chars in the prefix (e.g. "//")
	local escaped = prefix:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
	-- Match: optional whitespace, then closing token, then whitespace, comment prefix, then label (anything)
	return "%s*" .. escaped .. ".+"
end

-- Detect whether a line already carries one of our comments.
local function has_our_comment(line, ft)
	local pat = our_comment_pattern(ft)
	if not pat then
		return false
	end
	return line:find(pat) ~= nil
end

-- Strip our comment from a line (returns the bare closing-token line).
local function strip_our_comment(line, ft)
	local prefix = comment_prefix(ft)
	if not prefix then
		return line
	end
	local escaped = prefix:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
	-- Remove everything from the comment prefix onwards, then trim trailing whitespace
	local stripped = line:gsub("%s*" .. escaped .. ".*$", "")
	return stripped
end

-- Returns the closing token(s) for a filetype (used for line detection).
local close_tokens = {
	cpp = { "}", "};" },
	c = { "}", "};" },
	rust = { "}" },
	zig = { "}", "};" },
	java = { "}", "};" },
	javascript = { "}", "};" },
	javascriptreact = { "}", "};" },
	typescript = { "}", "};" },
	typescriptreact = { "}", "};" },
	go = { "}" },
	lua = { "end", "}" },
	python = { "DEDENT" }, -- indentation-based detection
	nim = { "DEDENT" }, -- indentation-based detection
}

-- Indentation-based closing-line detection for Python / Nim.
-- A line is a "closing line" when the next non-blank line has
-- less or equal indentation (dedent), and the line doesn't start
-- a new block (doesn't end with ':').
local function is_indent_closing_line(line, lnum)
	if line:match(":%s*$") or line:match(":%s*#") then
		return false
	end
	if line:match("^%s*$") or line:match("^%s*#") then
		return false
	end

	local current_indent = vim.fn.indent(lnum)
	local next_lnum = vim.fn.nextnonblank(lnum + 1)
	if next_lnum == 0 then
		return true
	end

	local next_indent = vim.fn.indent(next_lnum)
	return next_indent <= current_indent
end

-- Returns true if `line` is a closing line (one we should annotate).
-- `lnum` is required for indentation-based languages (Python / Nim).
local function is_closing_line(line, ft, lnum)
	local tokens = close_tokens[ft]
	if not tokens then
		return false
	end

	-- Python / Nim: indentation-based dedent detection
	if tokens[1] == "DEDENT" then
		lnum = lnum or vim.fn.line(".")
		local bare = strip_our_comment(line, ft)
		return is_indent_closing_line(bare, lnum)
	end

	local bare = strip_our_comment(line, ft)
	bare = bare:match("^%s*(.-)%s*$") -- trim
	for _, tok in ipairs(tokens) do
		if bare == tok then
			return true
		end
	end
	return false
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Core: add comment
-- ──────────────────────────────────────────────────────────────────────────────

function M.add_comment()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	local tpl = config.comment_style[ft]
	if not tpl then
		vim.notify("[block-end-comment] Filetype '" .. ft .. "' not configured", vim.log.levels.WARN)
		return
	end

	local lnum = vim.fn.line(".")
	local line = vim.fn.getline(lnum)

	-- Guard: must be a closing line
	if not is_closing_line(line, ft, lnum) then
		vim.notify("[block-end-comment] Cursor is not on a closing line", vim.log.levels.WARN)
		return
	end

	-- Guard: already has our comment → skip
	if has_our_comment(line, ft) then
		vim.notify("[block-end-comment] Comment already present", vim.log.levels.INFO)
		return
	end

	local label = parser.get_label(lnum, bufnr)
	if not label then
		vim.notify("[block-end-comment] Could not identify block type", vim.log.levels.INFO)
		return
	end

	-- Build and apply the new line
	local comment = string.format(tpl, label)
	local bare = strip_our_comment(line, ft) -- remove any stale comment first
	local new_line = bare .. " " .. comment
	vim.fn.setline(lnum, new_line)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Core: remove comment
-- ──────────────────────────────────────────────────────────────────────────────

function M.remove_comment()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype

	if not config.comment_style[ft] then
		vim.notify("[block-end-comment] Filetype '" .. ft .. "' not configured", vim.log.levels.WARN)
		return
	end

	local lnum = vim.fn.line(".")
	local line = vim.fn.getline(lnum)

	if not has_our_comment(line, ft) then
		vim.notify("[block-end-comment] No block-end-comment found on this line", vim.log.levels.INFO)
		return
	end

	local stripped = strip_our_comment(line, ft)
	vim.fn.setline(lnum, stripped)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Bulk: add / remove for the whole buffer
-- ──────────────────────────────────────────────────────────────────────────────

--- Run add_comment on every closing line in the buffer.
function M.add_all()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	local nlines = vim.api.nvim_buf_line_count(bufnr)
	local count = 0

	-- Save cursor, iterate, restore
	local saved = vim.fn.getcurpos()
	for l = 1, nlines do
		local line = vim.fn.getline(l)
		if is_closing_line(line, ft) and not has_our_comment(line, ft) then
			vim.fn.cursor(l, 1)
			M.add_comment()
			count = count + 1
		end
	end
	vim.fn.setpos(".", saved)
	vim.notify(("[block-end-comment] Added %d comment(s)"):format(count), vim.log.levels.INFO)
end

--- Remove all block-end-comment comments in the buffer.
function M.remove_all()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	local nlines = vim.api.nvim_buf_line_count(bufnr)
	local count = 0

	local saved = vim.fn.getcurpos()
	for l = 1, nlines do
		local line = vim.fn.getline(l)
		if has_our_comment(line, ft) then
			vim.fn.cursor(l, 1)
			M.remove_comment()
			count = count + 1
		end
	end
	vim.fn.setpos(".", saved)
	vim.notify(("[block-end-comment] Removed %d comment(s)"):format(count), vim.log.levels.INFO)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Auto-insert autocmd
-- ──────────────────────────────────────────────────────────────────────────────

local function setup_autocmd()
	local au_group = vim.api.nvim_create_augroup("BlockComment", { clear = true })

	-- Collect glob patterns for configured filetypes
	local ext_map = {
		cpp = "*.cpp,*.cc,*.cxx,*.hpp",
		c = "*.c,*.h",
		rust = "*.rs",
		zig = "*.zig",
		lua = "*.lua",
		python = "*.py",
		java = "*.java",
		javascript = "*.js,*.jsx,*.mjs,*.cjs",
		javascriptreact = "*.jsx",
		typescript = "*.ts,*.tsx,*.mts,*.cts",
		typescriptreact = "*.tsx",
		go = "*.go",
		nim = "*.nim,*.nims",
	}
	local patterns = {}
	for ft, _ in pairs(config.comment_style) do
		if ext_map[ft] then
			for _, p in ipairs(vim.split(ext_map[ft], ",")) do
				table.insert(patterns, p)
			end
		end
	end

	if #patterns == 0 then
		return
	end

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = au_group,
		pattern = patterns,
		callback = function()
			local ft = vim.bo.filetype
			local lnum = vim.fn.line(".")
			local line = vim.fn.getline(lnum)
			if is_closing_line(line, ft, lnum) and not has_our_comment(line, ft) then
				M.add_comment()
			end
		end,
	})
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Setup
-- ──────────────────────────────────────────────────────────────────────────────

function M.setup(opts)
	config = vim.tbl_deep_extend("force", defaults, opts or {})

	-- ── Commands ────────────────────────────────────────────────────────────────
	vim.api.nvim_create_user_command("BlockComment", function()
		M.add_comment()
	end, { desc = "Add block-end comment on current closing line" })

	vim.api.nvim_create_user_command("BlockCommentRemove", function()
		M.remove_comment()
	end, { desc = "Remove block-end-comment comment from current closing line" })

	vim.api.nvim_create_user_command("BlockCommentAll", function()
		M.add_all()
	end, { desc = "Add block-end comments to all closing lines in buffer" })

	vim.api.nvim_create_user_command("BlockCommentRemoveAll", function()
		M.remove_all()
	end, { desc = "Remove all block-end-comment comments in buffer" })

	-- ── Keymaps ─────────────────────────────────────────────────────────────────
	if config.keymaps then
		vim.keymap.set("n", "<leader>}", M.add_comment, { desc = "Add block-end comment" })
		vim.keymap.set("n", "<leader>{", M.remove_comment, { desc = "Remove block-end comment" })
	end

	-- ── Autocmd ─────────────────────────────────────────────────────────────────
	if config.auto_insert then
		setup_autocmd()
	end
end

return M
