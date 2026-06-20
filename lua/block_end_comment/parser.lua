-- lua/block_end_comment/parser.lua
-- Treesitter-based block detection for block_end_comment plugin.
-- Supports: rust, zig, cpp, c, lua, python (and any TS-supported language).

local M = {}

-- ──────────────────────────────────────────────────────────────────────────────
-- Language configs
-- Each entry maps a filetype to:
--   • node_types : TS node type(s) that represent a "block" we care about
--   • label_fn   : function(node, src) -> human-readable label string
-- ──────────────────────────────────────────────────────────────────────────────

-- Helper: get the text of a child node by field name (returns "" if missing)
local function field_text(node, field, src)
	local child = node:field(field)[1]
	if child then
		return vim.treesitter.get_node_text(child, src)
	end
	return ""
end

-- Helper: get text of first named child of a given type
local function child_text_by_type(node, type_name, src)
	for child in node:iter_children() do
		if child:type() == type_name then
			return vim.treesitter.get_node_text(child, src)
		end
	end
	return ""
end

-- Truncate long expressions so comments stay short
local function trunc(s, max)
	max = max or 40
	if #s > max then
		return s:sub(1, max - 1) .. "…"
	end
	return s
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Shared label functions (used across multiple languages)
-- ──────────────────────────────────────────────────────────────────────────────

local function label_for_loop(node, src)
	-- Works for C/C++/Rust/Zig style for loops
	local init = field_text(node, "initializer", src)
	-- fallback: grab the condition
	local cond = field_text(node, "condition", src)
	if init ~= "" then
		return "for " .. trunc(init)
	elseif cond ~= "" then
		return "for " .. trunc(cond)
	end
	-- Last resort: first line of the node text
	local text = vim.treesitter.get_node_text(node, src)
	local first = text:match("^([^\n]+)")
	return "for " .. trunc(first or "")
end

local function label_while_loop(node, src)
	local cond = field_text(node, "condition", src)
	if cond ~= "" then
		return "while " .. trunc(cond)
	end
	return "while"
end

local function label_if(node, src)
	local cond = field_text(node, "condition", src)
	if cond ~= "" then
		return "if " .. trunc(cond)
	end
	return "if"
end

