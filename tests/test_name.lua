local pb = require("pb");
local Msgs = pb.load_proto([[
message Msg1
{
  required int32 result = 1;
}

message Msg2
{
  required int32 x = 1;
  required int32 y = 2;
}
]],"TestMsg");

assert(Msgs.Msg1():Name() == "Msg1")
assert(Msgs.Msg2():Name() == "Msg2")
