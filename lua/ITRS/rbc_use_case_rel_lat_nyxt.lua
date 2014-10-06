--- ##########################################
--- RBC Use Case 2.6.1
--- Two Sources - one symbol: relative latency
--- ##########################################

local sa = require "geneos.sampler"
local lt = require "geneos.latency"
local md = require "geneos.marketdata"

local fields = { Bid = "wBidPrice", BidSize = "wBidSize", Ask = "wAskPrice", AskSize = "wAskSize" }
local insts_abm = { AAPL = "ABM.AAPL.ARCA", AMZN = "ABM.AMZN.ARCA", BIDU = "ABM.BIDU.ARCA" }
local insts_abmcache = { AAPL = "ABM_CACHE.AAPL.ARCA", AMZN = "ABM_CACHE.AMZN.ARCA", BIDU = "ABM_CACHE.BIDU.ARCA" }
--local fields = { Trade = "TRDPRC_1", Change = "NETCHNG_1", Bid = "BID", BidVo = "BIDSIZE", Ask = "ASK", AskSize = "ASKSIZE" }
--local insts = { Bund = "IDN_SELECTFEED.Bund", DAX = "IDN_SELECTFEED.DAX", Eurostoxx = "IDN_SELECTFEED.Eurostoxx" }

-- Using a nyxt data source
local abm_otc =
{
	feed = { type = "nyxt", ["library.filename"] = "flm-feed-nyxt.so" },
	nyxt = { middleware = "wmw", transport = "df_sub", dictionary = { download="true", source="WOMBAT" } },
	instruments = insts_abm,
	fields = fields
}

local mamacache =
{
	feed = { type = "nyxt", ["library.filename"] = "flm-feed-nyxt.so" },
	nyxt = { middleware = "wmw", transport = "df_sub", dictionary = { download="true", source="WOMBAT" } },
	instruments = insts_abmcache,
	fields = fields
}

-- Example WriterCallBack function 
local function WriterCallBack(why, what)
	if why == 'sampleTime' then		-- SampleTime event
		print "Got sample..."
	else							-- otherwise is a tick event
		local tick = what
		--print(string.format("Tick %s.%s Bid:%s BidSize%s Ask:%s AskSize:%s", 
			--tick.feed, tick.inst, tick.field.Bid, tick.field.BidSize, tick.field.Ask, tick.field.AskSize))
	end
end

local ctx = lt.newContext()			-- create the context object here
	:addWriter(WriterCallBack)		-- register the writer WriterCallBack
	:setBase("abm_otc", abm_otc)	-- Register the base feed
	:addFeed("mamacache", mamacache)	-- add an alt feed
	:start()						-- start the system, will automatically start feed subscriptions

-- creating view
local view = sa.createView("LATENCY", { "feed", "status", "numTicks", "numMatches", "minLatency", "maxLatency" })
view.headline.baselineFeed = "abm_otc"
view:publish()						-- publish a stats view, similar to FLM latency view

local count = 0
sa.doSample = function()
	count = count + 1
	print("[latency] sample " .. count)

	ctx:sample()					-- instruct the latency context to update its stats
	local mBase = ctx:getMetrics("abm_otc")	-- grab metrics from base feed
	local mAlt = ctx:getMetrics("mamacache")	-- grab metrics from alt feed

	view.row = {}
	view.row["abm_otc"] = {
		ctx.base.feed:getStatus(),				-- status of base feed
		mBase.numTicks,							-- add remaining stats to row
		mBase.matches,
		"",										-- note base feed will have no latency stats
		""
	}

	local min = ""
	if(mAlt.latMin ~= nil) then
		min = string.format("%0.0f", mAlt.latMin * 1000)	-- handle formatting in case of nil value
	end
	local max = ""
	if(mAlt.latMax ~= nil) then
		max = string.format("%0.0f", mAlt.latMax * 1000)
	end

	local alt = ctx:getFeedNum("mamacache")		-- lookup the feed id for the alt-feed
	view.row["mamacache"] = {
		ctx.feeds[alt].feed:getStatus(),		-- use feed it to lookup feed status
		mAlt.numTicks,							-- add remaining stats to row
		mAlt.matches,
		min,
		max
	}

	view:publish()
end
