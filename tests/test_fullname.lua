local pb = require("pb");
local Msgs = pb.load_proto([[
package org.test;

message Parent
{
	message Child {
		message GrandChild {
			required int32 GrandChildField = 1;
		}
		required GrandChild ChildField = 1;
	}
	required Child ParentField = 1;
}

]],"TestMsg");

local epfn = "org.test.Parent"
local pfn = Msgs.Parent():FullName()
assert(pfn == epfn, "Expected '" .. epfn .. "' received '" .. pfn .."'")
local ecfn = "org.test.Parent.Child"
local cfn = Msgs.Parent.Child():FullName()
assert(cfn == ecfn, "Expected '" .. ecfn .. "' received '" .. cfn .. "'")
local egfn = "org.test.Parent.Child.GrandChild"
local gfn = Msgs.Parent.Child.GrandChild():FullName()
assert(egfn == gfn, "Expected '" .. egfn .. "' received '" .. gfn .. "'")
