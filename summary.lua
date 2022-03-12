local _, addon = ...;

local relativeTime = LibStub("LibRelativeTime-1.0");

local function getReadyCountText(readyCount, next)
    if (readyCount == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return
        string.format(
            "%s ready",
            readyCount
        );
end

local function getReadyCountMineText(readyCount, highlightMine, readyCountMine, next)
    if (not highlightMine or readyCount == 0 or readyCountMine == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return
        string.format(
            "%s%s ready",
            readyCountMine > 0 and readyCountMine < readyCount and string.format("|cff00ff00%s|r/", readyCountMine) or "",
            readyCount == readyCountMine and string.format("|cff00ff00%s|r", readyCount) or readyCount
        );
end

local function getNextMineTimerText(short, nextIn, highlightMine, nextInMine, next)
    if (not highlightMine or nextIn == nil or nextInMine == nil) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    if (nextIn >= nextInMine) then
        return
            string.format(
                "|cff00ff00%s|r",
                relativeTime:Humanize(nextInMine, short)
        );
    else
        return
            string.format(
                "%s/|cff00ff00%s|r",
                relativeTime:Humanize(nextIn, short),
                relativeTime:Humanize(nextInMine, short)
        );
    end 
end

local function getNextTimerText(short, nextIn, next)
    if (nextIn == nil) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return relativeTime:Humanize(nextIn, short);
end

local function getIdleCountText(onlyLevelling, count, next)
    if (onlyLevelling or count == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return string.format("%s idle", count);
end

local function getIdleCountMineText(onlyLevelling, highlightMine, count, countMine, next)
    if (onlyLevelling or count == 0 or highlightMine and countMine == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return string.format(
        "%s%s idle",
        countMine > 0 and countMine < count and string.format("|cff00ff00%s|r/", countMine) or "",
        count == countMine and string.format("|cff00ff00%s|r", count) or count
    );
end

local function getIdleLevellingCountText(onlyLevelling, countLevelling, next)
    if (not onlyLevelling or countLevelling == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return string.format("%s idle", countLevelling);
end

local function getIdleLevellingCountMineText(
    onlyLevelling,
    highlightMine,
    countLevelling,
    countLevellingMine,
    next
)
    if (not onlyLevelling or countLevelling == 0 or highlightMine and countLevellingMine == 0) then
        if (next) then
            return next();
        else
            return nil;
        end
    end

    return string.format(
        "%s%s idle",
        countLevellingMine > 0 and countLevellingMine < countLevelling and string.format("|cff00ff00%s|r/", countLevellingMine) or "",
        countLevelling == countLevellingMine and string.format("|cff00ff00%s|r", countLevelling) or countLevelling
    );
end

local function getCountLabelPart(readyCount, highlightMine, readyCountMine)
    return
        getReadyCountMineText(
            readyCount,
            highlightMine,
            readyCountMine,
            function ()
                return getReadyCountText(readyCount);
            end
        );
end

local function getNextLabelPart(nextIn, highlightMine, nextInMine, short)
    return
        getNextMineTimerText(
            short,
            nextIn,
            highlightMine,
            nextInMine,
            function ()
                return getNextTimerText(short, nextIn);
            end
        );
end

local function getIdleLabelPart(
    enabled,
    hightlightMine,
    count,
    countMine,
    onlyLevelling,
    countLevelling,
    countLevellingMine
)
    if (not enabled) then
        return nil;
    end

    return getIdleLevellingCountMineText(
        onlyLevelling,
        hightlightMine,
        countLevelling,
        countLevellingMine,
        function ()
            return getIdleLevellingCountText(
                onlyLevelling,
                countLevelling,
                function ()
                    return getIdleCountMineText(
                        onlyLevelling,
                        hightlightMine,
                        count,
                        countMine,
                        function ()
                            return getIdleCountText(onlyLevelling, count);
                        end
                    );
                end
            );
        end
    );
end

local function getLabel(
    readyCount,
    nextIn,
    highlightMine,
    readyCountMine,
    nextInMine,
    showIdle,
    idleCount,
    showIdleLevellingOnly,
    idleCountLevelling,
    idleCountMine,
    idleCountLevellingMine
)
    local countText = getCountLabelPart(readyCount, highlightMine, readyCountMine);

    local idleText = getIdleLabelPart(
        showIdle,
        highlightMine,
        idleCount,
        idleCountMine,
        showIdleLevellingOnly,
        idleCountLevelling,
        idleCountLevellingMine
    );

    local nextText = getNextLabelPart(
        nextIn,
        highlightMine,
        nextInMine,
        countText ~= nil or idleText ~= nil
    );

    local parts = {};
    parts[#parts + 1] = countText;
    parts[#parts + 1] = nextText;
    parts[#parts + 1] = idleText;

    local result = table.concat(parts, ", ");
    return result or "no missions";
end

addon.summary = {
    getLabel = getLabel
};
