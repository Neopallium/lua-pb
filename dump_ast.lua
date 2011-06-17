
local ast = require"pb.proto.ast"

local utils = require"utils"

-- read .proto file.
local f = assert(io.open(arg[1]))
local contents = f:read("*a")
f:close()

-- parse .proto to AST
local ast = ast.parse(contents)

print(utils.dump(ast))

print("Valid .proto file")

