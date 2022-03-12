local name, addon = ...

local playerLoc;
local playerName;
local playerRealm;

local globalDB;
local profileDB;

local MINUTE_SECONDS = 60;
local HOUR_SECONDS = MINUTE_SECONDS * 60;
local DAY_SECONDS = HOUR_SECONDS * 24;

local DEFAULT_OPTIONS = {
    global = {
        classColor = true,
        crossRealm = true,
        mine = true,
        idle = {
            enable = true,
            upOnly = true,
            mineOnly = true,
        },
        size = "MEDIUM",
    },
	profile = {
        sync = true,
        -- "LAST" by default
        syncTypes = {
            [Enum.GarrisonFollowerType.FollowerType_9_0] = true,
        },
        lastSync = 0,
        minimap = { hide = false }
    },
}

local MODNAME	= "FollowerMissionsTimer"
FollowerMissionsTimer = CreateFrame("Frame", MODNAME);
FollowerMissionsTimer.idleCount = 0;
FollowerMissionsTimer.idleCountLevelling = 0;

local icon = LibStub("LibDBIcon-1.0");
local relativeTime = LibStub("LibRelativeTime-1.0");
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local function toggleCharacterSync(self)
    profileDB.sync = not profileDB.sync;
    for _, t in pairs(Enum.GarrisonFollowerType) do
        self:UpdateFollowers(t);
        self:UpdateTimers(t);
    end
    self:CheckTimers();
    self:CheckIdle();
    self:UpdateText();
end

local function toggleMinimapButton()
    local minimap = profileDB.minimap;
    minimap.hide = not minimap.hide;
    if (minimap.hide) then
        icon:Hide("FollowerMissionsTimer");
    else
        icon:Show("FollowerMissionsTimer");
    end
end

function FollowerMissionsTimer:ShowOptions()
    -- Blizzard bug, have to call twice to get to category
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.general);
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrames.general);
end

local function getFollowerType(followerTypeId)
    if (followerTypeId == Enum.GarrisonFollowerType.FollowerType_6_0 or
        followerTypeId == Enum.GarrisonFollowerType.FollowerType_6_2) then
        return "|cff996633[WoD]|r";
    end

    if (followerTypeId == Enum.GarrisonFollowerType.FollowerType_7_0) then
        return "|cff006600[Legion]|r";
    end

    if (followerTypeId == Enum.GarrisonFollowerType.FollowerType_8_0) then
        return "|cff990099[BfA]|r";
    end

    if (followerTypeId == Enum.GarrisonFollowerType.FollowerType_9_0) then
        return "|cff99ccff[SL]|r";
    end

    return "[Unknown]";
end

local function getCharacterName(character, server, showServer, highlightName)
    local result;
    if (showServer) then
        result = string.format("%s-%s", character, server:match("^([%a\192-\255]?[\128-\191]*[%a\192-\255]?[\128-\191]*[%a\192-\255]?[\128-\191]*)"));
    else
        result = character;
    end
    if (highlightName) then
        result = string.format("|cff00ff00%s|r", result);
    elseif (globalDB.classColor) then
        result = string.format("|c%s%s|r", select(4, GetClassColor(FMT_Data.classes[server][character])), result);
    end

    return result;
end

local function checkFollowerType(ready, pending)
    local previousFollowerTypeId = nil;
    local hideFollowerType = true;
    for _, counts in pairs(ready) do
        for followerTypeId in pairs(counts) do
            if (followerTypeId ~= previousFollowerTypeId) then
                if (previousFollowerTypeId == nil) then
                    previousFollowerTypeId = followerTypeId;
                else
                    hideFollowerType = false;
                    break;
                end
            end
        end
        if (not hideFollowerType) then
            break;
        end
    end
    if (hideFollowerType) then
        for _, mission in ipairs(pending) do
            if (mission.followerTypeId ~= previousFollowerTypeId) then
                if (previousFollowerTypeId == nil) then
                    previousFollowerTypeId = mission.followerTypeId;
                else
                    hideFollowerType = false;
                    break;
                end
            end
        end
    end

    return hideFollowerType;
end

