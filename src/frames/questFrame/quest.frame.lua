---@diagnostic disable: undefined-global

local DQuestNotes = DQuestNotes or {}

local DEBUG_MODE = false

local function DebugMsg(...)
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage(...)
    end
end

MAX_NUM_QUESTS = 32;
MAX_NUM_ITEMS = 10;
MAX_REQUIRED_ITEMS = 6;
QUEST_DESCRIPTION_GRADIENT_LENGTH = 30;
QUEST_DESCRIPTION_GRADIENT_CPS = 40;
QUESTINFO_FADE_IN = 1;

UIPanelWindows["DQuestFrame"] = { area = "left", pushable = 0 };

-- Initialize custom tooltip if not yet created
if not DialogueUITooltip then
    -- Create tooltip if tooltip.custom.lua didn't load
    local tooltip = CreateFrame("GameTooltip", "DialogueUITooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    
    -- Remove the standard background
    for i = 1, tooltip:GetNumRegions() do
        local region = select(i, tooltip:GetRegions())
        if region:GetObjectType() == "Texture" then
            local textureName = region:GetTexture()
            if textureName and (string.find(textureName, "UI%-Tooltip%-Background") or 
                               string.find(textureName, "UI%-Tooltip%-Border")) then
                region:Hide()
                region:SetTexture(nil)
            end
        end
    end
    
    -- Set custom background
    local bg = tooltip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\TooltipBackground-Temp")
    bg:SetTexCoord(0, 1, 0, 1)
    
    DialogueUITooltip = tooltip
end

if not QuestFrame_SetAsLastShown then
    QuestFrame_SetAsLastShown = function() end
end

if not DialogUI_Config then
    DialogUI_Config = {
        scale = 1.0,
        alpha = 1.0,
        fontSize = 1.0,
        hideTrivialQuests = false, -- New option
    };
end

local COLORS = {
    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    Ivory = {0.87, 0.86, 0.75}
};

-- ==========================================
-- Item usability check functions
-- ==========================================

function DQuestFrame_CanUseItem(itemLink)
    if not itemLink then return true end
    
    local tooltip = DialogueUITooltip
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "DQuestScanTooltip", UIParent, "GameTooltipTemplate")
    end
    
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    
    local canUse = true
    local reason = nil
    
    -- Check ALL tooltip lines (both left and right)
    for i = 1, tooltip:NumLines() do
        -- Check the LEFT side
        local leftText = getglobal(tooltip:GetName() .. "TextLeft" .. i)
        if leftText and leftText:IsShown() then
            local text = leftText:GetText() or ""
            local r, g, b = leftText:GetTextColor()
            
            DebugMsg(string.format("DEBUG Left %d: [%s] RGB(%.2f,%.2f,%.2f)", i, text, r, g, b))
            
            -- Red text on the left side (class, level requirements)
            if r > 0.8 and g < 0.4 and b < 0.4 and i > 1 then
                canUse = false
                reason = "class"
                DebugMsg(string.format("DEBUG: Red text in LEFT: [%s]", text))
            end
        end
        
        -- Check the RIGHT side (armor type is there!)
        local rightText = getglobal(tooltip:GetName() .. "TextRight" .. i)
        if rightText and rightText:IsShown() then
            local text = rightText:GetText() or ""
            local r, g, b = rightText:GetTextColor()
            
            DebugMsg(string.format("DEBUG Right %d: [%s] RGB(%.2f,%.2f,%.2f)", i, text, r, g, b))
            
            -- Armor type is usually on the right side (Leather, Mail, Plate)
            -- If it is red, the class cannot wear it
            if r > 0.8 and g < 0.4 and b < 0.4 then
                canUse = false
                reason = "armor_type"
                DebugMsg(string.format("DEBUG: RED ARMOR TYPE: [%s]", text))
            end
        end
    end
    
    tooltip:Hide()
    return canUse, reason
end

function DQuestFrame_GetCurrencyOverflowIcon(parent)
    local iconName = parent:GetName() .. "CurrencyOverflow"
    local icon = getglobal(iconName)
    
    if not icon then
        icon = parent:CreateTexture(iconName, "OVERLAY")
        icon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\CurrencyOverflow")
        icon:SetWidth(30)
        icon:SetHeight(30)
        -- Anchor to the center of the item icon, not to the edge of the frame
        icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 40, 10)
        icon:Hide()
    end
    
    return icon
end

function DQuestFrame_UpdateItemUsability(questItem, itemType, itemIndex)
    local icon = DQuestFrame_GetCurrencyOverflowIcon(questItem)
    local itemLink = GetQuestItemLink(itemType, itemIndex)
    
    -- Debug info
    DebugMsg(string.format("DEBUG: Updating item %d, type=%s, link=%s", 
        itemIndex, tostring(itemType), tostring(itemLink or "nil")))
    
    if itemLink then
        DebugMsg(string.format("DEBUG: Checking item usability for: %s", itemLink))
        local canUse, reason = DQuestFrame_CanUseItem(itemLink)
        
        DebugMsg(string.format("DEBUG: CanUse=%s, reason=%s", 
            tostring(canUse), tostring(reason or "nil")))
        
        if not canUse then
            DebugMsg("DEBUG: Item cannot be used - SHOWING overflow icon")
            icon:Show()
            questItem.cannotUseReason = reason
            
            -- Verify that the icon actually appeared
            DebugMsg(string.format("DEBUG: Icon visibility after Show: %s, parent: %s", 
                tostring(icon:IsVisible()), tostring(questItem:GetName())))
        else
            DebugMsg("DEBUG: Item can be used - HIDING overflow icon")
            icon:Hide()
            questItem.cannotUseReason = nil
        end
    else
        DebugMsg(string.format("DEBUG: No item link for index %d - HIDING icon", itemIndex))
        icon:Hide()
        questItem.cannotUseReason = nil
    end
end

function DQuestFrame_DebugCheckAllItems()
    DebugMsg("=== DEBUG: Checking all quest items ===")
    
    -- Check progress items
    local numRequiredItems = GetNumQuestItems()
    DebugMsg(string.format("Progress items count: %d", numRequiredItems))
    
    for i = 1, numRequiredItems do
        local itemLink = GetQuestItemLink("required", i)
        DebugMsg(string.format("Progress item %d: %s", i, tostring(itemLink)))
        if itemLink then
            local canUse, reason = DQuestFrame_CanUseItem(itemLink)
            DebugMsg(string.format("  -> Can use: %s, reason: %s", 
                tostring(canUse), tostring(reason or "none")))
        end
    end
    
    -- Check reward items (choice)
    local numChoices = GetNumQuestChoices()
    DebugMsg(string.format("Choice items count: %d", numChoices))
    
    for i = 1, numChoices do
        local itemLink = GetQuestItemLink("choice", i)
        DebugMsg(string.format("Choice item %d: %s", i, tostring(itemLink)))
        if itemLink then
            local canUse, reason = DQuestFrame_CanUseItem(itemLink)
            DebugMsg(string.format("  -> Can use: %s, reason: %s", 
                tostring(canUse), tostring(reason or "none")))
        end
    end
    
    -- Check fixed rewards
    local numRewards = GetNumQuestRewards()
    DebugMsg(string.format("Reward items count: %d", numRewards))
    
    for i = 1, numRewards do
        local itemLink = GetQuestItemLink("reward", i)
        DebugMsg(string.format("Reward item %d: %s", i, tostring(itemLink)))
        if itemLink then
            local canUse, reason = DQuestFrame_CanUseItem(itemLink)
            DebugMsg(string.format("  -> Can use: %s, reason: %s", 
                tostring(canUse), tostring(reason or "none")))
        end
    end
    
    DebugMsg("=== End debug check ===")
end

-- Add slash command to invoke
SLASH_DEBUGITEMS1 = "/debugitems"
SlashCmdList["DEBUGITEMS"] = function()
    DQuestFrame_DebugCheckAllItems()
end

-- ==========================================
-- Quest item event handlers
-- ==========================================

function DQuestItem_OnEnter()
    if (this:GetAlpha() > 0) then
        local tooltip = DialogueUITooltip
        if not tooltip then 
            tooltip = GameTooltip 
        end
        
        tooltip:SetOwner(this, "ANCHOR_RIGHT")
        
        if (this.rewardType == "item") then
            tooltip:SetQuestItem(this.type, this:GetID())
            
            -- Add reason for inability to use item
            if this.cannotUseReason then
                tooltip:AddLine(" ")
                local reasonText = "|cffff0000You cannot use this item|r"
                if this.cannotUseReason == "class" then
                    reasonText = "|cffff0000Wrong class required|r"
                elseif this.cannotUseReason == "skill" then
                    reasonText = "|cffff0000Skill required|r"
                elseif this.cannotUseReason == "level" then
                    reasonText = "|cffff0000Level too low|r"
                end
                tooltip:AddLine(reasonText)
                tooltip:Show()
            end
        elseif (this.rewardType == "spell") then
            tooltip:SetQuestRewardSpell(this:GetID())
            tooltip:Show()
        end
        
        tooltip:Show()
    end
    CursorUpdate()
end

function DQuestItem_OnLeave()
    if DialogueUITooltip then
        DialogueUITooltip:Hide()
    end
    GameTooltip:Hide()
    ResetCursor()
end

-- Constants from Storyline
local GOSSIP_AVAILABLE_FIELDS = 5;
local GOSSIP_ACTIVE_FIELDS = 4;

function SetFontColor(fontObject, key)
    local color = COLORS[key];
    if color then
        fontObject:SetTextColor(color[1], color[2], color[3]);
    end
end

