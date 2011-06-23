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
local function zigzag32(num)
	return bxor(lshift(num, 1), arshift(num, 31))
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
_M.zigzag32 = zigzag32

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

function varint64(buf, off, len, num)
	return append(buf, off, len, pack_varint64(num))
end
function varint32(buf, off, len, num)
	return append(buf, off, len, pack_varint32(num))
end

function svarint64(buf, off, len, num)
	return append(buf, off, len, pack_varint64(zigzag64(num)))
end

function svarint32(buf, off, len, num)
	return append(buf, off, len, pack_varint32(zigzag32(num)))
end

function fixed64(buf, off, len, num)
	return append(buf, off, len, spack('<I8', num))
end

function sfixed64(buf, off, len, num)
	return append(buf, off, len, spack('<i8', num))
end

function double(buf, off, len, num)
	return append(buf, off, len, spack('<d', num))
end

function fixed32(buf, off, len, num)
	return append(buf, off, len, spack('<I4', num))
end

function sfixed32(buf, off, len, num)
	return append(buf, off, len, spack('<i4', num))
end

function float(buf, off, len, num)
	return append(buf, off, len, spack('<f', num))
end

function string(buf, off, len, str)
	off = off + 1
	local len_data = pack_varint32(#str)
	buf[off] = len_data
	off = off + 1
	buf[off] = str
	return off, len + #len_data + #str
end

--
-- packed repeated fields
--
packed = setmetatable({},{
__index = function(tab, ftype)
	local fpack
	if type(ftype) == 'string' then
		-- basic type
		fpack = _M[ftype]
	else
		-- complex type (Enums)
		fpack = ftype
	end
	rawset(tag, ftype, function(buf, off, len, arr)
		for i=1, #arr do
			off, len = fpack(buf, off, len, arr[i])
		end
		return off, len
	end)
end,
})

function encode_field_tag(tag, wire_type)
	local tag_type = (tag * 8) + wire_type
	return pack_varint32(tag_type)
end

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

function group(buf, off, len, msg, fields, end_tag)
	local total = 0
	local len
	-- Pack group fields.
	off, len = pack_fields(buf, off, len, msg, fields)
	-- Group end tag
	off, len = append(buf, off, len, end_tag)
end

function message(buf, off, len, msg, fields)
	-- Pack message fields.
	return pack_fields(buf, off, len, msg, fields)
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

