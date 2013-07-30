require 'spec.helper'

describe('pb.standard.unpack', function()
  before(function()
    pb              = require 'pb'
    repeated        = require 'spec.fixtures.repeated'
    repeated_packed = require 'spec.fixtures.repeated_packed'
    bid_request     = require 'spec.fixtures.bid_request'
  end)

  it('should unpack repeated fields', function()
    local data  = io.open('./spec/fixtures/repeated.bin', 'r'):read('*all')

    local thing = repeated.Thing():Parse(data)
    assert_tables(thing.parts, { 44, 55 })
  end)

  it('should unpack repeated packed fields', function()
    local data  = io.open('./spec/fixtures/repeated_packed.bin', 'r'):read('*all')

    local thing = repeated_packed.Thing():Parse(data)
    assert_tables(thing.parts, { 77, 999 })
  end)

  it('should unpack repeated fields in google bid request', function()
    local data  = io.open('./spec/fixtures/bid_request.bin', 'r'):read('*all')

    local bid_request = bid_request.BidRequest():Parse(data)
    assert_length(bid_request.adslot, 1)
  end)
end)