function DQuestFrame_OnLoad()
    if QuestFrame then
        QuestFrame:UnregisterEvent("QUEST_COMPLETE");
        QuestFrame:UnregisterEvent("QUEST_PROGRESS");
        QuestFrame:UnregisterEvent("QUEST_DETAIL");
        QuestFrame:UnregisterEvent("QUEST_GREETING");
        QuestFrame:UnregisterEvent("QUEST_FINISHED");
        QuestFrame:UnregisterEvent("QUEST_ITEM_UPDATE");
        QuestFrame:UnregisterEvent("GOSSIP_SHOW");
    end
    
    this:RegisterEvent("QUEST_GREETING");
    this:RegisterEvent("QUEST_DETAIL");
    this:RegisterEvent("QUEST_PROGRESS");
    this:RegisterEvent("QUEST_COMPLETE");
    this:RegisterEvent("QUEST_FINISHED");
    this:RegisterEvent("QUEST_ITEM_UPDATE");
    this:RegisterEvent("VARIABLES_LOADED");
    
    this:SetMovable(true);
    this:EnableMouse(true);
    this:EnableKeyboard(false);
    
    DialogUI_HookOriginalQuestFunctions();
end

function DialogUI_SavePosition()
    if not DialogUIFramePosition then
        DialogUIFramePosition = {};
    end
    
    local frame = this or DQuestFrame or DGossipFrame;
    if not frame then return; end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint();
    DialogUIFramePosition.point = point;
    DialogUIFramePosition.relativePoint = relativePoint;
    DialogUIFramePosition.xOfs = xOfs;
    DialogUIFramePosition.yOfs = yOfs;
    
    DQuestFramePosition = DialogUIFramePosition;
end

function DialogUI_LoadPosition(frame)
    local position = DialogUIFramePosition or DQuestFramePosition;
    
    if position and position.point and frame then
        frame:ClearAllPoints();
        frame:SetPoint(
            position.point, 
            UIParent, 
            position.relativePoint or position.point, 
            position.xOfs or 0, 
            position.yOfs or -104
        );
    end
end

function DialogUI_ApplyPositionToAllFrames()
    if DQuestFrame then
        DialogUI_LoadPosition(DQuestFrame);
    end
    if DGossipFrame then
        DialogUI_LoadPosition(DGossipFrame);
    end
end

function DQuestFrame_SavePosition()
    DialogUI_SavePosition();
end

function DQuestFrame_LoadPosition()
    DialogUI_LoadPosition(DQuestFrame);
end

function DQuestFrame_OnMouseDown()
    if (arg1 == "LeftButton") then
        this:StartMoving();
    end
end

function DQuestFrame_OnMouseUp()
    this:StopMovingOrSizing();
    DialogUI_SavePosition();
    if DGossipFrame then
        DialogUI_LoadPosition(DGossipFrame);
    end
end

function HideDefaultFrames()
    if QuestFrame then
        QuestFrame:SetAlpha(0);
        QuestFrame:ClearAllPoints();
        QuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    
    if QuestFrameGreetingPanel then
        QuestFrameGreetingPanel:SetAlpha(0);
        QuestFrameGreetingPanel:ClearAllPoints();
        QuestFrameGreetingPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    if QuestFrameDetailPanel then
        QuestFrameDetailPanel:SetAlpha(0);
        QuestFrameDetailPanel:ClearAllPoints();
        QuestFrameDetailPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    if QuestFrameProgressPanel then
        QuestFrameProgressPanel:SetAlpha(0);
        QuestFrameProgressPanel:ClearAllPoints();
        QuestFrameProgressPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    if QuestFrameRewardPanel then
        QuestFrameRewardPanel:SetAlpha(0);
        QuestFrameRewardPanel:ClearAllPoints();
        QuestFrameRewardPanel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    if QuestNpcNameFrame then
        QuestNpcNameFrame:SetAlpha(0);
    end
    if QuestFramePortrait then
        QuestFramePortrait:SetTexture();
        QuestFramePortrait:SetAlpha(0);
    end
    
    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetAlpha(0);
    end
    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetAlpha(0);
    end
    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetAlpha(0);
    end
    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetAlpha(0);
    end
    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetAlpha(0);
    end
    if QuestFrameCompleteQuestButton then
        QuestFrameCompleteQuestButton:SetAlpha(0);
    end
end

function DialogUI_EnsureOriginalQuestHidden()
    if QuestFrame then
        QuestFrame:SetAlpha(0);
        QuestFrame:ClearAllPoints();
        QuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
    end
    
    if QuestFrameGreetingPanel then
        QuestFrameGreetingPanel:SetAlpha(0);
    end
    if QuestFrameDetailPanel then
        QuestFrameDetailPanel:SetAlpha(0);
    end
    if QuestFrameProgressPanel then
        QuestFrameProgressPanel:SetAlpha(0);
    end
    if QuestFrameRewardPanel then
        QuestFrameRewardPanel:SetAlpha(0);
    end
    if QuestNpcNameFrame then
        QuestNpcNameFrame:SetAlpha(0);
    end
    if QuestFramePortrait then
        QuestFramePortrait:SetTexture();
        QuestFramePortrait:SetAlpha(0);
    end
    
    if QuestFrameCloseButton then
        QuestFrameCloseButton:SetAlpha(0);
    end
    if QuestFrameGoodbyeButton then
        QuestFrameGoodbyeButton:SetAlpha(0);
    end
    if QuestFrameAcceptButton then
        QuestFrameAcceptButton:SetAlpha(0);
    end
    if QuestFrameDeclineButton then
        QuestFrameDeclineButton:SetAlpha(0);
    end
    if QuestFrameCompleteButton then
        QuestFrameCompleteButton:SetAlpha(0);
    end
    if QuestFrameCompleteQuestButton then
        QuestFrameCompleteQuestButton:SetAlpha(0);
    end
end

function DialogUI_HookOriginalQuestFunctions()
    if not DialogUI_OriginalCloseWindows then
        DialogUI_OriginalCloseWindows = CloseWindows;
        CloseWindows = function()
            if DQuestFrame and DQuestFrame:IsVisible() then
                HideUIPanel(DQuestFrame);
                return 1;
            end
            return DialogUI_OriginalCloseWindows();
        end;
    end
    
    if QuestFrame and QuestFrame.Show and not QuestFrame.DialogUI_OriginalShow then
        QuestFrame.DialogUI_OriginalShow = QuestFrame.Show;
        QuestFrame.Show = function(self)
            local result = QuestFrame.DialogUI_OriginalShow(self);
            self:SetAlpha(0);
            self:ClearAllPoints();
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
            return result;
        end;
    end
    
    if QuestFrameGreetingPanel and QuestFrameGreetingPanel.Show and not QuestFrameGreetingPanel.DialogUI_OriginalShow then
        QuestFrameGreetingPanel.DialogUI_OriginalShow = QuestFrameGreetingPanel.Show;
        QuestFrameGreetingPanel.Show = function(self)
            local result = QuestFrameGreetingPanel.DialogUI_OriginalShow(self);
            self:SetAlpha(0);
            return result;
        end;
    end
    
    if QuestFrameDetailPanel and QuestFrameDetailPanel.Show and not QuestFrameDetailPanel.DialogUI_OriginalShow then
        QuestFrameDetailPanel.DialogUI_OriginalShow = QuestFrameDetailPanel.Show;
        QuestFrameDetailPanel.Show = function(self)
            local result = QuestFrameDetailPanel.DialogUI_OriginalShow(self);
            self:SetAlpha(0);
            return result;
        end;
    end
    
    if QuestFrameProgressPanel and QuestFrameProgressPanel.Show and not QuestFrameProgressPanel.DialogUI_OriginalShow then
        QuestFrameProgressPanel.DialogUI_OriginalShow = QuestFrameProgressPanel.Show;
        QuestFrameProgressPanel.Show = function(self)
            local result = QuestFrameProgressPanel.DialogUI_OriginalShow(self);
            self:SetAlpha(0);
            return result;
        end;
    end
    
    if QuestFrameRewardPanel and QuestFrameRewardPanel.Show and not QuestFrameRewardPanel.DialogUI_OriginalShow then
        QuestFrameRewardPanel.DialogUI_OriginalShow = QuestFrameRewardPanel.Show;
        QuestFrameRewardPanel.Show = function(self)
            local result = QuestFrameRewardPanel.DialogUI_OriginalShow(self);
            self:SetAlpha(0);
            return result;
        end;
    end
end

