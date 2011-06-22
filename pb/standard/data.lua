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
local spack = struct.pack

local bit = require"bit"
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift
local arshift = bit.arshift

local char = string.char

-- ZigZag encode/decode
local function zigzag64(num)
	num = num * 2
	if num < 0 then
		num = (-num) - 1
	end
	return num
end
local function unzigzag64(num)
	if band(num, 1) == 1 then
		num = -(num + 1)
	end
	return num / 2
end
local function zigzag32(num)
	return bxor(lshift(num, 1), arshift(num, 31))
end
local function unzigzag32(num)
	return bxor(arshift(num, 1), -band(num, 1))
end

local function varint_next_byte(num)
	if num >= 0 and num < 128 then return num end
	local b = bor(band(num, 0x7F), 0x80)
	return (b), varint_next_byte(rshift(num, 7))
end

local function append(buf, off, len, data)
	off = off + 1
	buf[off] = data
	return off, len + #data
end

module(...)

-- export ZigZag functions.
_M.zigzag64 = zigzag64
_M.unzigzag64 = unzigzag64
_M.zigzag32 = zigzag32
_M.unzigzag32 = unzigzag32

----------------------------------------------------------------------------------
--
--  Pack code.
--
----------------------------------------------------------------------------------

local function pack_varint64(num)
	return char(varint_next_byte(num))
end

local function pack_varint32(num)
	return char(varint_next_byte(num))
end

pack = {
varint64 = function(buf, off, len, num)
	return append(buf, off, len, pack_varint64(num))
end,
varint32 = function(buf, off, len, num)
	return append(buf, off, len, pack_varint32(num))
end,

svarint64 = function(buf, off, len, num)
	return append(buf, off, len, pack_varint64(zigzag64(num)))
end,

svarint32 = function(buf, off, len, num)
	return append(buf, off, len, pack_varint32(zigzag32(num)))
end,

fixed64 = function(buf, off, len, num)
	return append(buf, off, len, pack('<I8', num))
end,

sfixed64 = function(buf, off, len, num)
	return append(buf, off, len, pack('<i8', num))
end,

double = function(buf, off, len, num)
	return append(buf, off, len, pack('<d', num))
end,

fixed32 = function(buf, off, len, num)
	return append(buf, off, len, pack('<I4', num))
end,

sfixed32 = function(buf, off, len, num)
	return append(buf, off, len, pack('<i4', num))
end,

float = function(buf, off, len, num)
	return append(buf, off, len, pack('<f', num))
end,

string = function(buf, off, len, str)
	off = off + 1
	local len_data = pack_varint32(#str)
	buf[off] = len_data
	off = off + 1
	buf[off] = str
	return off, len + #len_data + #str
end,
}

--
-- packed repeated fields
--
local packed = setmetatable({},{
__index = function(tab, ftype)
	local fpack = pack[ftype]
	rawset(tag, ftype, function(buf, off, len, arr)
		for i=1, #arr do
			off, len = fpack(buf, off, len, arr[i])
		end
		return off, len
	end)
end,
})

function encode_field_tag(field_num, wire_type)
	local tag = (field_num * 8) + wire_type
	return pack_varint32(tag)
end

local pack_field
local pack_fields

local function pack_length_field(buf, off, len, field, val)
	local pack = field.pack
	local field_len = 0
	local len_off

	-- pack field tag.
	off, len = append(buf, off, len, field.tag_type)

	-- reserve space for field length
	off = off + 1
	len_off = off
	buf[off] = '' -- place holder
	-- pack field
	off, field_len = pack(buf, off, 0, val)

	-- encode field length.
	local len_data = pack_varint32(field_len)
	buf[len_off] = len_data

	return off, len + field_len + #len_data
end

local function pack_repeated(buf, off, len, field, arr)
	local pack = field.pack
	local tag = field.tag_type
	if field.has_length then
		for i=1, #arr do
			-- pack length-delimited field
			off, len = pack_length_field(buf, off, len, field, arr[i])
		end
	else
		for i=1, #arr do
			-- pack field tag.
			off, len = append(buf, off, len, tag)

			-- pack field value.
			off, len = pack(buf, off, len, arr[i])
		end
	end
	return off, len
end

local function pack_fields(buf, off, len, msg, fields)
	local data = msg['.data']
	for i=1,#fields do
		local field = fields[i]
		local val = data[field.name]
		if val then
			if val ~= field.default then
				if field.is_repeated then
					if field.is_packed then
						-- pack length-delimited field
						off, len = pack_length_field(buf, off, len, field, val)
					else
						-- pack repeated field
						off, len = pack_repeated(buf, off, len, field, val)
					end
				elseif field.has_length then
					-- pack length-delimited field
					off, len = pack_length_field(buf, off, len, field, val)
				else -- is basic type.
					-- pack field tag.
					off, len = append(buf, off, len, field.tag_type)
			
					-- pack field
					off, len = field.pack(buf, off, len, val)
				end
			end
		else
			if field.rule == 'required' then
				error("Missing required field in " .. tostring(msg))
			end
		end
	end
	return off, len
end

function pack.group(buf, off, len, msg, fields, end_tag)
	local total = 0
	local len
	-- Pack group fields.
	off, len = pack_fields(buf, off, len, msg, fields)
	-- Group end tag
	off, len = append(buf, off, len, end_tag)
end

function pack.message(buf, off, len, msg, fields)
	-- Pack message fields.
	return pack_fields(buf, off, len, msg, fields)
end

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

unpack = {
varint64 = unpack_varint64,
varint32 = unpack_varint32,

svarint64 = function(data, off)
	local num
	num, off = unpack_varint64(data, off)
	return unzigzag64(num), off
end,

svarint32 = function(data, off)
	local num
	num, off = unpack_varint32(data, off)
	return unzigzag32(num), off
end,

fixed64 = function(data, off)
	return unpack('<I8', data, off), off + 8
end,

sfixed64 = function(data, off)
	return unpack('<i8', data, off), off + 8
end,

double = function(data, off)
	return unpack('<d', data, off), off + 8
end,

fixed32 = function(data, off)
	return unpack('<I4', data, off), off + 4
end,

sfixed32 = function(data, off)
	return unpack('<i4', data, off), off + 4
end,

float = function(data, off)
	return unpack('<f', data, off), off + 4
end,

string = function(data, off)
	local len
	-- decode string length.
	len, off = unpack_varint32(data, off)
	-- decode string data.
	local end_off = off + len
	return data:sub(off, end_off - 1), end_off
end,
}

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
	pack[k] = pack[v]
	unpack[k] = unpack[v]
end

