#!/usr/bin/env lua

package.path = package.path..';metalualib/?.lua'
package.path = package.path..';lib/?.lua'

_G.mlc = {}

require "lexer"
require "gg"
require "mlp_lexer"
require "mlp_misc"
require "mlp_table"
require "mlp_meta"
require "mlp_expr"
require "mlp_stat"

local vars = {
	String = true,
	Number = true,
	Id = true,
}

local tags = {
	Break = "break",
	True = "true",
	False = "false",
	Nil = "nil",
	Dots = "...",
}

local ops = {
	-- arithmetic
	["add"]    = "+",
	["sub"]    = "-",
	["div"]    = "\/",
	["pow"]    = "^",
	["mod"]    = "%",
	["unm"]    = "-",
	-- relational
	["eq"]     = "==",
	["le"]     = "<=",
	["lt"]     = "<",
	-- logistic
	["and"]    = " and ",
	["or"]     = " or ",
	["not"]    = " not ",

	["concat"] = "..",
	["len"]    = "#",
}

function replace_esc(str)
	local esc_t = {
		{"\\", "\\\\"},
		{"\'", "\\\'"},
		{"\"", "\\\""},
		{"\a", "\\a"},
		{"\b", "\\b"},
		{"\f", "\\f"},
		{"\n", "\\n"},
		{"\r", "\\r"},
		{"\t", "\\t"},
		{"\v", "\\v"},
	}

	local s = str
	for i=1, #esc_t do
		s = string.gsub(s, esc_t[i][1], esc_t[i][2])
	end
	return s
end

function ast_from_string_helper(src, filename)
	filename = filename or '(string)'
	local  lx  = mlp.lexer:newstream (src, filename)
	local  ast = mlp.chunk(lx)
	return ast
end

function parse_tree(tab, sep)
	if type(tab) ~= 'table' then 
		return ops[tab] or "" 
	end

	local tag = tab.tag or ""

	if vars[tag] then
		return get_var_str(tab) 
	end

	if tags[tag] ~= nil then
		return get_tag_str(tab)
	end

	local tokens = {}
	if tag == 'If' then
		table.insert(tokens, get_if_str(tab))
	elseif tag == 'Call' then
		table.insert(tokens, get_call_str(tab))
	elseif tag == "Invoke" then
		table.insert(tokens, get_invoke_str(tab))
	elseif tag == "Local" then
		table.insert(tokens, get_local_str(tab))
	elseif tag == "Localrec" then
		table.insert(tokens, get_local_str(tab))
	elseif tag == "Function" then
		table.insert(tokens, get_function_str(tab))
	elseif tag == "Set" then
		table.insert(tokens, get_set_str(tab))
	elseif tag == "Op" then
		table.insert(tokens, get_op_str(tab))
	elseif tag == "Index" then
		table.insert(tokens, get_index_str(tab))
	elseif tag == "Table" then
		table.insert(tokens, get_table_str(tab))
	elseif tag == "Pair" then
		table.insert(tokens, get_pair_str(tab))
	elseif tag == "Return" then
		table.insert(tokens, get_return_str(tab))
	elseif tag == "While" then
		table.insert(tokens, get_while_str(tab))
	elseif tag == "Fornum" then
		table.insert(tokens, get_fornum_str(tab))
	elseif tag == "Forin" then
		table.insert(tokens, get_forin_str(tab))
	elseif tag == "Repeat" then
		table.insert(tokens, get_repeat_str(tab))
	elseif tag == "Do" then
		table.insert(tokens, get_do_str(tab))
	else
		for i=1, #tab  do
			local str = parse_tree(tab[i])
			if str ~= "" then
				table.insert(tokens, str)
			end
		end
	end
	return table.concat(tokens, sep) 
end

function get_var_str(tab)
	if tab.tag == 'String' then
		return "\"" .. replace_esc(tab[1]) .. "\""
	else
		return tab[1]
	end
end

function get_tag_str(tab)
	return tags[tab.tag]
end

function get_op_str(ast)
	local tokens = {}
	table.insert(tokens, "(")
	if ast[1] == 'not' or ast[1] == 'unm' or ast[1] == 'len' then
		table.insert(tokens, ops[ast[1]])
		table.insert(tokens, parse_tree(ast[2], " "))
	else
		table.insert(tokens, parse_tree(ast[2], " "))
		table.insert(tokens, ops[ast[1]])
		table.insert(tokens, parse_tree(ast[3], " "))
	end
	table.insert(tokens, ")")
	return table.concat(tokens)
end

function get_set_str(ast)
	local tokens = {}
	table.insert(tokens, parse_tree(ast[1], ","))
	table.insert(tokens, " = ")
	table.insert(tokens, parse_tree(ast[2], ","))
	return "\n" .. table.concat(tokens, " ")
end

function get_call_str(ast)
	local tokens = {}
	for i=1, #ast do
		table.insert(tokens, parse_tree(ast[i], " "))
		if i < #ast and i > 1 then table.insert(tokens, ",") end
	end
	table.insert(tokens, 2, "(")
	table.insert(tokens, ")")
	return table.concat(tokens, "")