function DQuestFrame_OnEvent(event)
    DebugMsg("DEBUG: DQuestFrame_OnEvent: " .. tostring(event));
    
    if (event == "VARIABLES_LOADED") then
        DialogUI_ApplyPositionToAllFrames();
        DialogUI_LoadConfig();
        return;
    end
    
    if (event == "QUEST_FINISHED") then
        HideUIPanel(DQuestFrame);
        DQuestFrame_GossipData = nil  -- Clear data
        return;
    end
    
    if ((event == "QUEST_ITEM_UPDATE") and not DQuestFrame:IsVisible()) then
        return;
    end

    -- Priority handling of QUEST_GREETING
    if (event == "QUEST_GREETING") then
        DebugMsg("DEBUG: QUEST_GREETING received in DQuestFrame");
		
        DQuestFrame:EnableKeyboard(false);
        
        -- Force-hide GossipFrame if visible
        if GossipFrame and GossipFrame:IsVisible() then
            GossipFrame:Hide();
        end
        
        -- Hide DGossipFrame if visible
        if DGossipFrame and DGossipFrame:IsVisible() then
            HideUIPanel(DGossipFrame);
            DGossipFrame:Hide();
        end
        
        -- Hide all standard frames
        HideDefaultFrames();
        DialogUI_EnsureOriginalQuestHidden();
        
        -- Show DQuestFrame
        ShowUIPanel(DQuestFrame);
        
        -- Hide all panels except the greeting panel
        DQuestFrameRewardPanel:Hide();
        DQuestFrameProgressPanel:Hide();
        DQuestFrameDetailPanel:Hide();
        DQuestFrameGreetingPanel:Show();
        
        -- Update portrait if NPC exists
        if UnitExists("npc") then
            DQuestFrame_SetPortrait();
        end
        
        if DialogUI_ApplyAlpha then
            DialogUI_ApplyAlpha();
        end
        
        return;
    end
    
    -- For other events check NPC visibility
    local wasVisible = DQuestFrame:IsVisible();
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    if UnitExists("npc") then
        DQuestFrame_SetPortrait();
    end
    
    if not wasVisible then
        ShowUIPanel(DQuestFrame);
        DQuestFrame:EnableKeyboard(true);
    end
    
    if (not DQuestFrame:IsVisible()) then
        CloseQuest();
        return;
    end
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    if (event == "QUEST_DETAIL") then
        DebugMsg("DEBUG: Received QUEST_DETAIL");
        DQuestFrameRewardPanel:Hide();
        DQuestFrameProgressPanel:Hide();
        DQuestFrameGreetingPanel:Hide();
        DQuestFrameDetailPanel:Show();
        
        if DialogUI_ApplyAlpha then
            DialogUI_ApplyAlpha();
        end
        
    elseif (event == "QUEST_PROGRESS") then
        DebugMsg("DEBUG: Received QUEST_PROGRESS"); 
        DQuestFrameRewardPanel:Hide();
        DQuestFrameDetailPanel:Hide();
        DQuestFrameGreetingPanel:Hide();
        DQuestFrameProgressPanel:Show();
        
        if DialogUI_ApplyAlpha then
            DialogUI_ApplyAlpha();
        end
        
    elseif (event == "QUEST_COMPLETE") then
        DebugMsg("DEBUG: Received QUEST_COMPLETE");
        DQuestFrameProgressPanel:Hide();
        DQuestFrameDetailPanel:Hide();
        DQuestFrameGreetingPanel:Hide();
        DQuestFrameRewardPanel:Show();
        
        DQuestFrameItems_Update("DQuestReward");
        DQuestRewardScrollFrame:UpdateScrollChildRect();
        DQuestRewardScrollFrameScrollBar:SetValue(0);
        
        if DialogUI_ApplyAlpha then
            DialogUI_ApplyAlpha();
        end
        
    elseif (event == "QUEST_ITEM_UPDATE") then
        DebugMsg("DEBUG: Received QUEST_ITEM_UPDATE");
        if DQuestFrameDetailPanel:IsVisible() then
            DQuestFrameItems_Update("DQuestDetail");
            DQuestDetailScrollFrame:UpdateScrollChildRect();
            DQuestDetailScrollFrameScrollBar:SetValue(0);
        elseif DQuestFrameProgressPanel:IsVisible() then
            DQuestFrameProgressItems_Update();
            DQuestProgressScrollFrame:UpdateScrollChildRect();
            DQuestProgressScrollFrameScrollBar:SetValue(0);
        elseif DQuestFrameRewardPanel:IsVisible() then
            DQuestFrameItems_Update("DQuestReward");
            DQuestRewardScrollFrame:UpdateScrollChildRect();
            DQuestRewardScrollFrameScrollBar:SetValue(0);
        end
    end
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
end

function DQuestFrame_ForceShowRewardPanel()
    if not DQuestFrame:IsVisible() then
        ShowUIPanel(DQuestFrame);
    end
    
    DQuestFrameProgressPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    
    DQuestFrameRewardPanel:Show();
    
    DQuestFrameItems_Update("DQuestReward");
    DQuestRewardScrollFrame:UpdateScrollChildRect();
    DQuestRewardScrollFrameScrollBar:SetValue(0);
    
    if DialogUI_ApplyAlpha then
        DialogUI_ApplyAlpha();
    end
end

function DQuestFrame_SetPortrait()
    DQuestFrameNpcNameText:SetText(UnitName("npc"));
    if (UnitExists("npc")) then
        SetPortraitTexture(DQuestFramePortrait, "npc");
    else
        DQuestFramePortrait:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon");
    end
end

function DQuestFrame_GetXPRewardText()
    local xp = GetRewardXP();
    if xp and xp > 0 then
        if type(REWARD_XP) == "string" then
            return string.format(REWARD_XP, xp);
        else
            return "Experience gained: " .. xp;
        end
    end
    return nil;
end

function DQuestFrameRewardPanel_OnShow()
    DQuestFrame:EnableKeyboard(true);
    DQuestFrameDetailPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    DQuestFrameNpcNameText:SetText(GetTitleText());
    
    DQuestRewardText:SetText(GetRewardText());
    
    SetFontColor(DQuestFrameNpcNameText, "DarkBrown");
    SetFontColor(DQuestRewardTitleText, "DarkBrown");
    SetFontColor(DQuestRewardText, "DarkBrown");
    
    DQuestFrameItems_Update("DQuestReward");
    
    DQuestRewardScrollFrame:UpdateScrollChildRect();
    DQuestRewardScrollFrameScrollBar:SetValue(0);
    if (QUEST_FADING_DISABLE == "0") then
        DQuestRewardScrollChildFrame:SetAlpha(0);
        UIFrameFadeIn(DQuestRewardScrollChildFrame, QUESTINFO_FADE_IN);
    end
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    if DialogUI_ApplyAlpha then
        DialogUI_ApplyAlpha();
    end
end

function DQuestRewardCancelButton_OnClick()
    DeclineQuest();
    PlaySound("igQuestCancel");
end

function DQuestRewardCompleteButton_OnClick()
    if (DQuestFrameRewardPanel.itemChoice == 0 and GetNumQuestChoices() > 0) then
        QuestChooseRewardError();
    else
        GetQuestReward(DQuestFrameRewardPanel.itemChoice);
        PlaySound("igQuestListComplete");
    end
end

function DQuestProgressCompleteButton_OnClick()
    CompleteQuest();
    PlaySound("igQuestListComplete");
end

function DQuestGoodbyeButton_OnClick()
    DeclineQuest();
    PlaySound("igQuestCancel");
end

function DQuestItem_OnClick()
    if (IsControlKeyDown()) then
        if (this.rewardType ~= "spell") then
            DressUpItemLink(GetQuestItemLink(this.type, this:GetID()));
        end
    elseif (IsShiftKeyDown()) then
        if (ChatFrameEditBox:IsVisible() and this.rewardType ~= "spell") then
            ChatFrameEditBox:Insert(GetQuestItemLink(this.type, this:GetID()));
        end
    end
end

function DQuestRewardItem_OnClick()
    -- Check key modifiers (same as standard DQuestItem_OnClick)
    if (IsControlKeyDown()) then
        if (this.rewardType ~= "spell") then
            DressUpItemLink(GetQuestItemLink(this.type, this:GetID()));
        end
    elseif (IsShiftKeyDown()) then
        if (ChatFrameEditBox:IsVisible() and this.rewardType ~= "spell") then
            ChatFrameEditBox:Insert(GetQuestItemLink(this.type, this:GetID()));
        end
    -- Add reward selection logic for the reward panel
    elseif (this.type == "choice") then
        -- Highlight the selected reward
        if DQuestRewardItemHighlight then
            DQuestRewardItemHighlight:SetPoint("TOPLEFT", this, "TOPLEFT", -2, 5);
            DQuestRewardItemHighlight:Show();
        end
        -- Save the selected reward ID
        if DQuestFrameRewardPanel then
            DQuestFrameRewardPanel.itemChoice = this:GetID();
        end
    end
end

function DQuestItem_OnEnter()
    if (this:GetAlpha() > 0) then
        local tooltip = DialogueUITooltip
        if tooltip then
            tooltip:SetOwner(this, "ANCHOR_RIGHT")
            if (this.rewardType == "item") then
                tooltip:SetQuestItem(this.type, this:GetID())
                
                -- Add reason for inability to use item
                if this.cannotUseReason then
                    tooltip:AddLine(" ")
                    local reasonText = "|cffff0000You cannot use this item|r"
                    if this.cannotUseReason == "class" then
                        reasonText = "|cffff0000Wrong class required|r"
                    elseif this.cannotUseReason == "skill" then
                        reasonText = "|cffff0000Skill required|r"
                    elseif this.cannotUseReason == "level" then
                        reasonText = "|cffff0000Level too low|r"
                    end
                    tooltip:AddLine(reasonText)
                end
                tooltip:Show()
            elseif (this.rewardType == "spell") then
                tooltip:SetQuestRewardSpell(this:GetID())
                tooltip:Show()
            end
        else
            -- Fallback
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            if (this.rewardType == "item") then
                GameTooltip:SetQuestItem(this.type, this:GetID())
                if this.cannotUseReason then
                    GameTooltip:AddLine(" ")
                    local reasonText = "|cffff0000You cannot use this item|r"
                    if this.cannotUseReason == "class" then
                        reasonText = "|cffff0000Wrong class required|r"
                    elseif this.cannotUseReason == "skill" then
                        reasonText = "|cffff0000Skill required|r"
                    elseif this.cannotUseReason == "level" then
                        reasonText = "|cffff0000Level too low|r"
                    end
                    GameTooltip:AddLine(reasonText)
                end
                GameTooltip:Show()
            elseif (this.rewardType == "spell") then
                GameTooltip:SetQuestRewardSpell(this:GetID())
                GameTooltip:Show()
            end
        end
    end
    CursorUpdate()
