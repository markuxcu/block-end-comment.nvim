-- plugin/block_comment.lua
-- Neovim plugin entry point.
-- This file is sourced automatically by Neovim's plugin loader.
-- It simply guards against double-loading; actual setup is done by the user
-- calling require("block_comment").setup() in their config.

if vim.g.loaded_block_comment then return end
vim.g.loaded_block_comment = true
