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

local function append(buf, off, data)
	off = off + 1
	buf[off] = data
	return off
end

local function indent(buf, off, depth)
	return append(buf, off, ('  '):rep(depth))
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
	return append(buf, off, sformat("%q", val))
end
function bytes(buf, off, val)
	-- TODO: convert to hex: FF FF FF FF....
	return append(buf, off, sformat("%q", val))
end
-- 32-bit fixed
function fixed32(buf, off, val)
	return append(buf, off, sformat("%u", val))
end
function sfixed32(buf, off, val)
	return append(buf, off, sformat("%d", val))
end
function float(buf, off, val)
	return append(buf, off, tostring(val))
end

local dump_fields

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