end

function DQuestItem_OnLeave()
    if DialogueUITooltip then
        DialogueUITooltip:Hide()
    end
    GameTooltip:Hide()
    ResetCursor()
end

function DQuestFrameProgressPanel_OnShow()
    DQuestFrame:EnableKeyboard(true);
    DQuestFrameRewardPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    DQuestFrameNpcNameText:SetText(GetTitleText());
    DQuestProgressText:SetText(GetProgressText());
    SetFontColor(DQuestFrameNpcNameText, "DarkBrown");
    SetFontColor(DQuestProgressText, "DarkBrown");
    
    local isCompletable = IsQuestCompletable();
    if isCompletable then
        DQuestFrameCompleteButton:Enable();
    else
        DQuestFrameCompleteButton:Disable();
    end
    
    DQuestFrameProgressItems_Update();
    if (QUEST_FADING_DISABLE == "0") then
        DQuestProgressScrollChildFrame:SetAlpha(0);
        UIFrameFadeIn(DQuestProgressScrollChildFrame, QUESTINFO_FADE_IN);
    end
end

function DQuestFrameProgressItems_Update()
    local numRequiredItems = GetNumQuestItems();
    local questItemName = "DQuestProgressItem";
    
    if (numRequiredItems > 0 or GetQuestMoneyToGet() > 0) then
        DQuestProgressRequiredItemsText:Show();

        if (GetQuestMoneyToGet() > 0) then
            MoneyFrame_Update("DQuestProgressRequiredMoneyFrame", GetQuestMoneyToGet());

            if (GetQuestMoneyToGet() > GetMoney()) then
                DQuestProgressRequiredMoneyText:SetTextColor(1.0, 0.1, 0.1);
                SetMoneyFrameColor("DQuestProgressRequiredMoneyFrame", 1.0, 0.1, 0.1);
            else
                DQuestProgressRequiredMoneyText:SetTextColor(1.0, 1.0, 1.0);
                SetMoneyFrameColor("DQuestProgressRequiredMoneyFrame", 1.0, 1.0, 1.0);
            end
            DQuestProgressRequiredMoneyText:Show();
            DQuestProgressRequiredMoneyFrame:Show();

            -- First item below the money
            getglobal(questItemName .. 1):SetPoint("TOPLEFT", "DQuestProgressRequiredMoneyText", "BOTTOMLEFT", 0, -10);
        else
            DQuestProgressRequiredMoneyText:Hide();
            DQuestProgressRequiredMoneyFrame:Hide();

            -- First item below the header
            -- EDIT HERE: x = horizontal offset, y = vertical offset from header
            getglobal(questItemName .. 1):SetPoint("TOPLEFT", "DQuestProgressRequiredItemsText", "BOTTOMLEFT", -3, -25);
        end

        for i = 1, numRequiredItems, 1 do
            local requiredItem = getglobal(questItemName .. i);
            requiredItem.type = "required";
            local name, texture, numItems, quality, isUsable = GetQuestItemInfo(requiredItem.type, i);
            SetItemButtonCount(requiredItem, numItems);
            SetItemButtonTexture(requiredItem, texture);
            requiredItem:Show();
            DQuestFrame_UpdateItemUsability(requiredItem, requiredItem.type, i); 
            getglobal(questItemName .. i .. "Name"):SetText(name);
            
            local itemNameText = getglobal(questItemName .. i .. "Name");
            if itemNameText then
                itemNameText:SetTextColor(1.0, 1.0, 1.0);
            end
            
            -- EDIT HERE: positioning for items 2-6
            if (i > 1) then
                if (mod(i, 2) == 1) then
                    -- Odd indices (3, 5) - new row below the previous
                    -- EDIT: last number is the spacing between rows (currently -10)
                    requiredItem:SetPoint("TOPLEFT", questItemName .. (i - 2), "BOTTOMLEFT", 0, -10);
                else
                    -- Even indices (2, 4, 6) - to the right of the previous
                    -- EDIT: third number is the spacing between items in a row (currently 10)
                    requiredItem:SetPoint("LEFT", questItemName .. (i - 1), "RIGHT", 50, 0);
                end
            end
        end
    else
        DQuestProgressRequiredMoneyText:Hide();
        DQuestProgressRequiredMoneyFrame:Hide();
        DQuestProgressRequiredItemsText:Hide();
    end
    
    for i = numRequiredItems + 1, MAX_REQUIRED_ITEMS, 1 do
        getglobal(questItemName .. i):Hide();
    end
    
    DQuestProgressScrollFrame:UpdateScrollChildRect();
    DQuestProgressScrollFrameScrollBar:SetValue(0);
end

