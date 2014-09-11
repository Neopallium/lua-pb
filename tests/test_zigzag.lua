local d_zigzag = require'pb.standard.zigzag'
local struct = require'struct'

local zigzag = d_zigzag.zigzag64
local unzigzag = d_zigzag.unzigzag64

local first = tonumber(arg[1] or -10000000)
local last = tonumber(arg[2] or 10000000)
local bits = tonumber(arg[3] or 64)

if first > last then
	first, last = last, first
end

if bits == 32 then
	zigzag = d_pack.zigzag32
	unzigzag = d_unpack.unzigzag32
else
	bits = 64
end

print(string.format("test range(0x%016X <=> 0x%016X) bits=%d", first, last, bits))
print(string.format('--- count=%d', last - first))

local function tostr(num)
	if type(num) == 'number' then
		return struct.pack('>i8', num)
	end
	return num
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

local function to_hex(n)
	if type(n) == 'number' then
		return string.format('%016X', n)
	end
	local l = #n
	--return n:gsub('.', function(b) return string.format('%02X', b) end)
	if l == 8 then
		return string.format('%02X%02X%02X%02X%02X%02X%02X%02X', n:byte(1,8))
	end
	if l == 0 then return '00' end
	return string.format(('%02X'):rep(l), n:byte(1,l))
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

local function test_zigzag(n)
	local z2 = zigzag(n)
	local n2 = unzigzag(z2)
	--print(string.format('n1 = 0x%s, n2 = 0x%s, z=0x%s', to_hex(n), to_hex(n2), to_hex(z2)))
	if not cmp_raw64(n, n2) then
		assert(n == n2, string.format('0x%s ~= 0x%s: zigzag=0x%s', to_hex(n), to_hex(n2), to_hex(z2)))
	end
end

local special_cases = {
	0,
	1, 2, 3,
	-1, -2, -3,
	0x0FFFFFFFC,
	0x0FFFFFFFD,
	0x0FFFFFFFE,
	0x0FFFFFFFF,
	0x100000000,
	0x100000001,
	0x100000002,
	0x100000003,
	0x1FFFFFFFFFFFFA,
	0x1FFFFFFFFFFFFB,
	0x1FFFFFFFFFFFFC,
	0x1FFFFFFFFFFFFD,
	0x1FFFFFFFFFFFFE,
	0x1FFFFFFFFFFFFF,
	-- large 64bit integers encoded as strings.
	"\255\255\255\255\255\255\255\251",
	"\255\255\255\255\255\255\255\252",
	"\255\255\255\255\255\255\255\253",
	"\255\255\255\255\255\255\255\254",
	"\255\255\255\255\255\255\255\255",
	-- shorter integers.
	"\255\255\255\255\255\255\255", -- 7 bytes
	"\255\255\255\255\255\255", -- 6 bytes
	"\255\255\255\255\255", -- 5 bytes
	"\255\255\255\255", -- 4 bytes
	"\255\255\255", -- 3 bytes
	"\255\255", -- 2 bytes
	"\255", -- 1 byte
	"", -- 0 bytes
}

for i=1,#special_cases do
	local n = special_cases[i]
	if type(n) == 'number' then
		print(string.format('--------------- test num=0x%016X', n))
	else
		print(string.format('--------------- test str(%d)=0x%s', #n, to_hex(n)))
	end
	test_zigzag(n)
end

if true then
	local t = {}
	for i=1,last - first do
		local n = i + first
		-- cache results to make sure LuaJIT doesn't optimize away the zigzag/unzigzag code.
		t[i] = test_zigzag(n)
	end
end

