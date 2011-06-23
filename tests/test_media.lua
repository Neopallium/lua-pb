
local pb = require"pb"
local encode_msg = pb.encode
local decode_msg = pb.decode

local utils = require"utils"

-- load .proto file.
local media = pb.require"protos.media"

--print(utils.dump(media))

local MediaContent = media.MediaContent

local data = {
	media = {
		uri = "http://javaone.com/keynote.mpg",
		title = "Javaone Keynote",
		width = 640,
		height = 480,
		format = "video/mpg4",
		duration = 18000000,    -- half hour in milliseconds
		size = 58982400,        -- bitrate * duration in seconds / 8 bits per byte
		bitrate = 262144,       -- 256k
		person = {"Bill Gates", "Steve Jobs"},
		player = 'JAVA',
		copyright = nil,
	},
	image = {
		{
			uri = "http://javaone.com/keynote_large.jpg",
			title = "Javaone Keynote",
			width = 1024,
			height = 768,
			size = 'LARGE',
		},
		{
			uri = "http://javaone.com/keynote_small.jpg",
			title = "Javaone Keynote",
			width = 320,
			height = 240,
			size = 'SMALL',
		},
	},
}

local msg = MediaContent(data)

local bin = encode_msg(msg)

print("--- encoded message: bytes", #bin)

local file = assert(io.open(arg[1] or 'media.bin', 'w'))
assert(file:write(bin))
assert(file:close())

print("--- decode message")
local msg1, off = decode_msg(MediaContent(), bin)

print(utils.dump(msg1))

print("Valid .proto file")

