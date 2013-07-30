require 'spec.helper'

describe('pb.standard.unpack', function()
  before(function()
    pb       = require 'pb'
    repeated = require 'spec.fixtures.repeated'
  end)

  it('should unpack repeated fields', function()
    local data  = io.open('./spec/fixtures/repeated.bin', 'r'):read('*all')

    local thing = repeated.Thing():Parse(data)
    assert_tables(thing.parts, { 44, 55 })
  end)

  it('should unpack repeated packed fields', function()
  end)
end)
