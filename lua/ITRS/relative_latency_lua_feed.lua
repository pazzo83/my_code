--- ##########################################
--- RBC Use Case 2.6.1
--- Two Sources - one symbol: relative latency
--- ##########################################

local sa = require "geneos.sampler"
local lt = require "geneos.latency"
local md = require "geneos.marketdata"

local luaFeedAdapter = "flm-feed-lua.so"
local luaFeedInputScript = "lua_feed/inputFeed.lua"

local fields = { Trade = "Trade", Change = "Change", Bid = "Ask", Ask = "Bid", BidSize = "BidSize", AskSize = "AskSize" }
-- Create an example feed, subscribed to a single instrument
local my_instruments = { GOOG = "CODE.GOOG", AAPL = "CODE.AAPL" }
local my_instruments_cache = { GOOG = "CODE_CACHE.GOOG", AAPL = "CODE_CACHE.AAPL" }

-- Using a nyxt data source
local lua_feed =
{
	feed = { type = "lua", library = { filename = luaFeedAdapter }, verbose="true", rawlog="true" },
	lua = { script = luaFeedInputScript, value = { min = 1, max = 1000 } },
	instruments = my_instruments,
	fields = fields
}

local lua_feed_cache =
{
	feed = { type = "lua", library = { filename = luaFeedAdapter }, verbose="true", rawlog="true" },
	lua = { script = luaFeedInputScript, value = { min = 1, max = 1000 } },
	instruments = my_instruments_cache,
	fields = fields
}

-- Example WriterCallBack function 
local function WriterCallBack(why, what)
	if why == 'sampleTime' then		-- SampleTime event
		print "Got sample..."
	else							-- otherwise is a tick event
		local tick = what
		print(string.format("Tick %s.%s Trade:%s Change:%s Bid:%s BidSize%s Ask:%s AskSize:%s", 
			tick.feed, tick.inst, tick.field.Trade, tick.field.Change, tick.field.Bid, tick.field.BidSize, tick.field.Ask, tick.field.AskSize))
	end
end

local ctx = lt.newContext()			-- create the context object here
	:addWriter(WriterCallBack)		-- register the writer WriterCallBack
	:setBase("lua_feed", lua_feed)	-- Register the base feed
	:addFeed("lua_feed_cache", lua_feed_cache)	-- add an alt feed
	:start()						-- start the system, will automatically start feed subscriptions

-- creating view
local view = sa.createView("LATENCY", { "feed", "status", "numTicks", "numMatches", "minLatency", "maxLatency" })
view.headline.baselineFeed = "lua_feed"
view:publish()						-- publish a stats view, similar to FLM latency view

local count = 0
sa.doSample = function()
	count = count + 1
	print("[latency] sample " .. count)

	ctx:sample()					-- instruct the latency context to update its stats
	local mBase = ctx:getMetrics("lua_feed")	-- grab metrics from base feed
	local mAlt = ctx:getMetrics("lua_feed_cache")	-- grab metrics from alt feed

	view.row = {}
	view.row["lua_feed"] = {
		ctx.base.feed:getStatus(),				-- status of base feed
		mBase.numTicks,							-- add remaining stats to row
		mBase.matches,
		"",										-- note base feed will have no latency stats
		""
	}

	local min = ""
	if(mAlt.latMin ~= nill) then
		min = string.format("%0.0f", mAlt.latMin * 1000)	-- handle formatting in case of nil value
	end
	local max = ""
	if(mAlt.latMax ~= nil) then
		max = string.format("%0.0f", mAlt.latMax * 1000)
	end

	local alt = ctx:getFeedNum("lua_feed_cache")		-- lookup the feed id for the alt-feed
	view.row["lua_feed_cache"] = {
		ctx.feeds[alt].feed:getStatus(),		-- use feed it to lookup feed status
		mAlt.numTicks,							-- add remaining stats to row
		mAlt.matches,
		min,
		max
	}

	view:publish()
end
