
local pb = require"pb"
local decode_msg = pb.decode
local encode_msg = pb.encode

if #arg < 2 then
	print("Usage: " .. arg[0] .. " <input file> <output file>")
	return
end

local f = assert(io.open(arg[1]))
local bin = assert(f:read('*a'))
assert(f:close())

local msg, off = decode_msg(nil, bin)

pb.print(msg)

bin, len = encode_msg(msg)

local f = assert(io.open(arg[2], 'w'))
assert(f:write(bin))
assert(f:close())