local function label_function(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then
		return "fn " .. name
	end
	return "fn"
end

local function label_function_def(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then
		return "function " .. name
	end
	-- C/C++: name inside declarator → function_declarator → identifier
	local decl = node:field("declarator")[1]
	if decl then
		name = child_text_by_type(decl, "identifier", src)
		if name ~= "" then
			return "function " .. name
		end
	end
	return "function"
end

local function label_class(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then
		return "class " .. name
	end
	return "class"
end

local function label_struct(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then
		return "struct " .. name
	end
	return "struct"
end

local function label_namespace(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then
		return "namespace " .. name
	end
	return "namespace"
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Per-language node-type → label mapping
-- ──────────────────────────────────────────────────────────────────────────────

local lang_configs = {

	-- ── C / C++ ────────────────────────────────────────────────────────────────
	cpp = {
		{ types = { "for_statement" }, fn = label_for_loop },
		{
			types = { "for_range_loop" },
			fn = function(node, src)
				local decl = field_text(node, "declarator", src)
				local right = field_text(node, "right", src)
				if decl ~= "" and right ~= "" then
					return "for " .. trunc(decl) .. " in " .. trunc(right)
				end
				return "for"
			end,
		},
		{ types = { "while_statement" }, fn = label_while_loop },
		{
			types = { "do_statement" },
			fn = function()
				return "do"
			end,
		},
		{ types = { "if_statement" }, fn = label_if },
		{
			types = { "else_clause" },
			fn = function()
				return "else"
			end,
		},
		{ types = { "function_definition" }, fn = label_function_def },
		{ types = { "class_specifier" }, fn = label_class },
		{ types = { "struct_specifier" }, fn = label_struct },
		{ types = { "namespace_definition" }, fn = label_namespace },
		{
			types = { "switch_statement" },
			fn = function(n, s)
				local cond = field_text(n, "condition", s)
				return "switch " .. trunc(cond)
			end,
		},
	},

	-- ── Rust ───────────────────────────────────────────────────────────────────
	rust = {
		{
			types = { "for_expression" },
			fn = function(node, src)
				local pat = field_text(node, "pattern", src)
				local iter = field_text(node, "value", src)
				if pat ~= "" and iter ~= "" then
					return "for " .. trunc(pat) .. " in " .. trunc(iter)
				end
				return "for"
			end,
		},
		{ types = { "while_expression" }, fn = label_while_loop },
		{
			types = { "loop_expression" },
			fn = function()
				return "loop"
			end,
		},
		{ types = { "if_expression" }, fn = label_if },
		{
			types = { "else_clause" },
			fn = function()
				return "else"
			end,
		},
		{ types = { "function_item" }, fn = label_function },
		{
			types = { "impl_item" },
			fn = function(node, src)
				local type_ = field_text(node, "type", src)
				local trait = field_text(node, "trait", src)
				if trait ~= "" then
					return "impl " .. trunc(trait) .. " for " .. trunc(type_)
				end
				return "impl " .. trunc(type_)
			end,
		},
		{ types = { "struct_item" }, fn = label_struct },
		{
			types = { "enum_item" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				return "enum " .. name
			end,
		},
		{
			types = { "mod_item" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				return "mod " .. name
			end,
		},
		{
			types = { "match_expression" },
			fn = function(node, src)
				local val = field_text(node, "value", src)
				return "match " .. trunc(val)
			end,
		},
		{
			types = { "closure_expression" },
			fn = function()
				return "closure"
			end,
		},
	},

	-- ── Zig ────────────────────────────────────────────────────────────────────
	zig = {
		{
			types = { "for_statement", "for_expression" },
			fn = function(node, src)
				-- Zig: for (slice) |elem|
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("for%s*(%b())")
				return cap and ("for " .. trunc(cap)) or "for"
			end,
		},
		{
			types = { "while_statement", "while_expression" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("while%s*(%b())")
				return cap and ("while " .. trunc(cap)) or "while"
			end,
		},
		{
			types = { "if_statement", "if_expression" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("if%s*(%b())")
				return cap and ("if " .. trunc(cap)) or "if"
			end,
		},
		{ types = { "fn_decl", "function_declaration" }, fn = label_function },
		{
			types = { "struct_decl", "container_decl" },
			fn = function(node, src)
				-- Zig structs: const Foo = struct { ... }
				local p = node:parent()
				if p and p:type() == "var_decl" then
					local name = field_text(p, "name", src)
					if name ~= "" then
						return "struct " .. name
					end
				end
				return "struct"
			end,
		},
	},

	-- ── Lua ────────────────────────────────────────────────────────────────────
	lua = {
		{
			types = { "for_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				-- for k, v in pairs(t) do
				local vars = text:match("^for%s+(.-)%s+in%s")
				local iter = text:match("%s+in%s+(.-)%s+do")
				if vars and iter then
					return "for " .. trunc(vars) .. " in " .. trunc(iter)
				end
				-- for i = 1, 10 do
				local cap = text:match("^for%s+(.-)%s+do")
				return cap and ("for " .. trunc(cap)) or "for"
			end,
		},
		{
			types = { "while_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^while%s+(.-)%s+do")
				return cap and ("while " .. trunc(cap)) or "while"
			end,
		},
		{
			types = { "if_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^if%s+(.-)%s+then")
				return cap and ("if " .. trunc(cap)) or "if"
			end,
		},
		{ types = { "function_declaration", "local_function" }, fn = label_function_def },
		{
			types = { "function_definition" },
			fn = function(node, src)
				-- anonymous / assigned function: local foo = function() end
				local p = node:parent()
				if p then
					-- assignment: foo = function
					local lhs = p:field("name")[1] or p:field("left")[1]
					if lhs then
						return "function " .. trunc(vim.treesitter.get_node_text(lhs, src))
					end
				end
				return "function"
			end,
		},
	},

	-- ── Python ─────────────────────────────────────────────────────────────────
	-- Python uses indentation, but TS still gives us block nodes.
	-- We label at the *end* of the block (last line of node).
	python = {
		{
			types = { "for_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^for%s+(.-)%s*:")
				return cap and ("for " .. trunc(cap)) or "for"
			end,
		},
		{
			types = { "while_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^while%s+(.-)%s*:")
				return cap and ("while " .. trunc(cap)) or "while"
			end,
		},
		{
			types = { "if_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^if%s+(.-)%s*:")
				return cap and ("if " .. trunc(cap)) or "if"
			end,
		},
		{ types = { "function_definition" }, fn = label_function_def },
		{ types = { "class_definition" }, fn = label_class },
		{
			types = { "with_statement" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^with%s+(.-)%s*:")
				return cap and ("with " .. trunc(cap)) or "with"
			end,
		},
		{
			types = { "try_statement" },
			fn = function()
				return "try"
			end,
		},
		{
			types = { "except_clause" },
			fn = function(node, src)
				local text = vim.treesitter.get_node_text(node, src)
				local cap = text:match("^except%s+(.-)%s*:")
				return cap and ("except " .. trunc(cap)) or "except"
			end,
		},
	},

	-- ── Nim ───────────────────────────────────────────────────────────────────
	-- Indentation-based (like Python). Parser works; closing-line detection via
	-- close_tokens needs future enhancement.
	nim = {
		-- Routines
		{ types = { "proc_declaration" }, fn = label_function_def },
		{ types = { "func_declaration" }, fn = label_function_def },
		{ types = { "method_declaration" }, fn = label_function_def },
		{ types = { "iterator_declaration" }, fn = label_function_def },
		{
			types = { "macro_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "macro " .. name
				end
				return "macro"
			end,
		},
		{
			types = { "template_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "template " .. name
				end
				return "template"
			end,
		},
		{
			types = { "converter_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "converter " .. name
				end
				return "converter"
			end,
		},
		{
			types = { "concept_declaration" },
			fn = function()
				return "concept"
			end,
		},

		-- Type declarations
		-- type_declaration has type_symbol_declaration (name) as a child
		{
			types = { "type_declaration" },
			fn = function(node, src)
				for child in node:iter_children() do
					if child:type() == "type_symbol_declaration" then
						local name = field_text(child, "name", src)
						if name ~= "" then
							return "type " .. name
						end
					end
				end
				return "type"
			end,
		},
		-- object_declaration / enum_declaration: name is on sibling type_symbol_declaration
		{
			types = { "object_declaration" },
			fn = function(node, src)
				local p = node:parent()
				if p and p:type() == "type_declaration" then
					for child in p:iter_children() do
						if child:type() == "type_symbol_declaration" then
							local name = field_text(child, "name", src)
							if name ~= "" then
								return "object " .. name
							end
						end
					end
				end
				return "object"
			end,
		},
		{
			types = { "enum_declaration" },
			fn = function(node, src)
				local p = node:parent()
				if p and p:type() == "type_declaration" then
					for child in p:iter_children() do
						if child:type() == "type_symbol_declaration" then
							local name = field_text(child, "name", src)
							if name ~= "" then
								return "enum " .. name
							end
						end
					end
				end
				return "enum"
			end,
		},
		{
			types = { "type_section" },
			fn = function()
				return "type"
			end,
		},

		-- Loops
		{
			types = { "for" },
			fn = function(node, src)
				local left = field_text(node, "left", src)
				local right = field_text(node, "right", src)
				if left ~= "" and right ~= "" then
					return "for " .. trunc(left) .. " in " .. trunc(right)
				elseif left ~= "" then
					return "for " .. trunc(left)
				end
				return "for"
			end,
		},
		{
			types = { "while" },
			fn = function(node, src)
				local cond = field_text(node, "condition", src)
				if cond ~= "" then
					return "while " .. trunc(cond)
				end
				return "while"
			end,
		},

		-- Conditionals
		{ types = { "if" }, fn = label_if },
		{ types = { "when" }, fn = label_if }, -- same as if
		{
			types = { "case" },
			fn = function(node, src)
				local val = field_text(node, "value", src)
				if val ~= "" then
					return "case " .. trunc(val)
				end
				return "case"
			end,
		},
		{
			types = { "elif_branch" },
			fn = function(node, src)
				local cond = field_text(node, "condition", src)
				if cond ~= "" then
					return "elif " .. trunc(cond)
				end
				return "elif"
			end,
		},
		{
			types = { "else_branch" },
			fn = function()
				return "else"
			end,
		},
		{
			types = { "of_branch" },
			fn = function(node, src)
				local vals = field_text(node, "values", src)
				if vals ~= "" then
					return "of " .. trunc(vals)
				end
				return "of"
			end,
		},

		-- Error handling
		{
			types = { "try" },
			fn = function()
				return "try"
			end,
		},
		{
			types = { "except_branch" },
			fn = function(node, src)
				local vals = field_text(node, "values", src)
				if vals ~= "" then
					return "except " .. trunc(vals)
				end
				return "except"
			end,
		},
		{
			types = { "finally_branch" },
			fn = function()
				return "finally"
			end,
		},

		-- Named block
		{
			types = { "block" },
			fn = function(node, src)
				local label = field_text(node, "label", src)
				if label ~= "" then
					return "block " .. label
				end
				return "block"
			end,
		},

		-- Other
		{
			types = { "do_block" },
			fn = function()
				return "do"
			end,
		},
		{
			types = { "defer" },
			fn = function()
				return "defer"
			end,
		},
		{
			types = { "const_section" },
			fn = function()
				return "const"
			end,
		},
		{
			types = { "let_section" },
			fn = function()
				return "let"
			end,
		},
		{
			types = { "var_section" },
			fn = function()
				return "var"
			end,
		},
		{
			types = { "static_statement" },
			fn = function()
				return "static"
			end,
		},
	},

	-- ── JavaScript ─────────────────────────────────────────────────────────────
	javascript = {
		{ types = { "if_statement" }, fn = label_if },
		{ types = { "while_statement" }, fn = label_while_loop },
		{
			types = { "do_statement" },
			fn = function()
				return "do"
			end,
		},
		{
			types = { "for_statement" },
			fn = function(node, src)
				local init = field_text(node, "initializer", src)
				local cond = field_text(node, "condition", src)
				if init ~= "" then
					return "for " .. trunc(init)
				elseif cond ~= "" then
					return "for " .. trunc(cond)
				end
				local text = vim.treesitter.get_node_text(node, src)
				local first = text:match("^([^\n]+)")
				return "for " .. trunc(first or "")
			end,
		},
		{
			types = { "for_in_statement" },
			fn = function(node, src)
				local left = field_text(node, "left", src)
				local right = field_text(node, "right", src)
				if left ~= "" then
					if right ~= "" then
						return "for " .. trunc(left) .. " in " .. trunc(right)
					end
					return "for " .. trunc(left)
				end
				return "for...in"
			end,
		},
		{
			types = { "for_of_statement" },
			fn = function(node, src)
				local left = field_text(node, "left", src)
				local right = field_text(node, "right", src)
				if left ~= "" then
					if right ~= "" then
						return "for " .. trunc(left) .. " of " .. trunc(right)
					end
					return "for " .. trunc(left)
				end
				return "for...of"
			end,
		},
		{
			types = { "switch_statement" },
			fn = function(node, src)
				local val = field_text(node, "value", src)
				if val ~= "" then
					return "switch " .. trunc(val)
				end
				return "switch"
			end,
		},
		{
			types = { "try_statement" },
			fn = function()
				return "try"
			end,
		},
		{
			types = { "catch_clause" },
			fn = function(node, src)
				local param = field_text(node, "parameter", src)
				if param ~= "" then
					return "catch " .. trunc(param)
				end
				return "catch"
			end,
		},
		{
			types = { "finally_clause" },
			fn = function()
				return "finally"
			end,
		},
		{
			types = { "function_declaration" },
			fn = label_function_def,
		},
		{
			types = { "function_expression" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "fn " .. name
				end
				return "fn"
			end,
		},
		{
			types = { "arrow_function" },
			fn = function()
				return "arrow"
			end,
		},
		{ types = { "class_declaration" }, fn = label_class },
		{
			types = { "class_expression" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "class " .. name
				end
				return "class"
			end,
		},
		{
			types = { "method_definition" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "method " .. name
				end
				return "method"
			end,
		},
		{
			types = { "export_statement" },
			fn = function(node, src)
				local src_node = node:field("source")[1]
				if src_node then
					return "export from " .. trunc(vim.treesitter.get_node_text(src_node, src))
				end
				return "export"
			end,
		},
	},

	-- ── Java ───────────────────────────────────────────────────────────────────
	java = {
		{ types = { "if_statement" }, fn = label_if },
		{ types = { "while_statement" }, fn = label_while_loop },
		{ types = { "for_statement" }, fn = label_for_loop },
		{
			types = { "enhanced_for_statement" },
			fn = function(node, src)
				local variable = field_text(node, "variable", src)
				local value = field_text(node, "value", src)
				if variable ~= "" and value ~= "" then
					return "for " .. trunc(variable) .. " : " .. trunc(value)
				end
				return "for"
			end,
		},
		{
			types = { "do_statement" },
			fn = function()
				return "do"
			end,
		},
		{
			types = { "switch_expression" },
			fn = function(node, src)
				local cond = field_text(node, "condition", src)
				if cond ~= "" then
					return "switch " .. trunc(cond)
				end
				return "switch"
			end,
		},
		{
			types = { "try_statement" },
			fn = function()
				return "try"
			end,
		},
		{
			types = { "catch_clause" },
			fn = function(node, src)
				local param = field_text(node, "parameter", src)
				if param ~= "" then
					return "catch " .. trunc(param)
				end
				return "catch"
			end,
		},
		{
			types = { "finally_clause" },
			fn = function()
				return "finally"
			end,
		},
		{ types = { "method_declaration" }, fn = label_function_def },
		{
			types = { "constructor_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "constructor " .. name
				end
				return "constructor"
			end,
		},
		{ types = { "class_declaration" }, fn = label_class },
		{
			types = { "interface_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "interface " .. name
				end
				return "interface"
			end,
		},
		{
			types = { "enum_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "enum " .. name
				end
				return "enum"
			end,
		},
		{
			types = { "record_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "record " .. name
				end
				return "record"
			end,
		},
		{
			types = { "synchronized_statement" },
			fn = function(node, src)
				local cond = field_text(node, "condition", src)
				if cond ~= "" then
					return "synchronized " .. trunc(cond)
				end
				return "synchronized"
			end,
		},
	},

	-- ── Go ─────────────────────────────────────────────────────────────────────
	go = {
		{ types = { "if_statement" }, fn = label_if },
		{
			types = { "for_statement" },
			fn = function(node, src)
				local range = node:field("range")[1]
				if range then
					local left = field_text(range, "left", src)
					local value = field_text(range, "value", src)
					local right = field_text(range, "right", src)
					if left ~= "" and right ~= "" then
						if value ~= "" then
							return "for " .. trunc(left) .. ", " .. trunc(value) .. " := range " .. trunc(right)
						end
						return "for " .. trunc(left) .. " := range " .. trunc(right)
					end
					if right ~= "" then
						return "for range " .. trunc(right)
					end
					return "for range"
				end
				local init = field_text(node, "initializer", src)
				local cond = field_text(node, "condition", src)
				if init ~= "" then
					return "for " .. trunc(init)
				elseif cond ~= "" then
					return "for " .. trunc(cond)
				end
				return "for"
			end,
		},
		{
			types = { "switch_statement" },
			fn = function(node, src)
				local exp = field_text(node, "expression", src)
				if exp ~= "" then
					return "switch " .. trunc(exp)
				end
				return "switch"
			end,
		},
		{
			types = { "type_switch_statement" },
			fn = function(node, src)
				local val = field_text(node, "value", src)
				if val ~= "" then
					return "switch " .. trunc(val) .. ".(type)"
				end
				return "switch type"
			end,
		},
		{
			types = { "select_statement" },
			fn = function()
				return "select"
			end,
		},
		{ types = { "function_declaration" }, fn = label_function_def },
		{
			types = { "method_declaration" },
			fn = function(node, src)
				local name = field_text(node, "name", src)
				if name ~= "" then
					return "fn " .. name
				end
				return "fn"
			end,
		},
		{
			types = { "type_declaration" },
			fn = function(node, src)
				for child in node:iter_children() do
					if child:type() == "type_spec" then
						local name = field_text(child, "name", src)
						if name ~= "" then
							return "type " .. name
						end
					end
				end
				return "type"
			end,
		},
	},
}

-- Alias c → cpp config
lang_configs.c = lang_configs.cpp

-- TypeScript: inherit JS config + TS-specific nodes
lang_configs.typescript = vim.list_extend({}, lang_configs.javascript)
table.insert(lang_configs.typescript, { types = { "interface_declaration" }, fn = function(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then return "interface " .. name end
	return "interface"
end })
table.insert(lang_configs.typescript, { types = { "type_alias_declaration" }, fn = function(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then return "type " .. name end
	return "type"
end })
table.insert(lang_configs.typescript, { types = { "enum_declaration" }, fn = function(node, src)
	local name = field_text(node, "name", src)
	if name ~= "" then return "enum " .. name end
	return "enum"
end })

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

--- Returns the comment label for the block whose closing delimiter is on
--- `lnum` (1-based), or nil if nothing was found.
---
--- For brace languages (cpp/rust/zig/lua) we look at the node that *ends* on
--- that line. For Python we look at the node that contains the current line
--- as its last line.
---
---@param lnum integer  1-based line number of the closing line
---@param bufnr integer  buffer number
---@return string|nil
function M.get_label(lnum, bufnr)
	bufnr = bufnr or 0
	local ft = vim.bo[bufnr].filetype

	-- Normalise filetype aliases for config lookup and parser language
	local ft_aliases = {
		c = { config = "cpp", parser = "cpp" },
		["javascript.jsx"] = { config = "javascript", parser = "javascript" },
		javascriptreact = { config = "javascript", parser = "javascript" },
		["typescript.tsx"] = { config = "typescript", parser = "tsx" },
		typescriptreact = { config = "typescript", parser = "tsx" },
	}
	local normal = ft_aliases[ft]
	local config_ft, parser_lang
	if normal then
		config_ft = normal.config
		parser_lang = normal.parser
	else
		config_ft = ft
		parser_lang = ft
	end

	local cfg = lang_configs[config_ft]
	if not cfg then
		return nil
	end

	-- Ensure TS parser is available
	local ok, parser_obj = pcall(vim.treesitter.get_parser, bufnr, parser_lang)
	if not ok or not parser_obj then
		vim.notify("[block-end-comment] No treesitter parser for " .. ft, vim.log.levels.WARN)
		return nil
	end

	local tree = parser_obj:parse()[1]
	local root = tree:root()
	-- Convert to 0-based for TS
	local row = lnum - 1

	-- Get column of the closing character on this line.
	-- For Lua "end" keyword, use word-boundary match; fallback to col=0.
	local line_text = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local col = line_text:find("[}]")
	if not col then
		col = line_text:find("%f[%a]end%f[%A]")
	end
	col = math.max((col or 1) - 1, 0)

	-- Get the node AT the closing brace / on the last line
	local node = root:named_descendant_for_range(row, col, row, col)

	-- Use bufnr as source for get_node_text (table of lines not supported)
	local src = bufnr

	-- Walk up the tree to find a node that:
	--   (a) matches a type we care about, AND
	--   (b) ends on this line
	while node do
		local _, _, end_row, _ = node:range() -- 0-based end row
		if end_row == row then
			for _, entry in ipairs(cfg) do
				for _, t in ipairs(entry.types) do
					if node:type() == t then
						local ok2, label = pcall(entry.fn, node, src)
						if ok2 and label then
							return label
						end
					end
				end
			end
		end
		node = node:parent()
	end

	return nil
end

return M
