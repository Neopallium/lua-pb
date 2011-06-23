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
local type = type
local sformat = string.format
local char = string.char

local function append(buf, off, data)
	off = off + 1
	buf[off] = data
	return off
end

local function indent(buf, off, depth)
	return append(buf, off, ('  '):rep(depth))
end

--
-- Safe strings
--
local escapes = {}
for i=0,255 do
	escapes[char(i)] = sformat('\\%03o', i)
end
escapes['"'] = '\\"'
escapes["'"] = "\\'"
escapes["\\"] = "\\\\"
escapes["\r"] = "\\r"
escapes["\n"] = "\\n"
escapes["\t"] = "\\t"
-- safe chars
local safe = [=[`~!@#$%^&*()_-+={}[]|:;<>,.?/]=]
for i=1,#safe do
	local c = safe:sub(i,i)
	escapes[c] = c
end
local function safe_string(data)
	return data:gsub([[([^%w ])]], escapes)
end

module(...)

----------------------------------------------------------------------------------
--
--  dump code.
--
----------------------------------------------------------------------------------

-- varint types
function int32(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function int64(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function sint32(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function sint64(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function uint32(buf, off, val)
	return append(buf, off, sformat("%u", val))
end
function uint64(buf, off, val)
	return append(buf, off, sformat("%u", val))
end
function bool(buf, off, val)
	return append(buf, off, (val == 0) and "false" or "true")
end
function enum(buf, off, val)
	return append(buf, off, val)
end
-- 64-bit fixed
function fixed64(buf, off, val)
	return append(buf, off, sformat("%u", val))
end
function sfixed64(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function double(buf, off, val)
	return append(buf, off, tostring(val))
end
-- Length-delimited
function string(buf, off, val)
	off = append(buf, off, '"')
	off = append(buf, off, safe_string(val))
	return append(buf, off, '"')
end
function bytes(buf, off, val)
	off = append(buf, off, '"')
	off = append(buf, off, safe_string(val))
	return append(buf, off, '"')
end
-- 32-bit fixed
function fixed32(buf, off, val)
	return append(buf, off, sformat("%u", val))
end
function sfixed32(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function float(buf, off, val)
	return append(buf, off, sformat("%.8g", val))
end

local dump_fields
local dump_unknown_fields

local wire_types = {
[0] = function(buf, off, val, depth)
	return append(buf, off, sformat(": %u", val))
end,
[1] = function(buf, off, val, depth)
	return append(buf, off, sformat(": 0x%016x", val))
end,
[2] = function(buf, off, val, depth)
	if type(val) == 'table' then
		off = append(buf, off, " {\n")
		off = dump_unknown_fields(buf, off, val, depth + 1)
		off = indent(buf, off, depth)
		return append(buf, off, "}")
	end
	off = append(buf, off, ': "')
	off = append(buf, off, safe_string(val))
	return append(buf, off, '"')
end,
[3] = function(buf, off, val, depth)
	off = append(buf, off, " {\n")
	off = dump_unknown_fields(buf, off, val, depth + 1)
	off = indent(buf, off, depth)
	return append(buf, off, "}")
end,
[4] = nil, -- End group
[5] = function(buf, off, val, depth)
	return append(buf, off, sformat(": 0x%08x", val))
end,
}

local function dump_field(buf, off, field, val, depth)
	-- indent
	off = indent(buf, off, depth)
	-- dump field name
	off = append(buf, off, field.name)

	-- dump field
	local dump = field.dump
	if dump then
		if field.is_enum then
			off = append(buf, off, ": ")
			off = dump(buf, off, val)
		else
			off = append(buf, off, " {\n")
			off = dump(buf, off, val, depth + 1)
			off = indent(buf, off, depth)
			off = append(buf, off, "}")
		end
	else
		dump = _M[field.ftype]
		off = append(buf, off, ": ")
		off = dump(buf, off, val)
	end
	-- newline
	off = append(buf, off, "\n")
	return off
end

local function dump_repeated(buf, off, field, arr, depth)
	for i=1, #arr do
		off = dump_field(buf, off, field, arr[i], depth)
	end
	return off
end

function dump_unknown_fields(buf, off, unknowns, depth)
	for i=1,#unknowns do
		local field = unknowns[i]
		-- indent
		off = indent(buf, off, depth)
		-- dump field name
		off = append(buf, off, tostring(field.tag))
		-- dump field
		local dump = wire_types[field.wire]
		if not dump then
			error("Invalid unknown field wire_type=" .. tostring(field.wire))
		end
		off = dump(buf, off, field.value, depth)
		-- newline
		off = append(buf, off, "\n")
	end
	return off
end

local function dump_fields(buf, off, msg, fields, depth)
	local data = msg['.data']
	for i=1,#fields do
		local field = fields[i]
		local val = data[field.name]
		if val then
			if field.is_repeated then
				-- dump repeated field
				off = dump_repeated(buf, off, field, val, depth)
			else -- is basic type.
				off = dump_field(buf, off, field, val, depth)
			end
		end
	end
	-- dump unknown fields
	local unknowns = data.unknown_fields
	if unknowns then
		return dump_unknown_fields(buf, off, unknowns, depth)
	end

	return off
end

function group(buf, off, msg, fields, depth)
	-- dump group fields.
	return dump_fields(buf, off, msg, fields, depth)
end

function message(buf, off, msg, fields, depth)
	-- dump message fields.
	return dump_fields(buf, off, msg, fields, depth)
end

