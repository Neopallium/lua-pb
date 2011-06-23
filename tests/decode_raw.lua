
local pb = require"pb"
local decode_msg = pb.decode

local utils = require"utils"

local f = assert(io.open(arg[1]))
local bin = assert(f:read('*a'))
assert(f:close())

print("--- decode raw message")
local msg, off = decode_msg(nil, bin)

print(utils.dump(msg))

print("--- decoded raw message:", msg, off, #bin)

