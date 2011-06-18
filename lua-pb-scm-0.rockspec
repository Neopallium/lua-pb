#!/usr/bin/env lua

package	= 'lua-pb'
version	= 'scm-0'
source	= {
	url	= '__project_git_url__'
}
description	= {
	summary	= "Lua Protocol Buffers",
	detailed	= '',
	homepage	= '__project_homepage__',
	license	= 'MIT',
	maintainer = "Robert G. Jakabosky",
}
dependencies = {
	'lua >= 5.1',
	'lpeg',
}
build	= {
	type		= 'none',
	install = {
		lua = {
			['pb.proto.scanner'] = "pb/proto/scanner.lua",
			['pb.proto.grammar'] = "pb/proto/grammar.lua",
			['pb.proto.parser'] = "pb/proto/parser.lua",
			['pb.proto.ast'] = "pb/proto/ast.lua",
		}
	}
}
