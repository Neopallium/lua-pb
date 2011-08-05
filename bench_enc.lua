#!/usr/bin/env lua

-- Copyright (c) 2010 by Robert G. Jakabosky <bobby@neoawareness.com>
--
local zmq = require"zmq"
local quiet = false
local enable_gc = false
local collectgarbage = collectgarbage
local assert = assert
local MSEC_PER_SEC = 1000
local USEC_PER_SEC = MSEC_PER_SEC * 1000
local NSEC_PER_SEC = USEC_PER_SEC * 1000

if jit then
	--jit.opt.start("maxsnap=5000", "maxside=1000", "maxtrace=4000", "maxrecord=8000", "maxmcode=4096")
end

local TEST = false

local loop_multipler = 100

local i=1
while i <= #arg do
	local p = arg[i]
	if p == '-gc' then
		enable_gc = true
	elseif p == '-m' then
		i = i + 1
		loop_multipler = tonumber(arg[i])
	elseif p == '-t' then
		TEST = true
	end
	i = i + 1
end
if not enable_gc then
	print"GC is disabled so we can track memory usage better"
	print""
end

local LOOP_ENC_DEC       = (20 * loop_multipler)
local LOOP_CREATE_DELETE = (20 * loop_multipler)
local LOOP_ROUND_TRIP    = (20 * loop_multipler)
local LOOP_CREATE        = (20 * loop_multipler)
local TRIALS = 20
if TEST then TRIALS = 1 end

local BenchStatID = {
	BenchCreateAndDeleteEmpty   = 1,
	BenchCreateAndDeleteFull    = 2,
	BenchEncodeDifferentObjects = 3,
	BenchEncodeSameObject       = 4,
	BenchDecodeObject           = 5,
	BenchDecodeSameObject       = 6,
	BenchDecodeObjectCheckAll   = 7,
	BenchDecodeObjectCheckMedia = 8,
	BenchDecodeEncodeRoundTrip  = 9,
}
local MAX_BENCH_STATS = BenchStatID.BenchDecodeEncodeRoundTrip

local BenchStatInfo = {
	{ is_create=true,  name="Create empty",         desc="create & delete empty object" },
	{ is_create=true,  name="Create full",          desc="create & delete full object" },
	{ is_create=false, name="Encode diff",          desc="encode different objects" },
	{ is_create=false, name="Encode same",          desc="encode same object" },
	{ is_create=false, name="Decode",               desc="decode object" },
	{ is_create=false, name="Decode same",          desc="decode same object" },
	{ is_create=false, name="Decode & Check all",   desc="decode object & check all fields" },
	{ is_create=false, name="Decode & Check media", desc="decode object & check media field" },
	{ is_create=false, name="Round Trip",           desc="Round trip decode <-> encode <-> delete" },
}

local benchmarks = {}
local load_list = {
media = { "bench_media_pb" },
}

