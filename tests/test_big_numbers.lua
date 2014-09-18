
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
print(utils.dump(data))

local function to_hex(n)
	if type(n) == 'number' then
		return string.format('%016X', n)
	end
	local l = #n
	if l == 8 then
		return string.format('%02X%02X%02X%02X%02X%02X%02X%02X', n:byte(1,8))
	end
	if l == 0 then return '00' end
	return string.format(('%02X'):rep(l), n:byte(1,l))
end

local function tonum(str)
	if type(str) == 'string' then
		local l = #str
		if l == 8 then
			return struct.unpack('>i8', str)
		end
		if l == 0 then return 0 end
		return struct.unpack('>I' .. tostring(l), str)
	end
	return str
end

local function extend_raw64(n)
	return ('\0'):rep(8 - #n) .. n
end

local function cmp_raw64(n1, n2)
	if n1 == n2 then return true end
	-- compare Lua number with raw64 value
	if type(n1) == 'number' then
		return n1 == tonum(n2)
	elseif type(n2) == 'number' then
		return tonum(n1) == n2
	end
	-- normalize the length of two raw64 values to compare them.
	return extend_raw64(n1) == extend_raw64(n2)
end

local function check_msg(msg)
	assert(msg ~= nil)
	for k,v in pairs(data) do
		local v1 = msg[k]
		print('--- check:', k, to_hex(v1), to_hex(v))
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

