lua-pb
=======

Lua Protocol Buffers.

Modules
-------

Frontend `.proto` definition file parser:

* pb/proto/scanner.lua -- LPeg lexer for `.proto` files.
* pb/proto/util.lua    -- some utility functions.
* pb/proto/grammar.lua -- LPeg grammar for `.proto` files.
* pb/proto/parser.lua  -- LPeg based `.proto` -> AST tree parser.

There can be multiple Backend message definition compilers.  An optimized backend for LuaJIT
is planned.

Standard backend compiler

* pb/standard.lua         -- main compiler code.
* pb/standard/data.lua    -- pack/unpack code (Uses modules luabitops & struct)
* pb/standard/buffer.lua  -- encoding buffer

Finished
--------
* .proto definition parser
* Message encoder

TODO
----

* decoder
* resolving nested types (OuterMessage.InnerMessage)
* extended messages
* unkown fields.
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

Installing
----------

