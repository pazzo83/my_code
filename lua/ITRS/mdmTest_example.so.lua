local gs = require 'geneos.sampler'
local gh = require 'geneos.helpers'
local md = require 'geneos.marketdata'

--- Formats a single tick as a string, displaying all fields and values.
-- @param tick The tick to format.
-- @return A string representation of the tick.
local function formatTick(tick)
	local tmp = {  time=string.format("time=%s", gh.formatTime(tick.timeFirst, 6))  }
	if tick.timeFirst ~= tick.timeLast then
		tmp.time = tmp.time .. "->" .. gh.formatTime(tick.timeLast, 6)
	end
	for k,v in pairs(tick.field) do
		tmp[#tmp + 1] = k.."="..v
	end
	return table.concat(tmp, ", ")
end

--- Prints all ticks for a given instrument on a feed.
-- @param feed Feed on which the instrument is subscribed.
-- @param inst Name of the instrument to output ticks for.
local function printTicks(feed, inst)
	local tick = feed:getTicks(inst)
	while tick do
		print(tick.feed, tick.inst, formatTick(tick))
		tick = tick.next
	end
end

-- Create an example feed, subscribed to a single instrument
local exampleFeed = md.addFeed("ExampleFeed", {
	feed = { 
		type = "example",
		verbose = "true",
		library = { filename = "example/example.so", skipVersionCheck = "true" }
	},
	example = { setting1 = "v1", setting2 = "v2" },
	instruments = { Inst1 = "InstCode1" },
	fields = { Ask = "Ask", Bid = "Bid", TradePrice = "Trade Price" }
})
exampleFeed:start()

-- Our sample method, called every second
local count = 0
gs.doSample = function()
	count = count + 1
	print("Sample "..count, "Status "..exampleFeed:getStatus())
	printTicks(exampleFeed, "Inst1")
	printTicks(exampleFeed, "Inst2")
	if count == 5 then
		-- Subscribe to a new instrument
		exampleFeed:subscribe("Inst2", "InstCode2")
	elseif count == 10 then
		-- Unsubscribe from an existing instrument
		exampleFeed:unsubscribe("Inst1")
	elseif count >= 15 then
		-- End the test
		return false
	end
end
