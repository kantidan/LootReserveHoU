LootReserveHoU = LootReserveHoU or { };
LootReserveHoU.Client =
{
    -- Server Connection
    SessionServer = nil,
    Masquerade    = nil,

    -- Server Session Info
    StartTime         = 0,
    AcceptingReserves = false,
    RemainingReserves = 0,
    MaxReserves       = 0,
    Locked            = false,
    OptedOut          = false,
    LootCategories    = nil,
    Duration          = nil,
    MaxDuration       = nil,
    ItemReserves      = { }, -- { [ItemID] = { "Playername", "Playername", ... }, ... }
    ItemConditions    = { },
    RollRequest       = nil,
    Equip             = true,
    Blind             = false,
    Multireserve      = 1,

    Settings =
    {
        RollRequestShow             = true,
        RollRequestShowUnusable     = false,
        RollRequestShowUnusableBoE  = false,
        RollRequestGlowOnlyReserved = true,
        RollRequestAutoRollReserved = true,
        RollRequestAutoRollNotified = false,
        RollRequestWinnerReaction   = true,
        RollRequestLoserReaction    = true,
        CollapsedExpansions         = { },
        CollapsedCategories         = { },
        SwapLDBButtons              = false,
        LibDBIcon                   = { },
        AllowPreCache               = false,
        ShowReopenHint              = true,
    },
    CharacterFavorites = { },
    GlobalFavorites    = { },

    PendingItems             = { },
    PendingOpt               = nil,
    PendingOpen              = false,
    ServerSearchTimeoutTime  = nil,
    DurationUpdateRegistered = false,
    SessionEventsRegistered  = false,
    CategoryFlashing         = false,
    
    PendingLootListUpdate    = nil,

    SelectedCategory = nil,
};

function LootReserveHoU.Client:Load()
    LootReserveHoUCharacterSave.Client = LootReserveHoUCharacterSave.Client or { };
    LootReserveHoUGlobalSave.Client = LootReserveHoUGlobalSave.Client or { };

    -- Copy data from saved variables into runtime tables
    -- Don't outright replace tables, as new versions of the addon could've added more fields that would be missing in the saved data
    local function loadInto(to, from, field)
        if from and to and field then
            if from[field] then
                for k, v in pairs(from[field]) do
                    to[field] = to[field] or { };
                    to[field][k] = v;
                    empty = false;
                end
            end
            from[field] = to[field];
        end
    end
    loadInto(self, LootReserveHoUGlobalSave.Client, "Settings");
    loadInto(self, LootReserveHoUCharacterSave.Client, "CharacterFavorites");
    loadInto(self, LootReserveHoUGlobalSave.Client, "GlobalFavorites");

    LibStub("LibDBIcon-1.0").RegisterCallback("LootReserveHoU", "LibDBIcon_IconCreated", function(event, button, name)
        if name == "LootReserveHoU" then
            button.icon:SetTexture("Interface\\AddOns\\LootReserveHoU\\Assets\\Textures\\Icon");
        end
    end);
    LibStub("LibDBIcon-1.0"):Register("LootReserveHoU", LibStub("LibDataBroker-1.1"):NewDataObject("LootReserveHoU", {
        type = "launcher",
        text = "LootReserveHoU",
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
        OnClick = function(ldb, button)
            if button == "LeftButton" or button == "RightButton" then
                local window = ((button == "LeftButton") == self.Settings.SwapLDBButtons) and LootReserveHoU.Server.Window or LootReserveHoU.Client.Window;
                if InCombatLockdown() and window:IsProtected() and window == LootReserveHoU.Server.Window then
                    LootReserveHoU:ToggleServerWindow(not window:IsShown());
                else
                    window:SetShown(not window:IsShown());
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText("LootReserveHoU", HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1);
            tooltip:AddLine(format("Left-Click: Open %s Window", self.Settings.SwapLDBButtons and "Host" or "Reserves"));
            tooltip:AddLine(format("Right-Click: Open %s Window", self.Settings.SwapLDBButtons and "Reserves" or "Host"));
        end,
    }), self.Settings.LibDBIcon);
end

function LootReserveHoU.Client:IsFavorite(itemID)
    return self.CharacterFavorites[itemID] or self.GlobalFavorites[itemID];
end

