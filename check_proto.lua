
local lp = require"lpeg"
local parser = require"pb.proto.parser"

-- read .proto file.
local f = assert(io.open(arg[1]))
local contents = f:read("*a")
f:close()

-- parse tokens.
assert(parser.check(contents))

print("Valid .proto file")

