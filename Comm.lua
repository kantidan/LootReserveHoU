local LibDeflate = LibStub:GetLibrary("LibDeflate");

LootReserveHoU = LootReserveHoU or { };
LootReserveHoU.Comm =
{
    Prefix    = "LootReserveHoU",
    Handlers  = { },
    Listening = false,
};

local Opcodes =
{
    Version                   = 1,
    ReportIncompatibleVersion = 2,
    Hello                     = 3,
    SessionInfo               = 4,
    SessionStop               = 5,
    SessionReset              = 6,
    ReserveItem               = 7,
    ReserveResult             = 8,
    ReserveInfo               = 9,
    CancelReserve             = 10,
    CancelReserveResult       = 11,
    RequestRoll               = 12,
    PassRoll                  = 13,
    DeletedRoll               = 14,
    OptOut                    = 15,
    OptIn                     = 16,
    OptResult                 = 17,
    OptInfo                   = 18,
    SendWinner                = 19,
};

local LAST_UNCOMPRESSED_OPCODE = Opcodes.Hello;
local MAX_UNCOMPRESSED_SIZE = 20;

local function ThrottlingError()
    LootReserveHoU:ShowError("There was an error when reading session host's communications.|n|nIf both your and the host's addons are up to date, then this is likely due to Blizzard's excessive addon communication throttling which results in some messages outright not being delivered.|n|nWait a few seconds and click \"Search For Host\" in LootReserveHoU client window's settings menu to request up to date information from the host.");
end

function LootReserveHoU.Comm:SendCommMessage(channel, target, opcode, ...)
    -- local opKey;
    -- for k, v in pairs(Opcodes) do
    --     if v == opcode then
    --         opKey = k;
    --         break;
    --     end
    -- end
    -- LootReserveHoU:debug(channel, target, opKey or opcode, ...);
    
    local message = "";
    for _, part in ipairs({ ... }) do
        if type(part) == "boolean" then
            message = message .. tostring(part and 1 or 0) .. "|";
        else
            message = message .. tostring(part) .. "|";
        end
    end

    if opcode > LAST_UNCOMPRESSED_OPCODE then
        local length = #message;
        if length > MAX_UNCOMPRESSED_SIZE then
            message = LibDeflate:CompressDeflate(message);
            message = LibDeflate:EncodeForWoWAddonChannel(message);
        else
            length = -length;
        end
        message = length .. "|" .. message;
    end
    
    if channel ~= "WHISPER" or target and LootReserveHoU:IsMe(target) then
        local length
        local message = message
        if opcode > LAST_UNCOMPRESSED_OPCODE then
            length, message = strsplit("|", message, 2);
            length = tonumber(length);

            if length > 0 then
                message = LibDeflate:DecodeForWoWAddonChannel(message);
                message = message and LibDeflate:DecompressDeflate(message);
            end
        end
        C_Timer.After(0, function() self.Handlers[opcode](LootReserveHoU:Me(), strsplit("|", message)) end);
    end

    message = opcode .. "|" .. message;

    LootReserveHoU:SendCommMessage(self.Prefix, message, channel, target, "ALERT");

    return message;
end

function LootReserveHoU.Comm:StartListening()
    if not self.Listening then
        self.Listening = true;
        LootReserveHoU:RegisterComm(self.Prefix, function(prefix, text, channel, sender)
            if LootReserveHoU.Enabled and prefix == self.Prefix then
                local opcode, message = strsplit("|", text, 2);
                opcode = tonumber(opcode);
                if not opcode or not message then
                    return ThrottlingError();
                end

                local handler = self.Handlers[opcode];
                if handler then
                    local length;
                    if opcode > LAST_UNCOMPRESSED_OPCODE then
                        length, message = strsplit("|", message, 2);
                        length = tonumber(length);
                        if not length or not message then
                            return ThrottlingError();
                        end

                        if length > 0 then
                            message = LibDeflate:DecodeForWoWAddonChannel(message);
                            message = message and LibDeflate:DecompressDeflate(message);
                        end

                        if not message or #message ~= math.abs(length) then
                            return ThrottlingError();
                        end
                    end

                    sender = LootReserveHoU:Player(sender);
                    LootReserveHoU.Server:SetAddonUser(sender, true);
                    if not LootReserveHoU:IsMe(sender) then
                        handler(sender, strsplit("|", message));
                    end
                end
            end
        end);
    end
end

function LootReserveHoU.Comm:CanWhisper(target)
    return LootReserveHoU.Enabled and LootReserveHoU:IsPlayerOnline(target);
end

