-- Copyright (c) 2010-2014 by Robert G. Jakabosky <bobby@neoawareness.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local assert = assert
local print = print
local type = type

local mod_path = string.match(...,".*%.") or ''

local struct = require"struct"
local sunpack = struct.unpack
local spack = struct.pack

local bit = require"bit"
local band = bit.band
local bxor = bit.bxor
local lshift = bit.lshift
local arshift = bit.arshift

-- ZigZag encode
local zigzag64

local fmts = {
	'>I1', '>I2', '>I3',
	'>I4', '>I5', '>I6',
}
local function zigzag_raw64(num)
	local len = #num
	if len < 8 then
		if len <= 6 then
			if len == 0 then return 0 end
			-- small enough to use Lua numbers.
			return zigzag64(sunpack(fmts[len], num))
		end
		-- make sure string is 8 bytes long.
		num = '\0' .. num
	end
	local h,l = sunpack('>i4i4', num)
	h = h * 2
	if l < 0 then
		h = h + 0x01
	end
	l = l * 2
	if h < 0 then
		h = 0xFFFFFFFF - h
		l = 0xFFFFFFFF - l
	end
	return spack('>i4i4', h, l)
end

function zigzag64(num)
	if type(num) == 'string' then
		return zigzag_raw64(num)
	end
	num = num * 2
	if num < 0 then
		num = (-num) - 1
	end
	return num
end
local function zigzag32(num)
	return bxor(lshift(num, 1), arshift(num, 31))
end

-- ZigZag decode
local unzigzag64

local function unzigzag_raw64(num)
	local len = #num
	if len < 8 then
		if len <= 6 then
			-- small enough to use Lua numbers.
			return unzigzag64(sunpack(fmts[len], num))
		end
		-- make sure string is 8 bytes long.
		num = '\0' .. num
	end
	local h,l = sunpack('>I4I4', num)
	if l % 2 == 1 then
		if l == 0xFFFFFFFF then
			h = h + 1
			l = 0
		end
		l = 0xFFFFFFFF - l
		if h == 0 then
			-- sign extend
			h = -1
		else
			h = -h
		end
	end
	l = l / 2
	if h % 2 == 1 then
		l = l + 0x80000000
	end
	if h ~= -1 then
		h = h / 2
	end
	return spack('>i4i4', h, l)
end

function unzigzag64(num)
	if type(num) == 'string' then
		return unzigzag_raw64(num)
	end
	if num % 2 == 1 then
		num = -(num + 1)
	end
	return num / 2
end
local function unzigzag32(num)
	return bxor(arshift(num, 1), -band(num, 1))
end

module(...)

_M.zigzag64 = zigzag64
_M.zigzag32 = zigzag32

_M.unzigzag64 = unzigzag64
_M.unzigzag32 = unzigzag32

