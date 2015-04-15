local pb=require("pb")
local msgs=require("protos/filename")

local expected_filename = 'protos/filename'..'.proto'
assert(msgs.Parent():FileName() == expected_filename)
assert(msgs.Parent.Child():FileName() == expected_filename)
assert(msgs.Parent.Child.GrandChild():FileName() == expected_filename)


expected_filename = 'TestMsg.proto'
msgs = pb.load_proto([[
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

assert(msgs.Parent():FileName() == expected_filename)
assert(msgs.Parent.Child():FileName() == expected_filename)
assert(msgs.Parent.Child.GrandChild():FileName() == expected_filename)

