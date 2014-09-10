-- test require order when one proto imports another.

require'pb'
require'protos.import_a'
require'protos.import_b'

local msg = test.import.sub.AMessage()
print(msg)