function LootReserveHoU.Client:SetFavorite(itemID, enabled)
    if self:IsFavorite(itemID) == (enabled and true or false) then return; end
    
    local item = LootReserveHoU.ItemCache:Item(itemID);
    if not item or not item:GetInfo() then return; end
    local bindType = item:GetBindType();

    local favorites = bindType == LE_ITEM_BIND_ON_ACQUIRE and self.CharacterFavorites or self.GlobalFavorites;
    favorites[itemID] = enabled and true or nil;
    self:FlashCategory("Favorites");
end

function LootReserveHoU.Client:SearchForServer(startup)
    if not startup and self.ServerSearchTimeoutTime and time() < self.ServerSearchTimeoutTime then return; end
    self.ServerSearchTimeoutTime = time() + 10;

    LootReserveHoU.Comm:BroadcastHello();
end

function LootReserveHoU.Client:SetMasquerade(player)
    local oldMasquerade = self.Masquerade;
    if self.SessionServer and LootReserveHoU:IsMe(self.SessionServer) and LootReserveHoU.Server and LootReserveHoU.Server.CurrentSession then
        if not player or LootReserveHoU:IsMe(player) then
            self.Masquerade = nil;
        else
            self.Masquerade = player;
        end
        if oldMasquerade ~= self.Masquerade then
            LootReserveHoU.Comm:SendSessionInfo(LootReserveHoU:Me());
        end
    end
end

function LootReserveHoU.Client:StartSession(server, starting, startTime, acceptingReserves, lootCategories, duration, maxDuration, equip, blind, multireserve)
    self:ResetSession(true);
    self.SessionServer = server;
    self.StartTime = startTime;
    self.AcceptingReserves = acceptingReserves;
    self.LootCategories = lootCategories;
    self.Duration = duration;
    self.MaxDuration = maxDuration;
    self.Equip = equip;
    self.Blind = blind;
    self.Multireserve = multireserve;

    if self.MaxDuration ~= 0 and not self.DurationUpdateRegistered then
        self.DurationUpdateRegistered = true;
        LootReserveHoU:RegisterUpdate(function(elapsed)
            if self.SessionServer and self.AcceptingReserves and self.Duration ~= 0 then
                if self.Duration > elapsed then
                    self.Duration = self.Duration - elapsed;
                else
                    self.Duration = 0;
                    self:StopSession();
                end
            end
        end);
    end

    if not self.SessionEventsRegistered then
        self.SessionEventsRegistered = true;

        LootReserveHoU:RegisterEvent("GROUP_LEFT", function()
            if self.SessionServer and not LootReserveHoU:IsMe(self.SessionServer) then
                self:StopSession();
                self:ResetSession();
                self:UpdateCategories();
                self:UpdateLootList();
                self:UpdateReserveStatus();
            end
        end);

        LootReserveHoU:RegisterEvent("GROUP_ROSTER_UPDATE", function()
            if self.SessionServer and not LootReserveHoU:UnitInGroup(self.SessionServer) then
                self:StopSession();
                self:ResetSession();
                self:UpdateCategories();
                self:UpdateLootList();
                self:UpdateReserveStatus();
            end
        end);

        LootReserveHoU:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            if self.SessionServer and self.PendingOpen then
                self.Window:Show();
            end
            self.PendingOpen = false;
        end);

        local function OnTooltipSetHyperlink(tooltip)
            if self.SessionServer and not LootReserveHoU:IsMe(self.SessionServer) then
                local name, link = tooltip:GetItem();
                if not link then return; end
                
                -- Check if it's already been added
                local frame, text;
                for i = 1, 50 do
                frame = _G[tooltip:GetName() .. "TextLeft" .. i];
                if frame then
                    text = frame:GetText();
                end
                if text and string.find(text, " Reserved by ", 1, true) then return; end
                end

                local itemID = LootReserveHoU.ItemCache:Item(link):GetID();
                local tokenID = LootReserveHoU.Data:GetToken(itemID);
                if #self:GetItemReservers(tokenID or itemID) > 0 then
                    local reservesText = LootReserveHoU:FormatReservesTextColored(self:GetItemReservers(tokenID or itemID));
                    tooltip:AddLine("|TInterface\\BUTTONS\\UI-GroupLoot-Dice-Up:32:32:0:-4|t Reserved by " .. reservesText, 1, 1, 1);
                end
            end
        end
        GameTooltip             : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
        ItemRefTooltip          : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
        ItemRefShoppingTooltip1 : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
        ItemRefShoppingTooltip2 : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
        ShoppingTooltip1        : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
        ShoppingTooltip2        : HookScript("OnTooltipSetItem", OnTooltipSetHyperlink);
    end

    if starting then
        self.Masquerade = nil;
        local lootCategoriesText = LootReserveHoU:GetCategoriesText(self.LootCategories);
        LootReserveHoU:PrintMessage("Session started%s%s.", lootCategoriesText ~= "" and " for ", lootCategoriesText);
        if self.AcceptingReserves then
            PlaySound(SOUNDKIT.GS_CHARACTER_SELECTION_ENTER_WORLD);
        end
    end
