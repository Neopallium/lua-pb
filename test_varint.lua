local tconcat = table.concat

local data = require'pb.lua.data'
local bit = require'bit'
local utils = require"utils"

local pack = data.pack
local unpack = data.unpack

local function encode(_type, data)
	local buf = {}
	local off = pack[_type](buf, 0, 0, data)
	return tconcat(buf, '', 1, off)
end

local function decode(_type, data, off)
	return unpack[_type](data, off or 1)
end

local _type = arg[1] or 'varint32'
local first = arg[2] or -10
local last = arg[3] or 100

utils.hex_print(encode(_type, 150))
utils.hex_print(encode(_type, 300))

print(string.format("test range(%d <=> %d)", first, last))

local function test(_type)
	for n=first,last do
		local tmp = encode(_type, n)
		utils.hex_print(tmp)
		local n2, offset = decode(_type, tmp, 1)
		if n ~= n2 or offset ~= #tmp then
			utils.hex_print(tmp)
			assert(n == n2, string.format('%d ~= %d', n, n2))
		end
	end
end

test(_type)

