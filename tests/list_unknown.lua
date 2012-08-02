
local pb = require"pb"

if #arg < 1 then
	print("Usage: " .. arg[0] .. " <raw protobuf encoded message>")
	return
end

local f = assert(io.open(arg[1]))
local bin = assert(f:read('*a'))
assert(f:close())

local msg, off = pb.decode_raw(bin)

local function dump_fields(unknown)
	for i,v in ipairs(unknown) do
		print(i, v.tag, v.wire, v.value)
		if type(v.value) == 'table' then
			dump_fields(v.value)
		end
	end
end
dump_fields(msg.unknown_fields)

pb.print(msg)

