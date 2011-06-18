-- Copyright (c) 2010-2011 by Robert G. Jakabosky <bobby@neoawareness.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local lower = string.lower
local tremove = table.remove

local pack = string.match(...,"[a-zA-Z0-9.]*[.]") or ''

local lp = require"lpeg"
local scanner = require(pack .. "scanner")
local grammar = require(pack .. "grammar")
local parser = require(pack .. "parser")

-- create sub-table if it doesn't exists
local function create(tab, sub_tab)
	if not tab[sub_tab] then
		tab[sub_tab] = {}
	end
	return tab[sub_tab]
end

local Cap = function(...) return ... end
local function node_type(node)
	return node['.type']
end
local function make_node(node_type, node)
	node = node or {}
	node['.type'] = node_type
	return node
end
local function CapNode(ntype, ...)
	local fields = {...}
	local fcount = #fields
	return function(...)
		local node = make_node(ntype, {...})
		local idx = 0
		-- process named fields
		for i=1,fcount do
			local name = fields[i]
			local val = tremove(node, 1)
			node[name] = val
		end
		return node
	end
end

local captures = {
[1] = function(...)
	local proto = {
		types = {},
		...
	}
	for i=1,#proto do
		local sub = proto[i]
		local sub_type = node_type(sub)
		proto[i] = nil
		if sub_type == 'option' then
			create(proto, 'options')
			proto.options[sub.name] = sub.value
		elseif sub_type == 'package' then
			proto.package = sub.name
		elseif sub_type == 'import' then
			create(proto, 'imports')
			proto.imports[sub.name] = sub.value
		elseif sub_type == 'service' then
			create(proto, 'services')
			proto.services[sub.name] = sub
		else
			-- map 'name' -> type
			proto.types[sub.name] = sub
		end
	end
	return proto
end,
Package = CapNode("package",
	"name"
),
Import = CapNode("import",
	"file"
),
Option = CapNode("option",
	"name", "value"
),
Message = function(name, body)
	local node = make_node('message', body)
	node.name = name
	return node
end,
MessageBody = function(...)
	local body = {
		fields = {},
		...
	}
	local fcount = 0
	for i=1,#body do
		-- remove sub-node
		local sub = body[i]
		local sub_type = node_type(sub)
		body[i] = nil
		if sub_type == 'field' then
			-- map 'name' -> field
			body.fields[sub.name] = sub
			-- map order -> field
			fcount = fcount + 1
			body.fields[fcount] = sub
		elseif sub_type == 'extensions' then
			local list = create(body, 'extensions')
			local idx = #list
			-- append extensions
			for i=1,#sub do
				local range = sub[i]
				idx = idx + 1
				list[idx] = range
			end
		else
			create(body, 'types')
			-- map 'name' -> sub-type
			body.types[sub.name] = sub
		end
	end
	return body
end,
Group = function(rule, name, id, body)
	local group_ftype = 'group_' .. name
	local group = make_node('group', body)
	group.name = group_ftype
	local field = make_node('field')
	field.rule = rule
	field.ftype = group_ftype
	field.name = name
	field.id = id
	return group, field
end,
Enum = function(name, ...)
	local node = make_node('enum', {...})
	local options
	local values = {}
	node.name = name
	node.values = values
	for i=1,#node do
		-- remove next sub-node.
		local sub = node[i]
		local sub_type = node_type(sub)
		node[i] = nil
		-- option/enum_field
		if sub_type == 'option' then
			if not options then
				options = {} -- Enum has options
			end
			options[sub.name] = sub.value
		else
			-- map 'name' -> value
			values[sub[1]] = sub[2]
			-- map value -> 'name'
			values[sub[2]] = sub[1]
		end
	end
	node.options = options
	return node
end,
EnumField = function(...)
	return {...}
end,
Field = CapNode("field",
	"rule", "ftype", "name", "id", "options"
),
FieldOptions = function(...)
	local options = {...}
	for i=1,#options,2 do
		-- remove next option from list
		local name = options[i]
		options[i] = nil
		local value = options[i+1]
		options[i+1] = nil
		-- set option.
		options[name] = value
	end
	return options
end,
Extensions = CapNode("extensions"
),
Extension = function(first, last)
	if not last then
		-- single value.
		return first
	end
	-- range
	return {first, last}
end,
Service = CapNode("service",
	"name"
),
rpc = CapNode("rpc",
	"name", "request", "response"
),

Name = Cap,
GroupName = Cap,
ID = Cap,
Constant = Cap,
IntLit = tonumber,
SNumLit = tonumber,
StrLit = function(quoted)
	assert(quoted:sub(1,1) == '"')
	return quoted:sub(2,-2)
end,
BoolLit = function(bool)
	bool = lower(bool)
	return (bool == 'true')
end,
FieldRule = Cap,
Type = Cap,
}

local ast_patt = lp.P(parser.apply({}, captures)) * (scanner.EOF + scanner.error"invalid character")

module(...)

function parse(contents)
	return ast_patt:match(contents)
end