end

function LootReserveHoU.Client:StopSession()
    self.AcceptingReserves = false;
end

function LootReserveHoU.Client:ResetSession(refresh)
    self.SessionServer     = nil;
    self.RemainingReserves = 0;
    self.MaxReserves       = 0;
    self.LootCategories    = nil;
    self.ItemReserves      = { };
    self.ItemConditions    = { };
    self.Equip             = true;
    self.Blind             = false;
    self.Multireserve      = 1;
    self.PendingItems      = { };
    self.PendingOpts       = nil;

    if not refresh then
        self:StopCategoryFlashing();
    end
end

function LootReserveHoU.Client:GetRemainingReserves()
    return self.SessionServer and self.AcceptingReserves and self.RemainingReserves or 0;
end
function LootReserveHoU.Client:HasRemainingReserves()
    return self:GetRemainingReserves() > 0;
end
function LootReserveHoU.Client:GetMaxReserves()
    return self.SessionServer and self.MaxReserves or 0;
end

function LootReserveHoU.Client:IsItemReserved(itemID)
    return #self:GetItemReservers(LootReserveHoU.Data:GetToken(itemID) or itemID) > 0;
end
function LootReserveHoU.Client:IsItemReservedByMe(itemID, bypassMasquerade)
    for _, player in ipairs(self:GetItemReservers(LootReserveHoU.Data:GetToken(itemID) or itemID)) do
        if LootReserveHoU:IsSamePlayer(not bypassMasquerade and LootReserveHoU.Client.Masquerade or LootReserveHoU:Me(), player) then
            return true;
        end
    end
    return false;
end
function LootReserveHoU.Client:GetItemReservers(itemID)
    if not self.SessionServer then return { }; end
    return self.ItemReserves[LootReserveHoU.Data:GetToken(itemID) or itemID] or { };
end

function LootReserveHoU.Client:IsItemPending(itemID)
    return self.PendingItems[itemID];
end
function LootReserveHoU.Client:SetItemPending(itemID, pending)
    self.PendingItems[itemID] = pending or nil;
end

function LootReserveHoU.Client:Reserve(itemID)
    if not self.SessionServer then return; end
    if not self.AcceptingReserves then return; end
    
    local tokenID = LootReserveHoU.Data:GetToken(itemID);
    if tokenID then
        LootReserveHoU.Client:SetItemPending(tokenID, true);
    end
    LootReserveHoU.Client:SetItemPending(itemID, true);
    
    LootReserveHoU.Client:UpdateReserveStatus();
    LootReserveHoU.Comm:SendReserveItem(tokenID or itemID);
end

function LootReserveHoU.Client:CancelReserve(itemID)
    if not self.SessionServer then return; end
    if not self.AcceptingReserves then return; end
    
    local tokenID = LootReserveHoU.Data:GetToken(itemID);
    if tokenID then
        LootReserveHoU.Client:SetItemPending(tokenID, true);
    end
    LootReserveHoU.Client:SetItemPending(itemID, true);
    
    LootReserveHoU.Client:UpdateReserveStatus();
    LootReserveHoU.Comm:SendCancelReserve(tokenID or itemID);
end

function LootReserveHoU.Client:IsOptPending()
    return self.PendingOpt;
end
function LootReserveHoU.Client:SetOptPending(pending)
    self.PendingOpt = pending or nil;
end

function LootReserveHoU.Client:IsOptedOut()
    return self.OptedOut or false;
end
function LootReserveHoU.Client:IsOptedIn()
    return not self:IsOptedOut();
end

function LootReserveHoU.Client:OptOut()
    if not self.SessionServer then return; end
    if not self.AcceptingReserves then return; end
    self:SetOptPending(true);
    LootReserveHoU.Client:UpdateReserveStatus();
    LootReserveHoU.Comm:SendOptOut();
end

function LootReserveHoU.Client:OptIn()
    if not self.SessionServer then return; end
    if not self.AcceptingReserves then return; end
    self:SetOptPending(true);
    LootReserveHoU.Client:UpdateReserveStatus();
    LootReserveHoU.Comm:SendOptIn();
end
