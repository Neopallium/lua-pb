-- Copyright (c) 2010-2011 by Robert G. Jakabosky <bobby@neoawareness.com>
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
local pairs = pairs
local print = print
local error = error
local tostring = tostring
local setmetatable = setmetatable

local struct = require"struct"
local sunpack = struct.unpack

local bit = require"bit"
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local arshift = bit.arshift

local char = string.char

-- un-ZigZag encode/decode
local function unzigzag64(num)
	if band(num, 1) == 1 then
		num = -(num + 1)
	end
	return num / 2
end
local function unzigzag32(num)
	return bxor(arshift(num, 1), -band(num, 1))
end

module(...)

-- export un-ZigZag functions.
_M.unzigzag64 = unzigzag64
_M.unzigzag32 = unzigzag32

----------------------------------------------------------------------------------
--
--  Unpack code.
--
----------------------------------------------------------------------------------

local function unpack_varint64(data, off)
	local b = data:byte(off)
	local num = band(b, 0x7F)
	local boff = 7
	while b >= 128 do
		off = off + 1
		b = data:byte(off)
		num = bor(num, lshift(band(b, 0x7F), boff))
		boff = boff + 7
	end
	return num, off
end

local function unpack_varint32(data, off)
	local b = data:byte(off)
	local num = band(b, 0x7F)
	local boff = 7
	while b >= 128 do
		off = off + 1
		b = data:byte(off)
		num = bor(num, lshift(band(b, 0x7F), boff))
		boff = boff + 7
	end
	return num, off
end

_M.varint64 = unpack_varint64
_M.varint32 = unpack_varint32

function svarint64(data, off)
	local num
	num, off = unpack_varint64(data, off)
	return unzigzag64(num), off
end

function svarint32(data, off)
	local num
	num, off = unpack_varint32(data, off)
	return unzigzag32(num), off
end

function fixed64(data, off)
	return unpack('<I8', data, off), off + 8
end

function sfixed64(data, off)
	return unpack('<i8', data, off), off + 8
end

function double(data, off)
	return unpack('<d', data, off), off + 8
end

function fixed32(data, off)
	return unpack('<I4', data, off), off + 4
end

function sfixed32(data, off)
	return unpack('<i4', data, off), off + 4
end

function float(data, off)
	return unpack('<f', data, off), off + 4
end

function string(data, off)
	local len
	-- decode string length.
	len, off = unpack_varint32(data, off)
	-- decode string data.
	local end_off = off + len
	return data:sub(off, end_off - 1), end_off
end

function decode_field_tag(data, off)
	local tag
	tag, off = unpack_varint32(data, off)
	local field_num = rshift(tag, 3)
	local wire_type = band(tag, 7)
	return field_num, wire_type, off
end

--
-- Map field types to common wire types
--

-- map types.
local map_types = {
-- varints
int32  = "varint32",
uint32 = "varint32",
bool   = "varint32",
enum   = "varint32",
int64  = "varint64",
uint64 = "varint64",
sint32 = "svarint32",
sint64 = "svarint64",
-- bytes
bytes  = "string",
}
for k,v in pairs(map_types) do
	_M[k] = _M[v]
end

