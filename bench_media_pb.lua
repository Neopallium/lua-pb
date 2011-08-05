-- 
-- test Protobuf media messages.
-- 

local assert = assert
local print = print
local tostring = tostring
local table = table

require"pb"

local utils = require"utils"

local MediaContentHolder = require"protos.media"

local sample = {
	media = {
		uri = "http://javaone.com/keynote.mpg",
		title = "Javaone Keynote",
		height = 640,
		width = 480,
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
			uri = "http://javaone.com/keynote_thumbnail.jpg",
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
	assert(media.width == 480)
	assert(media.height == 640)
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
	assert(img.uri == "http://javaone.com/keynote_thumbnail.jpg")
	assert(img.title == "Javaone Keynote")
	assert(img.width == 320)
	assert(img.height == 240)
	assert(img.size == "SMALL")
end

local enc = { name="pb"}
function enc:create()
	return MediaContentHolder.MediaContent()
end
function enc:build(obj)
	if not obj then
		return MediaContentHolder.MediaContent(sample)
	end
	obj:CopyFrom(sample)
--[[
	-- create media record.
	local media = obj.media
	if not media then obj.media = {}; media = obj.media end
	media.format = "video/mpg4"
	media.player = "JAVA"
	media.title = "Javaone Keynote"
	media.uri = "http://javaone.com/keynote.mpg"
	media.duration = 18000000
	media.size = 58982400
	media.height = 640
	media.width = 480
	media.bitrate = 262144
	-- add persons.
	media.person = {}
	local person = media.person
	person:Add("Bill Gates")
	person:Add("Steve Jobs")

	-- create image records.
	obj.image = {}
	local image1 = obj.image:Add()
	image1.height = 768
	image1.title = "Javaone Keynote"
	image1.uri = "http://javaone.com/keynote_large.jpg"
	image1.width = 1024
	image1.size = "LARGE"

	local image2 = obj.image:Add()
	image2.height = 240
	image2.title = "Javaone Keynote"
	image2.uri = "http://javaone.com/keynote_thumbnail.jpg"
	image2.width = 320
	image2.size = "SMALL"
--]]

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
