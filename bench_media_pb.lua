-- 
-- test Protobuf media messages.
-- 

local assert = assert
local print = print
local tostring = tostring
local table = table

require"pb"

local utils = require"utils"

if jit then
	jit.opt.start("maxsnap=5000", "maxside=1000", "maxtrace=4000", "maxrecord=8000", "maxmcode=4096")
end

local MediaContentHolder = require"protos.media"

local sample = {
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
		player = "JAVA",
		copyright = nil,
	},
	image = {
		{
			uri = "http://javaone.com/keynote_large.jpg",
			title = "Javaone Keynote",
			width = 1024,
			height = 768,
			size = "LARGE",
		},
		{
			uri = "http://javaone.com/keynote_small.jpg",
			title = "Javaone Keynote",
			width = 320,
			height = 240,
			size = "SMALL",
		},
	},
}

--
-- Check MediaContent message
--
local function check_MediaContent_media(media)
	assert(media ~= nil)
	assert(media.uri == "http://javaone.com/keynote.mpg")
	assert(media.title == "Javaone Keynote")
	assert(media.width == 640)
	assert(media.height == 480)
	assert(media.format == "video/mpg4")
	assert(media.duration == 18000000)    -- half hour in milliseconds
	assert(media.size == 58982400)        -- bitrate * duration in seconds / 8 bits per byte
	assert(media.bitrate == 262144)       -- 256k
	local person = media.person
	assert(person[1] == "Bill Gates")
	assert(person[2] == "Steve Jobs")
	assert(media.player == "JAVA")
	assert(media.copyright == nil)
end

local function check_MediaContent(content)
	assert(content ~= nil)
	-- check media message
	check_MediaContent_media(content.media)
	-- check image messages.
	local image = content.image
	local img
	img = image[1]
	assert(img ~= nil)
	assert(img.uri == "http://javaone.com/keynote_large.jpg")
	assert(img.title == "Javaone Keynote")
	assert(img.width == 1024)
	assert(img.height == 768)
	assert(img.size == "LARGE")
	img = image[2]
	assert(img ~= nil)
	assert(img.uri == "http://javaone.com/keynote_small.jpg")
	assert(img.title == "Javaone Keynote")
	assert(img.width == 320)
	assert(img.height == 240)
	assert(img.size == "SMALL")
end

local enc = { name="pb"}
function enc:create()
	return MediaContentHolder.MediaContent()
end
function enc:build(obj, data)
	data = data or sample
	if not obj then
		return MediaContentHolder.MediaContent(data)
	end
	-- fill old message.
	obj.media = data.media
	obj.image = data.image
	return obj
end
function enc:free(obj)
end
function enc:check_part(obj)
	check_MediaContent_media(obj.media)
end
function enc:check_all(obj)
	check_MediaContent(obj)
end
function enc:encode(obj)
	return obj:Serialize()
end
function enc:decode(obj, data)
	obj = obj or MediaContentHolder.MediaContent()
	obj:Clear()
	assert(obj:Parse(data))
	return obj
end

return enc
