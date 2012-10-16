
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

local msg1 = Msgs.Msg1();
msg1.result = 0;
local buffer = msg1:Serialize();

local msg2 = Msgs.Msg2();
local m, off_err = msg2:Parse(buffer);

print("msg2:Parse(buffer) =", m, off_err);
print("msg2:IsInitialized() = ", msg2:IsInitialized())
print("msg2.x="..msg2.x);
print(msg2.y);

local m, off_err = msg2:ParsePartial(buffer);

print("msg2:ParsePartial(buffer) =", m, off_err);
print("msg2:IsInitialized() = ", msg2:IsInitialized())
print("msg2.x="..msg2.x);
print(msg2.y);

