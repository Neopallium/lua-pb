
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
local make_int64 = pb.get_make_int64_func()
for k,v in pairs(data) do
	if type(v) == 'string' then
		data[k] = make_int64(v:byte(1, 8))
	end
end

print(utils.dump(data))

local function to_hex(n)
	local t = type(n)
	if t ~= 'string' then
		if t == 'number' then
			return string.format('%016X', n)
		else
			return string.format('%08X%08X', tonumber(n / 0x100000000), tonumber(n % 0x100000000))
		end
	end
	local l = #n
	if l == 0 then return '0000000000000000' end
	n = (n:gsub('.', utils.hex))
	if l < 8 then
		n = ('00'):rep(8 - l) .. n
	end
	return n
end

local function cmp_raw64(n1, n2)
	if n1 == n2 then return true end
	if to_hex(n1) == to_hex(n2) then return true end
	return false
end

local function check_msg(msg)
	assert(msg ~= nil)
	for k,v in pairs(data) do
		local v1 = msg[k]
		print('--- check:', k, to_hex(v1), to_hex(v), type(v1), type(v))
		if not cmp_raw64(v1, v) then
			error(string.format("field '%s' differs: %s ~= %s",
				k, utils.dump(v1), utils.dump(v)))
		end
	end
end

local msg = BigNumbers1(data)

check_msg(msg)

pb.print(msg)

local bin = msg:Serialize()

print("--- encoded message: bytes", #bin)

local file = assert(io.open(arg[1] or 'big_nums.bin', 'w'))
assert(file:write(bin))
assert(file:close())

print("--- decode message")
local msg1, off = assert(BigNumbers1():Parse(bin))

check_msg(msg1)
print(utils.dump(msg1))
pb.print(msg1)

print("Valid .proto file")

