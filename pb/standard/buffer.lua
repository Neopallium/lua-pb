-- Copyright (c) 2010, Robert G. Jakabosky <bobby@sharedrealm.com> All rights reserved.

local concat = table.concat
local setmetatable = setmetatable

local mt = {}
mt.__index = mt

function mt:pack(off, end_off, clear)
	off = off or 1
	end_off = end_off or #self
	local data = concat(self, '', off, end_off)

	if clear then
		for i=off, end_off do
			self[i] = nil
		end
	end

	return data
end

function mt:truncate(off)
	for i=off or 1, #self do
		self[i] = nil
	end
end

local cache
function mt:release()
	-- don't cache large buffers.
	if #self < (32 * 1024) then
		-- clear buffer
		self:truncate(1)
		-- cheap buffer pool
		cache = self
	end
end

module(...)

function new()
	if cache then
		local self = cache
		cache = nil
		return self
	end
	return setmetatable({}, mt)
end

