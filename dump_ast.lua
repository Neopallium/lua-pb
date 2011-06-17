
local lp = require"lpeg"
local scanner = require"src.proto.scanner"
local grammar = require"src.proto.grammar"
local parser = require"src.proto.parser"

local utils = require"utils"

-- read .proto file.
local f = assert(io.open(arg[1]))
local contents = f:read("*a")
f:close()

local function Cnode(ntype)
	return function(name, ...)
print("create:", ntype)
		local node = { name = name, ...}
		node.ntype = ntype
		return node
	end
end

local captures = {
[1] = grammar.Ct,
Package = Cnode"root",
Import = function(file)
	return { ntype = 'import', file = file }
end,
Option = function(name, value)
	return { ntype = 'option', name = name, value = value }
end,
Message = Cnode"message",
Group = Cnode"group",
Field = Cnode"field",
Service = Cnode"service",
rpc = Cnode"rpc",

Name = grammar.C,
ID = grammar.C,
Constant = grammar.C,
}

local rules = {
--[1] = lp.V'Message',
}

local patt = lp.P(parser.apply(rules, captures))

--patt = (patt + scanner.ANY)^0
-- parse tokens.
local ast = assert(patt:match(contents))

print(utils.dump(ast))

print("Valid .proto file")

