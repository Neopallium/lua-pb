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
local sformat = string.format
local type = type
local pcall = pcall
local rawset = rawset

local mod_path = ...

local unknown = require(mod_path:gsub('(%.[-_%w]*)$','') .. ".unknown")
local new_unknown = unknown.new

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
	return num, off + 1
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
	return num, off + 1
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
	return sunpack('<I8', data, off)
end

function sfixed64(data, off)
	return sunpack('<i8', data, off)
end

function double(data, off)
	return sunpack('<d', data, off)
end

function fixed32(data, off)
	return sunpack('<I4', data, off)
end

function sfixed32(data, off)
	return sunpack('<i4', data, off)
end

function float(data, off)
	return sunpack('<f', data, off)
end

function string(data, off)
	local len
	-- decode string length.
	len, off = unpack_varint32(data, off)
	-- decode string data.
	local end_off = off + len
	return data:sub(off, end_off - 1), end_off
end

local function decode_field_tag(data, off)
	local tag_type
	tag_type, off = unpack_varint32(data, off)
	local tag = rshift(tag_type, 3)
	local wire_type = band(tag_type, 7)
	return tag, wire_type, off
end

--
-- WireType unpack functions for unknown fields.
--
local unpack_unknown_field

local function try_unpack_unknown_message(data, off, len)
	local tag, wire_type, val
	-- create new list of unknown fields.
	local msg = new_unknown()
	-- unpack fields for unknown message
	while (off <= len) do
		-- decode field tag & wire_type
		tag, wire_type, off = decode_field_tag(data, off)
		-- unpack field
		val, off = unpack_unknown_field(data, off, len, tag, wire_type, msg)
	end
	-- validate message
	if (off - 1) ~= len then
		error(sformat("Malformed Message, truncated ((off:%d) - 1) ~= len:%d): %s",
			off, len, tostring(msg)))
	end
	return msg, off
end

local wire_unpack = {
[0] = function(data, off, len, tag, unknowns)
	local val
	-- unpack varint
	val, off = unpack_varint32(data, off)
	-- add to list of unknown fields
	unknowns:addField(tag, 0, val)
	return val, off
end,
[1] = function(data, off, len, tag, unknowns)
	local val
	-- unpack 64-bit field
	val, off = fixed64(data, off)
	-- add to list of unknown fields
	unknowns:addField(tag, 1, val)
	return val, off
end,
[2] = function(data, off, len, tag, unknowns)
	local len, end_off, val
	-- decode data length.
	len, off = unpack_varint32(data, off)
	end_off = off + len
	-- try to decode as a message
	local status
	status, val = pcall(try_unpack_unknown_message, data, off, end_off - 1)
	if not status then
		-- failed to decode as a message
		-- decode as raw data.
		val = data:sub(off, end_off - 1)
	end
	-- add to list of unknown fields
	unknowns:addField(tag, 2, val)
	return val, end_off
end,
[3] = function(data, off, len, group_tag, unknowns)
	local tag, wire_type, val
	-- add to list of unknown fields
	local group = unknowns:addGroup(group_tag)
	-- unpack fields for unknown group.
	while (off <= len) do
		-- decode field tag & wire_type
		tag, wire_type, off = decode_field_tag(data, off)
		-- check for 'End group' tag
		if wire_type == 4 then
			if tag ~= group_tag then
				error("Malformed Group, invalid 'End group' tag")
			end
			return group, off
		end
		-- unpack field
		val, off = unpack_unknown_field(data, off, len, tag, wire_type, group)
	end
	error("Malformed Group, missing 'End group' tag")
end,
[4] = nil,
[5] = function(data, off, len, tag, unknowns)
	local val
	-- unpack 32-bit field
	val, off = fixed32(data, off)
	-- add to list of unknown fields
	unknowns:addField(tag, 5, val)
	return val, off
end,
}

