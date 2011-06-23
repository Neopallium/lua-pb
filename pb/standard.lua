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
local tostring = tostring

local mod_path = ...

local fpack = require(mod_path .. ".pack")
local encode_field_tag = fpack.encode_field_tag
local funpack = require(mod_path .. ".unpack")
local pack_msg = fpack.message
local unpack_msg = funpack.message

local buffer = require(mod_path .. ".buffer")
local new_buffer = buffer.new

local unknown = require(mod_path .. ".unknown")
local new_unknown = unknown.new

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

local define_types

local function resolve_type(node, name)
	-- check current node for type.
	local _type = node[name]
	if _type then
		return _type
	end
	-- check parent.
	local parent = node['.parent']
	if parent then
		return resolve_type(parent, name)
	end
	return nil
end

local function compile_fields(node, fields)
	-- create 'tag_type' -> field map
	local tags = {}
	node.tags = tags

	for i=1,#fields do
		local field = fields[i]
		-- repated fields
		field.is_repeated = (field.rule == 'repeated')
		field.has_length = field.is_packed
		-- get field wire_type
		local tag = field.tag
		local ftype = field.ftype
		local wire_type = wire_types[ftype]
		if not wire_type then
			-- message or group type.
				-- resolve type
			local user_type = resolve_type(node, ftype)
			field.user_type = user_type
			field.user_type_mt = user_type['.mt']
			-- get pack/unpack functions
			field.pack = user_type['.pack']
			field.unpack = user_type['.unpack']
			-- get new function
			field.new = user_type['.new']
			if field.is_group then
				wire_type = wire_types.group_start
				field.end_tag = encode_field_tag(tag, wire_types.group_end)
			elseif user_type.is_enum then
				wire_type = wire_types.enum
				if field.is_packed then
					-- packed enum
					field.pack = fpack.packed.enum
					field.unpack = funpack.packed.enum
				end
			else
				wire_type = wire_types.message
				field.has_length = true
			end
		elseif field.is_packed then
			-- packed basic type
			field.pack = fpack.packed[ftype]
			field.unpack = funpack.packed[ftype]
		else
			-- basic type
			field.pack = fpack[ftype]
			field.unpack = funpack[ftype]
		end
		-- create field tag_type.
		local tag_type = encode_field_tag(tag, wire_type)
		field.tag_type = tag_type
		field.wire_type = wire_type
		-- map field 'tag_type' -> field, for faster field decoding
		tags[tag_type] = field
	end
end

local function compile_types(parent, types)
	for i=1,#types do
		local ast = types[i]
		-- check if AST node has fields.
		local fields = ast.fields
		if fields then
			compile_fields(parent[ast.name], fields)
		end
		-- compile sub-types
		local types = ast.types
		if types then
			compile_types(parent, types)
		end
	end
end

local function new_msg(mt, data)
	data = data or {}
	local fields = mt.fields
	-- look for sub-messages
	for i=1,#fields do
		local field = fields[i]
		local name = field.name
		local field_mt = field.user_type_mt
		if field_mt then
			local value = data[name]
			if value then
				if field.is_repeated then
					for i=1,#value do
						value[i] = new_msg(field_mt, value[i])
					end
				else
					data[name] = new_msg(field_mt, value)
				end
			end
		end
	end
	return setmetatable({ ['.data'] = data}, mt)
end

local function define_message(parent, name, ast, is_group)
	local fields = ast.fields
	local methods = {}

	-- create Metatable for Message.
	local mt = { name = name, is_group = is_group,
	fields = fields,
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
		-- TODO: validate field.
		data[name] = value
	end,
	__tostring = function(msg)
		local data = msg['.data'] -- field data.
		local str = tostring(data)
		return str:gsub('table', name)
	end,
	}

	-- define public interface.
	local node = setmetatable({
	['.mt'] = mt,
	-- Message info.
	['.parent'] = parent,
	['.name'] = name,
	-- Message constructor.
	['.new'] = function(data)
		return new_msg(mt, data)
	end,
	},{
	-- make the 'node' table callable as a Message contructor.
	__call = function(tab, data)
		return new_msg(mt, data)
	end,
	})

	-- Typpe pack/unpack functions.
	if is_group then
		local pack = fpack.group
		local unpack = funpack.group
		-- encode group end tag.
		local end_tag = encode_field_tag(ast.tag, wire_types.group_end)
		-- group pack/unpack
		node['.pack'] = function(buf, off, len, msg)
			return pack(buf, off, len, msg, fields, end_tag)
		end
		node['.unpack'] = function(data, off, len, msg)
			if not msg then
				msg = new_msg(mt)
			end
			return unpack(data, off, len, msg, fields, end_tag)
		end
	else
		local pack = fpack.message
		local unpack = funpack.message
		-- message pack/unpack
			-- top-level message pack/unpack functions
		methods['.encode'] = function(msg)
			return encode_msg(msg, fields)
		end
		methods['.decode'] = function(msg, data, off)
			return decode_msg(msg, data, off or 1, fields)
		end
			-- field pack/unpack functions
		node['.pack'] = function(buf, off, len, msg)
			return pack(buf, off, len, msg, fields)
		end
		node['.unpack'] = function(data, off, len, msg)
			if not msg then
				msg = new_msg(mt)
			end
			return unpack(data, off, len, msg, fields)
		end
	end

	-- process sub-types
	define_types(node, ast.types)
	-- add to parent.
	parent[name] = node
	return node
end

local function define_enum(parent, name, node)
	local values = node.values

	-- mark as an Enum
	node.is_enum = true

	local pack = fpack.enum
	local unpack = funpack.enum
	-- field pack/unpack functions
	node['.pack'] = function(buf, off, len, enum)
		return pack(buf, off, len, values[enum])
	end
	node['.unpack'] = function(data, off, len)
		local enum
		enum, off = unpack(data, off, len)
		return values[enum], off
	end

	-- add to parent.
	parent[name] = node
	return node
end

function define_types(parent, types)
	if not types then return end
	for i=1,#types do
		local ast = types[i]
		local name = ast.name
		local node_type = ast['.type']
		if node_type == 'message' then
			define_message(parent, name, ast, false)
		elseif node_type == 'group' then
			define_message(parent, name, ast, true)
		elseif node_type == 'enum' then
			define_enum(parent, name, ast)
		else
			error("No define function for:", node_type)
		end
	end
end

module(...)

function compile(ast)
	local proto = {}
	-- phaze one: define types.
	define_types(proto, ast.types)
	-- phaze two: compile/resolve fields.
	compile_types(proto, ast.types)
	return proto
end

