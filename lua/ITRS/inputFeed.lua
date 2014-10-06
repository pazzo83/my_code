
require "math"

--[[
                 Instrument publishing
                 =====================
--]]

-- The instruments this feed is subscribed to.
-- Maps from the instrument name (as a string) to a tick record (which we use for publishing).
-- This instrument mapping is updated in response to subscribe/unsubscribe events received from Netprobe.
local subscribed_instruments = {}

-- Field value random range (populated from feed parameters near the end of the script)
local minValue, maxValue

-- Updates each field value to a random value in the parameterized range [minValue, maxValue].
local function randomizeFieldValues(tick)
    for fieldName,_ in pairs(tick.fields) do
        tick.fields[fieldName] = math.random(minValue, maxValue)
    end
end

-- Updates all instrument records with new random field values and publishes these to Netprobe.
local function updateAndPublishAll()
    for instrumentName,tick in pairs(subscribed_instruments) do
        tick.time = feed.gettimeofday() -- Set time to current time
        randomizeFieldValues(tick)      -- Set field values
        feed.publish(tick)              -- Publish
    end
end

--[[
                 Event processing
                 ================
--]]

local INFO = feed.logLevel.INFO

-- Controls the main feed loop
-- The feed will continue to run until this variable becomes false
local run = true

-- Event processing handler functions
local handler_map = {
    terminate = function(event)
        feed.logMessage(INFO, "Terminate event received, ending feed script")
        run = false
    end,
    subscribe = function(event)
        -- Create a tick for the requested instrument, used for publishing
        local inst = event
        inst.type = nil
        inst.time = { sec=0, usec=0 }
        -- Register the instrument
        subscribed_instruments[event.instrument] = inst
        feed.logMessage(INFO, "Added subscription for instrument '", event.instrument, "'")
    end,
    unsubscribe = function(event)
        -- Unregister the specified instrument
        subscribed_instruments[event.instrument] = nil
        feed.logMessage(INFO, "Removed subscription for instrument '", event.instrument, "'")
    end
}
-- Checks for events from the FLM plug-in and handles them
local function checkEvents(timeout)
    -- Wait for an event (with optional timeout)
    local event = feed.getEvent(timeout)
    while event do
        local handler_func = handler_map[event.type]
        if handler_func then
            -- Call the handler function, passing the event
            handler_func(event)
        end
        event = feed.getEvent()
    end
end

--[[
                 Main loop
                 =========
--]]

-- The "feed" global object is created by the Lua Feed Adapter Library (flm-feed-lua.so)

-- Display all parameters passed to us
feed.logMessage(feed.logLevel.INFO, "Parameters:")
for k,v in pairs(feed.params) do
    feed.logMessage(INFO, string.format("Parameter '%s' has value '%s'", k, v))
end
feed.logMessage(INFO, "")

-- Extract parameters for this feed
minValue = feed.params["lua.value.min"] or 1
maxValue = feed.params["lua.value.max"] or 1000
feed.logMessage(INFO, "Using minimum = ", minValue)
feed.logMessage(INFO, "Using maximum = ", maxValue)

-- The feed event loop
while (run) do
    checkEvents()
    updateAndPublishAll()
    feed.sleep(1.0)
end

