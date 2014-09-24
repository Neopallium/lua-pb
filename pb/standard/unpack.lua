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
local pairs = pairs
local print = print
local error = error
local tostring = tostring
local setmetatable = setmetatable
local sformat = string.format
local char = string.char
local type = type
local pcall = pcall
local rawset = rawset
local floor = math.floor

local mod_path = string.match(...,".*%.") or ''

local unknown = require(mod_path .. "unknown")
local new_unknown = unknown.new

local zigzag = require(mod_path .. "zigzag")
local unzigzag64 = zigzag.unzigzag64
local unzigzag32 = zigzag.unzigzag32

local pack = require(mod_path .. "pack")
local encode_field_tag = pack.encode_field_tag
local wire_types = pack.wire_types

local struct = require"struct"
local sunpack = struct.unpack

local bit = require"bit"
local band = bit.band
local rshift = bit.rshift

module(...)

----------------------------------------------------------------------------------
--
--  Unpack code.
--
----------------------------------------------------------------------------------

local make_int64 = char

local LNumMaxOff = 128 ^ 6
local function unpack_varint64_raw(num, data, off, signed)
	-- encode first 48bits
	b1 = band(num, 0xFF)
	num = floor(num / 256)
	b2 = band(num, 0xFF)
	num = floor(num / 256)
	b3 = band(num, 0xFF)
	num = floor(num / 256)
	b4 = band(num, 0xFF)
	num = floor(num / 256)
	b5 = band(num, 0xFF)
	num = floor(num / 256)
	b6 = band(num, 0xFF)
	num = floor(num / 256)

	local b = data:byte(off)
	local boff = 2 -- still one bit in 'num'
	num = num + (band(b, 0x7F) * boff)
	while b >= 128 do
		boff = boff * 128
		off = off + 1
		b = data:byte(off)
		num = num + (band(b, 0x7F) * boff)
	end
	-- encode last 16bits
	b7 = band(num, 0xFF)
	num = floor(num / 256)
	b8 = band(num, 0xFF)

	return make_int64(b8,b7,b6,b5,b4,b3,b2,b1, signed), off + 1
end

local function unpack_varint64(data, off, signed)
	local b = data:byte(off)
	local num = band(b, 0x7F)
	local boff = 128
	while b >= 128 do
		off = off + 1
		b = data:byte(off)
		if boff > LNumMaxOff and b > 0x1F then
			return unpack_varint64_raw(num, data, off, signed)
		end
		num = num + (band(b, 0x7F) * boff)
		boff = boff * 128
	end
	return num, off + 1
end

local function unpack_varint32(data, off)
	local b = data:byte(off)
	local num = band(b, 0x7F)
	local boff = 128
	while b >= 128 do
		off = off + 1
		b = data:byte(off)
		num = num + (band(b, 0x7F) * boff)
		boff = boff * 128
	end
	return num, off + 1
end

local basic = {
varint64 = function(data, off)
	return unpack_varint64(data, off, true)
end,
varuint64 = function(data, off)
	return unpack_varint64(data, off, false)
end,

varint32 = unpack_varint32,
varuint32 = unpack_varint32,

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
	-- check if the top 12 bits are zero.
	if data:byte(off + 7) == 0 and data:byte(off + 6) <= 0x1F then
		return sunpack('<I8', data, off)
	end
	-- read Little-endian
	local b1,b2,b3,b4,b5,b6,b7,b8 = data:byte(off, off + 7)
	-- convert to Big-endian
	return make_int64(b8,b7,b6,b5,b4,b3,b2,b1, false), off + 8
end,

sfixed64 = function(data, off)
	-- check if the top 12 bits are zero.
	if data:byte(off + 7) == 0 and data:byte(off + 6) <= 0x1F then
		return sunpack('<i8', data, off)
	end
	-- read Little-endian
	local b1,b2,b3,b4,b5,b6,b7,b8 = data:byte(off, off + 7)
	-- convert to Big-endian
	return make_int64(b8,b7,b6,b5,b4,b3,b2,b1, true), off + 8
end,

double = function(data, off)
	return sunpack('<d', data, off)
end,

fixed32 = function(data, off)
	return sunpack('<I4', data, off)
end,

sfixed32 = function(data, off)
	return sunpack('<i4', data, off)
end,

float = function(data, off)
	return sunpack('<f', data, off)
end,

string = function(data, off, len)
	-- decode string data.
	return data:sub(off, len), len + 1
end,
}

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

