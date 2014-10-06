local gs = require 'geneos.sampler'
local gh = require 'geneos.helpers'
local md = require 'geneos.marketdata'

--- Formats a single tick as a string, displaying all fields and values.
-- @param tick The tick to format.
-- @return A string representation of the tick.
-- local function formatTick(tick)
-- 	local tmp = { time=string.format("time=%s", gh.formatTime(tick.timeFirst, 6)) }
-- 	if tick.timeFirst ~= tick.timeLast then
-- 		tmp.time = tmp.time .. "->" .. formatTime(tick.timeLast, 6)
-- 	end
-- 	for k,v in pairs(tick.field) do
-- 		tmp[#tmp + 1] = k.."="..v
-- 	end
-- 	return table.concat(tmp, ", ")
-- end

-- --- Prints all ticks for a given instrument on a feed.
-- -- @param feed Feed on which the instrument is subscribed.
-- -- @param inst Name of the instrument to output ticks for.
-- local function printTicks(feed, inst)
-- 	local tick = feed:getTicks(inst)
-- 	while tick do
-- 		print(feed, inst, formatTick(tick))
-- 		tick = tick.next
-- 	end
-- end

-- Determine the Lua Feed Adapter configuration values.
--
-- The block below is more for use convenience than necessity,
-- users may just use hardcoded names in production code.

-- The path separator; either "\" or "/"
-- local sep = package.config:sub(1,1) 
-- The Lua feed adapter library file; .so on UNIX platforms, or .dll for Windows.
-- local luaFeedAdapter = (sep == "/") and "flm-feed-lua.so" or "flm-feed-lua.dll"
local luaFeedAdapter = "flm-feed-lua.so"

-- If specified as a relative path, the input feed script must be referenced from the Netprobe working dir.
-- Since we know the input feed file is in the same directory as this file, we can use our own path in the name.
-- local function dirname(path)
-- 	local pattern = string.format("^(.*%s)[^%s]-$", sep, sep)
-- 	return path:match(pattern) or ""
-- end
-- local luaFeedInputScript = dirname(debug.getinfo(1).source:sub(2)) .. "inputFeed.lua"
local luaFeedInputScript = "lua_feed/inputFeed.lua"

-- Create an example feed, subscribed to a single instrument
local my_instruments = { GOOG = "CODE.GOOG", AAPL = "CODE.AAPL" }

local lf = md.addFeed(
	"LuaFeed",
	{
		feed = {
			type = "lua",
			verbose = "true",
			library = { filename = luaFeedAdapter },
			rawlog = "true"
		},
		lua = {
			script = luaFeedInputScript,
			value = { min = 1, max = 1000 }
		},
		instruments = my_instruments,
		fields = { Trade = "Trade", Bid = "Ask", Ask = "Bid" }
	}
)
lf:start()

-- define columns and publish view
local cols = {	"instrument", "minSpread", "maxSpread", "ticksPerSample", "maxInterval", "tradePrice" }
local view = assert(gs.createView("lua_feed_spreads", cols))
local totalTicks = 0
view.headline.totalTicks = totalTicks
view:publish()

-- utility function to round up values
local function round2dp(value)
	return not value or math.ceil(value * 100 - 0.5) / 100
end

calculateRowStats = function(insName)
	local minSpread, maxSpread, maxInterval, tradePrice		-- default to nil values
	local tickCount = 0										-- default of 0 for a count
	local tick = lf:getTicks(insName)				-- grab ticks for this sample from the feed object

	if tick then
		local spread = math.abs(tick.field.Ask - tick.field.Bid)	-- note abs required as data is simulated
		local lastTime = tick.timeLast

		while tick.next do									-- iterate over the ticks
			local interval = tick.timeFirst - lastTime		-- work out interval since last tick
			spread  = math.abs(tick.field.Ask - tick.field.Bid)	-- Derive the spread from bid and Ask
			tickCount = tickCount + 1
			if not maxInterval or interval > maxInterval then maxInterval = interval end	-- Cal min and max values for the sample
			if not minSpread or spread < minSpread then minSpread = spread end
			if not maxSpread or spread > maxSpread then maxSpread = spread end
			lastTime = tick.timeLast
			tick = tick.next
		end
		tradePrice = tick.field.Trade 						-- Trade price stored from the last tick
	end
	return
	{														-- Construct the table which forms the row for this instrument
		minSpread = round2dp(minSpread),					-- Utility function is used to round to 2 decimal places
		maxSpread = round2dp(maxSpread),
		ticksPerSample = tickCount,
		maxInterval = round2dp(maxInterval),
		tradePrice = tradePrice
	},
	tickCount												-- also return the number of ticks observed
end


gs.doSample = function()
	for name,_ in pairs (my_instruments) do 	-- loop over each subscribed instrument
		local rowResult, additionalTicks = calculateRowStats(name)	-- Call calculateRowStats() which returns 2 values
		view.row[name] = rowResult									-- Apply the row data to the corresponding row
		totalTicks = totalTicks + additionalTicks					-- keep tally of total ticks observed
	end
	view.headline.totalTicks = totalTicks							-- update headline with latest tally
	view:publish()													-- publish the new view content
end

-- Our sample method, called every second
-- local count = 0
-- gs.doSample = function()
-- 	count = count + 1
-- 	print("Sample "..count, "Status "..lf:getStatus())
-- 	printTicks(lf, "Inst1")
-- 	printTicks(lf, "Inst2")
-- 	if count == 5 then
-- 		-- Unsubscribe from instrument 2
-- 		lf:unsubscribe("Inst2")
-- 	elseif count == 8 then
-- 		-- Subscribe again to instrument 2, but with a different code and fields
-- 		lf:subscribe("Inst2", "NEW.CODE.INST.2", { F1="F1", F3="F3" })
-- 	elseif count == 10 then
-- 		-- End the test
-- 		return false
-- 	end
-- end