function DQuestFrameGreetingPanel_OnShow()
    DQuestFrame:EnableKeyboard(false);
    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    local gossipData = DQuestFrame_GossipData
    local numActiveQuests, numAvailableQuests
    local gossipActiveQuests = {}
    local gossipAvailableQuests = {}
    
    if gossipData then
        gossipAvailableQuests = gossipData.available
        gossipActiveQuests = gossipData.active
        
        local availCount = table.getn(gossipAvailableQuests)
        local activeCount = table.getn(gossipActiveQuests)
        
        if gossipData.numAvailable then
            numAvailableQuests = gossipData.numAvailable
        else
            if availCount == 2 then
                numAvailableQuests = 1
            elseif availCount % 5 == 0 then
                numAvailableQuests = availCount / 5
            elseif availCount % 4 == 0 then
                numAvailableQuests = availCount / 4
            elseif availCount % 3 == 0 then
                numAvailableQuests = availCount / 3
            elseif availCount % 2 == 0 then
                numAvailableQuests = availCount / 2
            else
                numAvailableQuests = availCount
            end
        end
        
        if gossipData.numActive then
            numActiveQuests = gossipData.numActive
        else
            if activeCount == 2 then
                numActiveQuests = 1
            elseif activeCount % 4 == 0 then
                numActiveQuests = activeCount / 4
            elseif activeCount % 3 == 0 then
                numActiveQuests = activeCount / 3
            elseif activeCount % 2 == 0 then
                numActiveQuests = activeCount / 2
            else
                numActiveQuests = activeCount
            end
        end
    else
        numActiveQuests = GetNumActiveQuests();      -- Already accepted quests
        numAvailableQuests = GetNumAvailableQuests(); -- Quests available to take
        
        if numActiveQuests == 0 and numAvailableQuests == 0 then
            gossipActiveQuests = {GetGossipActiveQuests()};
            gossipAvailableQuests = {GetGossipAvailableQuests()};
            
            if table.getn(gossipAvailableQuests) > 0 then
                local availCount = table.getn(gossipAvailableQuests);
                if availCount % 5 == 0 then
                    numAvailableQuests = availCount / 5;
                elseif availCount % 4 == 0 then
                    numAvailableQuests = availCount / 4;
                elseif availCount % 3 == 0 then
                    numAvailableQuests = availCount / 3;
                else
                    numAvailableQuests = math.floor(availCount / 5);
                end
            end
            
            if table.getn(gossipActiveQuests) > 0 then
                local activeCount = table.getn(gossipActiveQuests);
                if activeCount % 4 == 0 then
                    numActiveQuests = activeCount / 4;
                elseif activeCount % 3 == 0 then
                    numActiveQuests = activeCount / 3;
                elseif activeCount % 2 == 0 then
                    numActiveQuests = activeCount / 2;
                else
                    numActiveQuests = math.floor(activeCount / 4);
                end
            end
        end
    end

    local greetingText
    if gossipData and gossipData.text and gossipData.text ~= "" then
        greetingText = gossipData.text
    else
        greetingText = GetGreetingText();
        if not greetingText or greetingText == "" then
            greetingText = GetGossipText();
        end
    end
    DGreetingText:SetText(greetingText or "");
    
    SetFontColor(DGreetingText, "DarkBrown");
    
    -- Hide text headers
    DCurrentQuestsText:Hide();
    DAvailableQuestsText:Hide();
    DQuestGreetingFrameHorizontalBreak:Hide();

    local buttonIndex = 1;

    -- First show ACTIVE quests (already accepted)
    if (numActiveQuests > 0) then
        -- Anchor the first button to the greeting text
        local greetingText = DGreetingText:GetText() or "";
        if greetingText ~= "" then
            DQuestTitleButton1:SetPoint("TOPLEFT", "DGreetingText", "BOTTOMLEFT", -10, -15);
        else
            DQuestTitleButton1:SetPoint("TOPLEFT", "DQuestGreetingScrollChildFrame", "TOPLEFT", 10, -10);
        end
        
        for i = 1, numActiveQuests, 1 do
            local questTitleButton = getglobal("DQuestTitleButton" .. buttonIndex);
            if not questTitleButton then break end
            
            local questTitle, isComplete, isDaily;
            
            if table.getn(gossipActiveQuests) > 0 then
                -- Gossip API 3.3.5: check data structure
                local totalFields = table.getn(gossipActiveQuests);
                local activeFields = math.floor(totalFields / numActiveQuests);
                
                local baseIndex = (i - 1) * activeFields + 1;
                questTitle = gossipActiveQuests[baseIndex];
                
                -- Try different indices for isComplete
                if activeFields >= 4 then
                    isComplete = gossipActiveQuests[baseIndex + 3]; -- 4th field
                else
                    isComplete = false;
                end
                
                -- Check isDaily if present
                isDaily = false;
                if activeFields >= 5 then
                    isDaily = gossipActiveQuests[baseIndex + 4]; -- 5th field
                end
            else
                -- Standard QUEST_GREETING quests
                questTitle = GetActiveTitle(i);
                isDaily = false;
                
                -- Check completion via quest objectives
                isComplete = false;
                local numEntries = GetNumQuestLogEntries();
                
                for q = 1, numEntries do
                    local qTitle, qLevel, qTag, qGroup, qPlayer, qComplete = GetQuestLogTitle(q);
                    
                    if qTitle and qTitle == questTitle then
                        -- Check via quest objectives
                        local numObjectives = GetNumQuestLeaderBoards(q);
                        
                        if numObjectives == 0 then
                            -- No objectives - quest is complete
                            isComplete = true;
                        else
                            -- Check all objectives
                            local allFinished = true;
                            for obj = 1, numObjectives do
                                local text, type, finished = GetQuestLogLeaderBoard(obj, q);
                                if not finished then
                                    allFinished = false;
                                    break;
                                end
                            end
                            isComplete = allFinished;
                        end
                        break;
                    end
                end
            end
            
            if questTitle and questTitle ~= "" then
                local displayText
                if (buttonIndex <= 9) then
                    displayText = buttonIndex .. ".  " .. questTitle
                else
                    displayText = questTitle
                end
                
                DQuestTitleButton_SetText(questTitleButton, displayText, buttonIndex)
                
                -- Set icon for active quest
                local iconTexture = getglobal(questTitleButton:GetName() .. "QuestIcon");
                if iconTexture then
                    iconTexture:SetTexCoord(0, 1, 0, 1);
                    iconTexture:SetWidth(24);
                    iconTexture:SetHeight(24);
                    
                    if isComplete then
                        if isDaily then
                            iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\CompleteDailyQuest");
                        else
                            iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\completeQuestIcon");
                        end
                    else
                        if isDaily then
                            iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\DailyQuest");
                        else
                            iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\incompleteQuestIcon");
                        end
                    end
                end
                
                questTitleButton:SetID(i);
                questTitleButton.isActive = 1;
                questTitleButton.type = "Active";
                questTitleButton.isGossip = (table.getn(gossipActiveQuests) > 0);
                questTitleButton.isComplete = isComplete;
                questTitleButton.isDaily = isDaily;
                questTitleButton:Show();
                
                if (buttonIndex > 1) then
                    questTitleButton:SetPoint("TOPLEFT", "DQuestTitleButton" .. (buttonIndex - 1), "BOTTOMLEFT", 0, -5);
                end
                
                buttonIndex = buttonIndex + 1;
            end
        end
    end

    -- Then show AVAILABLE quests (can be taken)
    if (numAvailableQuests > 0) then
        for i = 1, numAvailableQuests, 1 do
            local questTitleButton = getglobal("DQuestTitleButton" .. buttonIndex);
            if not questTitleButton then break end
            
            local questTitle, isTrivial, isDaily, isRepeatable;
            
            if table.getn(gossipAvailableQuests) > 0 then
                -- Gossip API 3.3.5: title, level, isLowLevel, isDaily, isRepeatable (5 fields)
                local availableFields = 5;
                local baseIndex = (i - 1) * availableFields + 1;
                questTitle = gossipAvailableQuests[baseIndex];
                isTrivial = gossipAvailableQuests[baseIndex + 2];
                isDaily = gossipAvailableQuests[baseIndex + 3];
                isRepeatable = gossipAvailableQuests[baseIndex + 4];
            else
                questTitle = GetAvailableTitle(i);
                isDaily = false;
                isRepeatable = false;
                isTrivial = IsAvailableQuestTrivial(i);
            end
            
            if DialogUI_Config and DialogUI_Config.hideTrivialQuests and isTrivial then
                -- Skip trivial quests
            elseif questTitle and questTitle ~= "" then
                local displayText
                if (buttonIndex <= 9) then
                    displayText = buttonIndex .. ".  " .. questTitle
                else
                    displayText = questTitle
                end
                
                DQuestTitleButton_SetText(questTitleButton, displayText, buttonIndex)
                
                -- Set icon for available quest
                local iconTexture = getglobal(questTitleButton:GetName() .. "QuestIcon");
                if iconTexture then
                    iconTexture:SetTexCoord(0, 1, 0, 1);
                    iconTexture:SetWidth(24);
                    iconTexture:SetHeight(24);
                    
                    if isDaily then
                        iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\DailyQuest");
                    elseif isRepeatable then
                        iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\repeatableQuestIcon");
                    else
                        iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\availableQuestIcon");
                    end
                end
                
                questTitleButton:SetID(i);
                questTitleButton.isActive = 0;
                questTitleButton.type = "Available";
                questTitleButton.isGossip = (table.getn(gossipAvailableQuests) > 0);
                questTitleButton.isDaily = isDaily;
                questTitleButton.isRepeatable = isRepeatable;
                questTitleButton:Show();
                
                if (buttonIndex > 1) then
                    questTitleButton:SetPoint("TOPLEFT", "DQuestTitleButton" .. (buttonIndex - 1), "BOTTOMLEFT", 0, -5);
                end
                
                buttonIndex = buttonIndex + 1;
            end
        end
    end

    -- Hide unused buttons
    for i = buttonIndex, MAX_NUM_QUESTS, 1 do
        local btn = getglobal("DQuestTitleButton" .. i);
        if btn then btn:Hide(); end
    end

    DQuestGreetingScrollFrame:UpdateScrollChildRect();
    DQuestGreetingScrollFrame:SetVerticalScroll(0);
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    DQuestFrame_GossipData = nil
end

-- Function to set button text with word wrap and expansion
function DQuestTitleButton_SetText(button, text, buttonIndex)
    if not button then return end
    
    local fontString = button:GetFontString()
    if not fontString then return end
    
    -- Set text with wrapping
    fontString:SetText(text)
    
    -- Allow word wrap
    fontString:SetWordWrap(true)
    
    -- Set maximum width for wrapping
    fontString:SetWidth(360)
    
    -- Force size calculation
    fontString:SetHeight(0) -- Auto height
    
    -- Get actual text dimensions
    local textWidth = fontString:GetStringWidth()
    local textHeight = fontString:GetStringHeight()
    
    -- Minimum button height 24px, expand for longer text
    local newHeight = math.max(24, textHeight + 8)
    
    -- Set new button height
    button:SetHeight(newHeight)
    
    -- Update background texture (but NOT the icon!)
    local bg = getglobal(button:GetName() .. "ProgressBackground")
    if bg then
        bg:SetWidth(math.min(textWidth + 45, 400))
        bg:SetHeight(newHeight)
    end
    
    -- Do NOT resize the icon!
    -- The icon should remain 24x24 as defined in XML
end

-- Function to update the background size under quest text
function DQuestTitleButton_UpdateProgressBackground(button)
    if not button then return end
    
    local text = button:GetFontString();
    local bg = getglobal(button:GetName() .. "ProgressBackground");
    
    if text and bg then
        local textWidth = text:GetStringWidth();
        local textHeight = text:GetStringHeight();
        
        if textWidth > 0 then
            -- Width = text width + padding
            -- 35px - space for icon on the left, 10px - right padding
            bg:SetWidth(textWidth + 45);
            -- Height = text height + small padding
            bg:SetHeight(math.max(24, textHeight + 4));
        end
    end
end

function DQuestFrame_OnKeyDown()
    local key = arg1;
    
    -- Movement keys list (SPACE removed!)
    local movementKeys = {
        W = true, A = true, S = true, D = true,
        UP = true, DOWN = true, LEFT = true, RIGHT = true,
        NUMPAD1 = true, NUMPAD2 = true, NUMPAD3 = true,
        NUMPAD4 = true, NUMPAD6 = true, NUMPAD7 = true, NUMPAD8 = true, NUMPAD9 = true
    }
    
    if movementKeys[key] then
        DQuestFrame:EnableKeyboard(false);
        return;
    end
    
    if key == "ESCAPE" then
        HideUIPanel(DQuestFrame);
        DQuestFrame:EnableKeyboard(false);  -- Disable on close
        return;
    end
    
    -- Handle SPACE
    if key == "SPACE" then
        -- Accept quest on the detail panel
        if DQuestFrameDetailPanel and DQuestFrameDetailPanel:IsVisible() then
            if DQuestFrameAcceptButton and DQuestFrameAcceptButton:IsEnabled() then
                AcceptQuest();
                PlaySound("igQuestListComplete");
                return;
            end
        -- Complete quest on the reward panel
        elseif DQuestFrameRewardPanel and DQuestFrameRewardPanel:IsVisible() then
            if DQuestFrameCompleteQuestButton and DQuestFrameCompleteQuestButton:IsEnabled() then
                if (DQuestFrameRewardPanel.itemChoice == 0 and GetNumQuestChoices() > 0) then
                    QuestChooseRewardError();
                else
                    GetQuestReward(DQuestFrameRewardPanel.itemChoice);
                    PlaySound("igQuestListComplete");
                end
                return;
            end
        -- Complete quest on the progress panel
        elseif DQuestFrameProgressPanel and DQuestFrameProgressPanel:IsVisible() then
            if DQuestFrameCompleteButton and DQuestFrameCompleteButton:IsEnabled() then
                CompleteQuest();
                PlaySound("igQuestListComplete");
                return;
            end
        end
    end

    -- Handle number keys 1-9
    if (key >= "1" and key <= "9") then
        local buttonNum = tonumber(key);
        
        local numActiveQuests = GetNumActiveQuests();
        local numAvailableQuests = GetNumAvailableQuests();
        
        if (numActiveQuests == 0 and numAvailableQuests == 0) then
            local gossipActive = {GetGossipActiveQuests()};
            local gossipAvailable = {GetGossipAvailableQuests()};
            numActiveQuests = math.floor(table.getn(gossipActive) / GOSSIP_ACTIVE_FIELDS);
            numAvailableQuests = math.floor(table.getn(gossipAvailable) / GOSSIP_AVAILABLE_FIELDS);
        end
        
        local totalQuests = numActiveQuests + numAvailableQuests;
        
        if (buttonNum <= totalQuests) then
            local questButton = getglobal("DQuestTitleButton" .. buttonNum);
            if (questButton and questButton:IsVisible()) then
                questButton:Click();
            end
        end
    end