local fixed64 = basic.fixed64
local fixed32 = basic.fixed32
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
	if len > 1 then
		status, val = pcall(try_unpack_unknown_message, data, off, end_off - 1)
	end
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
-- unpacked field
--
local function unpack_field(data, off, len, field, mdata, wire_type)
	local name = field.name
	local val
	local field_len = len
	local funpack = field.unpack

	-- check if wiretype is length-delimited
	if wire_type == 2 then
		-- decode field length.
		field_len, off  = unpack_varint32(data, off, len)
		-- change field length to offset.
		field_len = off + field_len - 1
		-- make sure field length is less then message length.
		if field_len > len then
			error(sformat("Malformed Field, truncated field_len:%d ~= len:%d): %s",
				field_len, len, field.name))
		end
	end

	if field.is_repeated then
		local arr = mdata[name]
		-- create array for repeated fields.
		if not arr then
			arr = field.new()
			mdata[name] = arr
		end
		-- check if repeated field was packed encoded.
		if wire_type == 2 and field.wire_type ~= 2 then
			-- unpack length-delimited packed array
			local i=#arr
			while (off <= field_len) do
				i = i + 1
				arr[i], off = funpack(data, off, field_len)
			end
			return arr, off
		end
		-- unpack repeated field (just one)
		arr[#arr + 1], off = funpack(data, off, field_len)
		return arr, off
	end
	-- non-repeated field
	if field.wire_type ~= wire_type then
		error(sformat("Malformed Message, wire_type of field doesn't match (%d ~= %d)!",
			field.wire_type, wire_type))
	end
	-- unpack field value.
	val, off = funpack(data, off, field_len)
	mdata[name] = val
	return val, off
end

local function unpack_fields(data, off, len, msg, tags, is_group)
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
		field = tags[tag]
		if field then
			val, off = unpack_field(data, off, len, field, mdata, wire_type)
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

local function group(data, off, len, msg, tags, end_tag)
	-- Unpack group fields.
	msg, off = unpack_fields(data, off, len, msg, tags, true)
	-- validate 'End group' tag
	if data:sub(off - #end_tag, off - 1) ~= end_tag then
		error("Malformed Group, invalid 'End group' tag: " .. tostring(msg))
	end
	return msg, off
end

local function message(data, off, len, msg, tags)
	-- Unpack message fields.
	return unpack_fields(data, off, len, msg, tags, false)
end

--
-- Map field types to common wire types
--

-- map types.
local map_types = {
-- varints
int32  = "varint32",
uint32 = "varuint32",
bool   = "varint32",
enum   = "varint32",
int64  = "varint64",
uint64 = "varuint64",
sint32 = "svarint32",
sint64 = "svarint64",
-- bytes
bytes  = "string",
}
for k,v in pairs(map_types) do
	basic[k] = basic[v]
end

local register_fields

local function get_type_unpack(mt)
	local unpack = mt.unpack
	-- check if this type has a unpack function.
	if not unpack then
		-- create a unpack function for this type.
		if mt.is_enum then
			local unpack_enum = basic.enum
			local values = mt.values
			unpack = function(data, off, len, enum)
				local enum
				enum, off = unpack_enum(data, off, len)
				return values[enum], off
			end
		elseif mt.is_message then
			local tags = mt.tags
			local new = mt.new
			unpack = function(data, off, len, msg)
				if not msg then
					msg = new()
				end
				return message(data, off, len, msg, tags)
			end
			register_fields(mt)
		elseif mt.is_group then
			local tags = mt.tags
			local new = mt.new
			-- encode group end tag.
			local end_tag = encode_field_tag(mt.tag, wire_types.group_end)
			unpack = function(data, off, len, msg)
				if not msg then
					msg = new()
				end
				return group(data, off, len, msg, tags, end_tag)
			end
			register_fields(mt)
		end
		-- cache unpack function.
		mt.unpack = unpack
	end
	return unpack
end

function register_fields(mt)
	-- check if the fields where already registered.
	if mt.unpack then return end
	local tags = mt.tags
	local fields = mt.fields
	for i=1,#fields do
		local field = fields[i]
		local tag = field.tag
		local ftype = field.ftype
		local wire_type = wire_types[ftype]
		-- check if the field is a user type
		local user_type_mt = field.user_type_mt
		if user_type_mt then
			field.unpack = get_type_unpack(user_type_mt)
			if field.is_group then
				wire_type = wire_types.group_start
			elseif user_type_mt.is_enum then
				wire_type = wire_types.enum
			else
				wire_type = wire_types.message
			end
		else
			field.unpack = basic[ftype]
		end
		-- create field tag_type.
		local tag_type = encode_field_tag(tag, wire_type)
		field.tag_type = tag_type
		field.wire_type = wire_type
	end
end

function register_msg(mt)
	local tags = mt.tags
	-- setup 'unpack' function for this message type.
	get_type_unpack(mt)
	-- create decode callback closure for this message type.
	return function(msg, data, off)
		return message(data, off, #data, msg, tags)
	end
end

function set_make_int64(func)
	make_int64 = func
end

