

function LootReserveHoU.Server.Export:UpdateReservesExportText()
    local members = LootReserveHoU.Server.CurrentSession and LootReserveHoU.Server.CurrentSession.Members or LootReserveHoU.Server.NewSessionSettings.ImportedMembers;
    local text = "";
    if members and next(members) then
        for player, member in LootReserveHoU:Ordered(members, function(aMember, bMember, aPlayer, bPlayer) return aPlayer < bPlayer; end) do
            local counts = { };
            for i, itemID in ipairs(member.ReservedItems) do
                counts[itemID] = (counts[itemID] or 0) + 1;
            end
            for itemID, count in pairs(counts) do
                text = text .. format("\n%s,%s,%d,%d,%d,%d", player, member.Class and select(2, LootReserveHoU:GetClassInfo(member.Class)) or "", member.ReservesDelta, member.RollBonus[itemID], itemID, count);
            end
        end
        text = "Player,Class,ExtraReserves,RollBonus,Item,Count" .. text;
    end
    self:SetText(text);
end

function LootReserveHoU.Server.Export:UpdateRollsExportText(onlySession)
    local minTime = 0;
    if onlySession then
        if LootReserveHoU.Server.CurrentSession then
            minTime = LootReserveHoU.Server.CurrentSession.StartTime;
        else
            minTime = -1
        end
    end
    local text = "";
    local missing = { };
    
    if minTime >= 0 then
        for _, roll in ipairs(LootReserveHoU.Server.RollHistory) do
            if roll.StartTime >= minTime then
                if roll.Item:IsCached() then
                    if #missing == 0 then
                        if roll.Winners then
                            for _, winner in ipairs(roll.Winners) do
                                text = text .. format("\n%d,%d,%s,%s,%d,%s", roll.StartTime, roll.Item:GetID(), roll.Item:GetName(), winner, roll.Custom and 0 or 1, roll.Phases and roll.Phases[1] or "");
                            end
                        else
                            -- this can happen with older rolls, or on a reserved item when nobody rolled
                            local max = 0;
                            local winners = { };
                            for player, rolls in pairs(roll.Players) do
                                for _, rollNumber in ipairs(rolls) do
                                    if rollNumber >= max then
                                        if rollNumber > max then
                                            wipe(winners);
                                            max = rollNumber;
                                        end
                                        winners[player] = true;
                                    end
                                end
                            end
                            if max > 0 then
                                for winner in pairs(winners) do
                                    text = text .. format("\n%d,%d,%s,%s,%d,%s", roll.StartTime, roll.Item:GetID(), roll.Item:GetName(), winner, roll.Custom and 0 or 1, roll.Phases and roll.Phases[1] or "");
                                end
                            end
                        end
                    end
                else
                    table.insert(missing, roll.Item);
                end
            end
        end
        if #missing > 0 then
            text = format("Loading item names...\nRemaining: %d\n\nInstall/Update ItemCache to remember the item database between sessions...", #missing);
        elseif text ~= "" then
            text = "Time,Item ID,Item Name,Winner,Reserved,Reason" .. text;
        end
    end
    
    self:SetText(text);
    
    if #missing > 0 then
        if #missing > LootReserveHoU.ItemSearch.BatchCap then
            for i = LootReserveHoU.ItemSearch.BatchCap + 1, #missing do
                missing[i] = nil;
            end
        end
        if not self.PendingRollsExportTextUpdate or self.PendingRollsExportTextUpdate:IsComplete() then
            self.PendingRollsExportTextUpdate = LootReserveHoU.ItemCache:OnCache(missing, function()
                self:UpdateRollsExportText();
            end);
        end
        self.PendingRollsExportTextUpdate:SetSpeed(math.ceil(#missing/LootReserveHoU.ItemSearch.BatchFrames));
    end
end

function LootReserveHoU.Server.Export:SetText(text)
    self.Window.Output.Scroll.EditBox:SetText(text);
    self.Window.Output.Scroll.EditBox:SetFocus();
    self.Window.Output.Scroll.EditBox:HighlightText();
    self.Window.Output.Scroll:UpdateScrollChildRect();
end

function LootReserveHoU.Server.Export:OnWindowLoad(window)
    self.Window = window;
    self.Window.TopLeftCorner:SetSize(32, 32); -- Blizzard UI bug?
    self.Window.TitleText:SetText("LootReserveHoU Host - Export");
    self.Window:SetMinResize(300, 130);
end