end

function get_function_str(ast)
	local tokens = {"function"}
	table.insert(tokens, "(")
	table.insert(tokens, parse_tree(ast[1], ","))
	table.insert(tokens, ")")
	table.insert(tokens, parse_tree(ast[2], " "))
	table.insert(tokens, "\nend")
	return table.concat(tokens, "")
end

function get_if_str(ast)
	local tokens = {}
	for i=1, #ast do
		if i % 2 == 0 then 
			table.insert(tokens, "then")
		elseif i == 1 then
			table.insert(tokens, "\nif")
		elseif i < #ast then
			table.insert(tokens, "\nelseif")
		else
			table.insert(tokens, "\nelse")
		end
		table.insert(tokens, parse_tree(ast[i], " "))
	end
	table.insert(tokens, "\nend\n")
	return table.concat(tokens, " ")
end

function get_index_str(ast)
	local tokens = {}
	table.insert(tokens, parse_tree(ast[1], " "))
	table.insert(tokens, "[")
	table.insert(tokens, parse_tree(ast[2], " "))
	table.insert(tokens, "]")
	return table.concat(tokens)
end

function get_table_str(ast)
	local tokens = {}
	table.insert(tokens, "{")
	for i=1, #ast do
		table.insert(tokens, parse_tree(ast[i], " "))
		if i < #ast then table.insert(tokens, ",") end
	end
	table.insert(tokens, "}")
	return table.concat(tokens, " ")
end

function get_pair_str(ast)
	local tokens = {}
	table.insert(tokens, "[")
	table.insert(tokens, parse_tree(ast[1], ""))
	table.insert(tokens, "]")
	table.insert(tokens, "=")
	table.insert(tokens, parse_tree(ast[2], ""))
	return table.concat(tokens, "")
end

function get_local_str(ast)
	local tokens = {"local"}
	table.insert(tokens, parse_tree(ast[1], ","))
	if #ast[2] > 0 then
		table.insert(tokens, "=")
		table.insert(tokens, parse_tree(ast[2], ","))
	end
	return "\n" .. table.concat(tokens, " ")
end

function get_return_str(ast)
	local tokens = {"\nreturn"}
	for i=1, #ast do
		table.insert(tokens, parse_tree(ast[i]))
		if i < #ast then table.insert(tokens, ",") end
	end
	return table.concat(tokens, " ")
end

function get_while_str(ast)
	local tokens = {"while"}
	table.insert(tokens, parse_tree(ast[1]))
	table.insert(tokens, "do")
	table.insert(tokens, parse_tree(ast[2]))
	table.insert(tokens, "\nend")
	return "\n" .. table.concat(tokens, " ")
end

function get_fornum_str(ast)
	local body_index, tokens = 4, {"for"}
	table.insert(tokens, parse_tree(ast[1]))
	table.insert(tokens, "=")
	table.insert(tokens, parse_tree(ast[2]))
	table.insert(tokens, ",")
	table.insert(tokens, parse_tree(ast[3]))
	if ast[4].tag == 'Number' then
		table.insert(tokens, ",")
		table.insert(tokens, parse_tree(ast[4]))
		body_index = 5
	end
	table.insert(tokens, "do")
	table.insert(tokens, parse_tree(ast[body_index]))
	table.insert(tokens, "\nend")
	return "\n" .. table.concat(tokens, " ")
end

function get_forin_str(ast)
	local tokens = {"for"}
	table.insert(tokens, parse_tree(ast[1], ","))
	table.insert(tokens, "in")
	table.insert(tokens, parse_tree(ast[2]))
	table.insert(tokens, "do")
	table.insert(tokens, parse_tree(ast[3]))
	table.insert(tokens, "\nend")
	return "\n" .. table.concat(tokens, " ")
end

function get_repeat_str(ast)
	local tokens = {"repeat"}
	table.insert(tokens, parse_tree(ast[1]))
	table.insert(tokens, "\nuntil")
	table.insert(tokens, parse_tree(ast[2]))
	return "\n" .. table.concat(tokens, " ") 
end

function get_do_str(ast)
	local tokens = {"do"}
	table.insert(tokens, parse_tree(ast[1]))
	table.insert(tokens, "\nend")
	return "\n" .. table.concat(tokens, " ")
end

function get_invoke_str(ast)
	local tokens = {}
	local ob = parse_tree(ast[1])
	table.insert(tokens, ob)
	table.insert(tokens, "[")
	table.insert(tokens, parse_tree(ast[2]))
	table.insert(tokens, "](")
	table.insert(tokens, ob)
	for i=3, #ast do
		table.insert(tokens, ",")
		table.insert(tokens, parse_tree(ast[i]))
	end
	table.insert(tokens, ")")
	return table.concat(tokens)
end


return {
	ast_from_string = ast_from_string_helper,
	ast_to_string = parse_tree,
}
