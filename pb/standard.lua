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
local type = type
local sformat = string.format
local tsort = table.sort

local mod_path = ...

local fpack = require(mod_path .. ".pack")
local encode_field_tag = fpack.encode_field_tag
local funpack = require(mod_path .. ".unpack")
local pack_msg = fpack.message
local unpack_msg = funpack.message

local fdump = require(mod_path .. ".dump")

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

local function dump_msg(msg, fields, depth)
	local buf = new_buffer()

	local off = fdump.message(buf, 0, msg, fields, depth or 0)

	local data = buf:pack(1, off, true)
	buf:release()
	return data
end

local define_types

-- get root node
local function get_root(node)
	local parent = node['.parent']
	if parent then
		return get_root(parent)
	end
	-- found root.
	return node
end

-- search a node for a type with 'name'.
local function find_type(node, name)
	local _type
	-- check full name
	_type = node[name]
	if _type then return _type end
	-- check multi-level names (i.e. "OuterMessage.InnerMessage")
	for part in name:gmatch("([^.]+)") do
		_type = node[part]
		if not _type then
			-- part not found, abort search
			return nil
		end
		-- found part, now check it for the next part
		node = _type
	end
	return _type
end

local function check_package_prefix(node, name)
	-- check for package prefix.
	local package = node['.package']
	if package then
		package = package .. '.'
		local plen = #package
		if name:sub(1, plen) == package then
			-- matches, trim package prefix from name.
			return true, name:sub(plen + 1)
		end
		-- name is not in package.
		return false, name
	end
	-- no package prefix.
	return false, name
end

local function resolve_type_internal(node, name, skip_node)
	-- check current node for type.
	local _type = find_type(node, name)
	if _type ~= skip_node then return _type end
	-- check parent.
	local parent = node['.parent']
	if parent then
		return resolve_type_internal(parent, name, skip_node)
	else
		-- no more parents, at root node.
		-- check if 'name' has the current package prefixed.
		local prefixed, sub_name = check_package_prefix(node, name)
		if prefixed then
			-- search for sub-type
			return resolve_type_internal(node, sub_name, skip_node)
		end
		-- type not in current package, check imports.
		local imports = node['.imports']
		-- at root node, now check imports.
		if imports then
			for i=1,#imports do
				local import = imports[i].proto
				-- search each import
				_type = resolve_type_internal(imports[i].proto, name, skip_node)
				if _type then return _type end
			end
		end
	end
	return nil
end

local function resolve_type(node, name, skip_node)
	-- check for absolute type name.
	if name:sub(1,1) == '.' then
		name = name:sub(2) -- trim '.' from start.
		-- skip to root node.
		node = get_root(node)
	end
	return resolve_type_internal(node, name, skip_node)
end

local function compile_fields(node, fields, tags)
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
			field.dump = user_type['.dump']
			-- get new function
			field.new = user_type['.new']
			if field.is_group then
				wire_type = wire_types.group_start
				field.end_tag = encode_field_tag(tag, wire_types.group_end)
			elseif user_type.is_enum then
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

local function compile_types(parent, types)
	for i=1,#types do
		local ast = types[i]
		local node = parent[ast.name]
		-- check if AST node has fields.
		local fields = ast.fields
		if fields then
			compile_fields(node, fields, ast.tags)
		end
		-- compile sub-types
		local types = ast.types
		if types then
			compile_types(node, types)
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
	local tags = {}
	ast.tags = tags

	-- create Metatable for Message.
	local mt = { name = name, is_group = is_group,
	fields = fields,
	tags = tags,
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
	['.type'] = ast['.type'],
	['.parent'] = parent,
	['.name'] = name,
	['.fields'] = fields,
	['.extensions'] = ast.extensions,
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
		local dump = fdump.group
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
			return unpack(data, off, len, msg, tags, end_tag)
		end
		node['.dump'] = function(buf, off, msg, depth)
			return dump(buf, off, msg, fields, depth)
		end
	else
		local pack = fpack.message
		local unpack = funpack.message
		local dump = fdump.message
		-- message pack/unpack/dump
			-- top-level message pack/unpack/dump functions
		methods['.encode'] = function(msg)
			return encode_msg(msg, fields)
		end
		methods['.decode'] = function(msg, data, off)
			return decode_msg(msg, data, off or 1, tags)
		end
		methods['.dump'] = function(msg, depth)
			return dump_msg(msg, fields, depth)
		end
			-- field pack/unpack/dump functions
		node['.pack'] = function(buf, off, len, msg)
			return pack(buf, off, len, msg, fields)
		end
		node['.unpack'] = function(data, off, len, msg)
			if not msg then
				msg = new_msg(mt)
			end
			return unpack(data, off, len, msg, tags)
		end
		node['.dump'] = function(buf, off, msg, depth)
			return dump(buf, off, msg, fields, depth)
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
	local dump = fdump.enum
	-- field pack/unpack/dump functions
	node['.pack'] = function(buf, off, len, enum)
		return pack(buf, off, len, values[enum])
	end
	node['.unpack'] = function(data, off, len)
		local enum
		enum, off = unpack(data, off, len)
		return values[enum], off
	end
	node['.dump'] = function(buf, off, enum, depth)
		return dump(buf, off, enum, depth)
	end

	-- add to parent.
	parent[name] = node
	return node
end

local function check_extension(extensions, tag)
	for i=1,#extensions do
		local extension = extensions[i]
		if type(extension) == 'number' then
			-- check single extension value.
			if extension == tag then return true end
		else
			-- check range
			local first, last = extension[1], extension[2]
			if first <= tag and tag <= last then return true end
		end
	end
	return false
end

-- field tag sort function.
local function sort_tags(f1, f2)
	return f1.tag < f2.tag
end

local function define_extend(parent, name, ast)
	-- find extended message
	local message = resolve_type(parent, name)
	-- validate extend
	assert(message, "Can't find extended 'message' " .. name)
	assert(message['.type'] == 'message', "Only 'message' types can be extended.")
	-- make sure the extended fields exists as extensions in the extended message.
	local extensions = message['.extensions']
	assert(extensions, "Extended 'message' type has no extensions, can't extend it.")
	local fields = ast.fields
	-- check that each extend field is an extension in the extended message.
	for i=1,#fields do
		local field = fields[i]
		if not check_extension(extensions, field.tag) then
			-- invalid extension
			error(sformat("Missing extension for field '%s' in extend '%s'", field.name, name))
		end
	end

	local extend = define_message(parent, name, ast, false)
	local m_mt = message['.mt']
	local mt = extend['.mt']
	-- copy fields from extended message.
	local m_fields = m_mt.fields
	local fields = mt.fields
	local fcount = #fields
	for i=1,#m_fields do
		local field = m_fields[i]
		local name = field.name
		fcount = fcount + 1
		fields[fcount] = field
		fields[name] = field
	end
	tsort(fields, sort_tags)

	local m_tags = m_mt.tags
	local tags = mt.tags
	for i=1,#m_tags do
		local field = m_tags[i]
		tags[field.tag] = field
		tags[field.tag_type] = field
	end

	return extend
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
		elseif node_type == 'extend' then
			define_extend(parent, name, ast)
		elseif node_type == 'enum' then
			define_enum(parent, name, ast)
		else
			error("No define function for:", node_type)
		end
	end
end

module(...)

function compile(ast)
	local proto = {
		['.package'] = ast.package,
		['.imports'] = ast.imports,
	}
	-- phaze one: define types.
	define_types(proto, ast.types)
	-- phaze two: compile/resolve fields.
	compile_types(proto, ast.types)
	return proto
end

