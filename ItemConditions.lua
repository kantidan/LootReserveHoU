LootReserveHoU = LootReserveHoU or { };
LootReserveHoU.ItemConditions = LootReserveHoU.ItemConditions or { };

local DefaultConditions =
{
    Hidden    = nil,
    Custom    = nil,
    Faction   = nil,
    ClassMask = nil,
    Limit     = nil,
};

function LootReserveHoU.ItemConditions:Get(itemID, server)
    if server and LootReserveHoU.Server.CurrentSession then
        return LootReserveHoU.Server.CurrentSession.ItemConditions[itemID] or LootReserveHoU.Data.ItemConditions[itemID];
    elseif server then
        return LootReserveHoU.Server:GetNewSessionItemConditions()[itemID] or LootReserveHoU.Data.ItemConditions[itemID];
    else
        return LootReserveHoU.Client.ItemConditions[itemID] or LootReserveHoU.Data.ItemConditions[itemID];
    end
end

function LootReserveHoU.ItemConditions:Make(itemID, server)
    if server and LootReserveHoU.Server.CurrentSession then
        LootReserveHoU:ShowError("Cannot edit loot during an active session");
        return nil;
    elseif server then
        local container = LootReserveHoU.Server:GetNewSessionItemConditions();
        local conditions = container[itemID];
        if not conditions then
            conditions = LootReserveHoU:Deepcopy(LootReserveHoU.Data.ItemConditions[itemID]);
            if not conditions then
                conditions = LootReserveHoU:Deepcopy(DefaultConditions);
            end
            container[itemID] = conditions;
        end
        return conditions;
    else
        LootReserveHoU:ShowError("Cannot edit loot on client");
        return nil;
    end
end

function LootReserveHoU.ItemConditions:Save(itemID, server)
    if server and LootReserveHoU.Server.CurrentSession then
        LootReserveHoU:ShowError("Cannot edit loot during an active session");
    elseif server then
        local container = LootReserveHoU.Server:GetNewSessionItemConditions();
        local conditions = container[itemID];
        if conditions then
            -- Coerce conditions
            if conditions.ClassMask == 0 then
                conditions.ClassMask = nil;
            end
            if conditions.Hidden == false then
                conditions.Hidden = nil;
            end
            if conditions.Custom == false then
                conditions.Custom = nil;
            end
            if conditions.Limit and conditions.Limit <= 0 then
                conditions.Limit = nil;
            end
        end

        -- If conditions are no different from the default - delete the table
        if conditions then
            local different = false;
            local default = LootReserveHoU.Data.ItemConditions[itemID];
            if default then
                for k, v in pairs(conditions) do
                    if v ~= default[k] then
                        different = true;
                        break;
                    end
                end
                for k, v in pairs(default) do
                    if v ~= conditions[k] then
                        different = true;
                        break;
                    end
                end
            else
                if next(conditions) then
                    different = true;
                end
            end

            if not different then
                conditions = nil;
                container[itemID] = nil;
            end
        end

        LootReserveHoU.Server.LootEdit:UpdateLootList();
        LootReserveHoU.Server.Import:SessionSettingsUpdated();
    else
        LootReserveHoU:ShowError("Cannot edit loot on client");
    end
end

function LootReserveHoU.ItemConditions:Delete(itemID, server)
    if server and LootReserveHoU.Server.CurrentSession then
        LootReserveHoU:ShowError("Cannot edit loot during an active session");
    elseif server then
        LootReserveHoU.Server:GetNewSessionItemConditions()[itemID] = nil;

        LootReserveHoU.Server.LootEdit:UpdateLootList();
        LootReserveHoU.Server.Import:SessionSettingsUpdated();
    else
        LootReserveHoU:ShowError("Cannot edit loot on client");
    end
end

