assert(LibStub, "LibRelativeTime-1.0 requires LibStub");

local lib, oldminor = LibStub:NewLibrary("LibRelativeTime-1.0", 1);
if not lib then return end
oldminor = oldminor or 0;

local function round(n)
    return n + (2^52 + 2^51) - (2^52 + 2^51);
end

local MINUTE_SECONDS = 60;
local HOUR_SECONDS = MINUTE_SECONDS * 60;
local DAY_SECONDS = HOUR_SECONDS * 24;

if (oldminor < 1) then
    lib.thresholds = {
        s = 45, -- seconds to minutes
        m = 45, -- minutes to hours
        h = 22, -- hours to days
    };
    lib.relativeTime = {
        s = "1 second",
        ss = "%d seconds",
        m = "1 minute",
        mm = "%d minutes",
        h = "1 hour",
        hh = "%d hours",
        d = "1 day",
        dd = "%d days",
    };
    lib.relativeTimeShort = {
        ss = "%d s",
        mm = "%d m",
        hh = "%d h",
        dd = "%d d",
    };

    local function durationAs(duration, seconds, unit)
        if (unit == "day") then
            return duration.day + (seconds - duration.day * DAY_SECONDS) / DAY_SECONDS;
        elseif (unit == "hour") then
            local h = duration.day * 24 + duration.hour;
            return h + (seconds - h * HOUR_SECONDS) / HOUR_SECONDS;
        elseif (unit == "minute") then
            local m = duration.day * 24 * 60 + duration.hour * 60 + duration.min;
            return m + (seconds - m * MINUTE_SECONDS) / MINUTE_SECONDS;
        else
            return seconds;
        end
    end

    local function formatTime(self, unit, amount, short)
        return string.format(short and self.relativeTimeShort[unit] or self.relativeTime[unit], amount);
    end

    function lib:ToDuration(duration)
        local d = date("!*t", duration);

        if (d.year > 0 or d.month > 0) then
            local noMonthSeconds = 
                d.sec +
                d.min * MINUTE_SECONDS +
                d.hour * HOUR_SECONDS +
                d.day * DAY_SECONDS
            local diff = duration - noMonthSeconds;
            d.day = d.day + diff / DAY_SECONDS;
            d.month = nil;
            d.year = nil;
        end

        return d;
    end

    function lib:Humanize(duration, short)
        local d = self:ToDuration(duration);

        local seconds,
              minutes,
              hours,
              days =
              round(durationAs(d, duration, "second")),
              round(durationAs(d, duration, "minute")),
              round(durationAs(d, duration, "hour")),
              round(durationAs(d, duration, "day"));

        if (short) then
            return
                seconds < self.thresholds.s and formatTime(self, "ss", seconds, short)
                or minutes < self.thresholds.m and formatTime(self, "mm", minutes, short)
                or hours < self.thresholds.h and formatTime(self, "hh", hours, short)
                or formatTime(self, "dd", days, short);
        end

        return
            seconds <= 1 and formatTime(self, "s")
            or seconds < self.thresholds.s and formatTime(self, "ss", seconds)
            or minutes <= 1 and formatTime(self, "m")
            or minutes < self.thresholds.m and formatTime(self, "mm", minutes)
            or hours <= 1 and formatTime(self, "h")
            or hours < self.thresholds.h and formatTime(self, "hh", hours)
            or days <= 1 and formatTime(self, "d")
            or formatTime(self, "dd", days);
    end
end