
local pb = require"pb"

local utils = require"utils"

-- load .proto file.
local proto = pb.require(arg[1])

print(utils.dump(proto))

print("Valid .proto file")