end

function DQuestFrame_OnShow()
    PlaySound("igQuestListOpen");
    
    if DialogUI_ApplyAlpha then
        DialogUI_ApplyAlpha();
    end
    
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    
    DQuestFrame:SetScript("OnUpdate", function()
        if not this.hideCheckCounter then
            this.hideCheckCounter = 0;
        end
        this.hideCheckCounter = this.hideCheckCounter + 1;
        
        if this.hideCheckCounter >= 10 then
            this.hideCheckCounter = 0;
            
            if QuestFrame then
                QuestFrame:SetAlpha(0);
                QuestFrame:ClearAllPoints();
                QuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000);
            end
            if QuestFrameGreetingPanel then
                QuestFrameGreetingPanel:SetAlpha(0);
            end
            if QuestFrameDetailPanel then
                QuestFrameDetailPanel:SetAlpha(0);
            end
            if QuestFrameProgressPanel then
                QuestFrameProgressPanel:SetAlpha(0);
            end
            if QuestFrameRewardPanel then
                QuestFrameRewardPanel:SetAlpha(0);
            end
        end
    end);
end

function DQuestFrame_OnHide()
    DQuestFrame:EnableKeyboard(false);
    DQuestFrame:SetScript("OnUpdate", nil);
    
    DQuestFrameGreetingPanel:Hide();
    DQuestFrameDetailPanel:Hide();
    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    
    DQuestFrame_GossipData = nil
    
    CloseQuest();
    PlaySound("igQuestListClose");
    
    DialogUI_SavePosition();
end

function DQuestTitleButton_OnClick()
    DebugMsg("DEBUG: DQuestTitleButton_OnClick executed!");
    
    local buttonID = this:GetID();
    local isActive = this.isActive;
    local isGossip = this.isGossip;
    local buttonType = this.type;
    
    DebugMsg(string.format("DEBUG: Button ID: %d, isActive: %s, isGossip: %s, type: %s", 
        buttonID, tostring(isActive), tostring(isGossip), tostring(buttonType)));
    
    -- For gossip quests use SelectGossip* functions
    if isGossip then
        if isActive == 1 then
            DebugMsg(string.format("DEBUG: Selecting Gossip Active Quest %d", buttonID));
            SelectGossipActiveQuest(buttonID);
        else
            DebugMsg(string.format("DEBUG: Selecting Gossip Available Quest %d", buttonID));
            SelectGossipAvailableQuest(buttonID);
        end
    else
        -- For standard QUEST_GREETING quests
        if isActive == 1 then
            DebugMsg(string.format("DEBUG: Selecting Standard Active Quest %d", buttonID));
            SelectActiveQuest(buttonID);
        else
            DebugMsg(string.format("DEBUG: Selecting Standard Available Quest %d", buttonID));
            SelectAvailableQuest(buttonID);
        end
    end
end

function DQuestMoneyFrame_OnLoad()
    DUI_MoneyFrame_OnLoad();
    DUI_MoneyFrame_SetType("STATIC");
end

function DQuestFrame_ShowXPReward(parentFrame, anchorFrame)
    local xp = GetRewardXP();
    if not xp or xp <= 0 then
        return nil;
    end
    
    local xpText = getglobal(parentFrame:GetName() .. "XPRewardText");
    if not xpText then
        xpText = parentFrame:CreateFontString(parentFrame:GetName() .. "XPRewardText", "ARTWORK", "DQuestFont");
    end
    
    xpText:SetText(string.format(REWARD_XP, xp));
    SetFontColor(xpText, "DarkBrown");
    xpText:Show();
    
    if anchorFrame then
        xpText:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -5);
    end
    
    return xpText;
end

