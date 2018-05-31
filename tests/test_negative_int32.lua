local pb = require"pb"
local value = -1
local integer32 = require"protos.int32"

local msg = integer32.TestInt32()
msg.int32_ = value;
binary,err = msg:Serialize();
assert(not err)

local decoded = integer32.TestInt32():Parse(binary)
assert(decoded:IsInitialized())
assert(decoded:HasField('int32_'))
assert(value == decoded.int32_)