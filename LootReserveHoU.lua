local addon, ns = ...;

LootReserveHoU = LibStub("AceAddon-3.0"):NewAddon("LootReserveHoU", "AceComm-3.0");
LootReserveHoU.Version = GetAddOnMetadata(addon, "Version");
LootReserveHoU.MinAllowedVersion = GetAddOnMetadata(addon, "X-Min-Allowed-Version");
LootReserveHoU.LatestKnownVersion = LootReserveHoU.Version;
LootReserveHoU.Enabled = true;

LootReserveHoU.EventFrame = CreateFrame("Frame", nil, UIParent);
LootReserveHoU.EventFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0);
LootReserveHoU.EventFrame:SetSize(0, 0);
LootReserveHoU.EventFrame:Show();

LootReserveHoU.LibRangeCheck = LibStub("LibRangeCheck-2.0");
LootReserveHoU.ItemCache     = LibStub("ItemCache");

LootReserveHoUCharacterSave =
{
    Client =
    {
        CharacterFavorites = nil,
    },
    Server =
    {
        CurrentSession = nil,
        RequestedRoll  = nil,
        RollHistory    = nil,
        RecentLoot     = nil,
    },
};
LootReserveHoUGlobalSave =
{
    Client =
    {
        Settings        = nil,
        GlobalFavorites = nil,
    },
    Server =
    {
        NewSessionSettings = nil,
        Settings           = nil,
        GlobalProfile      = nil,
    },
};

LootReserveHoU.BagCache = nil;

StaticPopupDialogs["LootReserveHoU_GENERIC_ERROR"] =
{
    text         = "%s",
    button1      = CLOSE,
    timeout      = 0,
    whileDead    = 1,
    hideOnEscape = 1,
};

LootReserveHoU_BACKDROP_BLACK_4 =
{
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
};

SLASH_LootReserveHoU1 = "/LootReserveHoU";
SLASH_LootReserveHoU2 = "/reserveHoU";
SLASH_LootReserveHoU3 = "/resHoU";
function SlashCmdList.LootReserveHoU(command)
    command = command:lower();

    if command == "" then
        LootReserveHoU.Client.Window:SetShown(not LootReserveHoU.Client.Window:IsShown());
    elseif command == "server" or command == "host" then
        LootReserveHoU:ToggleServerWindow(not LootReserveHoU.Server.Window:IsShown());
    elseif command == "roll" or command == "rolls" then
        LootReserveHoU:ToggleServerWindow(not LootReserveHoU.Server.Window:IsShown(), true);
    end
end

local pendingToggleServerWindow = nil;
local pendingLockdownHooked = nil;
function LootReserveHoU:ToggleServerWindow(state, rolls)
    if InCombatLockdown() and LootReserveHoU.Server.Window:IsProtected() then
        pendingToggleServerWindow = { state, rolls };
        if not pendingLockdownHooked then
            pendingLockdownHooked = true;
            self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                if pendingToggleServerWindow then
                    local params = pendingToggleServerWindow;
                    pendingToggleServerWindow = nil;
                    self:ToggleServerWindow(unpack(params));
                end
            end);
        end
        self:PrintMessage("Host window will %s once you're out of combat", state and "open" or "close");
        return;
    end

    if rolls then
        self.Server.Window:Show();
        self.Server:OnWindowTabClick(self.Server.Window.TabRolls);
    else
        self.Server.Window:SetShown(state);
    end
end

function LootReserveHoU:OnInitialize()
end

function LootReserveHoU:OnEnable()
    LootReserveHoU.Client:Load();
    LootReserveHoU.Server:Load();
    if LootReserveHoU.Client.Settings.AllowPreCache then
        LootReserveHoU.ItemSearch:Load();
    end
    
    LootReserveHoU.Comm:StartListening();

    local function Startup()
        LootReserveHoU.Server:Startup();
        -- Query other group members about their addon versions and request server session info if any
        LootReserveHoU.Client:SearchForServer(true);
    end

    LootReserveHoU:RegisterEvent("GROUP_JOINED", function()
        -- Load client and server after WoW client restart
        -- Server session should not normally exist when the player is outside of any raid groups, so restarting it upon regular group join shouldn't break anything
        -- With a delay, due to possible name cache issues
        C_Timer.After(1, Startup);
    end);

    -- Load client and server after UI reload
    -- This should be the only case when a player is already detected to be in a group at the time of addon loading
    Startup();
end

function LootReserveHoU:OnDisable()
end

function LootReserveHoU:ShowError(fmt, ...)
    StaticPopup_Show("LootReserveHoU_GENERIC_ERROR", "|cFFFFD200LootReserveHoU|r|n|n" .. format(fmt, ...) .. "|n ");
end

