-- plugin/block-end-comment.lua
-- Neovim plugin entry point.
-- This file is sourced automatically by Neovim's plugin loader.
-- It simply guards against double-loading; actual setup is done by the user
-- calling require("block-end-comment").setup() in their config.

if vim.g.loaded_block-end-comment then
	return
end
vim.g.loaded_block-end-comment = true
