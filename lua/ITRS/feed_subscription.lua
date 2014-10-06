--- #######################
--- feed_subscription.lua
--- #######################

local sa = require "geneos.sampler"
local md = require "geneos.marketdata"

local feedConfiguration = {} -- Feed configuration is a Lua table

feedConfiguration.feed = {  -- Generic feed configuration
	type = "example",
	["library.filename"] = "flm-feed-example.so",	-- verbose syntax due to '.' char in lib file
	["library.skipVersionCheck"] = "true", 			-- disables library version checking
	verbose = "false",								-- log verbosity
	rawlog = "true"									-- raw logging
}

feedConfiguration.example = {						-- feed specific configuration
	publishingPeriod = 1000							-- defines specific period between published tick updates
}

feedConfiguration.instruments = {					-- define the set of instruments to subscribe to
	GOOG = "DATA_SERVICE.GOOG",						-- map of names to instrument codes
	IBM = "DATA_SERVICE.IBM"
}

feedConfiguration.fields = {						-- define the set of fields to subscribe to
	Trade = "TRADE_PRICE",							-- map of names to field codes
	Bid = "BID",
	Ask = "ASK",
	Time = "QUOTIM"
}

local exampleFeed = md.addFeed("RFA-Feed", feedConfiguration)	-- Create a local feed using config from above
exampleFeed:start()												-- start the feed

-- Utility function to print tick content
function printTick(tick)
	print("----------------------")
	print("Got tick for: " .. tick.inst)
	print("Trade " .. tick.field.Trade)		-- note that subscribe fields are published
	print("Ask   " .. tick.field.Ask)		-- as fields on the returned tick table
	print("Time  " .. tick.field.Time)
	print("Bid   " .. tick.field.Bid)
end

-- doSample() called periodically to update view content
sa.doSample = function()
	local ticks = exampleFeed:getTicks("GOOG")	-- grab ticks per instrument
	while ticks do
		printTick(ticks)
		ticks = ticks.next
	end

	ticks = exampleFeed:getTicks("IBM")
	while ticks do
		printTick(ticks)
		ticks = ticks.next
	end
end