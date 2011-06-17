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

local lp = require"lpeg"
local scanner = require"src.proto.scanner"
local grammar = require"src.proto.grammar"
local parser = require"src.proto.parser"

local Cap = grammar.C
local function CapNode(ntype, ...)
	local fields = {...}
	local fcount = #fields
	return function(...)
		local node = {ntype = ntype, ...}
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
[1] = grammar.Ct,
Package = CapNode("package"
),
Import = CapNode("import",
	"file"
),
Option = CapNode("option",
	"name", "value"
),
Message = CapNode("message",
	"name"
),
Group = CapNode("group",
	"rule", "name", "id"
),
Enum = CapNode("enum",
	"name"
),
EnumField = CapNode("enum_field",
	"name", "value"
),
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
Service = CapNode("service",
	"name"
),
rpc = CapNode("rpc"),

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