function DQuestFrameItems_Update(questState)
    if (DQuestFrameRewardPanel) then
        DQuestFrameRewardPanel.itemChoice = 0;
    end
    if (DQuestRewardItemHighlight) then
        DQuestRewardItemHighlight:Hide();
    end

    local isQuestLog = 0;
    local numQuestRewards;
    local numQuestChoices;
    local numQuestSpellRewards = 0;
    local money;
    local xp;
    local spacerFrame;
    if (isQuestLog == 0) then
        numQuestRewards = GetNumQuestRewards();
        numQuestChoices = GetNumQuestChoices();
        if (GetRewardSpell()) then
            numQuestSpellRewards = 1;
        end
        money = GetRewardMoney();
        xp = GetRewardXP();
        spacerFrame = DQuestSpacerFrame;
    end

    local totalRewards = numQuestRewards + numQuestChoices + numQuestSpellRewards;
    local questItemName = questState .. "Item";
    local questItemReceiveText = getglobal(questState .. "ItemReceiveText");
    
    local hasAnyReward = (totalRewards > 0) or (money > 0) or (xp > 0);
    
    if not hasAnyReward then
        getglobal(questState .. "RewardTitleText"):Hide();
    else
        getglobal(questState .. "RewardTitleText"):Show();
        SetFontColor(getglobal(questState .. "RewardTitleText"), "DarkBrown");
        QuestFrame_SetAsLastShown(getglobal(questState .. "RewardTitleText"), spacerFrame);
    end
    
    if (money == 0) then
        getglobal(questState .. "MoneyFrame"):Hide();
    else
        getglobal(questState .. "MoneyFrame"):Show();
        QuestFrame_SetAsLastShown(getglobal(questState .. "MoneyFrame"), spacerFrame);
        DUI_MoneyFrame_UpdateFrame(questState .. "MoneyFrame", money);
    end

    for i = totalRewards + 1, MAX_NUM_ITEMS, 1 do
        getglobal(questItemName .. i):Hide();
    end

    local questItem, name, texture, isTradeskillSpell, quality, isUsable, numItems = 1;
    local rewardsCount = 0;
    local lastAnchorFrame = nil;

    if (numQuestChoices > 0) then
        local itemChooseText = getglobal(questState .. "ItemChooseText");
        itemChooseText:Show();
        SetFontColor(itemChooseText, "DarkBrown");
        QuestFrame_SetAsLastShown(itemChooseText, spacerFrame);

        local index;
        local baseIndex = rewardsCount;
        for i = 1, numQuestChoices, 1 do
            index = i + baseIndex;
            questItem = getglobal(questItemName .. index);
            questItem.type = "choice";
            numItems = 1;
            if (isQuestLog == 0) then
                name, texture, numItems, quality, isUsable = GetQuestItemInfo(questItem.type, i);
                if not name or not texture then
                    getglobal(questItemName .. index .. "Name"):SetText("Missing Item "..i);
                    SetItemButtonCount(questItem, 0);
                    SetItemButtonTexture(questItem, "Interface\\Icons\\INV_Misc_QuestionMark");
                end
            end
            questItem:SetID(i)
            questItem:Show();
            questItem.rewardType = "item"
            DQuestFrame_UpdateItemUsability(questItem, questItem.type, i)
            QuestFrame_SetAsLastShown(questItem, spacerFrame);
            
            local itemNameText = getglobal(questItemName .. index .. "Name");
            if itemNameText then
                itemNameText:SetText(name);
                if quality then
                    local r, g, b = GetItemQualityColor(quality);
                    itemNameText:SetTextColor(r, g, b);
                else
                    itemNameText:SetTextColor(1.0, 1.0, 1.0);
                end
            end
            
            SetItemButtonCount(questItem, numItems or 0);
            SetItemButtonTexture(questItem, texture);
            if (isUsable) then
                SetItemButtonTextureVertexColor(questItem, 1.0, 1.0, 1.0);
                SetItemButtonNameFrameVertexColor(questItem, 1.0, 1.0, 1.0);
            else
                SetItemButtonTextureVertexColor(questItem, 0.9, 0, 0);
                SetItemButtonNameFrameVertexColor(questItem, 0.9, 0, 0);
            end
            if (i > 1) then
                if (mod(i, 2) == 1) then
                    -- Increased spacing between item rows
                    questItem:SetPoint("TOPLEFT", questItemName .. (index - 2), "BOTTOMLEFT", 0, -25);
                else
                    -- Increased spacing between items in a row
                    questItem:SetPoint("TOPLEFT", questItemName .. (index - 1), "TOPRIGHT", 50, 0);
                end
            else
                -- Increased offset from "You will receive one of" text
                questItem:SetPoint("TOPLEFT", itemChooseText, "BOTTOMLEFT", -3, -15);
            end
            rewardsCount = rewardsCount + 1;
            lastAnchorFrame = questItem;
        end
    else
        getglobal(questState .. "ItemChooseText"):Hide();
    end

    if (numQuestSpellRewards > 0) then
        local learnSpellText = getglobal(questState .. "SpellLearnText");
        learnSpellText:Show();
        SetFontColor(learnSpellText, "DarkBrown");
        QuestFrame_SetAsLastShown(learnSpellText, spacerFrame);

        if (rewardsCount > 0) then
            -- Increased offset from last item
            learnSpellText:SetPoint("TOPLEFT", questItemName .. rewardsCount, "BOTTOMLEFT", 3, -15);
        else
            learnSpellText:SetPoint("TOPLEFT", questState .. "RewardTitleText", "BOTTOMLEFT", 0, -15);
        end

        if (isQuestLog == 1) then
            texture, name, isTradeskillSpell = GetQuestLogRewardSpell();
        else
            texture, name, isTradeskillSpell = GetRewardSpell();
        end

        if (isTradeskillSpell) then
            learnSpellText:SetText(REWARD_TRADESKILL_SPELL);
        else
            learnSpellText:SetText(REWARD_SPELL);
        end

        rewardsCount = rewardsCount + 1;
        questItem = getglobal(questItemName .. rewardsCount);
        questItem:Show();
        questItem.rewardType = "spell";
        SetItemButtonCount(questItem, 0);
        SetItemButtonTexture(questItem, texture);
        
        local spellNameText = getglobal(questItemName .. rewardsCount .. "Name");
        if spellNameText then
            spellNameText:SetText(name);
            spellNameText:SetTextColor(1.0, 0.82, 0.0);
        end
        
        -- Increased offset from spell text
        questItem:SetPoint("TOPLEFT", learnSpellText, "BOTTOMLEFT", -3, -15);
        lastAnchorFrame = questItem;
    else
        getglobal(questState .. "SpellLearnText"):Hide();
    end

    if (numQuestRewards > 0 or money > 0 or xp > 0) then
        SetFontColor(questItemReceiveText, "DarkBrown");
        
        if (numQuestSpellRewards > 0) then
            questItemReceiveText:SetText(TEXT(REWARD_ITEMS));
            -- Increased offset from spell
            questItemReceiveText:SetPoint("TOPLEFT", questItemName .. rewardsCount, "BOTTOMLEFT", 3, -15);
        elseif (numQuestChoices > 0) then
            questItemReceiveText:SetText(TEXT(REWARD_ITEMS));
            local index = numQuestChoices;
            if (mod(index, 2) == 0) then
                index = index - 1;
            end
            -- Increased offset from choice items
            questItemReceiveText:SetPoint("TOPLEFT", questItemName .. index, "BOTTOMLEFT", 3, -15);
        else
            questItemReceiveText:SetText(TEXT(REWARD_ITEMS_ONLY));
            -- Increased offset from reward title
            questItemReceiveText:SetPoint("TOPLEFT", questState .. "RewardTitleText", "BOTTOMLEFT", 3, -15);
        end
        questItemReceiveText:Show();
        QuestFrame_SetAsLastShown(questItemReceiveText, spacerFrame);
        lastAnchorFrame = questItemReceiveText;
        
        local index;
        local baseIndex = rewardsCount;
        for i = 1, numQuestRewards, 1 do
            index = i + baseIndex;
            questItem = getglobal(questItemName .. index);
            questItem.type = "reward";
            numItems = 1;
            if (isQuestLog == 1) then
                name, texture, numItems, quality, isUsable = GetQuestLogRewardInfo(i);
                if not name or not texture then
                    getglobal(questItemName .. index .. "Name"):SetText("Missing Reward "..i);
                    SetItemButtonCount(questItem, 0);
                    SetItemButtonTexture(questItem, "Interface\\Icons\\INV_Misc_QuestionMark");
                end
            else
                name, texture, numItems, quality, isUsable = GetQuestItemInfo(questItem.type, i);
                if not name or not texture then
                    getglobal(questItemName .. index .. "Name"):SetText("Missing Reward "..i);
                    SetItemButtonCount(questItem, 0);
                    SetItemButtonTexture(questItem, "Interface\\Icons\\INV_Misc_QuestionMark");
                end
            end
            questItem:SetID(i)
            questItem:Show();
            questItem.rewardType = "item";
            DQuestFrame_UpdateItemUsability(questItem, questItem.type, i)
            QuestFrame_SetAsLastShown(questItem, spacerFrame);
            
            local rewardNameText = getglobal(questItemName .. index .. "Name");
            if rewardNameText then
                rewardNameText:SetText(name);
                if quality then
                    local r, g, b = GetItemQualityColor(quality);
                    rewardNameText:SetTextColor(r, g, b);
                else
                    rewardNameText:SetTextColor(1.0, 1.0, 1.0);
                end
            end
            
            SetItemButtonCount(questItem, numItems or 0);
            SetItemButtonTexture(questItem, texture);
            if (isUsable) then
                SetItemButtonTextureVertexColor(questItem, 1.0, 1.0, 1.0);
                SetItemButtonNameFrameVertexColor(questItem, 1.0, 1.0, 1.0);
            else
                SetItemButtonTextureVertexColor(questItem, 0.5, 0, 0);
                SetItemButtonNameFrameVertexColor(questItem, 1.0, 0, 0);
            end

            if (i > 1) then
                if (mod(i, 2) == 1) then
                    -- Increased spacing between item rows
                    questItem:SetPoint("TOPLEFT", questItemName .. (index - 2), "BOTTOMLEFT", 0, -30);
                else
                    -- Increased spacing between items in a row
                    questItem:SetPoint("TOPLEFT", questItemName .. (index - 1), "TOPRIGHT", 60, 0);
                end
            else
                -- Increased offset from "You will also receive" text
                questItem:SetPoint("TOPLEFT", questState .. "ItemReceiveText", "BOTTOMLEFT", -3, -30);
            end
            rewardsCount = rewardsCount + 1;
            lastAnchorFrame = questItem;
        end
        
        -- XP block
        if xp and xp > 0 then
            local xpIcon = getglobal(questState .. "XPIcon");
            if not xpIcon then
                xpIcon = questItemReceiveText:GetParent():CreateTexture(questState .. "XPIcon", "ARTWORK");
            end
            
            xpIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\XP-Green.blp");
            if not xpIcon:GetTexture() then
                xpIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\XP-Green");
            end
            
            xpIcon:SetWidth(32);
            xpIcon:SetHeight(32);
            
            local xpRewardText = getglobal(questState .. "XPRewardText");
            if not xpRewardText then
                xpRewardText = questItemReceiveText:GetParent():CreateFontString(questState .. "XPRewardText", "ARTWORK", "DQuestFont");
            end
            
            local xpText = "Experience " .. xp;
            
            xpRewardText:SetText(xpText);
            SetFontColor(xpRewardText, "DarkBrown");
            
            if rewardsCount > baseIndex then
                local lastItemIndex = rewardsCount;
                if mod(lastItemIndex - baseIndex, 2) == 0 then
                    lastItemIndex = lastItemIndex - 1;
                end
                
                xpIcon:ClearAllPoints();
                -- Reduced offset from last item
                xpIcon:SetPoint("TOPLEFT", questItemName .. lastItemIndex, "BOTTOMLEFT", 0, -15);
                xpIcon:Show();
                
                xpRewardText:ClearAllPoints();
                xpRewardText:SetPoint("LEFT", questState .. "XPIcon", "RIGHT", 5, 0);
            else
                xpIcon:ClearAllPoints();
                -- Reduced offset from "You will also receive" text
                xpIcon:SetPoint("TOPLEFT", questItemReceiveText, "BOTTOMLEFT", 0, -10);
                xpIcon:Show();
                
                xpRewardText:ClearAllPoints();
                xpRewardText:SetPoint("LEFT", questState .. "XPIcon", "RIGHT", 5, 0);
            end
            xpRewardText:Show();
        else
            local xpIcon = getglobal(questState .. "XPIcon");
            if xpIcon then
                xpIcon:Hide();
            end
        end
    else
        questItemReceiveText:Hide();
        local xpRewardText = getglobal(questState .. "XPRewardText");
        if xpRewardText then
            xpRewardText:Hide();
        end
        local xpIcon = getglobal(questState .. "XPIcon");
        if xpIcon then
            xpIcon:Hide();
        end
    end
    
    if (questState == "QuestReward") then
        DQuestFrameCompleteQuestButton:Enable();
        DQuestFrameRewardPanel.itemChoice = 0;
        DQuestRewardItemHighlight:Hide();
    end
end

function DQuestFrameDetailPanel_OnShow()
    DQuestFrame:EnableKeyboard(true);
    DQuestFrameRewardPanel:Hide();
    DQuestFrameProgressPanel:Hide();
    DQuestFrameGreetingPanel:Hide();
    HideDefaultFrames();
    DialogUI_EnsureOriginalQuestHidden();
    DQuestFrameNpcNameText:SetText(GetTitleText());
    DQuestDescription:SetText(GetQuestText());
    DQuestObjectiveText:SetText(GetObjectiveText());
    SetFontColor(DQuestFrameNpcNameText, "DarkBrown");
    SetFontColor(DQuestDescription, "DarkBrown");
    SetFontColor(DQuestObjectiveText, "DarkBrown");
    QuestFrame_SetAsLastShown(DQuestObjectiveText, DQuestSpacerFrame);
    DQuestFrameItems_Update("DQuestDetail");
    DQuestDetailScrollFrame:UpdateScrollChildRect();
    DQuestDetailScrollFrameScrollBar:SetValue(0);

    DTextAlphaDependentFrame:SetAlpha(0);
    DQuestFrameAcceptButton:Disable();

    DQuestFrameDetailPanel.fading = 1;
    DQuestFrameDetailPanel.fadingProgress = 0;
    DQuestDescription:SetAlphaGradient(0, QUEST_DESCRIPTION_GRADIENT_LENGTH);
    if (QUEST_FADING_DISABLE == "1") then
        DQuestFrameDetailPanel.fadingProgress = 1024;
    end
    
    DialogUI_EnsureOriginalQuestHidden();