function LootReserveHoU.ItemConditions:Clear(server)
    if server and LootReserveHoU.Server.CurrentSession then
        LootReserveHoU:ShowError("Cannot edit loot during an active session");
    elseif server then
        table.wipe(LootReserveHoU.Server:GetNewSessionItemConditions());

        LootReserveHoU.Server.LootEdit:UpdateLootList();
        LootReserveHoU.Server.Import:SessionSettingsUpdated();
    else
        LootReserveHoU:ShowError("Cannot edit loot on client");
    end
end

function LootReserveHoU.ItemConditions:HasCustom(server)
    local container;
    if server and LootReserveHoU.Server.CurrentSession then
        container = LootReserveHoU.Server.CurrentSession.ItemConditions
    elseif server then
        container = LootReserveHoU.Server:GetNewSessionItemConditions();
    else
        container = LootReserveHoU.Client.ItemConditions;
    end

    if container then
        for _, conditions in pairs(container) do
            if conditions.Custom then
                return true;
            end
        end
    end
    return false;
end



local function IsItemUsable(itemID, playerClass, isMe)
    local numOwned;
    if isMe then
        numOwned = GetItemCount(itemID, true) - LootReserveHoU:GetTradeableItemCount(itemID);
    end
    
    local item = LootReserveHoU.ItemCache:Item(itemID);
    if not item:Cache():IsCached() then
        return item:IsUsableBy(playerClass), true;
    end
    
    -- If item is Armor or Weapon then fail if class cannot equip it
    if not item:IsUsableBy(playerClass) then return false end
    
    -- If item starts a quest, make sure the quest is not completed and I do not already own the item
    -- If item requires a quest to loot, make sure the quest is not completed, I am on it, and I do not already own the item
    if isMe then
        local questStartID = LootReserveHoU.Data:GetQuestStarted(itemID);
        local questDropID  = LootReserveHoU.Data:GetQuestDropRequirement(itemID);
        if questStartID or questDropID then
            if C_QuestLog.IsQuestFlaggedCompleted(questStartID or questDropID) then
                return false;
            end
            if numOwned > 0 then
                return false;
            end
        end
        if questDropID then
            local found = false;
            local collapsedHeaders = { };
            local i = 1;
            while GetQuestLogTitle(i) do
                local name, _, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(i);
                if isHeader then
                    if isCollapsed then
                        table.insert(collapsedHeaders, 1, i);
                        ExpandQuestHeader(i);
                    end
                elseif questID == questStartID or questID == questDropID then
                    found = true;
                    break;
                end
                i = i + 1;
            end

            for _, i in ipairs(collapsedHeaders) do
                CollapseQuestHeader(i);
            end
            if found then
                return false;
            end
        end
    end
    
    if not item:IsUsableBy(playerClass) then
        return false
    end
    if isMe and numOwned > 0 and item:IsUnique() then
        return false
    end
    
    local unique = item:IsUnique();
    if isMe and item:IsLoaded() then
        -- If item is class-locked then make sure this class is listed
        -- Also make sure the item is not unique if I already own one
        if not LootReserveHoU.TooltipScanner then
            LootReserveHoU.TooltipScanner = CreateFrame("GameTooltip", "LootReserveHoUTooltipScanner", UIParent, "GameTooltipTemplate");
            LootReserveHoU.TooltipScanner:Hide();
        end
        if not LootReserveHoU.TooltipScanner.Unique then
            LootReserveHoU.TooltipScanner.Unique = format("^(%s)$", ITEM_UNIQUE);
        end
        if not LootReserveHoU.TooltipScanner.AlreadyKnown then
            LootReserveHoU.TooltipScanner.AlreadyKnown = format("^(%s)$", ITEM_SPELL_KNOWN);
        end
        if not LootReserveHoU.TooltipScanner.ProfessionAllowed then
            LootReserveHoU.TooltipScanner.ProfessionAllowed = format("^%s$", ITEM_MIN_SKILL:gsub("%d+%$",""):gsub("%%s ", "([%%u%%l%%s]+) "):gsub("%(%%d%)", "%%((%%d+)%%)"));
        end

        LootReserveHoU.TooltipScanner:SetOwner(UIParent, "ANCHOR_NONE");
        LootReserveHoU.TooltipScanner:SetHyperlink("item:" .. itemID);
        for i = 1, LootReserveHoU.TooltipScanner:NumLines() do
            local line = _G[LootReserveHoU.TooltipScanner:GetName() .. "TextLeft" .. i];
            if line and line:GetText() then
                local problem = false;
                    
                if line:GetText():match(LootReserveHoU.TooltipScanner.AlreadyKnown) then
                    local r, g, b = line:GetTextColor();
                    r, g, b = r*255, g*255, b*255;
                    if r > 254 and r <= 255 and g > 31 and g <= 32 and b > 31 and b <= 32 then
                        problem = true;
                    end
                    
                elseif line:GetText():match(LootReserveHoU.TooltipScanner.ProfessionAllowed) then
                    if numOwned > 0 then
                        problem = true;
                    else
                        local r, g, b = line:GetTextColor();
                        r, g, b = r*255, g*255, b*255;
                        if r > 254 and r <= 255 and g > 31 and g <= 32 and b > 31 and b <= 32 then
                            problem = true;
                        end
                    end
                end
                if problem then
                    LootReserveHoU.TooltipScanner:Hide();
                    return false;
                end
            end
        end
        LootReserveHoU.TooltipScanner:Hide();
    end
    
    return true, not item:IsLoaded();
