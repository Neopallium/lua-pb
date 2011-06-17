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

local print = print
local error = error
local upper = string.upper
local sfind = string.find

local pack = string.match(...,"[a-zA-Z0-9.]*[.]") or ''

local lp = require"lpeg"
local grammar = require(pack .. 'grammar')
local scanner = require(pack .. 'scanner')
local P=lp.P
local S=lp.S
local V=lp.V
local R=lp.R
local B=lp.B

local C=lp.C
local Cf=lp.Cf
local Cc=lp.Cc

module(...)

-- Searches for the last substring in s which matches pattern
local function rfind(s, pattern, init, finish)
  init = init or #s
  finish = finish or 1
  
  for i = init, finish, -1 do
    local lfind, rfind = sfind(s, pattern, i)
    
    if lfind and rfind then
      return lfind, rfind
    end
  end
  
  return nil
end

-------------------------------------------------------------------------------
------------------------- Protocol Buffers grammer rules
-------------------------------------------------------------------------------
local S=V'IGNORED'
local listOf = grammar.listOf
local E=S* V';'

rules = {
-- initial rule
[1] = 'Proto';

IGNORED = scanner.IGNORED, -- seen as S below
EPSILON = P(true),
EOF = scanner.EOF,
BOF = scanner.BOF,
ID = scanner.IDENTIFIER,

IntLit = scanner.INTEGER,
StrLit = scanner.STRING,

-- identifiers
Name = V'ID' * ( V'.' * V'ID')^0,
GroupName = R'AZ' * (V'ID')^0,
UserType = (V'.')^-1 * V'Name',

-- Top-level
Proto = (S* (V'Message' + V'Extend' + V'Enum' + V'Import' + V'Package' + V'Option' +
	V'Service' + V';'))^0 *S,

Import = V'IMPORT' *S* V'StrLit' *E,
Package = V'PACKAGE' *S* V'Name' *E,

Option = V'OPTION' *S* V'OptionBody' *E,
OptionBody = V'Name' *S* V'=' *S* V'Constant',

Extend = V'EXTEND' *S* V'UserType' *S* V'{' * (S* (V'Field' + V'Group' + V';'))^0 *S* V'}',

Enum = V'ENUM' *S* V'ID' *S* V'{' * (S* (V'Option' + V'EnumField' + V';'))^0 *S* V'}',
EnumField = V'ID' *S* V'=' *S* V'IntLit' *E,

Service = V'SERVICE' *S* V'ID' *S* V'{' * (S* (V'Option' + V'rpc' + V';'))^0 *S* V'}',
rpc = V'RPC' *S* V'ID' *S* V'(' *S* V'UserType' *S* V')' *S*
	V'RETURNS' *S* V'(' *S* V'UserType' *S* V')' *E,

Group = V'FieldRule' *S* V'GROUP' *S* V'GroupName' *S* V'=' *S* V'IntLit' *S* V'MessageBody',

Message = V'MESSAGE' *S* V'ID' *S* V'MessageBody',

MessageBody = V'{' * (S* (V'Field' + V'Enum' + V'Message' + V'Extend' + V'Extensions'
	+ V'Group' + V'Option' + V';'))^0 *S* V'}',

Field = V'FieldRule' *S* V'Type' *S* V'ID' *S* V'=' *S* V'IntLit' *S*
	( V'[' *S* V'FieldOption' *S* V']')^-1 *E,
FieldOption = listOf(V'OptionBody', S* V',' *S),
FieldRule = (V'REQUIRED' + V'OPTIONAL' + V'REPEATED'),

Extensions = V'EXTENSIONS' *S* V'ExtensionList' *E,
ExtensionList = listOf(V'Extension', S* V',' *S),
Extension =  V'IntLit' *S* (V'TO' *S* (V'IntLit' + V'MAX')^1 )^-1,

Type = (V'DOUBLE' + V'FLOAT' + 
V'INT32' + V'INT64' +
V'UINT32' + V'UINT64' +
V'SINT32' + V'SINT64' +
V'FIXED32' + V'FIXED64' +
V'SFIXED32' + V'SFIXED64' +
V'BOOL' + 
V'STRING' + V'BYTES' + V'UserType'),

BoolLit = (V'TRUE' + V'FALSE'),
Constant = (V'ID' + V'IntLit' + V'StrLit' + V'BoolLit'),

}

-- add keywords and symbols to grammar
grammar.complete(rules, scanner.keywords)
grammar.complete(rules, scanner.symbols)

function check(input)
  local builder = P(rules)
  local result = builder:match(input)
  
  if result ~= #input + 1 then -- failure, build the error message
    local init, _ = rfind(input, '\n*', result - 1) 
    local _, finish = sfind(input, '\n*', result + 1)
    
    init = init or 0
    finish = finish or #input
    
    local line = scanner.lines(input:sub(1, result))
    local vicinity = input:sub(init + 1, finish)
    
    return false, 'Syntax error at line '..line..', near "'..vicinity..'"'
  end
  
  return true
end

function apply(extraRules, captures)
	return grammar.apply(rules, extraRules, captures)
end

