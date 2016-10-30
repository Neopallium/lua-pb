-- load lua-pb first.
require"pb"

-- now you can use require to load person.proto
require"person"

local msg = person.Person()
msg.name = "John Doe"
msg.id = 1234
msg.email = "jdoe@example.com"

local phone_work = person.Person.PhoneNumber()
phone_work.type = person.Person.PhoneType.WORK
phone_work.number = "123-456-7890"
msg.phone = {phone_work}

pb.print(msg)

print("Encode person message to binary.")
local bin = assert(msg:Serialize())
print("bytes =", #bin)

print("Decode person message from binary.")
local msg2 = person.Person():Parse(bin)
pb.print(msg2)

