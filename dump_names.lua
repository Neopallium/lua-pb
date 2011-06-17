
local lp = require"lpeg"
local scanner = require"pb.proto.scanner"
local grammar = require"pb.proto.grammar"
local parser = require"pb.proto.parser"

-- read .proto file.
local f = assert(io.open(arg[1]))
local contents = f:read("*a")
f:close()

local captures = {
Package = function(name, ...) print("Package:", name, ...); return name; end,
Message = function(name, ...) print("Message:", name, ...); return name; end,
Name = grammar.C,
ID = grammar.C,
}

local rules = {
--[1] = lp.V'Message',
}

local patt = lp.P(parser.apply(rules, captures))

--patt = (patt + scanner.ANY)^0
-- parse tokens.
assert(patt:match(contents))

print("Valid .proto file")