end

local usableCache = { };
local usableCacheHooked = nil;
local function IsItemUsableByMe(itemID)
    if not usableCacheHooked then
        usableCacheHooked = true;
        LootReserveHoU:RegisterEvent("QUEST_ACCEPTED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "CHAT_MSG_SKILL", function()
            usableCache = { };
        end);
    end
    if not usableCache[itemID] then
        local usable, unloaded = IsItemUsable(itemID, select(2, LootReserveHoU:UnitClass(LootReserveHoU:Me())), true);
        if not unloaded then
            usableCache[itemID] = usable;
        else
            return usable, false;
        end
    end
    return usableCache[itemID], true;
end


function LootReserveHoU.ItemConditions:IsItemUsable(itemID, playerClass)
    return IsItemUsable(itemID, playerClass, false);
end
function LootReserveHoU.ItemConditions:IsItemUsableByMe(itemID)
    return IsItemUsableByMe(itemID);
end

function LootReserveHoU.ItemConditions:TestClassMask(classMask, playerClass)
    return classMask and playerClass and bit.band(classMask, bit.lshift(1, playerClass - 1)) ~= 0;
end

function LootReserveHoU.ItemConditions:TestFaction(faction)
    return faction and UnitFactionGroup("player") == faction;
end

function LootReserveHoU.ItemConditions:TestLimit(limit, itemID, player, server)
    if limit <= 0 then
        -- Has no limiton the number of reserves
        return true;
    end

    if server then
        local reserves = LootReserveHoU.Server.CurrentSession.ItemReserves[itemID];
        if not reserves then
            -- Not reserved by anyone yet
            return true;
        end

        return #reserves.Players < limit;
    else
        return #LootReserveHoU.Client:GetItemReservers(itemID) < limit;
    end
end

