-- Copyright (c) 2010, Robert G. Jakabosky <bobby@sharedrealm.com> All rights reserved.

local error = error
local assert = assert
local tostring = tostring
local setmetatable = setmetatable

local mod_path = string.match(...,".*%.") or ''

local fpack = require(mod_path .. "pack")
local encode_field_tag = fpack.encode_field_tag
local funpack = require(mod_path .. "unpack")
local pack_msg = fpack.message
local unpack_msg = funpack.message

local fdump = require(mod_path .. "dump")

local buffer = require(mod_path .. "buffer")
local new_buffer = buffer.new

local unknown = require(mod_path .. "unknown")
local new_unknown = unknown.new

local mod_parent_path = mod_path:match("(.*%.)[^.]*%.")
local utils = require(mod_parent_path .. "utils")
local copy = utils.copy

local _M = {}

local wire_types = {
-- Varint types
int32 = 0, int64 = 0,
uint32 = 0, uint64 = 0,
sint32 = 0, sint64 = 0,
bool = 0, enum = 0,
-- 64-bit fixed
fixed64 = 1, sfixed64 = 1, double = 1,
-- Length-delimited
string = 2, bytes = 2,
message = 2, packed = 2,
-- Group (deprecated)
group = 3, group_start = 3,
group_end = 4,
-- 32-bit fixed
fixed32 = 5, sfixed32 = 5, float = 5,
}

local function encode_msg(msg, fields)
	local buf = new_buffer()

	local off, len = pack_msg(buf, 0, 0, msg, fields)

	local data = buf:pack(1, off, true)
	buf:release()
	assert(len == #data,
		"Invalid packed length.  This shouldn't happen, there is a bug in the message packing code.")
	return data
end