function LootReserveHoU.Comm:Broadcast(opcode, ...)
    if not LootReserveHoU.Enabled then return; end

    local message;
    if IsInGroup() then
        message = self:SendCommMessage(IsInRaid() and "RAID" or "PARTY", nil, opcode, ...);
    else
        message = self:SendCommMessage("WHISPER", LootReserveHoU:Me(), opcode, ...);
    end
end
function LootReserveHoU.Comm:Whisper(target, opcode, ...)
    if not self:CanWhisper(target) then return; end
    local message = self:SendCommMessage("WHISPER", target, opcode, ...);
end
function LootReserveHoU.Comm:Send(target, opcode, ...)
    if target then
        self:Whisper(target, opcode, ...);
    else
        self:Broadcast(opcode, ...);
    end
end
function LootReserveHoU.Comm:WhisperServer(opcode, ...)
    if LootReserveHoU.Client.SessionServer then
        self:Whisper(LootReserveHoU.Client.SessionServer, opcode, ...);
    else
        LootReserveHoU:ShowError("Loot reserves aren't active in your raid");
    end
end

-- Version
function LootReserveHoU.Comm:BroadcastVersion()
    LootReserveHoU.Comm:SendVersion();
end
function LootReserveHoU.Comm:SendVersion(target)
    LootReserveHoU.Comm:Send(target, Opcodes.Version,
        LootReserveHoU.Version,
        LootReserveHoU.MinAllowedVersion);
end
LootReserveHoU.Comm.Handlers[Opcodes.Version] = function(sender, version, minAllowedVersion)
    if LootReserveHoU.LatestKnownVersion >= version then return; end
    LootReserveHoU.LatestKnownVersion = version;

    if LootReserveHoU.Version < minAllowedVersion then
        PlaySoundFile("Interface\\Addons\\LootReserveHoU\\Assets\\Sounds\\Shutting Down.wav", "SFX")
        LootReserveHoU:PrintError("You're using an incompatible outdated version of LootReserveHoU. LootReserveHoU will be unable to communicate with other addon users until it is updated. Please update to version |cFFFFD200%s|r or newer to continue using the addon.", version);
        LootReserveHoU:ShowError("You're using an incompatible outdated version of LootReserveHoU.|n|nLootReserveHoU will be unable to communicate with other addon users until it is updated.|n|nPlease update to version |cFFFFD200%s|r or newer to continue using the addon.", version);
        LootReserveHoU.Comm:BroadcastReportIncompatibleVersion();
        LootReserveHoU.Enabled = false;
        LootReserveHoU.Client:StopSession();
        LootReserveHoU.Client:ResetSession();
        LootReserveHoU.Client:UpdateCategories();
        LootReserveHoU.Client:UpdateLootList();
        LootReserveHoU.Client:UpdateReserveStatus();
    elseif LootReserveHoU.Version < version then
        LootReserveHoU:PrintError("You're using an outdated version of LootReserveHoU. It will continue to work, but please update to version |cFFFFD200%s|r or newer.", version);
    end
end

-- ReportIncompatibleVersion
function LootReserveHoU.Comm:BroadcastReportIncompatibleVersion()
    LootReserveHoU.Comm:Broadcast(Opcodes.ReportIncompatibleVersion);
end
LootReserveHoU.Comm.Handlers[Opcodes.ReportIncompatibleVersion] = function(sender)
    LootReserveHoU.Server:SetAddonUser(sender, false);
end

-- Hello
function LootReserveHoU.Comm:BroadcastHello()
    LootReserveHoU.Comm:Broadcast(Opcodes.Hello);
    LootReserveHoU.Comm:BroadcastVersion();
end
LootReserveHoU.Comm.Handlers[Opcodes.Hello] = function(sender)
    if not LootReserveHoU:IsMe(sender) then
        LootReserveHoU.Comm:SendVersion(sender);
        if LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server:CanBeServer() then
            LootReserveHoU.Comm:SendSessionInfo(sender, true);
        end
    end
    
    if LootReserveHoU.Server.RequestedRoll and not LootReserveHoU.Server.RequestedRoll.RaidRoll and LootReserveHoU.Server:CanRoll(sender) then
        local players = { sender };
        if not LootReserveHoU.Server.RequestedRoll.Custom then
            table.wipe(players);
            for _, roll in ipairs(LootReserveHoU.Server.RequestedRoll.Players[sender] or { }) do
                if roll == 0 then
                    table.insert(players, sender);
                end
            end
        end
        local Roll = LootReserveHoU.Server.RequestedRoll
        LootReserveHoU.Comm:SendRequestRoll(sender, Roll.Item, players, Roll.Custom, Roll.Duration, Roll.MaxDuration, Roll.Phases and Roll.Phases[1] or "");
    end
