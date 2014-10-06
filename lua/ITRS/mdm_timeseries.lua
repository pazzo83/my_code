--- #######################
--- mdm_tutorial.lua
--- #######################
local math = require 'math'
local sqrt = math.sqrt

local gs = require 'geneos.sampler'
local md = require 'geneos.marketdata'
local cmd = require 'geneos.sampler.commands'

--- time series stuff
local analysisChain = require("netprobe.timeseries.timeseries")
local ArrayEmitter = require 'netprobe.netprobe'.ArrayEmitter

local function pp(val) print(inspect(val)) end
local function passThrough(data)
  pp(data)
  return data
end 

-- Print anything - including nested tables
local function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("[%s] => table\n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("(\n");
        table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write(")\n");
      else
        io.write(string.format("[%s] => %s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end


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
local cols = {  "instrument", "minSpread", "maxSpread", "ticksPerSample", "maxInterval", "tradePrice" }
local view = assert(gs.createView("spreads", cols))
local totalTicks = 0
view.headline.totalTicks = totalTicks
view:publish()

-- utility function to round up values
local function round2dp(value)
  return not value or math.ceil(value * 100 - 0.5) / 100
end

-- filter to get correct price
local tickChain = analysisChain {rtChecks = true}
  :select {'timeLast', price = function(d) sqrt(d.field.Ask*d.field.Bid) end } 

calculateRowStats = function(insName)
  local minSpread, maxSpread, maxInterval, tradePrice   -- default to nil values
  local tickCount = 0                   -- default of 0 for a count
  local tick = tutorialFeed:getTicks(insName)       -- grab ticks for this sample from the feed object

  if tick then

    local src = ArrayEmitter(tick, 'data')

    local function pumpData()
      src:emitAll()
      src = ArrayEmitter(tick, 'data')
    end

    local results = tickChain
      :iWindow('timeLast', analysisChain.iVolatility(5, 10, "price"))
      :connectTo('data', src)
      :keepAllView()
    pumpData()
    gs.logMessage('INFO', "Timeseries: ".. results:count())

    local spread = tick.field.Ask - tick.field.Bid
    local lastTime = tick.timeLast

    while tick.next do                  -- iterate over the ticks
      local interval = tick.timeFirst - lastTime    -- work out interval since last tick
      spread  = math.abs(tick.field.Ask - tick.field.Bid) -- Derive the spread from bid and Ask
      tickCount = tickCount + 1
      if not maxInterval or interval > maxInterval then maxInterval = interval end  -- Cal min and max values for the sample
      if not minSpread or spread < minSpread then minSpread = spread end
      if not maxSpread or spread > maxSpread then maxSpread = spread end
      lastTime = tick.timeLast
      tick = tick.next
    end
    tradePrice = tick.field.Trade             -- Trade price stored from the last tick
  end
  return
  {                           -- Construct the table which forms the row for this instrument
    minSpread = round2dp(minSpread),          -- Utility function is used to round to 2 decimal places
    maxSpread = round2dp(maxSpread),
    ticksPerSample = tickCount,
    maxInterval = round2dp(maxInterval),
    tradePrice = tradePrice
  },
  tickCount                       -- also return the number of ticks observed
end

gs.doSample = function()
  for name,_ in pairs (feedConfiguration.instruments) do  -- loop over each subscribed instrument
    local rowResult, additionalTicks = calculateRowStats(name)  -- Call calculateRowStats() which returns 2 values
    view.row[name] = rowResult                  -- Apply the row data to the corresponding row
    totalTicks = totalTicks + additionalTicks         -- keep tally of total ticks observed
  end
  view.headline.totalTicks = totalTicks             -- update headline with latest tally
  view:publish()                          -- publish the new view content
end

-- create the command and add to the headline
local c = cmd.newDefinition()
  :addHeadlineTarget(view, "totalTicks")          -- added to headline that matches the name 'totalTicks'

local resetTotalTicks = function(target,args)
  totalTicks = 0                      -- reset counter
  view.headline.totalTicks = totalTicks           -- update the view
  view:publish()                      -- publish out updated view
end

assert(gs.publishCommand(
  "Reset Tick Count",                   -- Name of the command, will appear like this as no path specified
  resetTotalTicks,                    -- named function to execute
  c                             -- command definition passed in here
))