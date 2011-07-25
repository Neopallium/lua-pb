-- Copyright (c) 2010, Robert G. Jakabosky <bobby@sharedrealm.com> All rights reserved.

local concat = table.concat
local setmetatable = setmetatable

local repeated_tag = {}
local function new_message_repeated(field)
	local new = field.new
	local mt = {
	field = field,
	[repeated_tag] = field,
	__newindex = function(self, idx, value)
		rawset(self, idx, new(value))
	end,
	}
	mt.__index = mt
	setmetatable(mt,{
	__call = function(mt, data)
		-- check if data is already a repeated object of the right type.
		if data and data[repeated_tag] == field then return data end
		-- create new repeated object
		local self = setmetatable({}, mt)
		-- return now if data is nil
		if not data then return self end
		-- copy data to new repeated object.
		for i=1,#data do
			self[i] = new(data[i])
		end
		return self
	end
	})

	function mt:add(val)
		val = val or new()
		self[#self + 1] = val
		return val
	end

	return mt
end

local function new_basic_repeated(field)
	local mt = {
	field = field,
	[repeated_tag] = field,
	}
	mt.__index = mt
	setmetatable(mt,{
	__call = function(mt, data)
		-- check if data is already a repeated object of the right type.
		if data and data[repeated_tag] == field then return data end
		-- create new repeated object
		local self = setmetatable({}, mt)
		-- return now if data is nil
		if not data then return self end
		-- copy data to new repeated object.
		for i=1,#data do
			self[i] = data[i]
		end
		return self
	end
	})

	function mt:add(val)
		self[#self + 1] = val
		return val
	end

	return mt
end

module(...)

function new(field)
	if field.is_message then
		return new_message_repeated(field)
	elseif field.is_group then
		return new_message_repeated(field)
	end
	return new_basic_repeated(field)
end