function LootReserveHoU:PrintError(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200LootReserveHoU: |r" .. format(fmt, ...), 1, 0, 0);
end

function LootReserveHoU:PrintMessage(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD200LootReserveHoU: |r" .. format(fmt, ...), 1, 1, 1);
end

function LootReserveHoU:debug(...)
    --@debug@
    print("[DEBUG] ", ...);
    --@end-debug@
end

function LootReserveHoU:debugFunc(func)
    --@debug@
    func();
    --@end-debug@
end

function LootReserveHoU:RegisterUpdate(handler)
    LootReserveHoU.EventFrame:HookScript("OnUpdate", function(self, elapsed)
        handler(elapsed);
    end);
end

function LootReserveHoU:RegisterEvent(...)
    if not LootReserveHoU.EventFrame.RegisteredEvents then
        LootReserveHoU.EventFrame.RegisteredEvents = { };
        LootReserveHoU.EventFrame:SetScript("OnEvent", function(self, event, ...)
            local handlers = self.RegisteredEvents[event];
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(...);
                end
            end
        end);
    end

    local params = select("#", ...);

    local handler = select(params, ...);
    if type(handler) ~= "function" then
        error("LootReserveHoU:RegisterEvent: The last passed parameter must be the handler function");
        return;
    end

    for i = 1, params - 1 do
        local event = select(i, ...);
        if type(event) == "string" then
            LootReserveHoU.EventFrame:RegisterEvent(event);
            LootReserveHoU.EventFrame.RegisteredEvents[event] = LootReserveHoU.EventFrame.RegisteredEvents[event] or { };
            table.insert(LootReserveHoU.EventFrame.RegisteredEvents[event], handler);
        else
            error("LootReserveHoU:RegisterEvent: All but the last passed parameters must be event names");
        end
    end
end

function LootReserveHoU:OpenMenu(menu, menuContainer, anchor)
    if UIDROPDOWNMENU_OPEN_MENU == menuContainer then
        CloseMenus();
        return;
    end

    local function FixMenu(menu)
        for _, item in ipairs(menu) do
            if item.notCheckable == nil then
                item.notCheckable = item.checked == nil;
            end
            if item.keepShownOnClick == nil and item.checked ~= nil then
                item.keepShownOnClick = true;
            end
            if item.tooltipText and item.tooltipTitle == nil then
                item.tooltipTitle = item.text;
            end
            if item.tooltipText and item.tooltipOnButton == nil then
                item.tooltipOnButton = true;
            end
            if item.hasArrow == nil and item.menuList then
                item.hasArrow = true;
            end
            if item.keepShownOnClick == nil and item.menuList then
                item.keepShownOnClick = true;
            end
            if item.menuList then
                FixMenu(item.menuList);
            end
        end
    end
    FixMenu(menu);
    EasyMenu(menu, menuContainer, anchor, 0, 0, "MENU");
end

function LootReserveHoU:OpenSubMenu(...)
    for submenu = 1, select("#", ...) do
        local arg1 = select(submenu, ...);
        local opened = false;
        for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
            local button = _G["DropDownList"..submenu.."Button"..i];
            if button and button.arg1 == arg1 then
                local arrow = _G[button:GetName().."ExpandArrow"];
                if arrow then
                    arrow:Click();
                    opened = true;
                    break;
                end
            end
        end
        if not opened then
            return false;
        end
    end
    return true;
end

function LootReserveHoU:ReopenMenu(button, ...)
    CloseMenus();
    button:Click();
    self:OpenSubMenu(...);
end

function LootReserveHoU:Round(num, nearest)
    nearest = nearest or 1;
    local lower = math.floor(num / nearest) * nearest;
    local upper = lower + nearest;
    return (upper - num < num - lower) and upper or lower;
end

-- Used to prevent LootReserveHoU:SendChatMessage from breaking a hyperlink into multiple segments if the message is too long
-- Use it if a text of undetermined length preceeds the hyperlink
-- GOOD: format("%s win %s", strjoin(", ", players), LootReserveHoU:FixLink(link)) - players might contain so many names that the message overflows 255 chars limit
--  BAD: format("%s won by %s", LootReserveHoU:FixLink(link), strjoin(", ", players)) - link is always early in the message and will never overflow the 255 chars limit
function LootReserveHoU:FixLink(link)
    return link:gsub(" ", "\1");
end
function LootReserveHoU:FixText(text)
    return text:gsub("\1", " ");
end

function LootReserveHoU:SendChatMessage(text, channel, target)
    if channel == "RAID_WARNING" and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        channel = "RAID";
    end
    if channel == "RAID" and not IsInRaid() then
        channel = "PARTY";
    end
    if channel == "PARTY" and not IsInGroup() then
        channel, target = "WHISPER", LootReserveHoU:Me();
    end
    if target and not LootReserveHoU:IsPlayerOnline(target) then return; end
    local function Send(text)
        if #text > 0 then
            text = self:FixText(text);
            if self.Server.SentMessages[text] then
                self.Server.SentMessages[text]:Cancel();
            end
            self.Server.SentMessages[text] = C_Timer.NewTicker(10, function() self.Server.SentMessages[text] = nil end, 1);
            if ChatThrottleLib then
                ChatThrottleLib:SendChatMessage("NORMAL", self.Comm.Prefix, text, channel, nil, target);
            else
                SendChatMessage(text, channel, nil, target);
            end
        end
    end

    if #text <= 250 then
        Send(text);
    else
        text = text .. " ";
        local accumulator = "";
        for word in text:gmatch("[^ ]- ") do
            if #accumulator + #word > 250 then
                Send(self:StringTrim(accumulator));
                accumulator = "";
            end
            accumulator = accumulator .. word;
        end
        Send(self:StringTrim(accumulator));
    end
end

function LootReserveHoU:GetCurrentExpansion()
    local version = GetBuildInfo();
    local expansion, major, minor = strsplit(".", version);
    return tonumber(expansion) - 1;
end

function LootReserveHoU:IsCrossRealm()
    return self:GetCurrentExpansion() == 0 and not C_Seasons.HasActiveSeason();
    -- This doesn't really work, because even in non-connected realms UnitFullName ends up returning your realm name,
    -- and we can't use UnitName either, because that one NEVER returns a realm for "player". WTB good API, 5g.
    --[[
    if self.CachedIsCrossRealm == nil then
        local name, realm = UnitFullName("player");
        if name then
            self.CachedIsCrossRealm = realm ~= nil;
        end
    end
    return self.CachedIsCrossRealm;
    ]]
end

function LootReserveHoU:GetNumClasses()
    return 11;
end

function LootReserveHoU:GetClassInfo(classID)
    local info = C_CreatureInfo.GetClassInfo(classID);
    if info then
        return info.className, info.classFile, info.classID;
    end
end

function LootReserveHoU:Player(player)
    if not self:IsCrossRealm() then
        return Ambiguate(player, "short");
    end

    local name, realm = strsplit("-", player);
    if not realm then
        realm = GetNormalizedRealmName();
        if not realm then
            -- it really does happen
            realm = GetRealmName();
            if realm then
                realm = realm:gsub("[%s%-]", "");
            end
            if not realm then
                -- ¯\_(ツ)_/¯
                return name;
            end
        end
    end
    return name .. "-" .. realm;
end

function LootReserveHoU:Me()
    return self:Player(UnitName("player"));
end

function LootReserveHoU:IsMe(player)
    return self:IsSamePlayer(player, self:Me());
end

function LootReserveHoU:IsSamePlayer(a, b)
    return self:Player(a) == self:Player(b);
end

function LootReserveHoU:IsPlayerOnline(player)
    return self:ForEachRaider(function(name, _, _, _, _, _, _, online)
        if self:IsSamePlayer(name, player) then
            return online or false;
        end
    end);
end

local function LootReserveHoU_UnitInRaid(player)
    if not LootReserveHoU:IsCrossRealm() then
        return UnitInRaid(player);
    end

    return IsInRaid() and LootReserveHoU:ForEachRaider(function(name, _, _, _, className, classFilename, _, online)
        if LootReserveHoU:IsSamePlayer(name, player) then
            return true;
        end
    end);
end

local function LootReserveHoU_UnitInParty(player)
    if not LootReserveHoU:IsCrossRealm() then
        return UnitInParty(player);
    end

    return IsInGroup() and not IsInRaid() and LootReserveHoU:ForEachRaider(function(name, _, _, _, className, classFilename, _, online)
        if LootReserveHoU:IsSamePlayer(name, player) then
            return true;
        end
    end);
end

function LootReserveHoU:UnitInGroup(player)
    if not self:IsCrossRealm() then
        if IsInRaid() then
            return LootReserveHoU_UnitInRaid(player) and true;
        elseif IsInGroup() then
            return LootReserveHoU_UnitInParty(player);
        else
            return LootReserveHoU:IsMe(player);
        end
    end

    return self:ForEachRaider(function(name)
        if self:IsSamePlayer(name, player) then
            return true;
        end
    end);
end

function LootReserveHoU:UnitClass(player)
    if not self:IsCrossRealm() then
        local className, classFilename, classId = UnitClass(player);
        if not className then
            if LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Members[player] and LootReserveHoU.Server.CurrentSession.Members[player].Class then
                return LootReserveHoU:GetClassInfo(LootReserveHoU.Server.CurrentSession.Members[player].Class);
            elseif LootReserveHoU.Server.NewSessionSettings and LootReserveHoU.Server.NewSessionSettings.ImportedMembers and LootReserveHoU.Server.NewSessionSettings.ImportedMembers[player] and LootReserveHoU.Server.NewSessionSettings.ImportedMembers[player].Class then
                return LootReserveHoU:GetClassInfo(LootReserveHoU.Server.NewSessionSettings.ImportedMembers[player].Class);
            end
        end
        return className, classFilename, classId;
    end

    return self:ForEachRaider(function(name, _, _, _, className, classFilename)
        if self:IsSamePlayer(name, player) then
            return className, classFilename, LootReserveHoU.Constants.ClassFilenameToClassID[classFilename];
        end
    end);
end

function LootReserveHoU:UnitRace(player)
    if not self:IsCrossRealm() then
        return UnitRace(player);
    end

    return self:ForEachRaider(function(name)
        if self:IsSamePlayer(name, player) then
            local unitID = self:GetGroupUnitID(player);
            if unitID then
                return UnitRace(unitID);
            end
        end
    end);
end

function LootReserveHoU:UnitSex(player)
    if not self:IsCrossRealm() then
        return UnitSex(player);
    end

    return self:ForEachRaider(function(name)
        if self:IsSamePlayer(name, player) then
            local unitID = self:GetGroupUnitID(player);
            if unitID then
                return UnitSex(unitID);
            end
        end
    end);
end

local function GetPlayerClassColor(player, dim, class)
    local className, classFilename, classId = LootReserveHoU:UnitClass(player);
    if class then
        className, classFilename, classId = LootReserveHoU:GetClassInfo(class);
    end
    if classFilename then
        local colors = RAID_CLASS_COLORS[classFilename];
        if colors then
            if dim then
                local r, g, b, a = colors:GetRGBA();
                return format("FF%02X%02X%02X", r * 128, g * 128, b * 128);
            else
                return colors.colorStr;
            end
        end
    end
    return dim and "FF404040" or "FF808080";
end

local function GetRaidUnitID(player)
    for i = 1, MAX_RAID_MEMBERS do
        local unit = UnitName("raid" .. i);
        if unit and LootReserveHoU:IsSamePlayer(LootReserveHoU:Player(unit), player) then
            return "raid" .. i;
        end
    end

    if LootReserveHoU:IsMe(player) then
        return "player";
    end
end

local function GetPartyUnitID(player)
    for i = 1, MAX_PARTY_MEMBERS do
        local unit = UnitName("party" .. i);
        if unit and LootReserveHoU:IsSamePlayer(LootReserveHoU:Player(unit), player) then
            return "party" .. i;
        end
    end

    if LootReserveHoU:IsMe(player) then
        return "player";
    end
end

function LootReserveHoU:GetGroupUnitID(player)
    if IsInRaid() then
        return GetRaidUnitID(player);
    elseif IsInGroup() then
        return GetPartyUnitID(player);
    elseif self:IsMe(player) then
        return "player"
    end
end

function LootReserveHoU:ColoredPlayer(player, class)
    local name, realm = strsplit("-", player);
    return realm and format("|c%s%s|r|c%s-%s|r", GetPlayerClassColor(player, false, class), name, GetPlayerClassColor(player, true, class), realm)
                  or format("|c%s%s|r",          GetPlayerClassColor(player, false, class), player);
end

function LootReserveHoU:ForEachRaider(func)
    if not IsInGroup() then
        local className, classFilename = UnitClass("player");
        local raceName,  raceFilename  = UnitRace("player");
        return func(self:Me(), 0, 1, UnitLevel("player"), className, classFilename, nil, true, UnitIsDead("player"), nil, nil, nil, "player", nil);
    end

    for i = 1, MAX_RAID_MEMBERS do
        local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i);
        if name then
            local name = self:Player(name);
            local unitID = self:IsMe(name) and "player" or UnitInRaid("player") and ("raid" .. i) or ("party" .. i);
            local result, a, b = func(name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole, unitID, i);
            if result ~= nil then
                return result, a, b;
            end
        else
            break;
        end
    end
end

local charSimplifications =
{
    ["a"  ] = "ÀÁÂÃÄÅàáâãäåĀāĂăĄąǍǎǞǟǠǡǺǻȀȁȂȃɐɑɒ",
    ["ae" ] = "ÆæǢǣǼǽ",
    ["b"  ] = "ƀƁƂƃɓʙ",
    ["c"  ] = "ÇçĆćĈĉĊċČčƇƈɔɕʗ",
    ["d"  ] = "ĎďĐđƉƊƋƌɖɗ",
    ["dz" ] = "ǄǅǆǱǲǳʣʥ",
    ["e"  ] = "ÈÉÊËèéêëĒēĔĕĖėĘęĚěƎƐǝȄȅȆȇɘəɚɛɜɝɞʚ",
    ["eth"] = "ð",
    ["f"  ] = "Ƒƒɟ",
    ["g"  ] = "ĜĝĞğĠġĢģƓǤǥǦǧǴǵɠɡɢʛ",
    ["h"  ] = "ĤĥĦħɥɦɧʜ",
    ["i"  ] = "ÌÍÎÏìíîïĨĩĪīĬĭĮįİıƗǏǐȈȉȊȋɨɩɪ",
    ["ij" ] = "Ĳĳ",
    ["j"  ] = "Ĵĵǰʄʝ",
    ["k"  ] = "ĶķĸƘƙǨǩʞ",
    ["l"  ] = "ĹĺĻļĽľĿŀŁłƚɫɬɭʟ",
    ["lj" ] = "Ǉǈǉ",
    ["m"  ] = "Ɯɯɰɱ",
    ["n"  ] = "ÑñŃńŅņŇňŉŊŋƝƞɲɳɴ",
    ["nj" ] = "Ǌǋǌ",
    ["o"  ] = "ÒÓÔÕÖØòóôõöøŌōŎŏŐőƆƟƠơǑǒǪǫǬǭǾǿȌȍȎȏɵ",
    ["oe" ] = "Œœɶ",
    ["oi" ] = "Ƣƣ",
    ["p"  ] = "ÞþƤƥ",
    ["q"  ] = "ʠ",
    ["r"  ] = "ŔŕŖŗŘřƦȐȑȒȓɹɺɻɼɽɾɿʀʁ",
    ["s"  ] = "ŚśŜŝŞşŠšſʂ",
    ["ss" ] = "ß",
    ["t"  ] = "ŢţŤťŦŧƫƬƭƮʇʈ",
    ["u"  ] = "ÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųƯưǓǔǕǖǗǘǙǚǛǜȔȕȖȗʉʊ",
    ["v"  ] = "Ʋʋʌ",
    ["w"  ] = "Ŵŵʍ",
    ["y"  ] = "ÝýÿŶŷŸƳƴʎʏ",
    ["z"  ] = "ŹźŻżŽžƵƶʐʑ",
};

local simplificationMapping = { }
for replacement, pattern in pairs(charSimplifications) do
    local len = pattern:utf8len();
    for i = 1, len do
        local char = pattern:utf8sub(i, i);
        simplificationMapping[char] = replacement;
    end
end

function LootReserveHoU:NormalizeName(name)
    for i = 1, name:utf8len() do
        if name:utf8sub(i, i) == "-" then
            return name:utf8sub(1, 1):utf8upper() .. name:utf8sub(2, i - 1):utf8lower() .. name:utf8sub(i);
        end
    end
    return name:utf8sub(1, 1):utf8upper() .. name:utf8sub(2):utf8lower();
end

local simplifiedNamesMemo = { };
local function SimplifyName(self, name)
    for i = 1, name:utf8len() do
        if name:utf8sub(i, i) == "-" then
            return self:NormalizeName(name:utf8sub(1, i - 1):utf8replace(simplificationMapping));
        end
    end
    return self:NormalizeName(name:utf8replace(simplificationMapping));
end

function LootReserveHoU:SimplifyName(name)
    if not simplifiedNamesMemo[name] then
        simplifiedNamesMemo[name] = SimplifyName(self, name);
    end
    return simplifiedNamesMemo[name];
end

function LootReserveHoU:GetNumGroupMembers(func)
    local count = 0;
    self:ForEachRaider(function() count = count + 1; end);
    return count;
end

function LootReserveHoU:IsTradeableItem(bag, slot)
    -- can't use C_Item.IsBound because it sometimes bugs and gives a usage error despite correctly receiving an ItemLocation
    return not LootReserveHoU:IsItemSoulbound(bag, slot) or LootReserveHoU:IsItemSoulboundTradeable(bag, slot);
end

local function CacheBagSlot(self, bag, slot, i)
    local _, quantity, locked, _, _, _, link, _, _, id, isBound = GetContainerItemInfo(bag, slot);
    if link then
        if i then
            table.insert(self.BagCache, i, {bag = bag, slot = slot, item = self.ItemCache:Item(link), quantity = quantity, locked = locked});
        else
            table.insert(self.BagCache, {bag = bag, slot = slot, item = self.ItemCache:Item(link), quantity = quantity, locked = locked});
        end
    end
end

local bagCacheHooked = nil;
local function CheckBagCache(self)
    if not bagCacheHooked then
        bagCacheHooked = true;
        self:RegisterEvent("BAG_UPDATE_DELAYED", function()
            LootReserveHoU:WipeBagCache();
        end);
        self:RegisterEvent("ITEM_LOCK_CHANGED", function(bag, slot)
            if not slot then return; end
            if self.BagCache then
                for i, slotData in ipairs(self.BagCache) do
                    if slotData.slot == slot and slotData.bag == bag then
                        table.remove(self.BagCache, i);
                        CacheBagSlot(self, bag, slot, i);
                    end
                end
            end
        end);
    end
    if not self.BagCache then
        self.BagCache = { };
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, GetContainerNumSlots(bag) do
                CacheBagSlot(self, bag, slot);
            end
        end
    end
end

local function match(item, itemOrID)
    if type(itemOrID) == "number" then
        return item:GetID() == itemOrID;
    else
        return item == itemOrID;
    end
end

function LootReserveHoU:WipeBagCache()
    self.BagCache = nil;
end

function LootReserveHoU:GetTradeableItemCount(itemOrID, includeLoot)
    CheckBagCache(self);
    local count, _ = 0;
    if includeLoot then
        _, count = self:IsLootingItem(itemOrID);
    end
    for _, slotData in ipairs(self.BagCache) do
        if match(slotData.item, itemOrID) and self:IsTradeableItem(slotData.bag, slotData.slot) then
            count = count + slotData.quantity;
        end
    end
    
    for i = 0, 19 do
        local link = GetInventoryItemLink("player", i);
        if link and link:find("item:%d+") then
            local item = self.ItemCache:Item(link);
            if match(item, itemOrID) and not item:Binds() then
                count = count + 1;
            end
        end
    end
    return count;
end
    
function LootReserveHoU:GetBagSlot(itemOrID, permitLocked, skipCount)
    CheckBagCache(self);
    skipCount = skipCount or 0;
    for _, slotData in ipairs(self.BagCache) do
        if match(slotData.item, itemOrID) and (permitLocked or not slotData.locked) then
            skipCount = skipCount - 1;
            if skipCount < 0 then
                return slotData.bag, slotData.slot;
            end
        end
    end
    return nil;
end

function LootReserveHoU:IsItemSoulbound(bag, slot)
    if not self.TooltipScanner then
        self.TooltipScanner = CreateFrame("GameTooltip", "LootReserveHoUTooltipScanner", UIParent, "GameTooltipTemplate");
        self.TooltipScanner:Hide();
    end

    self.TooltipScanner:SetOwner(UIParent, "ANCHOR_NONE");
    self.TooltipScanner:SetBagItem(bag, slot);
    for i = LootReserveHoU.TooltipScanner:NumLines(), 1, -1 do
        local line = _G[self.TooltipScanner:GetName() .. "TextLeft" .. i];
        if line and line:GetText() and line:GetText() == ITEM_SOULBOUND then
            self.TooltipScanner:Hide();
            return true;
        end
    end
    self.TooltipScanner:Hide();
    return false;
end

function LootReserveHoU:IsItemSoulboundTradeable(bag, slot)
    if not self.TooltipScanner then
        self.TooltipScanner = CreateFrame("GameTooltip", "LootReserveHoUTooltipScanner", UIParent, "GameTooltipTemplate");
        self.TooltipScanner:Hide();
    end

    if not self.TooltipScanner.SoulboundTradeable then
        self.TooltipScanner.SoulboundTradeable = BIND_TRADE_TIME_REMAINING:gsub("%.", "%%."):gsub("%%s", "(.+)");
    end

    self.TooltipScanner:SetOwner(UIParent, "ANCHOR_NONE");
    self.TooltipScanner:SetBagItem(bag, slot);
    for i = LootReserveHoU.TooltipScanner:NumLines(), 1, -1 do
        local line = _G[self.TooltipScanner:GetName() .. "TextLeft" .. i];
        if line and line:GetText() and line:GetText():match(self.TooltipScanner.SoulboundTradeable) then
            self.TooltipScanner:Hide();
            return true;
        end
    end
    self.TooltipScanner:Hide();
    return false;
end

function LootReserveHoU:IsItemBeingTraded(item)
    for i = 1, 6 do
        local link = GetTradePlayerItemLink(i);
        if link then
            local tradeItem = LootReserveHoU.ItemCache:Item(link);
            if tradeItem == item then
                return true;
            end
        end
    end
    return false;
end

function LootReserveHoU:PutItemInTrade(bag, slot)
    for i = 1, 6 do
        if not GetTradePlayerItemInfo(i) then
            PickupContainerItem(bag, slot);
            ClickTradeButton(i);
            return true;
        end
    end
    return false;
end

function LootReserveHoU:GetItemDescription(itemID, noTokenRedirect)
    local item = LootReserveHoU.ItemCache:Item(itemID);
    if not item:Cache():IsCached() then return; end
    local name, _, _, _, _, itemType, itemSubType, _, equipLoc, _, _, _, _, bindType = item:GetInfo();
    local skillRequired, skillLevelRequired = item:GetSkillRequired();
    local itemText = "";
    
    if not noTokenRedirect then
        local tokenID = LootReserveHoU.Data:GetToken(itemID);
        if tokenID then
            local token = LootReserveHoU.ItemCache:Item(tokenID);
            if not token:Cache():IsCached() then return; end
            return "From: " .. token:GetName();
        end
    end
    
    if item:IsUnique() then
        itemText = ITEM_UNIQUE .. " " .. itemText
    end
    
    if skillRequired then
        itemText = itemText .. skillLevelRequired .. " " .. skillRequired .. " "
    end
    
    if LootReserveHoU.Constants.RedundantSubTypes[itemSubType] then
        itemText = LootReserveHoU.Constants.RedundantSubTypes[itemSubType];
    elseif itemType == ARMOR then
        if itemSubType == MISCELLANEOUS or equipLoc == "INVTYPE_CLOAK" then
            itemText = itemText .. (_G[equipLoc] or "");
        else
            itemText = itemText .. itemSubType .. " " .. (_G[equipLoc] or "");
        end
    elseif itemType == WEAPON then
        itemText = itemText .. (_G[equipLoc] and (_G[equipLoc] .. " ") or "") .. (LootReserveHoU.Constants.WeaponTypeNames[itemSubType] or "");
    elseif itemType == "Recipe" then
        if itemSubType == "Book" then
            itemText = itemText .. "Skill Book";
        else
            itemText = itemText .. name:match("^[^:]+");
        end
    elseif itemType == "Container" then
        itemText = itemText .. (_G[equipLoc] or "");
    elseif itemType == "Trade Goods" then
        itemText = itemText .. "Trade Good";
    elseif itemType == MISCELLANEOUS then
        if item:StartsQuest() then
            itemText = itemText .. "Quest";
        else
            if itemSubType == "Junk" or itemSubType == "Other" then
                itemText = itemText .. itemType;
            else
               itemText = itemText .. itemSubType;
            end
        end
    else
        itemText = itemText .. itemType;
    end
    
    if bindType == LE_ITEM_BIND_ON_ACQUIRE then
        -- itemText = itemText .. "  (BoP)";
    elseif bindType == LE_ITEM_BIND_ON_EQUIP then
        itemText = itemText .. "  (BoE)";
    elseif itemText == LE_ITEM_BIND_ON_USE then
        itemText = itemText .. "  (BoU)";
    end
    
    return itemText;
end

function LootReserveHoU:IsLootingItem(itemOrID)
    local item = LootReserveHoU.ItemCache:Item(itemOrID);
    local firstIndex;
    local count = 0;
    for i = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(i);
        if itemLink and itemLink:find"item:%d" then -- GetLootSlotLink() sometimes returns "|Hitem:::::::::70:::::::::[]"
            local lootItem = LootReserveHoU.ItemCache:Item(itemLink);
            if lootItem and lootItem:GetID() == item:GetID() then
                firstIndex = firstIndex or i;
                count = count + 1;
            end
        end
    end
    return firstIndex, count;
end

function LootReserveHoU:CanLocate()
    return not not UnitPosition("player");
end

function LootReserveHoU:CanUseDBMLocator(unitID)
    return DBM and DBM.ReleaseRevision > 20220618000000 and self:CanLocate() and UnitIsVisible(unitID) and true or false;
end

function LootReserveHoU:GetContinent(unitID)
    local mapID = C_Map.GetBestMapForUnit(unitID)
    if not mapID then return; end
    
    local mapPos = C_Map.GetPlayerMapPosition(mapID, unitID)
    if not mapPos then return; end
    
    local continent, worldPos = C_Map.GetWorldPosFromMapPos(mapID, mapPos)
    if not continent or not worldPos then return; end
    
    return continent, worldPos;
end

function LootReserveHoU:GetRange(unitID, playerPos, targetPos)
    if not playerPos or not targetPos then
        local min, max = self.LibRangeCheck:getRange(unitID);
        if not min then
            return nil, nil, nil, nil;
        end
        return min, max, nil, format("%s%s|r yds", self:GetRangeColor(min), max and (min.."-"..max) or (min.."+"));
    end
    
    local x1, y1, x2, y2 = playerPos.x, playerPos.y, targetPos.x, targetPos.y;
    local facing = GetPlayerFacing();
    if not facing then return; end
    
    local dx    = x2 - x1;
    local dy    = y2 - y1;
    local dist  = math.sqrt(dx * dx + dy * dy);
    local angle = math.atan2(dy, dx) - facing;
    return dist, nil, angle, format("%s%.0f|r yd%s |TInterface\\Common\\Spacer:16|t", self:GetRangeColor(dist), dist, dist == 1 and "" or "s");
end

function LootReserveHoU:GetRangeColor(range)
    if range < 15 then
        return "|cff00ff00"; -- green
    elseif range < 25 then
        return "|cffffff00"; -- yellow
    elseif range < 40 then
        return "|cffff7700"; -- orange
    else
        return "|cffff0000"; -- red
    end
end

function LootReserveHoU:TransformSearchText(text)
    text = self:StringTrim(text, "[%s%[%]]");
    text = text:upper();
    text = text:gsub("`", "'"):gsub("´", "'"); -- For whatever reason [`´] doesn't work
    if not tonumber(text) then -- allow for item ids
        text = text:gsub("%A", "");
    end
    return text;
end

function LootReserveHoU:StringTrim(str, chars)
    chars = chars or "%s"
    return (str:match("^" .. chars .. "*(.-)" .. chars .. "*$"));
end

function LootReserveHoU:FormatToRegexp(fmt)
    return fmt:gsub("%d+%$",""):gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)");
end

function LootReserveHoU:Deepcopy(orig)
    if type(orig) == 'table' then
        local copy = { };
        for orig_key, orig_value in next, orig, nil do
            copy[self:Deepcopy(orig_key)] = self:Deepcopy(orig_value)
        end
        setmetatable(copy, self:Deepcopy(getmetatable(orig)))
        return copy;
    else
        return orig;
    end
end

function LootReserveHoU:TableRemove(tbl, val)
    for index, i in ipairs(tbl) do
        if i == val then
            return table.remove(tbl, index);
        end
    end
    return nil;
end

function LootReserveHoU:TableCount(tbl, val)
    local count = 0;
    for _, i in ipairs(tbl) do
        if i == val then
            count = count + 1;
        end
    end
    return count;
end

function LootReserveHoU:Contains(tbl, val)
    for _, i in ipairs(tbl) do
        if i == val then
            return true;
        end
    end
    return false;
end

function LootReserveHoU:Ordered_old(tbl, sorter)
    local __orderedIndex;
    local function __genOrderedIndex(t)
        local orderedIndex = { };
        for key in pairs(t) do
            table.insert(orderedIndex, key);
        end
        if sorter then
            table.sort(orderedIndex, function(a, b)
                return sorter(t[a], t[b], a, b);
            end);
        else
            table.sort(orderedIndex);
        end
        return orderedIndex;
    end

    local function orderedNext(t, state)
        local key;
        if state == nil then
            __orderedIndex = __genOrderedIndex(t)
            key = __orderedIndex[1];
        else
            for i = 1, table.getn(__orderedIndex) do
                if __orderedIndex[i] == state then
                    key = __orderedIndex[i + 1];
                end
            end
        end

        if key then
            return key, t[key];
        end

        __orderedIndex = nil;
        return
    end

    return orderedNext, tbl, nil;
end

function LootReserveHoU:Ordered(tbl, sorter)
    local __orderedIndex = { };
    for key in pairs(tbl) do
        table.insert(__orderedIndex, key);
    end
    if sorter then
        table.sort(__orderedIndex, function(a, b)
            return sorter(tbl[a], tbl[b], a, b);
        end);
    else
        table.sort(__orderedIndex);
    end

    local i = 0;
    local function orderedNext(t)
        i = i + 1;
        return __orderedIndex[i], t[__orderedIndex[i]];
    end

    return orderedNext, tbl, nil;
end

function LootReserveHoU:MakeMenuSeparator()
    return
    {
        text              = "",
        hasArrow          = false,
        dist              = 0,
        isTitle           = true,
        isUninteractable  = true,
        notCheckable      = true,
        iconOnly          = true,
        icon              = "Interface\\Common\\UI-TooltipDivider-Transparent",
        tCoordLeft        = 0,
        tCoordRight       = 1,
        tCoordTop         = 0,
        tCoordBottom      = 1,
        tSizeX            = 0,
        tSizeY            = 8,
        tFitDropDownSizeX = true,
        iconInfo =
        {
            tCoordLeft        = 0,
            tCoordRight       = 1,
            tCoordTop         = 0,
            tCoordBottom      = 1,
            tSizeX            = 0,
            tSizeY            = 8,
            tFitDropDownSizeX = true
        },
    };
end

function LootReserveHoU:RepeatedTable(element, count)
    local result = { };
    for i = 1, count do
        table.insert(result, element);
    end
    return result;
end

function LootReserveHoU:FormatPlayersText(players, colorFunc)
    colorFunc = colorFunc or function(...) return ...; end

    local playersSorted = { };
    local playerNames = { };
    for _, player in ipairs(players) do
        if not playerNames[player] then
           table.insert(playersSorted, player);
           playerNames[player] = true;
        end
    end

    local text = "";
    for _, player in LootReserveHoU:Ordered(playersSorted) do
        text = text .. (#text > 0 and ", " or "") .. colorFunc(player);
    end
    return text;
end

function LootReserveHoU:FormatPlayersTextColored(players, colorFunc)
    return self:FormatPlayersText(players, function(...) return self:ColoredPlayer(...); end);
end

local function FormatReservesText(players, excludePlayer, colorFunc)
    colorFunc = colorFunc or function(...) return ...; end

    local reservesCount = { };
    for _, player in ipairs(players) do
        if not excludePlayer or player ~= excludePlayer then
            reservesCount[player] = reservesCount[player] and reservesCount[player] + 1 or 1;
        end
    end

    local playersSorted = { };
    for player in pairs(reservesCount) do
        table.insert(playersSorted, player);
    end
    table.sort(playersSorted);

    local text = "";
    for _, player in ipairs(playersSorted) do
        text = text .. (#text > 0 and ", " or "") .. colorFunc(player) .. (reservesCount[player] > 1 and format(" x%d", reservesCount[player]) or "");
    end
    return text;
end

function LootReserveHoU:FormatReservesText(players, excludePlayer)
    return FormatReservesText(players, excludePlayer);
end

function LootReserveHoU:FormatReservesTextColored(players, excludePlayer)
    return FormatReservesText(players, excludePlayer, function(...) return self:ColoredPlayer(...); end);
end

function LootReserveHoU:GetCategoriesText(categories, shortName, delimiter)
    local name = shortName and "NameShort" or "Name";
    delimiter = delimiter or " / ";
    local text = ""
    for i, category in ipairs(categories or { }) do
        text = format("%s%s%s", text, i == 1 and "" or delimiter, LootReserveHoU.Data.Categories[category][name]);
    end
    return text;
end

local function GetReservesData(players, me, colorFunc)
    local reservesCount = { };
    for _, player in ipairs(players) do
        reservesCount[player] = reservesCount[player] and reservesCount[player] + 1 or 1;
    end

    local uniquePlayers = { };
    for player in pairs(reservesCount) do
        table.insert(uniquePlayers, player);
    end

    return FormatReservesText(players, me, colorFunc), me and reservesCount[me] or 0, #uniquePlayers, #players;
end

function LootReserveHoU:GetReservesData(players, me)
    return GetReservesData(players, me);
end

function LootReserveHoU:GetReservesDataColored(players, me)
    return GetReservesData(players, me, function(...) return self:ColoredPlayer(...); end);
end

local function GetReservesString(server, isUpdate, link, reservesText, myReserves, uniqueReservers, reserves)
    local blind, multireserve;
    if server then
        blind = LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Settings.Blind;
        multireserve = LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Settings.Multireserve;

        if blind then
            return "";
        end
    else
        blind = LootReserveHoU.Client.Blind;
        multireserve = LootReserveHoU.Client.Multireserve;
    end

    if uniqueReservers <= 1 then
        if myReserves > 0 then
            return format("You are%s%s reserving %s%s.%s",
                isUpdate and " now" or "",
                blind and "" or " the only player",
                link,
                (isUpdate or blind) and "" or " thus far",
                multireserve > 1 and format(" You have %d %s on this item.", myReserves, myReserves == 1 and "reserve" or "reserves") or "");
        else
           return "";
        end
    elseif myReserves > 0 then
        local otherReserves = reserves - myReserves;
        local otherReservers = uniqueReservers - 1;
        return format("There %s%s %d %s for %s: %s.",
            otherReserves == 1 and "is" or "are",
            isUpdate and " now" or "",
            otherReserves,
            multireserve > 1 and format("%s by %d %s", otherReserves == 1 and "other reserve" or "other reserves",
                                                       otherReservers,
                                                       otherReservers == 1 and "player" or "players")
                             or format("%s", otherReserves == 1 and "other contender" or "other contenders"),
            link,
            reservesText);
    else
        return "";
    end
end

function LootReserveHoU:GetReservesString(server, players, player, isUpdate, link)
    return GetReservesString(self, isUpdate, link, self:GetReservesData(players, player));
end

function LootReserveHoU:GetReservesStringColored(server, players, player, isUpdate, link)
    return GetReservesString(server, isUpdate, link, self:GetReservesDataColored(players, player));
end