end

function DQuestFrameDetailPanel_OnUpdate(elapsed)
    if (this.fading) then
        DialogUI_EnsureOriginalQuestHidden();
        
        this.fadingProgress = this.fadingProgress + (elapsed * QUEST_DESCRIPTION_GRADIENT_CPS);
        PlaySound("WriteQuest");
        if (not DQuestDescription:SetAlphaGradient(this.fadingProgress, QUEST_DESCRIPTION_GRADIENT_LENGTH)) then
            this.fading = nil;
            if (QUEST_FADING_DISABLE == "0") then
                UIFrameFadeIn(DTextAlphaDependentFrame, QUESTINFO_FADE_IN);
            else
                DTextAlphaDependentFrame:SetAlpha(1);
            end
            DQuestFrameAcceptButton:Enable();
        end
    end
end

function DQuestDetailAcceptButton_OnClick()
    AcceptQuest();
end

function DQuestDetailDeclineButton_OnClick()
    DeclineQuest();
    PlaySound("igQuestCancel");
end

function DQuestFrame_OnCancel()
    HideUIPanel(DQuestFrame);
end

function UpdateQuestIcons()
    for i = 1, MAX_NUM_QUESTS do
        local button = getglobal("DQuestTitleButton"..i);
        if not button or not button:IsVisible() then break end
        
        local iconTexture = getglobal(button:GetName() .. "QuestIcon");
        if not iconTexture then break end
        
        iconTexture:SetTexCoord(0, 1, 0, 1);
        iconTexture:SetWidth(24);
        iconTexture:SetHeight(24);
        
        if button.type == "Active" then
            -- Active quest (in progress)
            if button.isComplete then
                -- Complete - ready to turn in
                if button.isDaily then
                    iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\CompleteDailyQuest");
                else
                    iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\completeQuestIcon");
                end
            else
                -- Not complete - in progress
                if button.isDaily then
                    iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\DailyQuest");
                else
                    iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\incompleteQuestIcon");
                end
            end
            
        elseif button.type == "Available" then
            -- Available quest (can be taken)
            if button.isDaily then
                iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\DailyQuest");
            elseif button.isRepeatable then
                iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\repeatableQuestIcon");
            else
                iconTexture:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\availableQuestIcon");
            end
        end
    end
end

function DialogUI_ResetPosition()
    DialogUIFramePosition = nil;
    DQuestFramePosition = nil;
    
    if DQuestFrame then
        DQuestFrame:ClearAllPoints();
        DQuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104);
    end
    if DGossipFrame then
        DGossipFrame:ClearAllPoints();
        DGossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104);
    end
    
    DebugMsg("DialogUI: All frame positions reset to default.");
end

function DQuestFrame_ResetPosition()
    DialogUI_ResetPosition();
end

function DialogUI_DebugState()
    local position = DialogUIFramePosition or DQuestFramePosition;
    if position then
        DebugMsg("Saved Position: (" .. (position.xOfs or 0) .. ", " .. (position.yOfs or 0) .. ")");
    else
        DebugMsg("No saved position found");
    end
    
    if DQuestFrame then
        local movable = DQuestFrame:IsMovable() and "YES" or "NO";
        local mouseEnabled = DQuestFrame:IsMouseEnabled() and "YES" or "NO";
        local visible = DQuestFrame:IsVisible() and "YES" or "NO";
        
        DebugMsg("Quest Frame: Movable=" .. movable .. ", Mouse=" .. mouseEnabled .. ", Visible=" .. visible);
    end
    
    if DGossipFrame then
        local movable = DGossipFrame:IsMovable() and "YES" or "NO";
        local mouseEnabled = DGossipFrame:IsMouseEnabled() and "YES" or "NO";
        local visible = DGossipFrame:IsVisible() and "YES" or "NO";
        
        DebugMsg("Gossip Frame: Movable=" .. movable .. ", Mouse=" .. mouseEnabled .. ", Visible=" .. visible);
    end
end

function DQuestFrame_DebugState()
    DialogUI_DebugState();
end

SlashCmdList["DIALOGUI_RESET"] = DialogUI_ResetPosition;
SLASH_DIALOGUI_RESET1 = "/resetdialogs";
SLASH_DIALOGUI_RESET2 = "/resetquest";
SLASH_DIALOGUI_RESET3 = "/questframereset";

SlashCmdList["DIALOGUI_DEBUG"] = DialogUI_DebugState;
SLASH_DIALOGUI_DEBUG1 = "/debugquest";
SLASH_DIALOGUI_DEBUG2 = "/debugdialogs";

function DialogUI_ShowConfig()
    if DConfigFrame then
        ShowUIPanel(DConfigFrame);
    else
        DebugMsg("DialogUI: Configuration window not available yet. Try /reload.");
    end
end

function DialogUI_HideConfig()
    if DConfigFrame then
        HideUIPanel(DConfigFrame);
    end
end

function DialogUI_ToggleConfig()
    if DConfigFrame then
        if DConfigFrame:IsVisible() then
            DialogUI_HideConfig();
        else
            DialogUI_ShowConfig();
        end
    else
        DialogUI_ShowConfig();
    end
end

SlashCmdList["DIALOGUI_CONFIG"] = DialogUI_ToggleConfig;
SLASH_DIALOGUI_CONFIG1 = "/dialogui";
SLASH_DIALOGUI_CONFIG2 = "/dialogconfig";
SLASH_DIALOGUI_CONFIG3 = "/dconfig";

SlashCmdList["DIALOGUI_SETTINGS"] = DialogUI_ToggleConfig;
SLASH_DIALOGUI_SETTINGS1 = "/dialogsettings";

function DialogUI_TestQuestFrame()
    if DQuestFrame then
        DQuestFrame:Show();
        HideDefaultFrames();
        
        if DQuestFrameGreetingPanel then
            DQuestFrameGreetingPanel:Show();
        end
    else
        DebugMsg("DialogUI: ERROR - DQuestFrame does not exist!");
    end
end

SlashCmdList["DIALOGUI_TEST"] = DialogUI_TestQuestFrame;
SLASH_DIALOGUI_TEST1 = "/dtest";

function DialogUI_LoadConfig()
    if DialogUI_SavedConfig then
        DialogUI_Config.scale = DialogUI_SavedConfig.scale or 1.0;
        DialogUI_Config.alpha = DialogUI_SavedConfig.alpha or 1.0;
        DialogUI_Config.fontSize = DialogUI_SavedConfig.fontSize or 1.0;
        DialogUI_Config.hideTrivialQuests = DialogUI_SavedConfig.hideTrivialQuests or false;
    end
end

function DialogUI_SaveConfig()
    if not DialogUI_SavedConfig then
        DialogUI_SavedConfig = {};
    end
    
    DialogUI_SavedConfig.scale = DialogUI_Config.scale;
    DialogUI_SavedConfig.alpha = DialogUI_Config.alpha;
    DialogUI_SavedConfig.fontSize = DialogUI_Config.fontSize;
    DialogUI_SavedConfig.hideTrivialQuests = DialogUI_Config.hideTrivialQuests;
end

function DialogUI_ApplyAlpha()
    local alpha = DialogUI_Config.alpha;
    
    if DQuestFrame then
        DialogUI_ApplyAlphaToPanel(DQuestFrame, alpha);
        
        local rewardPanel = getglobal("DQuestFrameRewardPanel");
        if rewardPanel then
            DialogUI_ApplyAlphaToPanel(rewardPanel, alpha);
        end
        
        local progressPanel = getglobal("DQuestFrameProgressPanel");
        if progressPanel then
            DialogUI_ApplyAlphaToPanel(progressPanel, alpha);
        end
        
        local greetingPanel = getglobal("DQuestFrameGreetingPanel");
        if greetingPanel then
            DialogUI_ApplyAlphaToPanel(greetingPanel, alpha);
        end
        
        local detailPanel = getglobal("DQuestFrameDetailPanel");
        if detailPanel then
            DialogUI_ApplyAlphaToPanel(detailPanel, alpha);
        end
    end
    
    if DGossipFrame then
        DialogUI_ApplyAlphaToPanel(DGossipFrame, alpha);
        
        local gossipGreetingPanel = getglobal("DGossipFrameGreetingPanel");
        if gossipGreetingPanel then
            DialogUI_ApplyAlphaToPanel(gossipGreetingPanel, alpha);
        end
    end
    
    local moneyFrame = getglobal("DQuestProgressRequiredMoneyFrame");
    if moneyFrame then
        DialogUI_ApplyAlphaToPanel(moneyFrame, alpha);
    end
end

function DialogUI_ApplyAlphaToPanel(panel, alpha)
    if not panel then return; end

    local regions = {panel:GetRegions()};
    for i = 1, table.getn(regions) do
        local region = regions[i];
        if region and region:GetObjectType() == "Texture" then
            local texturePath = region:GetTexture();
            if texturePath and (
                string.find(texturePath, "Parchment") or
                string.find(texturePath, "Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\Parchment")
                ) then
                region:SetAlpha(alpha);
                break;
            end
        end
    end
end

-- Temporary test - show icon on all items
function DQuestFrame_DebugShowAllIcons()
    for i = 1, 10 do
        local item = getglobal("DQuestRewardItem" .. i)
        if item and item:IsVisible() then
            local icon = DQuestFrame_GetCurrencyOverflowIcon(item)
            icon:Show()
            DebugMsg("Showed icon on " .. item:GetName())
        end
    end
end

SLASH_DEBUGICONS1 = "/debugicons"
SlashCmdList["DEBUGICONS"] = DQuestFrame_DebugShowAllIcons
