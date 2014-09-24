-- sudo luarocks install lpeg
-- sudo luarocks install struct

inspect = require 'spec.inspect'
telescope = require 'telescope'

local function compare_tables(t1, t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  for k1,v1 in pairs(t1) do
  local v2 = t2[k1]
  if v2 == nil or not compare_tables(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
  local v1 = t1[k2]
  if v1 == nil or not compare_tables(v1,v2) then return false end
  end
  return true
end

telescope.make_assertion("tables", function(_, a, b)
  return "Expected table to be " .. inspect(b) .. ", but was " .. inspect(a)
end, function(a, b)
  return compare_tables(a, b)
end)

telescope.make_assertion("length", function(_, a, b)
	if not a then return "Expected table but got nil" end
  return "Expected table length to be " .. b .. ", but was " .. #a
end, function(a, b)
	if not a then return false end
  return #a == b
end)