local function checkServer(ready, pending)
    if (not globalDB.crossRealm) then
        return true;
    end
    local previousServer = nil;
    local hideServer = true;
    for _, counts in pairs(ready) do
        for _, server in pairs(counts) do
            if (server.server ~= previousServer) then
                if (previousServer == nil) then
                    previousServer = server.server;
                else
                    hideServer = false;
                    break;
                end
            end
        end
        if (not hideServer) then
            break;
        end
    end
    if (hideServer) then
        for _, mission in ipairs(pending) do
            if (mission.server ~= previousServer) then
                if (previousServer == nil) then
                    previousServer = mission.server;
                else
                    hideServer = false;
                    break;
                end
            end
        end
    end

    return hideServer;
end

local FollowerMissionsTimerLDB = LibStub("LibDataBroker-1.1"):NewDataObject("FollowerMissionsTimer", {
    type = "data source",
    text = "missions timer",
    OnClick = function(_, buttonPressed)
        if (buttonPressed == "LeftButton") then
            ShowGarrisonLandingPage(C_Garrison.GetLandingPageGarrisonType());
        elseif (buttonPressed == "RightButton") then
            FollowerMissionsTimer:ShowOptions();
        end
    end,
    OnTooltipShow = function(tooltip)
        local ready, pending = FollowerMissionsTimer:CheckTimers();

        tooltip:SetText("Follower Missions Timer");
        tooltip:AddLine(" ");

        local hideFollowerType = checkFollowerType(ready, pending);
        local hideServer = checkServer(ready, pending);

        for _, counts in pairs(ready) do
            for followerTypeId, count in pairs(counts) do
                tooltip:AddLine(
                    string.format(
                        "%s %s |cffc7c7cf%s|r",
                        getCharacterName(count.character, count.server, not hideServer, globalDB.mine and count.character == playerName and count.server == playerRealm),
                        hideFollowerType and "" or getFollowerType(followerTypeId),
                        count.count .. " mission" .. (count.count > 1 and "s" or "") .. " ready"),
                    1, 1, 1
                );
            end
        end

        local count = 0;
        for _, mission in ipairs(pending) do
            count = count + 1;
            local message = string.format(
                "%s %s |cffc7c7cf%s|r",
                getCharacterName(mission.player, mission.server, not hideServer, globalDB.mine and mission.player == playerName and mission.server == playerRealm),
                hideFollowerType and "" or getFollowerType(mission.followerTypeId),
                mission.name
            );
            tooltip:AddDoubleLine(message, relativeTime:Humanize(mission.timeLeft, true), 1, 1, 1, 0, 0.59, 0.78);

            if (globalDB.size == "SHORT" or
                globalDB.size == "MEDIUM" and count >= 10) then
                break;
            end
        end

        if (count < #pending) then
            tooltip:AddLine("+ another " .. (#pending - count) .. " missions", 1, 1, 1);
        end

        tooltip:AddLine(" ");
        tooltip:AddDoubleLine("Left-click", "open Missions", 0.851, 0.745, 0.133, 1, 1, 1);
        tooltip:AddDoubleLine("Right-click", " open Options", 0.851, 0.745, 0.133, 1, 1, 1);
        tooltip:AddDoubleLine("Type /fmt", " to see available commands", 0.851, 0.745, 0.133, 1, 1, 1);

        tooltip:Show();
    end,
    icon = "Interface\\Icons\\Garrison_Building_SparringArena",
});

local function clearData(character, followerTypeId, exclude)
    local removeIds = {};
    local _exclude = exclude or {};
    for k, v in pairs(character) do
        if (v.followerTypeId == followerTypeId and not _exclude[k]) then
            removeIds[#removeIds + 1] = k;
        end
    end
    for _, id in ipairs(removeIds) do
        character[id] = nil;
    end
end

function FollowerMissionsTimer:UpdateFollowers(followerTypeId)
    if (profileDB.sync == false) then
        FMT_Data.followers[playerRealm][playerName] = nil;
        return;
    end

    FMT_Data.followers[playerRealm][playerName] = FMT_Data.followers[playerRealm][playerName] or {};

    if (not profileDB.syncTypes[followerTypeId]) then
        FMT_Data.followers[playerRealm][playerName][followerTypeId] = nil;
        return;
    end

    local db = {};

    local followers = C_Garrison.GetFollowers(followerTypeId);
    if (followers == nil) then
        db = nil;
    else
        for _, follower in ipairs(followers) do
            if (follower.isCollected) then
                db[#db + 1] = {
                    id = follower.followerID,
                    isIdle = C_Garrison.GetFollowerMissionTimeLeftSeconds(follower.followerID) == nil,
                    isMaxLevel = follower.levelXP == 0,
                    name = follower.name
                };
            end
        end
    end

    FMT_Data.followers[playerRealm][playerName][followerTypeId] = db;
end

function FollowerMissionsTimer:UpdateTimers(followerTypeId)
    if (profileDB.sync == false) then
        FMT_Data.missions[playerRealm][playerName] = nil;
        return;
    end
    if (not profileDB.syncTypes[followerTypeId] and FMT_Data.missions[playerRealm][playerName] ~= nil) then
        clearData(FMT_Data.missions[playerRealm][playerName], followerTypeId);
        return;
    end

    local missions = C_Garrison.GetInProgressMissions(followerTypeId);

    FMT_Data.missions[playerRealm][playerName] = FMT_Data.missions[playerRealm][playerName] or {};
    local db = FMT_Data.missions[playerRealm][playerName];

    if (missions == nil) then
        clearData(db, followerTypeId);
    else
        local newMissionIds = {};
        for _, mission in ipairs(missions) do
            newMissionIds[mission.missionID] = true;
            db[mission.missionID] = { id = mission.missionID, name = mission.name, endTime = mission.missionEndTime, followerTypeId = mission.followerTypeID };
        end
        clearData(db, followerTypeId, newMissionIds);
    end

    profileDB.lastSync = GetServerTime();
    profileDB.version = globalDB.version;
end

function FollowerMissionsTimer:CheckTimers()
    local ctime = GetServerTime();
    local minTimeLeft = ctime;
    local minTimeLeftMine = ctime;
    local nextMissionEnd = nil;
    local nextMissionEndMine = nil;
    local ready = {};
    local pending = {};

    local readyCount = 0;
    local readyCountMine = 0;

    for realm, players in pairs(FMT_Data.missions) do
        if (globalDB.crossRealm or realm == playerRealm) then
            for player, missions in pairs(players) do
                local fullname = string.format("%s-%s", player, realm);
                for _, mission in pairs(missions) do
                    local mtime = mission.endTime;
                    local delta = mtime - ctime;
                    if (delta <= 0) then
                        ready[fullname] = ready[fullname] or {};
                        ready[fullname][mission.followerTypeId] = ready[fullname][mission.followerTypeId] or { count = 0, character = player, server = realm};
                        ready[fullname][mission.followerTypeId].count = ready[fullname][mission.followerTypeId].count + 1;
                        readyCount = readyCount + 1;
                        if (player == playerName and realm == playerRealm) then
                            readyCountMine = readyCountMine + 1;
                        end
                    else
                        pending[#pending + 1] = {
                            timeLeft = delta,
                            name = mission.name,
                            player = player,
                            followerTypeId = mission.followerTypeId,
                            server = realm,
                        };
                        if (delta < minTimeLeft) then
                            minTimeLeft = delta;
                            nextMissionEnd = mtime;
                        end
                        if (player == playerName and realm == playerRealm and delta < minTimeLeftMine) then
                            minTimeLeftMine = delta;
                            nextMissionEndMine = mtime;
                        end
                    end
                end
            end
        end
    end

    table.sort(pending, function (a, b) return a.timeLeft < b.timeLeft end);

    self.readyCount = readyCount;
    self.readyCountMine = readyCountMine;
    self.nextMissionEnd = nextMissionEnd;
    self.nextMissionEndMine = nextMissionEndMine;
    self.nextIn = nextMissionEnd ~= nil and minTimeLeft or nil;
    self.nextInMine = nextMissionEndMine ~= nil and minTimeLeftMine or nil;

    return ready, pending;
end

function FollowerMissionsTimer:CheckIdle()
    local followersData = FMT_Data.followers;
    local idle = {};
    local total = 0;
    local totalLevelling = 0;

    for realm, players in pairs(followersData) do
        if (globalDB.crossRealm or realm == playerRealm) then
            for player, followerTypes in pairs(players) do
                local fullname = string.format("%s-%s", player, realm);
                local playerTotal = 0;
                local playerTotalLevelling = 0;
                for followerType, followers in pairs(followerTypes) do
                    for _, follower in ipairs(followers) do
                        if (follower.isIdle) then
                            playerTotal = playerTotal + 1;
                            if (not follower.isMaxLevel) then
                                playerTotalLevelling = playerTotalLevelling + 1;
                            end
                        end
                    end
                end

                idle[fullname] = {
                    idleCount = playerTotal,
                    idleCountLevelling = playerTotalLevelling
                };
                total = total + playerTotal;
                totalLevelling = totalLevelling + playerTotalLevelling;
            end
        end
    end

    self.idle = idle;
    self.idleCount = total;
    self.idleCountLevelling = totalLevelling;
end

function FollowerMissionsTimer:UpdateText()
    local fullname = string.format("%s-%s", playerName, playerRealm);
    local mineCount = self.idle[fullname].idleCount;
    local mineCountLevelling = self.idle[fullname].idleCountLevelling;
    FollowerMissionsTimerLDB.text =
        addon.summary.getLabel(
            self.readyCount,
            self.nextIn,
            globalDB.mine,
            self.readyCountMine,
            self.nextInMine,
            globalDB.idle.enable,
            globalDB.idle.mineOnly and mineCount or self.idleCount,
            globalDB.idle.upOnly,
            globalDB.idle.mineOnly and mineCountLevelling or self.idleCountLevelling,
            mineCount,
            mineCountLevelling
        );
end

local function getNextInterval(endTime)
    local t = GetServerTime();
    local delta = endTime - t;

    if (delta <= 0) then
        return nil;
    end

    local d = relativeTime:ToDuration(delta);

    if (d.day > 1) then
        return d.hour > 1 and d.hour * HOUR_SECONDS or DAY_SECONDS;
    end

    if (d.day == 1) then
        return d.hour > 1 and d.hour * HOUR_SECONDS or HOUR_SECONDS;
    end
    
    if (d.hour > 1) then
        return d.min > 5 and d.min * MINUTE_SECONDS or HOUR_SECONDS;
    end

    if (d.hour == 1) then
        return d.min > 5 and d.min * MINUTE_SECONDS or MINUTE_SECONDS;
    end

    if (d.min > 1) then
        return MINUTE_SECONDS;
    end

    return 1;
end

function FollowerMissionsTimer:StartUpdateTextTimer(nextInterval)
    if (self.handle ~= nil and not self.handle:IsCancelled()) then
        self.handle:Cancel();
    end

    self:UpdateText();

    if (self.nextMissionEnd == nil) then
        return;
    end

    local interval = nextInterval or getNextInterval((self.nextMissionEndMine == nil or self.nextMissionEnd < self.nextMissionEndMine) and self.nextMissionEnd or self.nextMissionEndMine);
    if (interval == nil) then
        return;
    end
    self.interval = interval;

    self.handle = C_Timer.NewTicker(interval, function()
        local tickInterval = getNextInterval((self.nextMissionEndMine == nil or self.nextMissionEnd < self.nextMissionEndMine) and self.nextMissionEnd or self.nextMissionEndMine);
        if (tickInterval == nil) then
            self:CheckTimers();
            self:StartUpdateTextTimer();
            return;
        end

        local t = GetServerTime();
        self.nextIn = self.nextMissionEnd - t;
        self.nextInMine = self.nextMissionEndMine and self.nextMissionEndMine - t or nil;

        self:UpdateText();

        if (tickInterval ~= self.interval) then
            self:StartUpdateTextTimer(tickInterval);
        end
    end);
end

function FollowerMissionsTimer:SetupOptions()
    self.options = {
        name = "Follower Missions Timer",
        type = "group",
        args = {
            general = {
                order = 1,
                type = "group",
                name = "Options",
                cmdInline = true,
                args = {
                    header = {
                        type = "header",
                        name = "Display options",
                        order = 10,
                    },
                    classColor = {
                        order = 11,
                        type = "toggle",
                        name = "Highlight character names",
                        desc = "Toggle to highlight character names with class color. |cffD9BE22*global setting|r",
                        width = "full",
                        get = function()
                            return globalDB.classColor;
                        end,
                        set = function(_, value)
                            globalDB.classColor = value;
                        end,
                    },
                    crossRealm = {
                        order = 12,
                        type = "toggle",
                        name = "Enable cross realm display",
                        desc = "Toggle to show characters from all realms on the account. |cffD9BE22*global setting|r",
                        width = "full",
                        get = function()
                            return globalDB.crossRealm;
                        end,
                        set = function(_, value)
                            globalDB.crossRealm = value;
                            self:CheckTimers();
                            self:UpdateText();
                        end,
                    },
                    mine = {
                        order = 13,
                        type = "toggle",
                        name = "Highlight 'mine'",
                        desc = "Toggle to highlight current character missions. |cffD9BE22*global setting|r",
                        width = "full",
                        get = function()
                            return globalDB.mine;
                        end,
                        set = function(_, value)
                            globalDB.mine = value;
                            self:CheckTimers();
                            self:UpdateText();
                        end,
                    },
                    size = {
                        order = 14,
                        type = "select",
                        style = "dropdown",
                        name = "Tooltip size",
                        desc = "Choose the tooltip size to display. |cffD9BE22*global setting|r",
                        width = "double",
                        values = function()
                            return {
                                ["SHORT"] = "Only completed missions and the next one",
                                ["MEDIUM"] = "Completed and next 10 missions",
                                ["LONG"] = "Completed and all active missions",
                            }
                        end,
                        get = function()
                            return globalDB.size;
                        end,
                        set = function(_, value)
                            globalDB.size = value;
                        end,
                    },
                    minimap = {
                        order = 15,
                        type = "toggle",
                        width = "full",
                        name = "Hide minimap button",
                        desc = "Toggle to hide minimap button.",
                        get = function()
                            return profileDB.minimap.hide;
                        end,
                        set = function(_, value)
                            toggleMinimapButton();
                        end,
                    },
                    header2 = {
                        type = "header",
                        name = "Idle followers",
                        order = 20,
                    },
                    enable = {
                        order = 21,
                        type = "toggle",
                        width = "full",
                        name = "Show",
                        desc = "Show followers count who are not on a mission. |cffD9BE22*global setting|r",
                        get = function()
                            return globalDB.idle.enable;
                        end,
                        set = function(_, value)
                            globalDB.idle.enable = value;
                            self:CheckIdle();
                            self:UpdateText();
                        end,
                    },
                    levelling = {
                        order = 22,
                        type = "toggle",
                        width = "full",
                        name = "Levelling only",
                        desc = "Show levelling followers only. |cffD9BE22*global setting|r",
                        get = function()
                            return globalDB.idle.upOnly;
                        end,
                        set = function(_, value)
                            globalDB.idle.upOnly = value;
                            self:CheckIdle();
                            self:UpdateText();
                        end,
                    },
                    mineOnly = {
                        order = 23,
                        type = "toggle",
                        width = "full",
                        name = "Mine only",
                        desc = "Show current character followers only. |cffD9BE22*global setting|r",
                        get = function()
                            return globalDB.idle.mineOnly;
                        end,
                        set = function(_, value)
                            globalDB.idle.mineOnly = value;
                            self:CheckIdle();
                            self:UpdateText();
                        end,
                    },
                    header3 = {
                        type = "header",
                        name = "Data collect options",
                        order = 30,
                    },
                    sync = {
                        order = 31,
                        type = "toggle",
                        width = "full",
                        name = "Monitor current character",
                        desc = "Toggle to make current character to be monitored.",
                        get = function()
                            return profileDB.sync;
                        end,
                        set = function(_, value)
                            toggleCharacterSync(self);
                        end,
                    },
                    syncTypes = {
                        order = 32,
                        type = "multiselect",
                        name = "Mission types:",
                        desc = "Choose mission types to monitor",
                        values = function()
                            return {
                                [1] = "Warlords of Draenor",
                                [2] = "Warlords of Draenor (Naval)",
                                [4] = "Legion Class Hall",
                                [22] = "Battle for Azeroth",
                                [123] = "Shadowlands Covenant",
                            }
                        end,
                        get = function(_, key)
                            return profileDB.syncTypes[key];
                        end,
                        set = function(_, key, value)
                            profileDB.syncTypes[key] = value;
                            self:UpdateFollowers(key);
                            self:UpdateTimers(key);
                            self:CheckTimers();
                            self:UpdateText();
                        end,
                        disabled = function()
                            return not profileDB.sync;
                        end,
                    },
                },
            },
        },
    };

	self.options.args.profile = AceDBOptions:GetOptionsTable(self.db);
	self.options.args.profile.order = -2;

	AceConfig:RegisterOptionsTable(MODNAME, self.options, nil);

	self.optionsFrames = {};
	self.optionsFrames.general = AceConfigDialog:AddToBlizOptions(MODNAME, self.options.name, nil, "general");
	self.optionsFrames.profile = AceConfigDialog:AddToBlizOptions(MODNAME, "Profiles", self.options.name, "profile");
end

function FollowerMissionsTimer:OnProfileChanged(_, database)
	profileDB = database.profile;

    for _, t in pairs(Enum.GarrisonFollowerType) do
        self:UpdateFollowers(t);
        self:UpdateTimers(t);
    end
    self:CheckTimers();
    self:CheckIdle();
    self:UpdateText();
end

local function registerSlashCommands(self)
    SLASH_FMT1 = "/fmt";
    SLASH_FMT2 = "/followermissionstimer";
    SlashCmdList["FMT"] = function(msg)
        local m = { strsplit(" ", msg or "help") };
        if (m[1] == "" or m[1] == "help") then
            print("/fmt [help] - commands help");
            print("/fmt config - open options dialog");
            print("/fmt minimap - toggle minimap button");
            print("/fmt character - toggle missions monitor for this character");
            print("/fmt class - toggle character names to be class color (global setting)");
            print("/fmt type {WOD|LEGION|BFA|SL|LAST|ALL} - toggle missions monitor for an expansion (for this character). 'LAST' makes the last expansion monitored only. 'ALL' makes all expansions to be monitored.");
            print("/fmt size {SHORT|MEDIUM|LONG} - set missions monitor list size (global setting). For 'SHORT' only ready and the next mission will be listed. For 'MEDIUM' list will include all ready lines and 10 next missions (default). 'LONG' will list everything.");
            print("/fmt server - toggle display of cross realm missions (global setting)");
        elseif (m[1] == "config") then
            self:ShowOptions();
        elseif (m[1] == "minimap") then
            toggleMinimapButton();
        elseif (m[1] == "character") then
            toggleCharacterSync(self)
            print(profileDB.sync and playerName .. " is now monitored." or playerName .. " is not monitored anymore.");
        elseif (m[1] == "class") then
            globalDB.classColor = not globalDB.classColor;
            print(globalDB.classColor and "Character names are now colored by class." or "Character names are not colored by class now.");
        elseif (m[1] == "server") then
            globalDB.crossRealm = not globalDB.crossRealm;
            print(globalDB.crossRealm and "Cross realm missions are now shown." or "Current realm missions are shown only.");
            self:CheckTimers();
            self:CheckIdle();
            self:UpdateText();
        elseif (m[1] == "type") then
            if (m[2] == nil or m[2] == "") then
                print("Follower mission type is missing. Please provide one of the values: WOD, LEGION, BFA, SL, LAST, ALL.");
            else
                local syncTypes = profileDB.syncTypes;
                local type = strupper(m[2]);
                if (type == "WOD") then
                    syncTypes[Enum.GarrisonFollowerType.FollowerType_6_0] = not syncTypes[Enum.GarrisonFollowerType.FollowerType_6_0];
                    syncTypes[Enum.GarrisonFollowerType.FollowerType_6_2] = syncTypes[Enum.GarrisonFollowerType.FollowerType_6_0];
                    self:UpdateFollowers(Enum.GarrisonFollowerType.FollowerType_6_0);
                    self:UpdateFollowers(Enum.GarrisonFollowerType.FollowerType_6_2);
                    self:UpdateTimers(Enum.GarrisonFollowerType.FollowerType_6_0);
                    self:UpdateTimers(Enum.GarrisonFollowerType.FollowerType_6_2);
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("Warlords of Draenor missions are " .. (syncTypes[Enum.GarrisonFollowerType.FollowerType_6_0] and "now monitored." or "not monitored anymore."));
                elseif (type == "LEGION") then
                    syncTypes[Enum.GarrisonFollowerType.FollowerType_7_0] = not syncTypes[Enum.GarrisonFollowerType.FollowerType_7_0];
                    self:UpdateFollowers(Enum.GarrisonFollowerType.FollowerType_7_0);
                    self:UpdateTimers(Enum.GarrisonFollowerType.FollowerType_7_0);
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("Legion missions are " .. (syncTypes[Enum.GarrisonFollowerType.FollowerType_7_0] and "now monitored." or "not monitored anymore."));
                elseif (type == "BFA") then
                    syncTypes[Enum.GarrisonFollowerType.FollowerType_8_0] = not syncTypes[Enum.GarrisonFollowerType.FollowerType_8_0];
                    self:UpdateFollowers(Enum.GarrisonFollowerType.FollowerType_8_0);
                    self:UpdateTimers(Enum.GarrisonFollowerType.FollowerType_8_0);
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("Battle for Azeroth missions are " .. (syncTypes[Enum.GarrisonFollowerType.FollowerType_8_0] and "now monitored." or "not monitored anymore."));
                elseif (type == "SL") then
                    syncTypes[Enum.GarrisonFollowerType.FollowerType_9_0] = not syncTypes[Enum.GarrisonFollowerType.FollowerType_9_0];
                    self:UpdateFollowers(Enum.GarrisonFollowerType.FollowerType_9_0);
                    self:UpdateTimers(Enum.GarrisonFollowerType.FollowerType_9_0);
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("Shadowlands missions are " .. (syncTypes[Enum.GarrisonFollowerType.FollowerType_9_0] and "now monitored." or "not monitored anymore."));
                elseif (type == "LAST") then
                    profileDB.syncTypes = {
                        [Enum.GarrisonFollowerType.FollowerType_6_0] = nil,
                        [Enum.GarrisonFollowerType.FollowerType_6_2] = nil,
                        [Enum.GarrisonFollowerType.FollowerType_7_0] = nil,
                        [Enum.GarrisonFollowerType.FollowerType_8_0] = nil,
                        [Enum.GarrisonFollowerType.FollowerType_9_0] = true,
                    };
                    for _, t in pairs(Enum.GarrisonFollowerType) do
                        self:UpdateFollowers(t);
                        self:UpdateTimers(t);
                    end
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("Only Shadowlands missions are monitored now.");
                elseif (type == "ALL") then
                    for _, t in pairs(Enum.GarrisonFollowerType) do
                        profileDB.syncTypes[t] = true;
                        self:UpdateFollowers(t);
                        self:UpdateTimers(t);
                    end
                    self:CheckTimers();
                    self:CheckIdle();
                    self:UpdateText();
                    print("All mission types are monitored now.");
                else
                    print("Unknown mission type: " .. m[2]);
                end
            end
        elseif (m[1] == "size") then
            if (m[2] == nil or m[2] == "") then
                print("List size is missing. Please provide one of the values: SHORT, MEDIUM, LONG.");
            else
                local size = strupper(m[2]);
                if (size == "SHORT") then
                    globalDB.size = size;
                    print("List now has short length. Only ready missions and the next one will be shown.");
                elseif (size == "MEDIUM") then
                    globalDB.size = size;
                    print("List now has medium length. Only ready missions and 10 next will be shown.");
                elseif (size == "LONG") then
                    globalDB.size = size;
                    print("List now has long length. Full list will be shown.");
                else
                    print("Unknown size: " .. m[2]);
                end
            end
        else
            print("Unknown command: " .. m[1]);
        end
    end
end

local function upgradeDb()
    if (FMT_Data.Version < 3) then
        for _, realm in pairs(FMT_Data.Settings) do
            for _, character in pairs(realm) do
                if (type(character.minimap) == "boolean") then
                    character.minimap = { hide = not character.minimap };
                end
                -- "LAST" by default
                character.syncTypes = {
                    [Enum.GarrisonFollowerType.FollowerType_9_0] = true,
                };
            end
        end

        FMT_Data.Version = 3;
    end

    if (FMT_Data.Version < 4) then
        local realms = {};
        for realmName, realm in pairs(FMT_Data.Settings) do
            realms[realmName] = realm;
        end
        FMT_Data.Settings = {
            classColor = true,
            profiles = realms,
        };

        FMT_Data.Version = 4;
    end

    if (FMT_Data.Version < 5) then
        FMT_Data.Settings.size = "MEDIUM";

        FMT_Data.Version = 5;
    end

    if (FMT_Data.Version < 6) then
        if (FMT_Data.Settings.profiles == nil) then
            FMT_Data.Settings = {
                classColor = true,
                size = "MEDIUM",
                profiles = {},
            };
        end

        FMT_Data.Version = 6;
    end

    if (FMT_Data.Version < 7) then
        FMT_Data.Settings.crossRealm = true;

        FMT_Data.Version = 7;
    end

    local version = FMT_Options.global.version or 0;

    if (version < 1) then
        if (FMT_Data.Settings) then
            FMT_Options = {
                global = {
                    classColor = FMT_Data.Settings.classColor,
                    crossRealm = FMT_Data.Settings.crossRealm,
                    size = FMT_Data.Settings.size,
                    version = 1,
                },
            };

            FMT_Options.profileKeys = {};
            FMT_Options.profiles = {};

            FMT_Data.classes = {};
            FMT_Data.missions = FMT_Data.Data;
            FMT_Data.Data = nil;

            for realm, characters in pairs(FMT_Data.Settings.profiles) do
                FMT_Data.classes[realm] = {};

                for char, opts in pairs(characters) do
                    local key = char .. " - " .. realm;
                    FMT_Options.profileKeys[key] = key;

                    FMT_Options.profiles[key] = {};
                    local newOpts = FMT_Options.profiles[key];
                    newOpts.syncTypes = opts.syncTypes;
                    newOpts.sync = opts.sync;
                    newOpts.minimap = opts.minimap;

                    FMT_Data.classes[realm][char] = opts.class;
                end
            end

            FMT_Data.Settings = nil;
        else
            FMT_Options.global.version = 1;
        end
    end

    if (version < 2) then
        FMT_Data.followers = {};
        FMT_Options.global.version = 2;
    end
end

local function onevent(self, event, arg1, ...)
    if (event == "ADDON_LOADED" and name == arg1) then
        FMT_Data = FMT_Data or
            {
                Version = 7,
                classes = {},
                followers = {},
                missions = {},
            };
        FMT_Options = FMT_Options or {
            global = {
                version = 2,
            }
        };
        print("Follower Missions Timer is loaded.");
        self:UnregisterEvent("ADDON_LOADED");
    end
    if (event == "PLAYER_LOGIN") then
        playerLoc = PlayerLocation:CreateFromUnit("player");
        playerName = C_PlayerInfo.GetName(playerLoc);
        playerRealm = GetNormalizedRealmName();

        upgradeDb();

        self.db = AceDB:New("FMT_Options", DEFAULT_OPTIONS, true);
        if (not self.db) then
            print("Error: Database not loaded correctly. Please exit WoW and delete FollowerMissionsTimer.lua file in: \\World of Warcraft\\_retail_\\WTF\\Account\\<Account Name>\\SavedVariables\\");
        end

        self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
        self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
        self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

        globalDB = self.db.global;
        profileDB = self.db.profile;

        FMT_Data.classes[playerRealm] = FMT_Data.classes[playerRealm] or {};
        FMT_Data.classes[playerRealm][playerName] = select(2, C_PlayerInfo.GetClass(playerLoc));

        FMT_Data.missions[playerRealm] = FMT_Data.missions[playerRealm] or {};
        FMT_Data.followers[playerRealm] = FMT_Data.followers[playerRealm] or {};

        registerSlashCommands(self);

        icon:Register("FollowerMissionsTimer", FollowerMissionsTimerLDB, profileDB.minimap);

        self:SetupOptions();

        -- self:CheckTimers();
        -- self:CheckIdle();
        -- self:StartUpdateTextTimer();

        self.debouncedUpdate = addon.utils.debounce(
            0.2,
            function(type)
                self:UpdateFollowers(type);
                self:UpdateTimers(type);
                self:CheckTimers();
                self:CheckIdle();
                self:StartUpdateTextTimer();
            end,
            true
        );
        self:RegisterEvent("GARRISON_MISSION_LIST_UPDATE");
        self:UnregisterEvent("PLAYER_LOGIN");
    end
    if (event == "GARRISON_MISSION_LIST_UPDATE") then
        self.debouncedUpdate(arg1);
    end
end

FollowerMissionsTimer:RegisterEvent("ADDON_LOADED");
FollowerMissionsTimer:RegisterEvent("PLAYER_LOGIN");
FollowerMissionsTimer:SetScript("OnEvent", onevent);
