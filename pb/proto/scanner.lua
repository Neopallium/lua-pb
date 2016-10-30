-- Copyright (c) 2010-2011 by Robert G. Jakabosky <bobby@neoawareness.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local _G = _G
local upper = string.upper

local mod_path = string.match(...,".*%.") or ''

local lp = require"lpeg"
local util = require(mod_path .. 'util')
local P=lp.P
local S=lp.S
local R=lp.R
local B=lp.B

local C=lp.C
local Cf=lp.Cf
local Cc=lp.Cc

module(...)

-------------------------------------------------------------------------------
------------------------- Basic Patterns
-------------------------------------------------------------------------------

-- numbers
local num_sign = (S'+-')
local digit = R'09'
local hexLit = P"0" * S"xX" * (R('09','af','AF'))^1
local octLit = P"0" * (R'07')^1
local decimals = digit^1
local exponent = S'eE' * num_sign^-1 * decimals
local floatLit = (decimals * P"." * decimals^-1  * exponent^-1) +
	(decimals * exponent) +
	( P"." * decimals * exponent^-1) + P"inf" + P"nan"
--local floatLit = (digit^1 * ((P".")^-1 * digit^0)^-1 * (S'eE' * num_sign^-1 * digit^1)^-1)
local sfloatLit = (num_sign)^-1 * floatLit
local decLit = digit^1
local sdecLit = (num_sign)^-1 * decLit

-- alphanumeric
local AZ = R('az','AZ')
local AlphaNum = AZ + R('09')
local identChar = AlphaNum + P"_"
local not_identChar = -identChar
local ident = (AZ + P"_") * (identChar)^0

-------------------------------------------------------------------------------
------------------------- Util. functions.
-------------------------------------------------------------------------------

function lines(subject)
	local _, num = subject:gsub('\n','')
	return num + 1
end

function error(msg)
	return function (subject, i)
		local line = lines(subject:sub(1,i))
		_G.error('Lexical error in line '..line..', near "'
			.. util.show_text(subject:sub(i-10,i)).. '": ' .. msg, 0)
	end
end

local function literals(tab, term)
	local ret = P(false)
	for i=1,#tab do
		-- remove literal from list.
		local lit = tab[i]
		tab[i] = nil
		-- make literal pattern
		local pat = P(lit)
		-- add terminal pattern
		if term then
			pat = pat * term
		end
		-- map LITERAL -> pattern(literal)
		tab[upper(lit)] = pat
		-- combind all literals into one pattern.
		ret = pat + ret
	end
	return ret
end

-------------------------------------------------------------------------------
------------------------- Tokens
-------------------------------------------------------------------------------

keywords = {
-- syntax
"syntax",
-- package
"package", "import",
-- main types
"message", "extend", "enum",
"option",
-- field modifiers
"required", "optional", "repeated",
-- message extensions
"extensions", "to", "max",
-- message groups
"group",
-- RPC
"service",
"rpc", "returns",
-- buildin types
"double", "float",
"int32", "int64",
"uint32", "uint64",
"sint32", "sint64",
"fixed32", "fixed64",
"sfixed32", "sfixed64",
"bool",
"string", "bytes",
-- booleans
"true", "false",
}
KEYWORD = literals(keywords, not_identChar)

symbols = {
"=", ";",
".", ",",
"{", "}",
"(", ")",
"[", "]",
}
SYMBOL = literals(symbols)

INTEGER = hexLit + octLit + decLit
SINTEGER = hexLit + octLit + sdecLit
NUMERIC = hexLit + octLit + floatLit + decLit
SNUMERIC = hexLit + octLit + sfloatLit + sdecLit

IDENTIFIER = ident

local singlequoted = P"'" * ((1 - S"'\n\r\\") + (P'\\' * 1))^0 * (P"'" + error"unfinished single-quoted string")
local doublequoted = P'"' * ((1 - S'"\n\r\\') + (P'\\' * 1))^0 * (P'"' + error"unfinished double-quoted string")
STRING = singlequoted + doublequoted

COMMENT = (P"//" * (1 - P"\n")^0) + (P"/*" * (1 - P"*/")^0 * P"*/")

-------------------------------------------------------------------------------
------------------------- Other patterns
-------------------------------------------------------------------------------

SPACE = S' \t\n\r'

IGNORED = (SPACE + COMMENT)^0

TOKEN = IDENTIFIER + KEYWORD + SYMBOL + SNUMERIC + STRING

ANY = TOKEN + COMMENT + SPACE

BOF = P(function(s,i) return (i==1) and i end)

EOF = P(-1)