local function load_benchmark(msg_name, name)
	local test = require(name)
	test.msg_name = msg_name
	-- add loaded benchmark to list.
	local list = benchmarks[msg_name] or {}
	benchmarks[msg_name] = list
	list[#list + 1] = test
	-- intialize stats
	local stats = {}
	test.stats = stats
	for i=1,MAX_BENCH_STATS do
		stats[i] = { secs = math.huge, mem = math.huge, bytes = 0, counts = 0}
	end
end

-- load all benchmarks.
for msg_name,list in pairs(load_list) do
	for i=1,#list do
		load_benchmark(msg_name, list[i])
	end
end

local function printf(fmt, ...)
	local res
	if not quiet then
		fmt = fmt or ''
		res = io.write(string.format(fmt, ...))
		io.stdout:flush()
	end
	return res
end

local function record_bench_stat(id, bench, usecs, mem, count, bytes)
	id = BenchStatID[id]
	local stat = bench.stats[id]
	assert(stat)
	-- convert usecs to secs
	local secs = (usecs / USEC_PER_SEC)
	-- only keep the minimum of each round.
	if stat.secs > secs then
		stat.secs = secs
		stat.bytes = bytes
		stat.count = count
	end
	if stat.mem > mem then
		stat.mem = mem
	end
	if TEST then
		printf("%20s: %6.0f nsecs\n", BenchStatInfo[id].name, ((secs * NSEC_PER_SEC) / count));
	end
end

local function full_gc()
	-- make sure all free-able memory is freed
	collectgarbage"collect"
	collectgarbage"collect"
	collectgarbage"collect"
end

local function stat_width(id, format)
	local width = 12;
	local name_len = #BenchStatInfo[id].name
	if (width < name_len) then width = name_len end
	return format:gsub('%%%*', "%%" .. tostring(width))
end

-- print stats table.
local function bench_enc_print_stats(list)
	-- print headers.
	printf("Units: nano seconds\n");
	printf("%10s", "");
	for s=1,MAX_BENCH_STATS do
		printf(", %12s", BenchStatInfo[s].name);
	end
	printf(", %12s", "Encode Size");
	printf("\n");
	for i=1,#list do
		local bench = list[i]
		local stats = bench.stats
		printf("%-10s", bench.name);
		for s=1,MAX_BENCH_STATS do
			local stat = stats[s]
			printf(stat_width(s, ", %*.0f"),
				((stat.secs * NSEC_PER_SEC) / stat.count));
		end
		printf(", %12.0f", bench.encode_size);
		printf("\n");
	end
	printf("\n");
---[[
	-- print headers.
	printf("Units: MBytes per second.\n");
	printf("%10s", "");
	for s=1,MAX_BENCH_STATS do
		if not (BenchStatInfo[s].is_create) then
			printf(", %12s", BenchStatInfo[s].name);
		end
	end
	printf("\n");
	for i=1,#list do
		local bench = list[i]
		local stats = bench.stats
		printf("%-10s", bench.name);
		for s=1,MAX_BENCH_STATS do
			if not (BenchStatInfo[s].is_create) then
				local stat = stats[s]
				printf(stat_width(s, ", %*.3f"), stat.bytes / stat.secs / (1024 * 1024));
			end
		end
		printf("\n");
	end
--]]
	printf("\n");
---[[
	-- print headers.
	printf("Units: Objects per second.\n");
	printf("%10s", "");
	for s=1,MAX_BENCH_STATS do
		printf(", %12s", BenchStatInfo[s].name);
	end
	printf("\n");
	for i=1,#list do
		local bench = list[i]
		local stats = bench.stats
		printf("%-10s", bench.name);
		for s=1,MAX_BENCH_STATS do
			local stat = stats[s]
			printf(stat_width(s, ", %*.0f"), stat.count / stat.secs);
		end
		printf("\n");
	end
--]]
	printf("\n");
---[[
	-- print headers.
	printf("Units: KBytes.\n");
	printf("%10s", "");
	for s=1,MAX_BENCH_STATS do
		printf(", %12s", BenchStatInfo[s].name);
	end
	printf("\n");
	for i=1,#list do
		local bench = list[i]
		local stats = bench.stats
		printf("%-10s", bench.name);
		for s=1,MAX_BENCH_STATS do
			local stat = stats[s]
			printf(stat_width(s, ", %*.0f"), stat.mem);
		end
		printf("\n");
	end
--]]
end

local function bench_create_empty_objects(bench, count)
	local timer, diff, mem
	local obj

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:create()
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	record_bench_stat("BenchCreateAndDeleteEmpty", bench, diff, mem, count, 0)
	collectgarbage"restart"
	full_gc()
end

local function bench_create_full_objects(bench, count)
	local timer, diff, mem
	local obj

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:build()
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	record_bench_stat("BenchCreateAndDeleteFull", bench, diff, mem, count, 0)
	collectgarbage"restart"
	full_gc()
end

local function bench_encode_different_objects(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:build()
		buffer = bench:encode(obj)
		len = #buffer
		total_len = total_len + len
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	-- record encode size. 
	bench.encode_size = len
	record_bench_stat("BenchEncodeDifferentObjects", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_encode_same_object(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	obj = bench:build()
	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		buffer = bench:encode(obj)
		len = #buffer
		total_len = total_len + len
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	record_bench_stat("BenchEncodeSameObject", bench, diff, mem, count, total_len)
	bench:free(obj)
	collectgarbage"restart"
	full_gc()
end

local function bench_decode_object(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- encode object. 
	obj = bench:build()
	buffer = bench:encode(obj)
	len = #buffer
	bench:free(obj)

	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:decode(nil, buffer)
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	total_len = len * count
	record_bench_stat("BenchDecodeObject", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_decode_same_object(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- encode object. 
	obj = bench:build()
	buffer = bench:encode(obj)
	len = #buffer
	bench:free(obj)
	obj = nil

	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:decode(obj, buffer)
	end
	bench:free(obj)
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	total_len = len * count
	record_bench_stat("BenchDecodeSameObject", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_decode_object_check_all(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- encode object. 
	obj = bench:build()
	buffer = bench:encode(obj)
	len = #buffer
	bench:free(obj)

	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:decode(nil, buffer)
		bench:check_all(obj)
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	total_len = len * count
	record_bench_stat("BenchDecodeObjectCheckAll", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_decode_object_check_partial(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- encode object. 
	obj = bench:build()
	buffer = bench:encode(obj)
	len = #buffer
	bench:free(obj)

	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:decode(nil, buffer)
		bench:check_part(obj)
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	total_len = len * count
	record_bench_stat("BenchDecodeObjectCheckMedia", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_decode_encode_round_trip(bench, count)
	local timer, diff, mem
	local obj
	local len = 0
	local total_len = 0
	local buffer

	full_gc()
	if not enable_gc then collectgarbage"stop" end
	mem = (collectgarbage"count")
	-- encode object. 
	obj = bench:build()
	buffer = bench:encode(obj)
	len = #buffer
	bench:free(obj)

	-- start timer. 
	timer = zmq.stopwatch_start()
	for i=1,count do
		obj = bench:decode(nil, buffer)
		total_len = total_len + len
		buffer = bench:encode(obj)
		len = #buffer
		total_len = total_len + len
		bench:free(obj)
	end
	-- bench finished 
	diff = timer:stop()
	mem = (collectgarbage"count") - mem
	record_bench_stat("BenchDecodeEncodeRoundTrip", bench, diff, mem, count, total_len)
	collectgarbage"restart"
	full_gc()
end

local function bench_enc_run(bench)
	local obj

	printf("--------- Benchmark: %s\n", bench.name)

	-- test check_* functions.
	obj = bench:build()
	bench:check_all(obj)
	bench:free(obj)

	for i=1,TRIALS do
		bench_create_empty_objects(bench, LOOP_CREATE_DELETE)
	end
	for i=1,TRIALS do
		bench_create_full_objects(bench, LOOP_CREATE_DELETE)
	end

	for i=1,TRIALS do
		bench_encode_different_objects(bench, LOOP_ENC_DEC)
	end
	for i=1,TRIALS do
		bench_encode_same_object(bench, LOOP_ENC_DEC)
	end

	for i=1,TRIALS do
		bench_decode_object(bench, LOOP_ENC_DEC)
	end
	for i=1,TRIALS do
		bench_decode_same_object(bench, LOOP_ENC_DEC)
	end
	for i=1,TRIALS do
		bench_decode_object_check_all(bench, LOOP_ENC_DEC)
	end
	for i=1,TRIALS do
		bench_decode_object_check_partial(bench, LOOP_ENC_DEC)
	end

	for i=1,TRIALS do
		bench_decode_encode_round_trip(bench, LOOP_ROUND_TRIP)
	end
end

local list = benchmarks.media
for i=1,#list do
	bench_enc_run(list[i])
end
bench_enc_print_stats(list)

