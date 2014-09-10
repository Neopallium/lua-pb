local d_pack = require'pb.standard.pack'
local d_unpack = require'pb.standard.unpack'
local bit = require'bit'

local zigzag = d_pack.zigzag64
local unzigzag = d_unpack.unzigzag64

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

local t = {}
for i=1,last - first do
	local n = i + first
	local n2 = unzigzag(zigzag(n))
	-- cache results to make sure LuaJIT doesn't optimize away the zigzag/unzigzag code.
	t[i] = n2
	if n ~= n2 then
		assert(n == n2, string.format('%d ~= %d: zigzag=%d', n, n2, d_pack.zigzag64(n)))
	end
end