end

-- SessionInfo
function LootReserveHoU.Comm:BroadcastSessionInfo(starting)
    local session = LootReserveHoU.Server.CurrentSession;
    if session.Settings.Blind then
        for player in pairs(session.Members) do
            if LootReserveHoU:IsPlayerOnline(player) then
                LootReserveHoU.Comm:SendSessionInfo(player, starting);
            end
        end
    else
        LootReserveHoU.Comm:SendSessionInfo(nil, starting);
    end
end
function LootReserveHoU.Comm:SendSessionInfo(target, starting)
    local session = LootReserveHoU.Server.CurrentSession;
    if not session then return; end

    target = target and LootReserveHoU:Player(target);
    local realTarget = target
    if target and LootReserveHoU:IsMe(target) and LootReserveHoU.Client.Masquerade then
        realTarget = target
        target     = LootReserveHoU.Client.Masquerade
    end
    if target and not session.Members[target] then return; end

    local membersInfo = "";
    local refPlayers = { };
    for player, member in pairs(session.Members) do
        if not target or LootReserveHoU:IsSamePlayer(player, target) then
            membersInfo = membersInfo .. (#membersInfo > 0 and ";" or "") .. format("%s=%s,%d", player, session.Settings.Lock and member.Locked and "#" or member.ReservesLeft, session.Settings.MaxReservesPerPlayer + member.ReservesDelta);
            table.insert(refPlayers, player);
        end
    end

    local optInfo = "";
    local refPlayers = { };
    for player, member in pairs(session.Members) do
        if not target or LootReserveHoU:IsSamePlayer(player, target) then
            optInfo = optInfo .. (#optInfo > 0 and ";" or "") .. format("%s=%s", player, strjoin(",", member.OptedOut and "1" or "0"));
        end
    end

    local refPlayerToIndex = { };
    for index, player in ipairs(refPlayers) do
        refPlayerToIndex[player] = index;
    end

    local itemReserves = "";
    for itemID, reserve in pairs(session.ItemReserves) do
        if session.Settings.Blind and target then
            if LootReserveHoU:Contains(reserve.Players, target) then
                local _, myReserves = LootReserveHoU:GetReservesData(reserve.Players, target);
                itemReserves = itemReserves .. (#itemReserves > 0 and ";" or "") .. format("%d=%s", itemID, strjoin(",", unpack(LootReserveHoU:RepeatedTable(refPlayerToIndex[target] or target, myReserves))));
            end
        else
            local players = { };
            for _, player in ipairs(reserve.Players) do
                table.insert(players, refPlayerToIndex[player] or player);
            end
            itemReserves = itemReserves .. (#itemReserves > 0 and ";" or "") .. format("%d=%s", itemID, strjoin(",", unpack(players)));
        end
    end

    local itemConditions = "";
    for itemID, conditions in pairs(session.ItemConditions) do
        local packed = LootReserveHoU.ItemConditions:Pack(conditions);
        itemConditions = itemConditions .. (#itemConditions > 0 and ";" or "") .. format("%d=%s", itemID, packed);
    end

    local lootCategories = "";
    for i, category in ipairs(session.Settings.LootCategories) do
        lootCategories = format("%s%s%s", lootCategories, i == 1 and "" or ";", category);
    end

    LootReserveHoU.Comm:Send(realTarget, Opcodes.SessionInfo,
        starting == true,
        session.StartTime or 0,
        session.AcceptingReserves and true or false, -- In case it's nil
        membersInfo,
        lootCategories,
        format("%.2f", session.Duration),
        session.Settings.Duration,
        itemReserves,
        itemConditions,
        session.Settings.Equip,
        session.Settings.Blind,
        session.Settings.Multireserve or 1,
        optInfo);
end
LootReserveHoU.Comm.Handlers[Opcodes.SessionInfo] = function(sender, starting, startTime, acceptingReserves, membersInfo, lootCategories, duration, maxDuration, itemReserves, itemConditions, equip, blind, multireserve, optInfo)
    starting = tonumber(starting) == 1;
    startTime = tonumber(startTime);
    acceptingReserves = tonumber(acceptingReserves) == 1;
    duration = tonumber(duration);
    maxDuration = tonumber(maxDuration);
    equip = tonumber(equip) == 1;
    blind = tonumber(blind) == 1;
    multireserve = tonumber(multireserve);
    multireserve = math.max(1, multireserve);

    if LootReserveHoU.Client.SessionServer and LootReserveHoU.Client.SessionServer ~= sender and LootReserveHoU.Client.StartTime > startTime then
        LootReserveHoU:ShowError("%s is attempting to broadcast their older loot reserve session, but you're already connected to %s.|n|nPlease tell %s that they need to reset their session.", LootReserveHoU:ColoredPlayer(sender), LootReserveHoU:ColoredPlayer(LootReserveHoU.Client.SessionServer), LootReserveHoU:ColoredPlayer(sender));
        return;
    end
    
    if #lootCategories > 0 then
        lootCategories = { strsplit(";", lootCategories) };
    else
        lootCategories = { };
    end
    for i, category in ipairs(lootCategories) do
        lootCategories[i] = tonumber(category);
    end

    LootReserveHoU.Client:StartSession(sender, starting, startTime, acceptingReserves, lootCategories, duration, maxDuration, equip, blind, multireserve);

    LootReserveHoU.Client.RemainingReserves = 0;
    LootReserveHoU.Client.MaxReserves       = 0;
    local refPlayers = { };
    if #membersInfo > 0 then
        membersInfo = { strsplit(";", membersInfo) };
        for _, infoStr in ipairs(membersInfo) do
            local player, info = strsplit("=", infoStr, 2);
            table.insert(refPlayers, player);
            if LootReserveHoU:IsSamePlayer(LootReserveHoU.Client.Masquerade or LootReserveHoU:Me(), player) then
                local remainingReserves, maxReserves = strsplit(",", info);
                LootReserveHoU.Client.RemainingReserves = tonumber(remainingReserves) or 0;
                LootReserveHoU.Client.MaxReserves = tonumber(maxReserves) or 0;
                LootReserveHoU.Client.Locked = remainingReserves == "#";
            end
        end
    end
    
    if #optInfo > 0 then
        optInfo = { strsplit(";", optInfo) };
        for _, infoStr in ipairs(optInfo) do
            local player, info = strsplit("=", infoStr, 2);
            table.insert(refPlayers, player);
            if LootReserveHoU:IsSamePlayer(LootReserveHoU.Client.Masquerade or LootReserveHoU:Me(), player) then
                local optOut = strsplit(",", info);
                LootReserveHoU.Client.OptedOut = optOut == "1" or nil;
            end
        end
    end

    LootReserveHoU.Client.ItemReserves = { };
    if #itemReserves > 0 then
        itemReserves = { strsplit(";", itemReserves) };
        for _, reserves in ipairs(itemReserves) do
            local itemID, playerRefs = strsplit("=", reserves, 2);
            local players;
            if #playerRefs > 0 then
                players = { };
                for _, ref in ipairs({ strsplit(",", playerRefs) }) do
                    table.insert(players, tonumber(ref) and refPlayers[tonumber(ref)] or ref);
                end
            end
            LootReserveHoU.Client.ItemReserves[tonumber(itemID)] = players;
        end
    end

    LootReserveHoU.Client.ItemConditions = { };
    if #itemConditions > 0 then
        itemConditions = { strsplit(";", itemConditions) };
        for _, conditions in ipairs(itemConditions) do
            local itemID, packed = strsplit("=", conditions, 2);
            LootReserveHoU.Client.ItemConditions[tonumber(itemID)] = LootReserveHoU.ItemConditions:Unpack(packed);
        end
    end

    LootReserveHoU.Client:UpdateCategories();
    LootReserveHoU.Client:UpdateLootList();
    if acceptingReserves and not LootReserveHoU.Client.Locked and LootReserveHoU.Client.RemainingReserves > 0 and not LootReserveHoU.Client.OptedOut then
        if UnitAffectingCombat("player") then
            LootReserveHoU.Client.PendingOpen = true;
        else
            LootReserveHoU.Client.Window:Show();
        end
    end
end

-- SessionStop
function LootReserveHoU.Comm:SendSessionStop()
    LootReserveHoU.Comm:Broadcast(Opcodes.SessionStop);
end
LootReserveHoU.Comm.Handlers[Opcodes.SessionStop] = function(sender)
    if LootReserveHoU.Client.SessionServer == sender then
        LootReserveHoU.Client:StopSession();
        LootReserveHoU.Client:UpdateReserveStatus();
    end
end

-- SessionReset
function LootReserveHoU.Comm:SendSessionReset()
    LootReserveHoU.Comm:Broadcast(Opcodes.SessionReset);
end
LootReserveHoU.Comm.Handlers[Opcodes.SessionReset] = function(sender)
    if LootReserveHoU.Client.SessionServer == sender then
        LootReserveHoU.Client:ResetSession();
        LootReserveHoU.Client:UpdateCategories();
        LootReserveHoU.Client:UpdateLootList();
    end
end
function LootReserveHoU.Comm:SendOptInfo(target, out)
    local session = LootReserveHoU.Server.CurrentSession;
    if not session then return; end

    target = target and LootReserveHoU:Player(target);
    if target and not session.Members[target] then return; end

    LootReserveHoU.Comm:Send(target, Opcodes.OptInfo, out == true);
end
LootReserveHoU.Comm.Handlers[Opcodes.OptInfo] = function(sender, out)
    out = tonumber(out) == 1;

    if LootReserveHoU.Client.SessionServer and LootReserveHoU.Client.SessionServer ~= sender and LootReserveHoU.Client.StartTime > startTime then
        LootReserveHoU:ShowError("%s is attempting to broadcast their older loot reserve session, but you're already connected to %s.|n|nPlease tell %s that they need to reset their session.", LootReserveHoU:ColoredPlayer(sender), LootReserveHoU:ColoredPlayer(LootReserveHoU.Client.SessionServer), LootReserveHoU:ColoredPlayer(sender));
        return;
    end

    LootReserveHoU.Client.OptedOut = out;

    LootReserveHoU.Client:UpdateReserveStatus();
    if LootReserveHoU.Client.SessionServer and LootReserveHoU.Client.AcceptingReserves and not LootReserveHoU.Client.Locked and LootReserveHoU.Client.RemainingReserves > 0 and not LootReserveHoU.Client.OptedOut then
        if UnitAffectingCombat("player") then
            LootReserveHoU.Client.PendingOpen = true;
        else
            LootReserveHoU.Client.Window:Show();
        end
    elseif LootReserveHoU.Client.OptedOut then
        if not LootReserveHoU.Client.Masquerade then
            LootReserveHoU.Client.Window:Hide();
        end
    end
end

-- Opt Out
function LootReserveHoU.Comm:SendOptOut()
    LootReserveHoU.Comm:WhisperServer(Opcodes.OptOut);
end
LootReserveHoU.Comm.Handlers[Opcodes.OptOut] = function(sender)
    if LootReserveHoU.Server.CurrentSession then
        LootReserveHoU.Server:Opt(sender, true);
    end
end

-- Opt In
function LootReserveHoU.Comm:SendOptIn()
    LootReserveHoU.Comm:WhisperServer(Opcodes.OptIn);
end
LootReserveHoU.Comm.Handlers[Opcodes.OptIn] = function(sender)
    if LootReserveHoU.Server.CurrentSession then
        LootReserveHoU.Server:Opt(sender, nil);
    end
end

-- OptResult
function LootReserveHoU.Comm:SendOptResult(target, result, forced)
    LootReserveHoU.Comm:Whisper(target, Opcodes.OptResult,
        result,
        forced);
end
LootReserveHoU.Comm.Handlers[Opcodes.OptResult] = function(sender, result, forced)
    result = tonumber(result);
    forced = tonumber(forced) == 1;

    if LootReserveHoU.Client.SessionServer == sender then

        local text = LootReserveHoU.Constants.OptResultText[result];
        if not text or #text > 0 then
            LootReserveHoU:ShowError("Failed to opt out/in:|n%s", text or "Unknown error");
        end

        if forced then
            local categories = LootReserveHoU:GetCategoriesText(LootReserveHoU.Client.LootCategories);
            local msg1 = format("%s has opted you %s using your %d%s reserve%s%s.",
                LootReserveHoU:ColoredPlayer(sender),
                result and "out of" or "into",
                LootReserveHoU.Client.ReservesLeft,
                LootReserveHoU.Client:GetMaxReserves() == 0 and "" or " remaining",
                LootReserveHoU.Client.ReservesLeft == 1 and "" or "s",
                categories ~= "" and format(" for %s", categories) or "");
            local msg2 = format("You can opt back %s with  !opt %s.",
                result and "in" or "out",
                result and "in" or "out");
            LootReserveHoU:PrintError(msg1 .. " " .. msg2)
            LootReserveHoU:ShowError(msg1 .. "|n" .. msg2)
        else
        
        end
        LootReserveHoU.Client:SetOptPending(false);
        LootReserveHoU.Client:UpdateReserveStatus();
    end
end

-- ReserveItem
function LootReserveHoU.Comm:SendReserveItem(itemID)
    LootReserveHoU.Comm:WhisperServer(Opcodes.ReserveItem, itemID);
end
LootReserveHoU.Comm.Handlers[Opcodes.ReserveItem] = function(sender, itemID)
    itemID = tonumber(itemID);

    if LootReserveHoU.Server.CurrentSession and itemID then
        LootReserveHoU.ItemCache(itemID):OnCache(function()
            LootReserveHoU.Server:Reserve(sender, itemID);
        end);
    end
end

-- ReserveResult
function LootReserveHoU.Comm:SendReserveResult(target, itemID, result, remainingReserves, forced)
    LootReserveHoU.Comm:Whisper(target, Opcodes.ReserveResult,
        itemID,
        result,
        remainingReserves,
        forced);
end
LootReserveHoU.Comm.Handlers[Opcodes.ReserveResult] = function(sender, itemID, result, remainingReserves, forced)
    itemID = tonumber(itemID);
    result = tonumber(result);
    local locked = remainingReserves == "#";
    remainingReserves = tonumber(remainingReserves) or 0;
    forced = tonumber(forced) == 1;

    if LootReserveHoU.Client.SessionServer == sender then
        LootReserveHoU.Client.RemainingReserves = remainingReserves;
        LootReserveHoU.Client.Locked = locked;
        if result == LootReserveHoU.Constants.ReserveResult.Locked then
            LootReserveHoU.Client.Locked = true;
        end

        local text = LootReserveHoU.Constants.ReserveResultText[result];
        if not text or #text > 0 then
            LootReserveHoU:ShowError("Failed to reserve:|n%s", text or "Unknown error");
        end
        if forced then
            LootReserveHoU.ItemCache:Item(itemID):OnCache(function(item)
                local link = item:GetLink();
                LootReserveHoU:PrintError("%s has reserved an item for you: %s", LootReserveHoU:ColoredPlayer(sender), link);
                LootReserveHoU:ShowError("%s has reserved an item for you:|n%s", LootReserveHoU:ColoredPlayer(sender), link);
            end);
        end

        for _, rewardID in ipairs(LootReserveHoU.Data:GetTokenRewards(itemID) or {}) do
            LootReserveHoU.Client:SetItemPending(rewardID, false);
        end
        LootReserveHoU.Client:SetItemPending(itemID, false);
        LootReserveHoU.Client:UpdateReserveStatus();
    end
end

-- ReserveInfo
function LootReserveHoU.Comm:BroadcastReserveInfo(itemID, players)
    LootReserveHoU.Comm:SendReserveInfo(nil, itemID, players);
end
function LootReserveHoU.Comm:SendReserveInfo(target, itemID, players)
    LootReserveHoU.Comm:Send(target, Opcodes.ReserveInfo,
        itemID,
        strjoin(",", unpack(players)));
end
LootReserveHoU.Comm.Handlers[Opcodes.ReserveInfo] = function(sender, itemID, players)
    itemID = tonumber(itemID);

    if LootReserveHoU.Client.SessionServer == sender then
        local wasReserver = LootReserveHoU.Client:IsItemReservedByMe(itemID, true);

        if #players > 0 then
            players = { strsplit(",", players) };
        else
            players = { };
        end

        local previousReserves = LootReserveHoU.Client.ItemReserves[itemID];
        local _, myOldReserves, oldReservers, oldRolls = LootReserveHoU:GetReservesData(previousReserves or { }, LootReserveHoU:Me());
        local _, myNewReserves, newReservers, newRolls = LootReserveHoU:GetReservesData(players, LootReserveHoU:Me());
        local isUpdate = oldRolls ~= newRolls;

        LootReserveHoU.Client.ItemReserves[itemID] = players;

        if LootReserveHoU.Client.SelectedCategory and LootReserveHoU.Client.SelectedCategory.Reserves then
            LootReserveHoU.Client:UpdateLootList();
        else
            LootReserveHoU.Client:UpdateReserveStatus();
        end
        if not LootReserveHoU.Client.Blind then
            LootReserveHoU.Client:FlashCategory("Reserves", "all");
        end
        local isReserver = LootReserveHoU.Client:IsItemReservedByMe(itemID, true);
        if wasReserver or isReserver then
            local isViewingMyReserves = LootReserveHoU.Client.SelectedCategory and LootReserveHoU.Client.SelectedCategory.Reserves == "my";
            LootReserveHoU.Client:FlashCategory("Reserves", "my", wasReserver and isReserver and myOldReserves == myNewReserves and oldRolls ~= newRolls and not isViewingMyReserves);
        end
        if wasReserver and isReserver and myOldReserves == myNewReserves and oldRolls ~= newRolls then
            PlaySound(oldRolls < newRolls and SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.ALARM_CLOCK_WARNING_2);
            LootReserveHoU.ItemCache:Item(itemID):OnCache(function(item)
                LootReserveHoU:PrintMessage(LootReserveHoU:GetReservesStringColored(false, players, LootReserveHoU:Me(), isUpdate, item:GetLink()));
            end);
        end
    end
end

-- CancelReserve
function LootReserveHoU.Comm:SendCancelReserve(itemID)
    LootReserveHoU.Comm:WhisperServer(Opcodes.CancelReserve, itemID);
end
LootReserveHoU.Comm.Handlers[Opcodes.CancelReserve] = function(sender, itemID)
    itemID = tonumber(itemID);

    if LootReserveHoU.Server.CurrentSession then
        LootReserveHoU.Server:CancelReserve(sender, itemID);
    end
end

-- CancelReserveResult
function LootReserveHoU.Comm:SendCancelReserveResult(target, itemID, result, remainingReserves, count, quiet)
    LootReserveHoU.Comm:Whisper(target, Opcodes.CancelReserveResult,
        itemID,
        result,
        remainingReserves,
        count,
        quiet);
end
LootReserveHoU.Comm.Handlers[Opcodes.CancelReserveResult] = function(sender, itemID, result, remainingReserves, count, quiet)
    itemID = tonumber(itemID);
    result = tonumber(result);
    local locked = remainingReserves == "#";
    remainingReserves = tonumber(remainingReserves) or 0;
    count = tonumber(count);
    quiet = tonumber(quiet) == 1;

    if LootReserveHoU.Client.SessionServer == sender then
        LootReserveHoU.Client.RemainingReserves = remainingReserves;
        LootReserveHoU.Client.Locked = locked;
        if result == LootReserveHoU.Constants.CancelReserveResult.Forced then
            LootReserveHoU.ItemCache:Item(itemID):OnCache(function(item)
                local link = item:GetLink();
                if quiet then
                    LootReserveHoU:PrintError("%s removed your reserve for %s%s due to winning an item.", LootReserveHoU:ColoredPlayer(sender), link, count > 1 and format(" x%d", count) or "");
                else
                    LootReserveHoU:ShowError("%s removed your reserve for %s%s", LootReserveHoU:ColoredPlayer(sender), link, count > 1 and format(" x%d", count) or "");
                    LootReserveHoU:PrintError("%s removed your reserve for %s%s", LootReserveHoU:ColoredPlayer(sender), link, count > 1 and format(" x%d", count) or "");
                end
            end);
        elseif result == LootReserveHoU.Constants.CancelReserveResult.Locked then
            LootReserveHoU.Client.Locked = true;
        end

        local text = LootReserveHoU.Constants.CancelReserveResultText[result];
        if not text or #text > 0 then
            LootReserveHoU:ShowError("Failed to cancel reserve:|n%s", text or "Unknown error");
        end

        for _, rewardID in ipairs(LootReserveHoU.Data:GetTokenRewards(itemID) or {}) do
            LootReserveHoU.Client:SetItemPending(rewardID, false);
        end
        LootReserveHoU.Client:SetItemPending(itemID, false);
        if LootReserveHoU.Client.SelectedCategory and LootReserveHoU.Client.SelectedCategory.Reserves then
            LootReserveHoU.Client:UpdateLootList();
        else
            LootReserveHoU.Client:UpdateReserveStatus();
        end
    end
end

-- RequestRoll
function LootReserveHoU.Comm:BroadcastRequestRoll(item, players, custom, duration, maxDuration, phase)
    LootReserveHoU.Comm:SendRequestRoll(nil, item, players, custom, duration, maxDuration, phase);
end
function LootReserveHoU.Comm:SendRequestRoll(target, item, players, custom, duration, maxDuration, phase)
    LootReserveHoU.Comm:Send(target, Opcodes.RequestRoll,
        format("%d,%d", item:GetID(), item:GetSuffix() or 0),
        strjoin(",", unpack(players)),
        custom == true,
        format("%.2f", duration or 0),
        maxDuration or 0,
        phase or "",
        LootReserveHoU.Server.Settings.AcceptRollsAfterTimerEnded);
end
LootReserveHoU.Comm.Handlers[Opcodes.RequestRoll] = function(sender, item, players, custom, duration, maxDuration, phase, acceptRollsAfterTimerEnded)
    local id, suffix = strsplit(",", item);
    item = LootReserveHoU.ItemCache:Item(tonumber(id), tonumber(suffix));
    custom = tonumber(custom) == 1;
    duration = tonumber(duration);
    maxDuration = tonumber(maxDuration);
    phase = phase and #phase > 0 and phase or nil;
    acceptRollsAfterTimerEnded = tonumber(acceptRollsAfterTimerEnded) == 1;

    if LootReserveHoU.Client.SessionServer == sender or custom then
        if #players > 0 then
            players = { strsplit(",", players) };
        else
            players = { };
        end
        LootReserveHoU.Client:RollRequested(sender, item, players, custom, duration, maxDuration, phase, acceptRollsAfterTimerEnded);
    end
end

-- PassRoll
function LootReserveHoU.Comm:SendPassRoll(item)
    LootReserveHoU.Comm:Whisper(LootReserveHoU.Client.RollRequest.Sender, Opcodes.PassRoll, format("%d,%s", item:GetID(), item:GetSuffix() or 0));
end
LootReserveHoU.Comm.Handlers[Opcodes.PassRoll] = function(sender, item)
    item = LootReserveHoU.ItemCache:Item(strsplit(",", item));

    if true--[[LootReserveHoU.Server.CurrentSession]] then
        LootReserveHoU.Server:PassRoll(sender, item);
    end
end

-- DeletedRoll
function LootReserveHoU.Comm:SendDeletedRoll(player, item, roll, phase)
    LootReserveHoU.Comm:Whisper(player, Opcodes.DeletedRoll,
        format("%d,%s", item:GetID(), item:GetSuffix() or 0), roll, phase);
end
LootReserveHoU.Comm.Handlers[Opcodes.DeletedRoll] = function(sender, item, roll, phase)
    item = LootReserveHoU.ItemCache:Item(strsplit(",", item));
    roll = tonumber(roll);

    item:OnCache(function()
        local link = item:GetLink();
        LootReserveHoU:ShowError ("Your %sroll%s on %s was deleted", phase and #phase > 0 and format("%s ", phase) or "", roll and format(" of %d", roll) or "", link);
        LootReserveHoU:PrintError("Your %sroll%s on %s was deleted", phase and #phase > 0 and format("%s ", phase) or "", roll and format(" of %d", roll) or "", link);
    end);
end


-- SendWinner
function LootReserveHoU.Comm:BroadcastWinner(...)
    LootReserveHoU.Comm:SendWinner(nil, ...);
end
function LootReserveHoU.Comm:SendWinner(target, item, winners, losers, roll, custom, phase, raidRoll)
    LootReserveHoU.Comm:Send(target, Opcodes.SendWinner,
        format("%d,%s", item:GetID(), item:GetSuffix() or 0),
        strjoin(",", unpack(winners)),
        strjoin(",", unpack(losers)),
        roll or "",
        custom == true,
        phase or "",
        raidRoll == true);
end
LootReserveHoU.Comm.Handlers[Opcodes.SendWinner] = function(sender, item, winners, losers, roll, custom, phase, raidRoll)
    item     = LootReserveHoU.ItemCache:Item(strsplit(",", item));
    roll     = tonumber(roll);
    custom   = tonumber(custom) == 1;
    phase    = phase and #phase > 0 and phase or nil;
    raidRoll = tonumber(raidRoll) == 1;

    if LootReserveHoU.Client.SessionServer == sender or custom then
        if #winners > 0 then
            winners = { strsplit(",", winners) };
        else
            winners = { };
        end
        if #losers > 0 then
            losers = { strsplit(",", losers) };
        else
            losers = { };
        end
        if LootReserveHoU.Client.Settings.RollRequestWinnerReaction and LootReserveHoU:Contains(winners, LootReserveHoU:Me()) then
            item:OnCache(function()
                local race, sex = select(3, LootReserveHoU:UnitRace(LootReserveHoU:Me())), LootReserveHoU:UnitSex(LootReserveHoU:Me());
                local soundTable = custom and LootReserveHoU.Constants.Sounds.Congratulate or LootReserveHoU.Constants.Sounds.Cheer;
                if race and sex and soundTable[race] and soundTable[race][sex] then
                    PlaySound(soundTable[race][sex]);
                end
                PlaySound(LootReserveHoU.Constants.Sounds.LevelUp);
                
                LootReserveHoU:PrintMessage("Congratulations! %s has awarded you %s%s%s",
                    LootReserveHoU:ColoredPlayer(sender),
                    item:GetLink(),
                    raidRoll and " via raid-roll" or custom and phase and format(" for %s", phase or "") or "",
                    roll and not raidRoll and format(" with a roll of %d", roll) or ""
                );
            end);
        end
        if LootReserveHoU.Client.Settings.RollRequestLoserReaction and LootReserveHoU:Contains(losers, LootReserveHoU:Me()) then
            item:OnCache(function()
                local race, sex = select(3, LootReserveHoU:UnitRace(LootReserveHoU:Me())), LootReserveHoU:UnitSex(LootReserveHoU:Me());
                local soundTable = LootReserveHoU.Constants.Sounds.Cry;
                if race and sex and soundTable[race] and soundTable[race][sex] then
                    PlaySound(soundTable[race][sex]);
                end
                
                LootReserveHoU:PrintMessage("You have lost a roll for %s",
                    item:GetLink()
                );
            end);
        end
    end
end