function LootReserveHoU.ItemConditions:TestPlayer(player, itemID, server)
    if not server and not LootReserveHoU.Client.SessionServer then
        -- Show all items until connected to a server, unless the item is locked to the other faction
        local conditions = self:Get(itemID, server);
        if conditions and conditions.Faction and not self:TestFaction(conditions.Faction) then
            return false, LootReserveHoU.Constants.ReserveResult.FailedFaction;
        end
        return true;
    end
    local playerClass, playerClassID = select(2, LootReserveHoU:UnitClass(player));

    local conditions = self:Get(itemID, server);
    local equip
    if server then
        if LootReserveHoU.Server.CurrentSession then
            equip = LootReserveHoU.Server.CurrentSession.Settings.Equip;
        else
            equip = LootReserveHoU.Server.NewSessionSettings.Equip or false;
        end
    else
        equip = LootReserveHoU.Client.Equip;
    end
    if conditions and conditions.Hidden then
        return false, LootReserveHoU.Constants.ReserveResult.ItemNotReservable;
    end
    if conditions and conditions.ClassMask and playerClass and not self:TestClassMask(conditions.ClassMask, playerClassID) then
        return false, LootReserveHoU.Constants.ReserveResult.FailedClass;
    end
    if equip and playerClass and not self:IsItemUsable(itemID, playerClass) then
        return false, LootReserveHoU.Constants.ReserveResult.FailedUsable;
    end
    if conditions and conditions.Faction and not self:TestFaction(conditions.Faction) then
        return false, LootReserveHoU.Constants.ReserveResult.FailedFaction;
    end
    if conditions and conditions.Limit and not self:TestLimit(conditions.Limit, itemID, player, server) then
        return false, LootReserveHoU.Constants.ReserveResult.FailedLimit;
    end
    return true;
end

function LootReserveHoU.ItemConditions:TestServer(itemID)
    local conditions = self:Get(itemID, true);
    if conditions then
        if conditions.Hidden then
            return false;
        end
        if conditions.Faction and not self:TestFaction(conditions.Faction) then
            return false;
        end
    end
    return true;
end

function LootReserveHoU.ItemConditions:IsItemVisibleOnClient(itemID)
    local tokenID = LootReserveHoU.Data:GetToken(itemID);
    if tokenID and not self:IsItemVisibleOnClient(tokenID) then
        return false;
    end
    local canReserve, conditionResult = self:TestPlayer(LootReserveHoU.Client.Masquerade or LootReserveHoU:Me(), itemID, false);
    return canReserve or conditionResult == LootReserveHoU.Constants.ReserveResult.FailedLimit
           or ((conditionResult == LootReserveHoU.Constants.ReserveResult.FailedClass or conditionResult == LootReserveHoU.Constants.ReserveResult.FailedUsable) and (LootReserveHoU.Client.Locked or not LootReserveHoU.Client.AcceptingReserves));
end

function LootReserveHoU.ItemConditions:IsItemReservableOnClient(itemID)
    local tokenID = LootReserveHoU.Data:GetToken(itemID);
    if tokenID and not self:IsItemReservableOnClient(tokenID) then
        return false;
    end
    local canReserve, conditionResult = self:TestPlayer(LootReserveHoU.Client.Masquerade or LootReserveHoU:Me(), itemID, false);
    return canReserve;
end

function LootReserveHoU.ItemConditions:Pack(conditions)
    local text = "";
    if conditions.Hidden then
        text = text .. "-";
    elseif conditions.Custom then
        text = text .. "+";
    end
    if conditions.Faction == "Alliance" then
        text = text .. "A";
    elseif conditions.Faction == "Horde" then
        text = text .. "H";
    end
    if conditions.ClassMask and conditions.ClassMask ~= 0 then
        text = text .. "C" .. conditions.ClassMask;
    end
    if conditions.Limit and conditions.Limit ~= 0 then
        text = text .. "L" .. conditions.Limit;
    end
    return text;
end

function LootReserveHoU.ItemConditions:Unpack(text)
    local conditions = LootReserveHoU:Deepcopy(DefaultConditions);

    for i = 1, #text do
        local char = text:sub(i, i);
        if char == "-" then
            conditions.Hidden = true;
        elseif char == "+" then
            conditions.Custom = true;
        elseif char == "A" then
            conditions.Faction = "Alliance";
        elseif char == "H" then
            conditions.Faction = "Horde";
        elseif char == "C" then
            for len = 1, 10 do
                local mask = text:sub(i + 1, i + len);
                if tonumber(mask) then
                    conditions.ClassMask = tonumber(mask);
                else
                    break;
                end
            end
        elseif char == "L" then
            for len = 1, 10 do
                local limit = text:sub(i + 1, i + len);
                if tonumber(limit) then
                    conditions.Limit = tonumber(limit);
                else
                    break;
                end
            end
        end
    end
    return conditions;
end