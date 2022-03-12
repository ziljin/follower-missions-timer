local _, addon = ...;

local fmod = math.fmod;
local strbyte = string.byte;
local strlen = string.len;

local function hash (text)
    local counter = 1
    local len = strlen(text)
    for i = 1, len, 3 do
        counter = fmod(counter*8161, 4294967279) +  -- 2^32 - 17: Prime!
            (strbyte(text,i)*16776193) +
            ((strbyte(text,i+1) or (len-i+256))*8372226) +
            ((strbyte(text,i+2) or (len-i+256))*3932164)
    end
    return fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
end

local function pack(...)
    local params = {};
    local n = select("#", ...);
    if (n > 0) then
        for i = 1, n do
            params[i] = select(i, ...);
        end
        params.n = n;
    end
    return params;
end

local function stopTimer(timer)
    if (timer ~= nil and not timer:IsCancelled()) then
        timer:Cancel();
    end
end

local function stringify (o)
    if type(o) == "table" then
        local s = "{ "
        for k,v in pairs(o) do
                if type(k) ~= "number" then k = '"'..k..'"' end
                s = s .. "["..k.."] = " .. stringify(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local function debounce (interval, delegate, distinct)
    if (distinct) then
        local timers = {};
        return function(...)
            local params = pack(...);
            local hash = addon.utils.hash(stringify(params));
            stopTimer(timers[hash]);
            timers[hash] = C_Timer.NewTicker(
                interval,
                function ()
                    stopTimer(timers[hash]);
                    timers[hash] = nil;
                    delegate(unpack(params));
                end,
                1
            );
        end
    end
    local timer = nil;
    return function(...)
        local params = pack(...);
        stopTimer(timer);
        timer = C_Timer.NewTicker(
            interval,
            function ()
                stopTimer(timer);
                timer = nil;
                delegate(unpack(params));
            end,
            1
        );
    end
end

addon.utils = {
    debounce = debounce,
    hash = hash,
    stringify = stringify
};