lua-pb
=======

Lua Protocol Buffers.

Supports dynamic loading of Protocol Buffer message definition files `.proto`

Installing
----------

	$ sudo luarocks install "https://raw.github.com/Neopallium/lua-pb/master/lua-pb-scm-0.rockspec"

Design
------

Frontend `.proto` definition file parser:

* pb/proto/scanner.lua -- LPeg lexer for `.proto` files.
* pb/proto/util.lua    -- some utility functions.
* pb/proto/grammar.lua -- LPeg grammar for `.proto` files.
* pb/proto/parser.lua  -- LPeg based `.proto` -> AST tree parser.

There can be multiple Backend message definition compilers.  An optimized backend for LuaJIT
is planned.

Standard backend compiler

* pb/standard.lua         -- main compiler code.
* pb/standard/pack.lua    -- pack code (Uses modules luabitops & struct)
* pb/standard/unpack.lua  -- unpack code (Uses modules luabitops & struct)
* pb/standard/buffer.lua  -- encoding buffer
* pb/standard/unknown.lua -- object for hold unknown fields.
* pb/standard/dump.lua    -- message dumping code.

Finished
--------
* .proto definition parser
* Message encoder
* Message decoder
* Raw message decoding.
* Dumping messages to text format.

TODO
----

* packing unknown fields.
* resolving nested types (OuterMessage.InnerMessage)
* extended messages
* LuaJIT optimized backend compiler.
* custom options:

	import "google/protobuf/descriptor.proto";
	
	extend google.protobuf.MessageOptions {
	  optional string my_option = 51234;
	}
	
	message MyMessage {
	  option (my_option) = "Hello world!";
	}

* services

