## require(name)

Loads a .proto file.

```lua
pb.require(name)  
```

# protobuf message methods

## FileName()
Returns '.proto' file name and path there this message is located.

```lua
msg:FileName()
```

## FullName()

Returns fully qualified message name e.g. in case of:
```protobuf
package org.test;

message Parent {
	message Child {
		message GrandChild {
			required int32 GrandChildField = 1;
		}
		required int32 ChildField = 1;
	}
	required int32 ParentField = 1;
}
```
it will be:

```protobuf
	org.test.Parent
	org.test.Parent.Child
	org.test.Parent.Child.GrandChild
```

```lua
msg:FullName()
```

## Name()

Returns message name.

```lua
msg:Name()
```

## MergeFrom(other_msg)

Merges the contents of the specified message into the current message.

This method merges the contents of the specified message into the current
message. Singular fields that are set in the specified message overwrite
the corresponding fields in the current message. Repeated fields are
appended. Singular sub-messages and groups are recursively merged.

```lua
msg:MergeFrom(msg2)
```

## CopyFrom(other_msg)

Copies the contents of the specified message into the current message.

The method clears the current message and then merges the specified
message using MergeFrom.

```lua
msg:CopyFrom(msg2)
```

## Clear()

Clears all data that was set in the message.

```lua
msg:Clear()
```

## IsInitialized()

Checks if the message is initialized.

```lua
local is_init, errmsg = msg:IsInitialized()
```

## Merge(data, format, off, len)

Merges serialized protocol buffer data into this message.

When we find a field in `data` that is already present
in this message:

* If it's a "repeated" field, we append to the end of our list.
* Else, if it's a scalar, we overwrite our field.
* Else, (it's a nonrepeated composite), we recursively merge 
into the existing composite.

Args:

* data: A serialized message encode in `format`.
* format: The optional encoding format of `data`.  (defaults to "binary")
* off: Optional offset into `data`.  (defaults to 1)
* len: Optional number of bytes to parse from `data`.  (defaults to `#data`)

Formats:

* binary

```lua
local msg, off = msg:Merge(data, 'text')
```

## Parse(data, format, off, len)

Like MergeFromString(), except we clear the object first.

## ParsePartial(data, format, off, len)

Like Parse(), but accepts messages that are missing required fields. 

## Serialize(format, depth)

Serializes the protocol message to a string encoding it using `format`.

Args:

* format: The optional serialization format.  (defaults to 'binary').
* depth: Optional depth for indenting.  (defaults to 0)

Formats:

* binary
* text

```lua
local bin, errmsg = msg:Serialize('text')
```

## SerializePartial(format, depth)

Serializes the protocol message to a binary string.

This method is similar to SerializeToString but doesn`t check if the
message is initialized.

# Access unknown fields

A message will store all unknown fields in field 'unknown_fields'

```lua
for i,v in ipairs(msg.unknown_fields) do
	print("idx =", i, "tag =", v.tag, "wiretype =", v.wire, "value =", v.value)
end
```