local function decode_msg(msg, data, off, fields)
	return unpack_msg(data, off, #data, msg, fields)
end

local function dump_msg(msg, fields, depth)
	local buf = new_buffer()

	local off = fdump.message(buf, 0, msg, fields, depth or 0)

	local data = buf:pack(1, off, true)
	buf:release()
	return data
end

local function new_message(mt, data)
	local msg = setmetatable({ ['.data'] = {}}, mt)
	if not data then return msg end

	-- copy data into message
	local fields = mt.fields
	for i=1,#fields do
		local field = fields[i]
		local name = field.name
		local value = data[name]
		if value then
			msg[name] = value
		end
	end
	return msg
end
_M.new = new_message

function _M.def(parent, name, ast)
	local methods = {}
	local fields = copy(ast.fields)
	local tags = {}

	-- create Metatable for Message/Group.
	local is_group = (ast['.type'] == 'group')
	local mt = {
	name = name,
	is_group = is_group,
	fields = fields,
	methods = methods,
	tags = tags,
	extensions = copy(ast.extensions),
	__index = function(msg, name)
		local data = msg['.data'] -- field data.
		-- get field value.
		local value = data[name]
		-- field is already set, just return the value
		if value then return value end
		-- check field for a default value.
		local field = fields[name] -- field info.
		if field then return field.default end
		-- check methods
		local method = methods[name]
		if method then return method end
		-- check for unknown field.
		if name == 'unknown_fields' then
			-- create Unknown field set object
			value = new_unknown()
			data.unknown_fields = value
			return value
		end
		error("Invalid field:" .. name)
	end,
	__newindex = function(msg, name, value)
		local data = msg['.data'] -- field data.
		-- get field info.
		local field = fields[name]
		if not field then error("Invalid field:" .. name) end
		-- check if field is a message/group
		local new = field.new
		if new then
			if field.is_repeated then
				for i=1,#value do
					value[i] = new(value[i])
				end
			else
				value = new(value)
			end
		end
		data[name] = value
	end,
	__tostring = function(msg)
		local data = msg['.data'] -- field data.
		local str = tostring(data)
		return str:gsub('table', name)
	end,
	-- hid this metatable.
	__metatable = false,
	}
	-- create message contructor
	local function new_msg(data)
		return new_message(mt, data)
	end
	mt.new = new_msg

	-- process fields
	for i=1,#fields do
		local field = fields[i]
		-- field rule to 'is_<rule>' mapping.
		field['is_' .. field.rule] = true
		-- get field wire_type
		local ftype = field.ftype
		local wire_type = wire_types[ftype]
		if not wire_type then
			-- field is a user type, it needs to be resolved.
			field.need_resolve = true
		else
			-- basic type
			field.is_basic = true
		end
	end

	-- Type pack/unpack functions.
	if is_group then
		local pack = fpack.group
		local unpack = funpack.group
		local dump = fdump.group
		-- encode group end tag.
		local end_tag = encode_field_tag(ast.tag, wire_types.group_end)
		-- group pack/unpack
		mt.pack = function(buf, off, len, msg)
			return pack(buf, off, len, msg, fields, end_tag)
		end
		mt.unpack = function(data, off, len, msg)
			if not msg then
				msg = new_msg(mt)
			end
			return unpack(data, off, len, msg, tags, end_tag)
		end
		mt.dump = function(buf, off, msg, depth)
			return dump(buf, off, msg, fields, depth)
		end
	else
		local pack = fpack.message
		local unpack = funpack.message
		local dump = fdump.message
		-- message pack/unpack/dump
			-- top-level message pack/unpack/dump functions
		methods.Serialize = function(msg, format, depth)
			if format == 'text' then
				return dump_msg(msg, fields, depth)
			else
				return encode_msg(msg, fields)
			end
		end
		methods.Parse = function(msg, data, off)
			return decode_msg(msg, data, off or 1, tags)
		end
			-- field pack/unpack/dump functions
		mt.pack = function(buf, off, len, msg)
			return pack(buf, off, len, msg, fields)
		end
		mt.unpack = function(data, off, len, msg)
			if not msg then
				msg = new_msg(mt)
			end
			return unpack(data, off, len, msg, tags)
		end
		mt.dump = function(buf, off, msg, depth)
			return dump(buf, off, msg, fields, depth)
		end
	end

	return mt
end

function _M.compile(node, mt, fields)
	local tags = mt.tags
	for i=1,#fields do
		local field = fields[i]
		-- packed arrays have a length
		field.has_length = field.is_packed
		-- get field tag & wire_type
		local tag = field.tag
		local ftype = field.ftype
		local wire_type = wire_types[ftype]
		-- check if the field is a user type
		local user_type = field.user_type
		local user_type_mt = field.user_type_mt
		if user_type then
			-- message or group type.
			local _type = user_type['.type']
			-- get pack/unpack functions
			field.pack = user_type_mt.pack
			field.unpack = user_type_mt.unpack
			field.dump = user_type_mt.dump
			-- get new function from metatable.
			field.new = user_type_mt.new
			if field.is_group then
				wire_type = wire_types.group_start
				field.end_tag = encode_field_tag(tag, wire_types.group_end)
			elseif _type == 'enum' then
				field.is_enum = true
				wire_type = wire_types.enum
				if field.is_packed then
					-- packed enum
					field.pack = fpack.packed[field.pack]
					field.unpack = funpack.packed[field.unpack]
				end
			else
				wire_type = wire_types.message
				field.has_length = true
				field.is_message = true
			end
		elseif field.is_packed then
			-- packed basic type
			field.is_basic = true
			field.pack = fpack.packed[ftype]
			field.unpack = funpack.packed[ftype]
		else
			-- basic type
			field.is_basic = true
			field.pack = fpack[ftype]
			field.unpack = funpack[ftype]
		end
		-- create field tag_type.
		local tag_type = encode_field_tag(tag, wire_type)
		field.tag_type = tag_type
		field.wire_type = wire_type
		-- map field 'tag_type' -> field, for faster field decoding
		tags[tag_type] = field
		tags[tag] = field
	end
end

return _M
