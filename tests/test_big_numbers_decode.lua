
local pb = require"pb"

local utils = require"utils"

-- load .proto file.
local big_nums = require"protos.big_numbers"

local BigNumbers1 = big_nums.BigNumbers1

local data = {
	field1 = "\127\255\255\255\255\255\255\255",
	field2 = "\127\255\255\255\255\255\255\255",
	field3 = "\127\255\255\255\255\255\255\255",
	field4 = "\127\255\255\255\255\255\255\255",
	field5 = "\127\255\255\255\255\255\255\255",
	field6 = 9876543210.9876543210,
}
local cdata = {
	field1 = "9223372036854775807ULL",
	field2 = "9223372036854775807ULL",
	field3 = "9223372036854775807ULL",
	field4 = "9223372036854775807ULL",
	field5 = "9223372036854775807ULL",
}
-- detect LuaJIT 2.x
if jit then
	local ffi = require'ffi'
	if ffi then
		-- load cdata.
		for field,val in pairs(cdata) do
			data[field] = loadstring("return 9223372036854775807ULL")()
		end
	end
end

print(utils.dump(data))

local function check_msg(msg)
	assert(msg ~= nil)
	for k,v in pairs(data) do
		print('--- check:', k, msg[k])
		assert(msg[k] == v)
	end
end

local file = assert(io.open(arg[1] or 'big_nums.bin', 'r'))
local bin = assert(file:read('*a'))
assert(file:close())

print("--- decode message")
local msg1, off = assert(BigNumbers1():Parse(bin))

print(utils.dump(msg1))
pb.print(msg1)
check_msg(msg1)

print("Valid .proto file")

