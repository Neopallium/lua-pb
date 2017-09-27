local pb = require"pb"
local proto = require"protos.recursion"

local msg = proto.A()
msg.a1 = 123
msg.a2 = proto.B()
msg.a2.b1 = 456
msg.a2.b2 = proto.A()
msg.a2.b2.a1 = 678

local bin = assert(msg:Serialize())

local msg1 = msg:Parse(bin)

assert(msg.a2.b2.a1 == msg1.a2.b2.a1)

pb.print(msg1)
