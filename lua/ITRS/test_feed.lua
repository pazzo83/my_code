local md = require "geneos.marketdata"
local sa = require "geneos.sampler"
 
local eg_instrument_map = { 
    Some = "SomeInstrumentName", 
    Other = "SomeOtherInstrumentName",
    }
 
local eg_field_map = { Trade = "TRDPRC_1", Bid = "BID", Ask = "ASK", FeedTime = "DateTime" }
 
local eg = md.addFeed("example",
        {
            feed = { 
                type = "example", library = { filename = "flm-feed-example", skipVersionCheck = "true" },
            },
            example = { publishingPeriod = "2000" },
            instruments = eg_instrument_map,
            fields = eg_field_map,
        }
    )
 
eg:start()
 
local cols = {"Tick", "Rate", "Trade", "Bid", "Ask", "FeedTime", "ReceivedTime"}
local view = sa.createView("Example", cols)
 
local function instAsRow(inst)
    local rate = 0
    view.row[inst] = { Rate = 0 }
 
    local tick = eg:getTicks(inst)
    while tick do
        rate = rate + 1
        for i = 3, #cols do
            local col = cols[i]
            view.row[inst][col] = tick.field[col]
        end
        -- Get seconds and fraction and format them nicely
        local recv_sec, recv_frac = math.modf(tick.timeFirst)
        view.row[inst].ReceivedTime = os.date("%Y-%m-%d %H:%M:%S", recv_sec)..string.format(".%03d", recv_frac * 1000)
        -- get next tick
        tick = tick.next
    end
 
    view.row[inst].Rate = rate
end
 
sa.doSample = function()
 
    instAsRow("Some")
    instAsRow("Other")
 
    view.headline.samplingStatus = eg:getStatus()
    print(sa.name, "publishing")
    view:publish()
end