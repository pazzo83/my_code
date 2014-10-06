--- #######################
--- mdm_tutorial.lua
--- #######################

local gs = require 'geneos.sampler'
local md = require 'geneos.marketdata'
local cmd = require 'geneos.sampler.commands'
local ffi = require 'socket'

gs.logMessage('INFO', 'Entity name: ' .. gs.entityName)
gs.logMessage('INFO', 'Sampler name: ' .. gs.name)
gs.logMessage('INFO', 'Sampler type: ' .. gs.type)

for key,value in pairs(gs.params) do
	gs.logMessage('INFO', 'Parameter key=' .. key .. ', value=' .. value)
end

-- Subscribe to some data
local feedConfiguration = {
	feed = {
		type = "nyxt",
		["library.filename"] = "flm-feed-nyxt.so"
	},
	nyxt = {
		middleware = "wmw", transport = "df_sub", dictionary = { download="true", source="WOMBAT" }
	},
	instruments = {
		AAPL = "ABM.AAPL.ARCA",
		AMZN = "ABM.AMZN.ARCA"
	},
	fields = {
		Trade = "wTradePrice",
		Bid = "wBidPrice",
		Ask = "wAskPrice",
		Time = "wTradeTime"
	}
}

local tutorialFeed = md.addFeed("Test_NYSE", feedConfiguration)
tutorialFeed:start()

-- define columns and publish view
local cols = {	"instrument", "minSpread", "maxSpread", "ticksPerSample", "maxInterval", "avgAsk", "avgBid", "avgSpread", "geoAvgSpread", "stdDevBid", "stdDevAsk", "stdDevSpread", "skewSpread", "kurtosisSpread", "tradePrice" }
local view = assert(gs.createView("spreads", cols))
local totalTicks = 0
view.headline.totalTicks = totalTicks
view:publish()

-- utility function to round up values
local function roundFunc(value, idp)
	local mult = 10^(idp or 0)
	return not value or math.ceil(value * mult - 0.5) / mult
end

calculateRowStats = function(insName)
	local minSpread, maxSpread, maxInterval, tradePrice		-- default to nil values
	local sumBid, sumAsk, sumSpread, avgBid, avgAsk, avgSpread, geoAvgSpread = 0, 0, 0, 0, 0, 0, 0 -- default to 0 for avgs
	local tickCount, sumBidSq, sumAskSq, sumSpreadSq, sumSpread3, sumSpread4 = 0, 0, 0, 0, 0, 0    -- default of 0 for a count and variance calcs
	local stdDevBid, stdDevAsk, stdDevSpread, skewSpread, kurtosisSpread = 0, 0, 0, 0, 0 -- variance of bid, ask, and spread
	local multSpread = 1 -- used to calculate geom mean of spread, has to be set to "1" due to multiplication

	local tick = tutorialFeed:getTicks(insName)				-- grab ticks for this sample from the feed object

	if tick then
		local spread = tick.field.Ask - tick.field.Bid	-- note abs required as data is simulated
		local lastTime = tick.timeLast

		local getStatsFromTicks = function (t) -- function to get stats from tick table
			local count = 0
			while t.next do
				spread  = t.field.Ask - t.field.Bid	-- Derive the spread from bid and Ask
				sumSpread = sumSpread + spread
				sumAsk = sumAsk + t.field.Ask
				sumBid = sumBid + t.field.Bid

				multSpread = spread * multSpread
				
				if not minSpread or spread < minSpread then minSpread = spread end
				if not maxSpread or spread > maxSpread then maxSpread = spread end
				count = count + 1
				t = t.next
			end
			return
				{ -- table to return with our stats
					avgBid = (sumBid/count),
					avgAsk = (sumAsk/count),
					avgSpread = (sumSpread/count),
					geoAvgSpread = multSpread^(1/count),
					minSpread,
					maxSpread
				}
		end
		statsTable = getStatsFromTicks(tick)

		while tick.next do									-- iterate over the ticks
			local interval = tick.timeFirst - lastTime		-- work out interval since last tick
			spread  = tick.field.Ask - tick.field.Bid	-- Derive the spread from bid and Ask
			if not maxInterval or interval > maxInterval then maxInterval = interval end	-- Cal min and max values for the sample
			lastTime = tick.timeLast

			tickCount = tickCount + 1 -- count ticks

			-- getting variance here
			sumBidSq = (tick.field.Bid - statsTable.avgBid)^2 + sumBidSq
			sumAskSq = (tick.field.Ask - statsTable.avgAsk)^2 + sumAskSq
			sumSpreadSq = (spread - statsTable.avgSpread)^2 + sumSpreadSq

			-- to calculate skewness and kurtosis
			sumSpread3 = (spread - statsTable.avgSpread)^3 + sumSpread3
			sumSpread4 = (spread - statsTable.avgSpread)^4 + sumSpread4

			tick = tick.next
		end
		tradePrice = tick.field.Trade 						-- Trade price stored from the last tick
	end
	return
	{														-- Construct the table which forms the row for this instrument
		minSpread = roundFunc(minSpread, 4),					-- Utility function is used to round to 2 decimal places
		maxSpread = roundFunc(maxSpread, 4),
		ticksPerSample = tickCount,
		maxInterval = roundFunc(maxInterval, 4),
		avgBid = roundFunc(statsTable.avgBid, 2),
		avgAsk = roundFunc(statsTable.avgAsk, 2),
		avgSpread = roundFunc(statsTable.avgSpread, 4),
		geoAvgSpread = roundFunc(statsTable.geoAvgSpread, 4),
		stdDevBid = roundFunc(math.sqrt(sumBidSq/tickCount), 8), -- getting std dev by taking sqrt of variance
		stdDevAsk = roundFunc(math.sqrt(sumAskSq/tickCount), 8),
		stdDevSpread = roundFunc(math.sqrt(sumSpreadSq/tickCount), 8),
		skewSpread = roundFunc((sumSpread3/tickCount)/((sumSpreadSq/tickCount)^(3/2)), 8),
		kurtosisSpread = roundFunc((sumSpread4/tickCount)/((sumSpreadSq/tickCount)^2), 8),
		tradePrice = tradePrice
	},
	tickCount												-- also return the number of ticks observed
end

gs.doSample = function()
	for name,_ in pairs (feedConfiguration.instruments) do 	-- loop over each subscribed instrument
		local rowResult, additionalTicks = calculateRowStats(name)	-- Call calculateRowStats() which returns 2 values
		view.row[name] = rowResult									-- Apply the row data to the corresponding row
		totalTicks = totalTicks + additionalTicks					-- keep tally of total ticks observed
	end
	view.headline.totalTicks = totalTicks							-- update headline with latest tally
	view:publish()													-- publish the new view content
end

-- create the command and add to the headline
local c = cmd.newDefinition()
	:addHeadlineTarget(view, "totalTicks")					-- added to headline that matches the name 'totalTicks'

local resetTotalTicks = function(target,args)
	totalTicks = 0											-- reset counter
	view.headline.totalTicks = totalTicks 					-- update the view
	view:publish()											-- publish out updated view
end

assert(gs.publishCommand(
	"Reset Tick Count",										-- Name of the command, will appear like this as no path specified
	resetTotalTicks,										-- named function to execute
	c 														-- command definition passed in here
))