function unpack_unknown_field(data, off, len, tag, wire_type, unknowns)
	local funpack = wire_unpack[wire_type]
	if funpack then
		return funpack(data, off, len, tag, unknowns)
	end
	error(sformat("Invalid wire_type=%d, for unknown field=%d, off=%d, len=%d",
		wire_type, tag, off, len))
end

--
-- packed repeated fields
--
packed = setmetatable({},{
__index = function(tab, ftype)
	local funpack
	if type(ftype) == 'string' then
		-- basic type
		funpack = _M[ftype]
	else
		-- complex type (Enums)
		funpack = ftype
	end
	rawset(tab, ftype, function(data, off, len, arr)
		local i=#arr
		while (off <= len) do
			i = i + 1
			arr[i], off = funpack(data, off, len, nil)
		end
		return arr, off
	end)
end,
})

local unpack_field
local unpack_fields

local function unpack_length_field(data, off, len, field, val)
	-- decode field length.
	local field_len
	field_len, off  = unpack_varint32(data, off, len)

	-- unpack field
	return field.unpack(data, off, off + field_len - 1, val)
end

local function unpack_field(data, off, len, field, mdata)
	local name = field.name
	local val

	if field.is_repeated then
		local arr = mdata[name]
		-- create array for repeated fields.
		if not arr then
			arr = {}
			mdata[name] = arr
		end
		if field.is_packed then
			-- unpack length-delimited packed array
			return unpack_length_field(data, off, len, field, arr)
		end
		-- unpack repeated field (just one)
		if field.has_length then
			-- unpack length-delimited field.
			arr[#arr + 1], off = unpack_length_field(data, off, len, field, nil)
		else
			arr[#arr + 1], off = field.unpack(data, off, len)
		end
		return arr, off
	elseif field.has_length then
		-- unpack length-delimited field
		val, off = unpack_length_field(data, off, len, field, mdata[name])
		mdata[name] = val
		return val, off
	end
	-- is basic type.
	val, off = field.unpack(data, off, len)
	mdata[name] = val
	return val, off
end

local function unpack_fields(data, off, len, msg, fields, is_group)
	local tag, wire_type, field, val
	local mdata = msg['.data']
	local unknowns

	while (off <= len) do
		-- decode field tag & wire_type
		tag, wire_type, off = decode_field_tag(data, off)
		-- check for "End group"
		if wire_type == 4 then
			if not is_group then
				error("Malformed Message, found extra 'End group' tag: " .. tostring(msg))
			end
			return msg, off
		end
		field = fields[tag]
		if field then
			if field.wire_type ~= wire_type then
				error(sformat("Malformed Message, wire_type of field doesn't match (%d ~= %d!",
					field.wire_type, wire_type))
			end
			val, off = unpack_field(data, off, len, field, mdata)
		else
			if not unknowns then
				-- check if Message already has Unknown fields object.
				unknowns = mdata.unknown_fields
				if not unknowns then
					-- need to create an Unknown fields object.
					unknowns = new_unknown()
					mdata.unknown_fields = unknowns
				end
			end
			-- unpack Unknown field
			val, off = unpack_unknown_field(data, off, len, tag, wire_type, unknowns)
		end
	end
	-- Groups should not end here.
	if is_group then
		error("Malformed Group, truncated, missing 'End group' tag: " .. tostring(msg))
	end
	-- validate message
	if (off - 1) ~= len then
		error(sformat("Malformed Message, truncated ((off:%d) - 1) ~= len:%d): %s",
			off, len, tostring(msg)))
	end
	return msg, off
end

function group(data, off, len, msg, fields, end_tag)
	-- Unpack group fields.
	msg, off = unpack_fields(data, off, len, msg, fields, true)
	-- validate 'End group' tag
	if data:sub(off - #end_tag, off) ~= end_tag then
		error("Malformed Group, invalid 'End group' tag: " .. tostring(msg))
	end
	return msg, off
end

function message(data, off, len, msg, fields)
	-- Unpack message fields.
	return unpack_fields(data, off, len, msg, fields, false)
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

