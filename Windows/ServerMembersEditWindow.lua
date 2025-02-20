function LootReserveHoU.Server.MembersEdit:UpdateMembersList()
    LootReserveHoUServerButtonMembersEdit:SetGlow(not LootReserveHoU.Server.CurrentSession and next(LootReserveHoU.Server.NewSessionSettings.ImportedMembers));

    if not self.Window:IsShown() then return; end

    self.Window.Header.Name:SetWidth(LootReserveHoU:IsCrossRealm() and 300 or 200);
    self.Window:SetMinResize(LootReserveHoU:IsCrossRealm() and 650 or 550, 150);

    local list = self.Window.Scroll.Container;
    list.Frames = list.Frames or { };
    list.LastIndex = 0;

    -- Clear everything
    for _, frame in ipairs(list.Frames) do
        frame:Hide();
    end

    local missing = { };

    self.Window.NoSession:SetShown(not LootReserveHoU.Server.CurrentSession and not next(LootReserveHoU.Server.NewSessionSettings.ImportedMembers));
    self.Window.Header.LockedIcon:SetShown(LootReserveHoU.Server.CurrentSession);
    self.Window.ImportExportButton:SetText(LootReserveHoU.Server.CurrentSession and "Export" or "Import/Export");
    self.Window.ImportExportButton:SetWidth(LootReserveHoU.Server.CurrentSession and 60 or 90);

    local function createFrame(player, member)
        list.LastIndex = list.LastIndex + 1;
        local frame = list.Frames[list.LastIndex];
        while not frame do
            frame = CreateFrame("Frame", nil, list, "LootReserveHoUServerMembersEditMemberTemplate");

            if #list.Frames == 0 then
                frame:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -4);
                frame:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -4);
            else
                frame:SetPoint("TOPLEFT", list.Frames[#list.Frames], "BOTTOMLEFT", 0, 0);
                frame:SetPoint("TOPRIGHT", list.Frames[#list.Frames], "BOTTOMRIGHT", 0, 0);
            end
            table.insert(list.Frames, frame);
            frame = list.Frames[list.LastIndex];
        end

        frame.Player = player;
        frame.Member = member;
        frame:Show();

        frame.Alt:SetShown(list.LastIndex % 2 == 0);
        frame.NameFrame:SetText(format("%s%s%s", LootReserveHoU:ColoredPlayer(player), not LootReserveHoU.Server.CurrentSession and "|cFF808080 (imported)|r" or "", LootReserveHoU:IsPlayerOnline(player) == nil and "|cFF808080 (not in raid)|r" or LootReserveHoU:IsPlayerOnline(player) == false and "|cFF808080 (offline)|r" or ""));

        local won = LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Members[player] and LootReserveHoU.Server.CurrentSession.Members[player].WonRolls;
        local wonMaxQuality = 0;
        if won then
            for _, roll in ipairs(won) do
                if roll.Item:IsCached() then
                    wonMaxQuality = math.max(wonMaxQuality, roll.Item:GetQuality());
                else
                    table.insert(missing, roll.Item);
                end
            end
        end
        frame.WonRolls:SetText(format("|c%s%d|r", wonMaxQuality > 0 and select(4, GetItemQualityColor(wonMaxQuality)) or "FF404040", won and #won or 0));

        if LootReserveHoU.Server.CurrentSession then
            frame.CheckButtonLocked:Show();
            frame.CheckButtonLocked:SetChecked(member.Locked);
            frame.CheckButtonLocked:SetEnabled(LootReserveHoU.Server.CurrentSession.Settings.Lock);
            frame.CheckButtonLocked:SetAlpha(LootReserveHoU.Server.CurrentSession.Settings.Lock and 1 or 0.25);
            frame.ButtonDeltaIncrement:SetShown(LootReserveHoU.Server.CurrentSession.Settings.MaxReservesPerPlayer + member.ReservesDelta < LootReserveHoU.Constants.MAX_MULTIRESERVES);
            frame.ButtonDeltaDecrement:SetShown(LootReserveHoU.Server.CurrentSession.Settings.MaxReservesPerPlayer + member.ReservesDelta > 0);
        else
            frame.CheckButtonLocked:Hide();
            frame.ButtonDeltaIncrement:Hide();
            frame.ButtonDeltaDecrement:Hide();
        end

        local maxCount = (LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Settings.MaxReservesPerPlayer or LootReserveHoU.Server.NewSessionSettings.MaxReservesPerPlayer) + member.ReservesDelta;
        local count = member.ReservesLeft and (maxCount - member.ReservesLeft) or #member.ReservedItems;
        frame.Count:SetText(format("|cFF%s%d/%d|r", (count >= maxCount or member.OptedOut) and "00FF00" or count > 0 and "FFD200" or "FF0000", count, maxCount));

        frame.ReservesFrame.Items = frame.ReservesFrame.Items or { };
        local reservedItems = { };
        local itemOrder = { };
        local uniqueCount = 0;
        for _, itemID in ipairs(member.ReservedItems) do
            if not reservedItems[itemID] then
                reservedItems[itemID] = 0;
                uniqueCount = uniqueCount + 1;
            end
            reservedItems[itemID] = reservedItems[itemID] + 1;
        end
        for itemID, count in pairs(reservedItems) do
            local item = LootReserveHoU.ItemCache:Item(itemID);
            table.insert(itemOrder, item);
            if not item:IsCached() then
                table.insert(missing, item);
            end
        end
        
        local last = 0;
        local lastCount = 0;
        for _, item in LootReserveHoU:Ordered(itemOrder, function(a, b) return a < b end) do
            local count = reservedItems[item:GetID()];
            last = last + 1;
            local button = frame.ReservesFrame.Items[last];
            while not button do
                button = CreateFrame("Button", nil, frame.ReservesFrame, "LootReserveHoUServerMembersEditItemTemplate");
                table.insert(frame.ReservesFrame.Items, button);
                button = frame.ReservesFrame.Items[last];
            end
            if last == 1 then
                button:SetPoint("LEFT", frame.ReservesFrame, "LEFT");
            else
                button:SetPoint("LEFT", frame.ReservesFrame.Items[last - 1], "RIGHT", 4 + (lastCount > 0 and 10 or 0) + lastCount*8, 0);
            end
            button:Show();
            button.Item = item:GetID();

            local name, link, texture = item:GetNameLinkTexture();
            button.Link = link;
            button.Icon.Texture:SetTexture(texture);
            if uniqueCount == 1 and item:GetID() ~= 0 then
                if link then
                    button.Icon.Name:SetText((link):gsub("[%[%]]", "") .. (count > 1 and ("|r x" .. count) or ""));
                else
                    button.Icon.Name:SetText("|cFFFF0000Loading...|r");
                end
                button.Icon.Name:Show();
            else
                if count > 1 then
                    button.Icon.Name:SetText("|rx" .. count);
                    button.Icon.Name:Show();
                else
                    button.Icon.Name:Hide();
                end
            end
            if count > 1 then
               lastCount = #tostring(count);
            else
               lastCount = 0; 
            end
        end
        for i = last + 1, #frame.ReservesFrame.Items do
            frame.ReservesFrame.Items[i]:Hide();
        end
    end

    for player, member in LootReserveHoU:Ordered(LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Members or LootReserveHoU.Server.NewSessionSettings.ImportedMembers, function(aMember, bMember, aPlayer, bPlayer) return aPlayer < bPlayer; end) do
        createFrame(player, member);
    end

    for i = list.LastIndex + 1, #list.Frames do
        list.Frames[i]:Hide();
    end

    list:GetParent():UpdateScrollChildRect();

    if #missing > 0 then
        if not self.PendingMembersEditUpdate or self.PendingMembersEditUpdate:IsComplete() then
            self.PendingMembersEditUpdate = LootReserveHoU.ItemCache:OnCache(missing, function()
                self:UpdateMembersList();
            end);
        end
    end
end

function LootReserveHoU.Server.MembersEdit:ClearImported()
    if LootReserveHoU.Server.CurrentSession then return; end

    table.wipe(LootReserveHoU.Server.NewSessionSettings.ImportedMembers);
    self:UpdateMembersList();
end

function LootReserveHoU.Server.MembersEdit:OnWindowLoad(window)
    self.Window = window;
    self.Window.TopLeftCorner:SetSize(32, 32); -- Blizzard UI bug?
    self.Window.TitleText:SetText("LootReserveHoU Host - Players");
    self.Window:SetMinResize(LootReserveHoU:IsCrossRealm() and 650 or 550, 150);
    self:UpdateMembersList();
end
