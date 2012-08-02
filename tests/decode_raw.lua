
local pb = require"pb"

if #arg < 1 then
	print("Usage: " .. arg[0] .. " <raw protobuf encoded message>")
	return
end

local f = assert(io.open(arg[1]))
local bin = assert(f:read('*a'))
assert(f:close())

local msg, off = pb.decode_raw(bin)

pb.print(msg)

