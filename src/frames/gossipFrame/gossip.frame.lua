---@diagnostic disable: undefined-global

local DEBUG_MODE = false

local function DebugMsg(...)
    if DEBUG_MODE then
        DEFAULT_CHAT_FRAME:AddMessage(...)
    end
end

NUMGOSSIPBUTTONS = 32;

local COLORS = {
    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    Ivory = {0.87, 0.86, 0.75}
};

local savedGossipQuests = {
    available = {},
    active = {},
    text = ""
}

local totalGossipButtons = 0
local talentWipePending = false
local binderPending = false
local gossipCloseTimer = nil

-- Constants for data structure with default values
local GOSSIP_AVAILABLE_FIELDS = 2;  -- title, level, isTrivial, isDaily, isRepeatable
local GOSSIP_ACTIVE_FIELDS = 2;    -- Will be determined dynamically
local GOSSIP_OPTIONS_FIELDS = 2;     -- text, type

local gossipOpenTime = 0
local GOSSIP_MIN_OPEN_TIME = 0.5 -- Minimum time in seconds before closing

-- Flag for tracking QUEST_GREETING
local questGreetingPending = false
local questGreetingTimer = nil

-- Function to determine the number of fields in active quests
local function DetermineActiveQuestFields()
    -- If already determined, return the saved value
    if GOSSIP_ACTIVE_FIELDS then
        return GOSSIP_ACTIVE_FIELDS;
    end
    
    -- Try to get test data
    local testQuests = {GetGossipActiveQuests()};
    local testSize = table.getn(testQuests);
    
    if testSize > 0 then
        -- Try different variants
        if testSize % 4 == 0 then
            GOSSIP_ACTIVE_FIELDS = 4;  -- Standard format
        elseif testSize % 3 == 0 then
            GOSSIP_ACTIVE_FIELDS = 3;  -- Alternative format
        elseif testSize % 2 == 0 then
            GOSSIP_ACTIVE_FIELDS = 2;  -- Simplified format (name and level only)
        else
            GOSSIP_ACTIVE_FIELDS = 4;  -- Default
        end
    else
        GOSSIP_ACTIVE_FIELDS = 4;  -- Default value
    end
    
    return GOSSIP_ACTIVE_FIELDS;
end

-- Function to reset field determination (can be called when needed)
local function ResetActiveQuestFields()
    GOSSIP_ACTIVE_FIELDS = nil;
end

-- Function to check whether an NPC has quests via QUEST_GREETING
local function HasQuestGreetingQuests()
    -- Check standard greeting APIs
    local numActive = GetNumActiveQuests();
    local numAvailable = GetNumAvailableQuests();
    
    if numActive > 0 or numAvailable > 0 then
        return true;
    end
    
    return false;
end

-- Function to check whether an NPC is a trainer or other special type
-- that uses QUEST_GREETING instead of GOSSIP_SHOW for quests
local function IsSpecialQuestNPC()
    -- Get gossip options
    local gossipOptions = {GetGossipOptions()};
    local numOptions = 0;
    
    if GOSSIP_OPTIONS_FIELDS and table.getn(gossipOptions) > 0 then
        numOptions = math.floor(table.getn(gossipOptions) / GOSSIP_OPTIONS_FIELDS);
    end
    
    -- If there is only one option and it is "trainer" or "unlearn",
    -- then this is a trainer with QUEST_GREETING quests
    if numOptions == 1 then
        local optionType = gossipOptions[2]; -- type of the second element in the pair (text, type)
        if optionType == "trainer" or optionType == "unlearn" or optionType == "battlemaster" then
            return true;
        end
    end
    
    -- Check gossip text - if it is empty or the standard trainer text
    local gossipText = GetGossipText();
    if gossipText and (gossipText == "" or string.find(string.lower(gossipText), "i can instruct you")) then
        return true;
    end
    
    return false;
end

function SetFontColor(fontObject, key)
    local color = COLORS[key];
    if color then
        fontObject:SetTextColor(color[1], color[2], color[3]);
    end
end

function HideDefaultFrames()
    if GossipFrame and GossipFrame:IsVisible() then
        GossipFrame:Hide()
        GossipFrame:SetAlpha(0)
        GossipFrame:ClearAllPoints()
        GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000)
    end

    if GossipFrameGreetingPanel then 
        GossipFrameGreetingPanel:Hide()
        GossipFrameGreetingPanel:SetAlpha(0)
    end
    if GossipNpcNameFrame then 
        GossipNpcNameFrame:Hide()
        GossipNpcNameFrame:SetAlpha(0)
    end
    if GossipFrameCloseButton then 
        GossipFrameCloseButton:Hide()
        GossipFrameCloseButton:SetAlpha(0)
    end
    if GossipFramePortrait then 
        GossipFramePortrait:Hide()
        GossipFramePortrait:SetTexture()
        GossipFramePortrait:SetAlpha(0)
    end
end

function DGossipFrame_OnLoad()
    HideDefaultFrames()
	
	CreateGossipButtons()

    this:RegisterEvent("GOSSIP_SHOW");
    this:RegisterEvent("GOSSIP_CLOSED");
    this:RegisterEvent("VARIABLES_LOADED");
    this:RegisterEvent("CONFIRM_TALENT_WIPE");
    this:RegisterEvent("CONFIRM_BINDER");
    this:RegisterEvent("GOSSIP_CONFIRM");
    
    -- Register QUEST_GREETING to handle conflicts
    this:RegisterEvent("QUEST_GREETING");

    this:SetMovable(true);
    this:EnableMouse(true);

    if not DGossipKeyFrame then
        CreateFrame("Frame", "DGossipKeyFrame", UIParent)
        DGossipKeyFrame:SetScript("OnKeyDown", DGossipFrame_OnKeyDown)
        DGossipKeyFrame:EnableKeyboard(false)
        DGossipKeyFrame:SetToplevel(true)
        DGossipKeyFrame:SetAllPoints(UIParent)
        DGossipKeyFrame:SetFrameStrata("TOOLTIP")
    end

    if GossipFrame then
        GossipFrame:UnregisterEvent("GOSSIP_SHOW")
        GossipFrame:UnregisterEvent("GOSSIP_CLOSED")
    end
end

function DGossipFrame_OnEvent()
    if not DGossipFrame then
        return;
    end

    if (event == "VARIABLES_LOADED") then
        if DialogUI_LoadPosition then
            DialogUI_LoadPosition(DGossipFrame);
        end
        if DialogUI_LoadConfig then
            DialogUI_LoadConfig();
        end
        if GossipFrame then
            GossipFrame:UnregisterEvent("GOSSIP_SHOW")
            GossipFrame:UnregisterEvent("GOSSIP_CLOSED")
        end
        return;
    end

    if (event == "CONFIRM_TALENT_WIPE") then
        talentWipePending = true
        return;
    end

    if (event == "CONFIRM_BINDER") then
        binderPending = true
        return;
    end

    if (event == "GOSSIP_CONFIRM") then
        return;
    end

    if (event == "QUEST_GREETING") then
        DebugMsg("DEBUG: QUEST_GREETING received in DGossipFrame");
        
        if DGossipFrame:IsVisible() then
            HideUIPanel(DGossipFrame);
        end
        
        if DQuestFrame then
            ShowUIPanel(DQuestFrame);
            if DQuestFrameGreetingPanel then
                DQuestFrameGreetingPanel:Show();
            end
            if DQuestFrame_SetPortrait then
                DQuestFrame_SetPortrait();
            end
        end
        
        return;
    end

    if (event == "GOSSIP_CLOSED") then
        gossipOpenTime = 0
        
        if gossipCloseTimer then
            gossipCloseTimer:Hide()
            gossipCloseTimer:SetScript("OnUpdate", nil)
            gossipCloseTimer = nil
        end
        
        questGreetingPending = false
        if questGreetingTimer then
            questGreetingTimer:Hide()
            questGreetingTimer:SetScript("OnUpdate", nil)
            questGreetingTimer = nil
        end
        
        if DGossipFrame:IsVisible() then
            HideUIPanel(DGossipFrame)
        end
        
        if DGossipKeyFrame then
            DGossipKeyFrame:EnableKeyboard(false)
        end
        
        talentWipePending = false
        binderPending = false
        
        return;
    end

    if (event == "GOSSIP_SHOW") then
        -- Get data in several ways for reliability
        local availableQuests = {GetGossipAvailableQuests()};
        local activeQuests = {GetGossipActiveQuests()};
        local gossipOptions = {GetGossipOptions()};
        
        local numAvailable = GetNumGossipAvailableQuests();
        local numActive = GetNumGossipActiveQuests();
        
        -- Calculate count from data if API returned 0
        local availCount = table.getn(availableQuests);
        local activeCount = table.getn(activeQuests);
        
        if numAvailable == 0 and availCount > 0 then
            if availCount % 5 == 0 then
                numAvailable = availCount / 5;
            elseif availCount % 4 == 0 then
                numAvailable = availCount / 4;
            elseif availCount % 3 == 0 then
                numAvailable = availCount / 3;
            elseif availCount % 2 == 0 then
                numAvailable = availCount / 2;
            else
                numAvailable = 1;
            end
        end
        
        if numActive == 0 and activeCount > 0 then
            if activeCount % 4 == 0 then
                numActive = activeCount / 4;
            elseif activeCount % 3 == 0 then
                numActive = activeCount / 3;
            elseif activeCount % 2 == 0 then
                numActive = activeCount / 2;
            else
                numActive = 1;
            end
        end
        
        -- Correctly calculate the number of options
        local numOptions = 0;
        local optionsCount = table.getn(gossipOptions);
        -- Each option consists of 2 elements: text and type
        if optionsCount > 0 then
            numOptions = math.floor(optionsCount / 2);
        end
        
        -- If GetGossipOptions returned empty, try other methods
        -- Sometimes in 3.3.5 options may be available through other APIs
        if numOptions == 0 then
            -- Check if there is gossip text - if so, the window should be shown
            local gossipText = GetGossipText();
            if gossipText and gossipText ~= "" then
                -- Check the standard window - if it has options, use them
                if GossipFrame and GossipFrameGreetingPanel then
                    -- Try to get options from the standard frame
                    local standardOptions = {};
                    for i = 1, 32 do
                        local button = getglobal("GossipTitleButton" .. i);
                        if button and button:IsVisible() and button:GetText() then
                            local text = button:GetText();
                            local iconType = "gossip";
                            -- Determine type by text or icon
                            if button.type then
                                iconType = button.type;
                            end
                            table.insert(standardOptions, text);
                            table.insert(standardOptions, iconType);
                            numOptions = numOptions + 1;
                        end
                    end
                    
                    if numOptions > 0 then
                        gossipOptions = standardOptions;
                        DebugMsg(string.format("DEBUG: Got %d options from standard frame", numOptions));
                    end
                end
            end
        end

        DebugMsg(string.format("DEBUG: GOSSIP_SHOW - numActive=%d, numAvailable=%d, numOptions=%d (raw=%d)", 
            numActive, numAvailable, numOptions, optionsCount));

        -- Show the window if there is anything (quests OR options OR just text)
        local gossipText = GetGossipText();
        local hasContent = (numActive > 0) or (numAvailable > 0) or (numOptions > 0) or 
                          (gossipText and gossipText ~= "");
        
        if hasContent then
            -- Save data
            savedGossipQuests.available = availableQuests
            savedGossipQuests.active = activeQuests
            savedGossipQuests.text = gossipText
            savedGossipQuests.numAvailable = numAvailable
            savedGossipQuests.numActive = numActive
            
            DebugMsg("DEBUG: Showing DGossipFrame");
            DGossipFrame_ShowGossipWindow(availableQuests, activeQuests, gossipOptions);
        else
            DebugMsg("DEBUG: Nothing to show");
        end
        
        return;
    end
end

function DGossipFrame_ShowGossipWindow(availableQuests, activeQuests, gossipOptions)
    gossipOpenTime = GetTime()
    
    if gossipCloseTimer then
        gossipCloseTimer:Hide()
        gossipCloseTimer:SetScript("OnUpdate", nil)
        gossipCloseTimer = nil
    end
    
    HideDefaultFrames()

    -- Show DGossipFrame and all its child elements
    if not DGossipFrame:IsVisible() then
        ShowUIPanel(DGossipFrame)
    end
    
    -- Force-show all required frames
    if DGossipFrameGreetingPanel then
        DGossipFrameGreetingPanel:Show()
    end
    
    if DGossipGreetingScrollFrame then
        DGossipGreetingScrollFrame:Show()
    end
    
    if DGossipGreetingScrollChildFrame then
        DGossipGreetingScrollChildFrame:Show()
    end

    -- Update content
    DGossipFrameUpdate(availableQuests, activeQuests, gossipOptions)

    if DialogUI_ApplyAlpha then
        DialogUI_ApplyAlpha()
    end
	
    talentWipePending = false
    binderPending = false
end

function DGossipFrameUpdate(availableQuests, activeQuests, gossipOptions)
    DebugMsg("DEBUG: DGossipFrameUpdate STARTED")
    availableQuests = availableQuests or {}
    activeQuests = activeQuests or {}
    gossipOptions = gossipOptions or {}
    
    local availCount = table.getn(availableQuests)
    local activeCount = table.getn(activeQuests)
    local optionsCount = table.getn(gossipOptions)
    
    DebugMsg(string.format("DEBUG: DGossipFrameUpdate - avail=%d, active=%d, options=%d", 
        availCount, activeCount, optionsCount))
    
    -- Clear buttons
    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i)
        if button then
            button:Hide()
            button:SetText("")
            button.type = nil
            button.isGossip = nil
            
            -- Find the icon and explicitly show it
            local icon = _G[button:GetName() .. "QuestIcon"]
            if icon then
                icon:SetTexture(nil)
                icon:Hide()  -- Hide before setting texture
                icon:Show()  -- Show after clearing
            end
        end
    end
    
    DGossipFrame.buttonIndex = 1
    
    -- Update data
    local greetingText = getglobal("DGossipGreetingText")
    if greetingText then
        greetingText:SetText(GetGossipText() or "")
    end
    
    local nameText = getglobal("DGossipFrameNpcNameText")
    if nameText and UnitExists("npc") then
        nameText:SetText(UnitName("npc"))
    end
    
    if DGossipFramePortrait and UnitExists("npc") then
        SetPortraitTexture(DGossipFramePortrait, "npc")
    end
    
    -- Show both quests and options!
    -- First active quests
    if activeCount > 0 then
        DGossipFrameActiveQuestsUpdate(activeQuests);
    end
    
    -- Then available quests
    if availCount > 0 then
        DGossipFrameAvailableQuestsUpdate(availableQuests);
    end
    
    -- Then options
    if optionsCount > 0 then
        DGossipFrameOptionsUpdate(gossipOptions);
    end
    
    if DGossipFrameGreetingPanel then
        DGossipFrameGreetingPanel:Show()
    end
    
    -- Update scroll
    local scrollFrame = getglobal("DGossipGreetingScrollFrame")
    if scrollFrame then
        scrollFrame:UpdateScrollChildRect()
        scrollFrame:SetVerticalScroll(0)
    end
    
    DebugMsg(string.format("DEBUG: DGossipFrameUpdate finished, final buttonIndex=%d", DGossipFrame.buttonIndex))
	DebugGossipIcons()
end

function DGossipFrame_OnKeyDown()
    local key = arg1

    local movementKeys = {
        W = true, A = true, S = true, D = true,
        UP = true, DOWN = true, LEFT = true, RIGHT = true,
        SPACE = true, NUMPAD1 = true, NUMPAD2 = true, NUMPAD3 = true,
        NUMPAD4 = true, NUMPAD6 = true, NUMPAD7 = true, NUMPAD8 = true, NUMPAD9 = true
    }
    
    if movementKeys[key] then
        DGossipKeyFrame:EnableKeyboard(false)
        local reEnableTime = GetTime() + 0.05
        DGossipKeyFrame:SetScript("OnUpdate", function()
            if GetTime() >= reEnableTime then
                if DGossipFrame:IsVisible() then
                    DGossipKeyFrame:EnableKeyboard(false)
                end
                DGossipKeyFrame:SetScript("OnUpdate", nil)
            end
        end)
        return
    end

    if key == "ESCAPE" then
        CloseGossip()
        DialogUI_SavePosition()  -- Save position!
        return
    end

    -- SPACE selects the first available option (quest or gossip)
    if key == "SPACE" then
        DGossipSelectFirstAvailable()
        return
    end

    if key >= "1" and key <= "9" then
        local buttonIndex = tonumber(key)
        DGossipSelectOption(buttonIndex)
        return
    end

    DGossipKeyFrame:EnableKeyboard(false)

    local reEnableTime = GetTime() + 0.05
    DGossipKeyFrame:SetScript("OnUpdate", function()
        if GetTime() >= reEnableTime then
            if DGossipFrame:IsVisible() then
                DGossipKeyFrame:EnableKeyboard(false)
            end
            DGossipKeyFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function DGossipSelectFirstAvailable()
    if not DGossipFrame:IsVisible() then
        return
    end

    -- Find the first visible button
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton and titleButton:IsVisible() and titleButton:GetText() and titleButton:GetText() ~= "" then
            DGossipTitleButton_OnClick_Direct(titleButton)
            return
        end
    end
end

function DGossipSelectOption(buttonIndex)
    if not DGossipFrame:IsVisible() then
        return
    end

    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton and titleButton:IsVisible() and titleButton:GetText() and titleButton:GetText() ~= "" then
            local buttonText = titleButton:GetText()
            local _, _, numStr = string.find(buttonText, "^(%d+)%.")
            if numStr then
                local displayNum = tonumber(numStr)
                if displayNum == buttonIndex then
                    DGossipTitleButton_OnClick_Direct(titleButton)
                    return
                end
            end
        end
    end
end

function DGossipFrame_OnMouseDown()
    if (arg1 == "LeftButton") then
        this:StartMoving();
    end
end

function DGossipFrame_OnMouseUp()
    this:StopMovingOrSizing();
    DialogUI_SavePosition();
    if DQuestFrame then
        DialogUI_LoadPosition(DQuestFrame);
    end
end

function DGossipTitleButton_OnClick_Direct(button)
    if not button then return end

    local buttonType = button.type
    local buttonID = button:GetID()
    local isGossip = button.isGossip

    DebugMsg(string.format("DEBUG: DGossipTitleButton_OnClick_Direct - type=%s, ID=%d, isGossip=%s, specialType=%s", 
        tostring(buttonType), buttonID, tostring(isGossip), tostring(button.specialType)));

    -- Handle the "Goodbye" button
    if button.specialType == "goodbye" then
        CloseGossip();
        return;
    end

    -- For gossip quests (isGossip=true) use SelectGossip*
    if isGossip then
        if buttonType == "available" then
            DebugMsg(string.format("DEBUG: Selecting Gossip Available Quest %d", buttonID));
            SelectGossipAvailableQuest(buttonID);
            return
        elseif buttonType == "active" then
            DebugMsg(string.format("DEBUG: Selecting Gossip Active Quest %d", buttonID));
            SelectGossipActiveQuest(buttonID);
            return
        end
    end
	
	-- Check for book opening
    if button.specialType == "book" or (button.text and string.find(string.lower(button.text), "read")) then
        -- Book opening logic can be added here
        if DUIBookFrame then
            DUIBookFrame:ShowUI();
        end
        return;
    end

    -- For regular gossip options (not quests)
    if buttonType == "gossip" then
        DebugMsg(string.format("DEBUG: Selecting Gossip Option %d", buttonID));
        SelectGossipOption(buttonID);
        return
    end

    DebugMsg("DEBUG: ERROR - Unknown button type: " .. tostring(buttonType));
end

function DGossipTitleButton_OnClick()
    DGossipTitleButton_OnClick_Direct(this)
end

function GetValidIconPath(basePath)
    -- Try different path and extension variants
    local variations = {}
    
    -- First try with double backslashes (Windows-style) - this works in 3.3.5
    local winPath = string.gsub(basePath, "/", "\\")
    table.insert(variations, winPath .. ".blp")
    table.insert(variations, winPath .. ".tga")
    table.insert(variations, winPath)
    
    -- Also try with forward slashes
    table.insert(variations, basePath .. ".blp")
    table.insert(variations, basePath .. ".tga")
    table.insert(variations, basePath)
    
    for _, path in ipairs(variations) do
        local tex = DGossipFrame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(path)
        if tex:GetTexture() then
            tex:SetTexture(nil) -- clear
            return path
        end
        tex:SetTexture(nil)
    end
    
    return nil
end

function SetGossipButtonIcon(button, iconType, text)
    if not button then return false end
    
    local iconName = button:GetName() .. "QuestIcon"
    local gossipIcon = _G[iconName]
    
    if not gossipIcon then
        -- Search via GetRegions
        local regions = {button:GetRegions()}
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "Texture" then
                gossipIcon = region
                break
            end
        end
    end
    
    if not gossipIcon then
        DebugMsg("ERROR: No icon texture found for " .. button:GetName())
        return false
    end
    
    -- Positioning
    gossipIcon:ClearAllPoints()
    gossipIcon:SetWidth(24)
    gossipIcon:SetHeight(24)
    gossipIcon:SetPoint("LEFT", button, "LEFT", 5, 0)
    
    -- Determine the base path with DOUBLE BACKSLASHES
    local basePath = "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\"
    local iconFile = "gossipIcon" -- default
    
    -- Extended type mapping
    local iconMap = {
        -- Basic
        ["goodbye"] = "gossipIcon",
        ["bye"] = "gossipIcon",
        ["gossip"] = "gossipIcon",
        
        -- Special NPCs
        ["vendor"] = "vendorGossipIcon",
        ["trainer"] = "trainerGossipIcon",
        ["binder"] = "binderGossipIcon",
		["barber"] = "barber",
        ["taxi"] = "flightGossipIcon",
        ["flight"] = "flightGossipIcon",
        ["banker"] = "bankerGossipIcon",
        ["battlemaster"] = "battlemasterGossipIcon",
        ["unlearn"] = "unlearnGossipIcon",
        ["tabard"] = "guildMasterGossipIcon",
        ["auctionHouse"] = "auctionHouseGossipIcon",
        ["stablemaster"] = "stablemasterGossipIcon",
        ["innkeeper"] = "innkeeperGossipIcon",
        ["guildMaster"] = "guildMasterGossipIcon",
        ["mailbox"] = "mailboxGossipIcon",
        ["pettrainer"] = "pettrainerGossipIcon",
        ["weaponsTrainer"] = "weaponsTrainerGossipIcon",
        ["professionTrainer"] = "professionTrainerGossipIcon",
        ["classTrainer"] = "classTrainerGossipIcon",
        ["deeprunTram"] = "deeprunTramGossipIcon",
        
        -- Classes
        ["warrior"] = "warriorGossipIcon",
        ["paladin"] = "paladinGossipIcon",
        ["hunter"] = "hunterGossipIcon",
        ["rogue"] = "rogueGossipIcon",
        ["priest"] = "priestGossipIcon",
        ["shaman"] = "shamanGossipIcon",
        ["mage"] = "mageGossipIcon",
        ["warlock"] = "warlockGossipIcon",
        ["druid"] = "druidGossipIcon",
        ["deathKnight"] = "deathKnightGossipIcon",
        
        -- Professions
        ["alchemy"] = "alchemyGossipIcon",
        ["blacksmithing"] = "blacksmithingGossipIcon",
        ["enchanting"] = "enchantingGossipIcon",
        ["engineering"] = "engineeringGossipIcon",
        ["herbalism"] = "herbalismGossipIcon",
        ["leatherworking"] = "leatherworkingGossipIcon",
        ["mining"] = "miningGossipIcon",
        ["skinning"] = "skinningGossipIcon",
        ["tailoring"] = "tailoringGossipIcon",
        ["jewelcrafting"] = "jewelcraftingGossipIcon",
        ["inscription"] = "inscriptionGossipIcon",
        ["cooking"] = "cookingGossipIcon",
        ["fishing"] = "fishingGossipIcon",
        ["firstAid"] = "first aidGossipIcon",
    }
    
    if iconMap[iconType] then
        iconFile = iconMap[iconType]
    else
        DebugMsg(string.format("WARNING: Unknown icon type '%s', using default", tostring(iconType)))
    end
    
    -- Find a valid path
    local fullPath = basePath .. iconFile
    local validPath = GetValidIconPath(fullPath)
    
    if not validPath then
        DebugMsg(string.format("WARNING: Could not find icon file: %s (type: %s)", iconFile, tostring(iconType)))
        -- Try the standard icon
        validPath = GetValidIconPath(basePath .. "gossipIcon")
    end
    
    if validPath then
        gossipIcon:SetTexture(validPath)
        gossipIcon:SetVertexColor(1.0, 1.0, 1.0)
        gossipIcon:SetAlpha(1.0)
        gossipIcon:SetDrawLayer("OVERLAY")
        gossipIcon:Show()
        
        DebugMsg(string.format("Icon set: %s -> %s", iconType, validPath))
        return true
    else
        DebugMsg("CRITICAL: No valid icon path found!")
        return false
    end
end

function DGossipFrameOptionsUpdate(optionsTable)
    if not optionsTable or table.getn(optionsTable) == 0 then
        DebugMsg("DEBUG: OptionsUpdate - empty table")
        return
    end
    
    local titleIndex = 1
    local optionsCount = table.getn(optionsTable)
    local numOptions = math.floor(optionsCount / 2)

    DebugMsg(string.format("DEBUG: OptionsUpdate - numOptions=%d, raw=%d", numOptions, optionsCount))

    if numOptions == 0 then return end

    for i = 1, numOptions do
        local baseIndex = (i - 1) * 2 + 1
        local text = optionsTable[baseIndex]
        local iconType = optionsTable[baseIndex + 1]

        if not text then
            DebugMsg(string.format("DEBUG: No text for option %d", i))
            break
        end

        if (DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS) then
            if not DGossipFrame.optionsLimitReached then
                DGossipFrame.optionsLimitReached = true
                DebugMsg("|cffff0000[DialogUI]|r This NPC has too many dialog options. Only the first " .. NUMGOSSIPBUTTONS .. " options are shown.", 1, 0.5, 0)
            end
            break
        end

        local titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex)
        
        if not titleButton then
            DebugMsg("|cffff0000[DialogUI]|r Error: failed to create dialog button #" .. DGossipFrame.buttonIndex, 1, 0, 0)
            break
        end

        local numberedText = DGossipFrame.buttonIndex .. ". " .. text
        
        -- Use the new function for gossip buttons
        DGossipTitleButton_SetGossipText(titleButton, numberedText)

        totalGossipButtons = totalGossipButtons + 1

        titleButton:SetID(titleIndex)
        titleButton.type = "gossip"
        titleButton.specialType = iconType
        titleButton.isGossip = false

        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- Determine icon by text
        local detectedIconType = DetermineGossipIconTypeByText(text)
        DebugMsg(string.format("Text: '%s' -> Detected type: '%s', API type: '%s'", text, detectedIconType, tostring(iconType)))
        
        SetGossipButtonIcon(titleButton, detectedIconType, text)

        -- Set background texture
        titleButton:SetNormalTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-common")
        local normalTexture = titleButton:GetNormalTexture()
        if normalTexture then
            normalTexture:SetDrawLayer("BACKGROUND")
        end
        
        titleButton:SetNormalFontObject("DQuestButtonTitleGossip")
        
        -- Configure button text
        local buttonText = titleButton:GetFontString()
        if buttonText then
            buttonText:ClearAllPoints()
            buttonText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
            buttonText:SetDrawLayer("ARTWORK")
        end

        titleButton:Show()
        
        -- Dynamic positioning
        if DGossipFrame.buttonIndex > 1 then
            local prevButton = getglobal("DGossipTitleButton" .. (DGossipFrame.buttonIndex - 1))
            if prevButton then
                titleButton:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT", 0, -5)
            end
        end
        
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1
        titleIndex = titleIndex + 1
    end
    
    DebugMsg(string.format("DEBUG: OptionsUpdate finished - buttonIndex now %d", DGossipFrame.buttonIndex))
end

-- Function to set gossip button text with word wrap
function DGossipTitleButton_SetGossipText(button, text)
    if not button then return end
    
    local fontString = button:GetFontString()
    if not fontString then return end
    
    -- Set text with wrapping
    fontString:SetText(text)
    fontString:SetWordWrap(true)
    fontString:SetWidth(360) -- Maximum text width
    fontString:SetHeight(0) -- Auto height
    
    -- Get actual dimensions
    local textWidth = fontString:GetStringWidth()
    local textHeight = fontString:GetStringHeight()
    
    -- Minimum height 24px, expand as needed
    local newHeight = math.max(24, textHeight + 8)
    
    button:SetHeight(newHeight)
    
    -- Update background if present
    local bg = getglobal(button:GetName() .. "ProgressBackground")
    if bg then
        bg:SetWidth(math.min(textWidth + 45, 400))
        bg:SetHeight(newHeight)
    end
end

-- Function to determine icon type by option text (Russian localization)
function DetermineGossipIconTypeByText(optionText)
    if not optionText then return "gossip" end
    
    local text = string.lower(optionText)
    
    -- Class trainers
    local classTrainers = {
        -- Russian
        ["воин"] = "warrior",
        ["паладин"] = "paladin",
        ["охотник"] = "hunter",
        ["разбойник"] = "rogue",
        ["жрец"] = "priest",
        ["шаман"] = "shaman",
        ["маг"] = "mage",
        ["чернокнижник"] = "warlock",
        ["друид"] = "druid",
        ["рыцарь смерти"] = "deathKnight",
        -- English
        ["warrior"] = "warrior",
        ["paladin"] = "paladin",
        ["hunter"] = "hunter",
        ["rogue"] = "rogue",
        ["priest"] = "priest",
        ["shaman"] = "shaman",
        ["mage"] = "mage",
        ["warlock"] = "warlock",
        ["druid"] = "druid",
        ["death knight"] = "deathKnight",
    }
    
    for keyword, iconType in pairs(classTrainers) do
        if string.find(text, keyword) then
            return iconType
        end
    end
    
    -- Profession trainers
    local professionTrainers = {
        -- Russian
        ["алхимия"] = "alchemy",
        ["кузнечное дело"] = "blacksmithing",
        ["наложение чар"] = "enchanting",
        ["инженерное дело"] = "engineering",
        ["травничество"] = "herbalism",
        ["кожевничество"] = "leatherworking",
        ["горное дело"] = "mining",
        ["снятие шкур"] = "skinning",
        ["портняжное дело"] = "tailoring",
        ["ювелирное дело"] = "jewelcrafting",
        ["начертание"] = "inscription",
        ["кулинария"] = "cooking",
        ["рыбная ловля"] = "fishing",
        ["первая помощь"] = "firstAid",
        -- English
        ["alchemy"] = "alchemy",
        ["blacksmithing"] = "blacksmithing",
        ["enchanting"] = "enchanting",
        ["engineering"] = "engineering",
        ["herbalism"] = "herbalism",
        ["leatherworking"] = "leatherworking",
        ["mining"] = "mining",
        ["skinning"] = "skinning",
        ["tailoring"] = "tailoring",
        ["jewelcrafting"] = "jewelcrafting",
        ["inscription"] = "inscription",
        ["cooking"] = "cooking",
        ["fishing"] = "fishing",
        ["first aid"] = "firstAid",
    }
    
    for keyword, iconType in pairs(professionTrainers) do
        if string.find(text, keyword) then
            return iconType
        end
    end
    
    -- Special NPCs
    if string.find(text, "банк") or string.find(text, "bank") then
        return "banker"
    elseif string.find(text, "таверна") or string.find(text, "inn") or string.find(text, "трактирщик") or string.find(text, "innkeeper") then
        return "innkeeper"
    elseif string.find(text, "укротитель грифонов") or string.find(text, "полет") or string.find(text, "flight") or string.find(text, "грифон") or string.find(text, "taxi") then
        return "flight"
    elseif string.find(text, "регистратор гильдий") or string.find(text, "гильдия") or string.find(text, "guild") or string.find(text, "tabard") then
        return "guildMaster"
    elseif string.find(text, "замочник") or string.find(text, "locksmith") then
        return "gossip" -- no special icon
    elseif string.find(text, "смотритель стойл") or string.find(text, "стойла") or string.find(text, "stable") then
        return "stablemaster"
    elseif string.find(text, "учитель оружейных навыков") or string.find(text, "оружейные навыки") or string.find(text, "weapon") then
        return "weaponsTrainer"
    elseif string.find(text, "военачальник") or string.find(text, "battlemaster") or string.find(text, "бой") then
        return "battlemaster"
    elseif string.find(text, "парикмахер") or string.find(text, "barber") then
        return "barber" -- no special icon
    elseif string.find(text, "словарь силы") or string.find(text, "lexicon") then
        return "gossip" -- no special icon
    elseif string.find(text, "дом офицеров") or string.find(text, "officer") then
        return "gossip" -- no special icon
    elseif string.find(text, "аукцион") or string.find(text, "auction") then
        return "auctionHouse"
    elseif string.find(text, "торговец") or string.find(text, "vendor") or string.find(text, "продавец") then
        return "vendor"
    elseif string.find(text, "тренер") or string.find(text, "trainer") then
        return "trainer"
    end
    
    return "gossip"
end

function DGossipFrameAvailableQuestsUpdate(questsTable)
    if not questsTable or table.getn(questsTable) == 0 then
        DebugMsg("DEBUG: AvailableQuestsUpdate - empty table")
        return;
    end

    local dataSize = table.getn(questsTable)
    
    local fieldsPerQuest = 5
    if dataSize % 5 == 0 then
        fieldsPerQuest = 5
    elseif dataSize % 4 == 0 then
        fieldsPerQuest = 4
    elseif dataSize % 3 == 0 then
        fieldsPerQuest = 3
    elseif dataSize % 2 == 0 then
        fieldsPerQuest = 2
    else
        fieldsPerQuest = 1
    end
    
    local numQuests = math.floor(dataSize / fieldsPerQuest)

    DebugMsg(string.format("DEBUG: AvailableQuestsUpdate - dataSize=%d, fieldsPerQuest=%d, numQuests=%d", 
        dataSize, fieldsPerQuest, numQuests))

    if numQuests == 0 then return end

    local titleIndex = 1

    for i = 1, numQuests do
        if DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS then break end
        
        local titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        if not titleButton then break end
        
        local baseIndex = (i - 1) * fieldsPerQuest + 1
        local questTitle = questsTable[baseIndex]
        local questLevel = questsTable[baseIndex + 1]
        local isTrivial = questsTable[baseIndex + 2]
        local isDaily = questsTable[baseIndex + 3]
        local isRepeatable = questsTable[baseIndex + 4]

        DebugMsg(string.format("DEBUG: Quest %d - title=%s, level=%s", 
            i, tostring(questTitle), tostring(questLevel)))

        if not questTitle or questTitle == "" then break end

        local displayText = DGossipFrame.buttonIndex .. ". " .. questTitle
        
        -- Use the wrap function
        DGossipTitleButton_SetGossipText(titleButton, displayText)
        
        titleButton:SetID(titleIndex);
        titleButton.type = "available"
        titleButton.questIndex = titleIndex
        titleButton.isGossip = true
        titleButton.isTrivial = isTrivial
        titleButton.isDaily = isDaily
        titleButton.isRepeatable = isRepeatable

        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- Icon
        local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
        if not gossipIcon then
            local regions = {titleButton:GetRegions()}
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    gossipIcon = region
                    break
                end
            end
        end
        
        if gossipIcon then
            gossipIcon:SetWidth(24)
            gossipIcon:SetHeight(24)
            gossipIcon:SetPoint("LEFT", titleButton, "LEFT", 5, 0)
            gossipIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\availableQuestIcon")
            gossipIcon:Show()
        end

        -- Button setup
        titleButton:SetNormalTexture("Interface/AddOns/DialogUI/src/assets/art/parchment/OptionBackground-common")
        
        local btnText = titleButton:GetFontString()
        if btnText then
            btnText:ClearAllPoints()
            btnText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
        end

        titleButton:Show()
        
        -- Dynamic positioning
        if DGossipFrame.buttonIndex > 1 then
            local prevButton = getglobal("DGossipTitleButton" .. (DGossipFrame.buttonIndex - 1))
            if prevButton then
                titleButton:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT", 0, -5)
            end
        end
        
        DebugMsg(string.format("DEBUG: Button %d ready - isGossip=%s, ID=%d", 
            DGossipFrame.buttonIndex, tostring(titleButton.isGossip), titleIndex))
        
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1
    end
end

function DGossipFrameActiveQuestsUpdate(questsTable)
    if not questsTable or table.getn(questsTable) == 0 then return end

    local dataSize = table.getn(questsTable)

    DebugMsg(string.format("DEBUG: ActiveQuests - dataSize=%d", dataSize))

    local quests = {}
    local i = 1

    -- Sequential parsing with correct isComplete detection
    while i <= dataSize do
        local field = questsTable[i]

        -- Look for a string (quest title)
        if type(field) == "string" then
            local questTitle = field
            local questLevel = nil
            local isComplete = false
            local isLowLevel = nil

            local nextIndex = i + 1

            -- Skip nil fields
            while nextIndex <= dataSize and questsTable[nextIndex] == nil do
                nextIndex = nextIndex + 1
            end

            -- Look for level (number > 1)
            if nextIndex <= dataSize and type(questsTable[nextIndex]) == "number" then
                local val = questsTable[nextIndex]
                if val > 1 or val < 0 then
                    questLevel = val
                    nextIndex = nextIndex + 1
                end
            end

            -- Skip nil again
            while nextIndex <= dataSize and questsTable[nextIndex] == nil do
                nextIndex = nextIndex + 1
            end

            -- Look for isLowLevel and isComplete flags (0 or 1)
            local flagsFound = 0
            while nextIndex <= dataSize and flagsFound < 2 do
                local val = questsTable[nextIndex]
                if type(val) == "number" and (val == 0 or val == 1) then
                    if flagsFound == 0 then
                        -- First flag
                        if nextIndex + 1 <= dataSize then
                            local nextVal = questsTable[nextIndex + 1]
                            if type(nextVal) == "number" and (nextVal == 0 or nextVal == 1) then
                                -- Two flags: isLowLevel, isComplete
                                isLowLevel = (val == 1)
                                isComplete = (nextVal == 1)
                                nextIndex = nextIndex + 2
                                flagsFound = 2
                            else
                                -- One flag: isComplete
                                isComplete = (val == 1)
                                nextIndex = nextIndex + 1
                                flagsFound = 1
                            end
                        else
                            -- Last flag: isComplete
                            isComplete = (val == 1)
                            nextIndex = nextIndex + 1
                            flagsFound = 1
                        end
                    end
                else
                    break
                end
                -- Exit after processing flags
                break
            end

            table.insert(quests, {
                title = questTitle,
                level = questLevel,
                isComplete = isComplete,
                isLowLevel = isLowLevel
            })

            DebugMsg(string.format("DEBUG: Parsed quest - title='%s', level=%s, isComplete=%s", 
                tostring(questTitle), tostring(questLevel), tostring(isComplete)))

            i = nextIndex
        else
            DebugMsg(string.format("DEBUG: Skipping field %d = %s", i, tostring(field)))
            i = i + 1
        end
    end

    local numQuests = #quests
    DebugMsg(string.format("DEBUG: ActiveQuests - parsed %d valid quests", numQuests))

    if numQuests == 0 then return end

    local titleIndex = 1

    for i = 1, numQuests do
        if DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS then break end

        local titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        if not titleButton then break end

        local quest = quests[i]
        local questTitle = quest.title
        local isComplete = quest.isComplete

        local displayText = DGossipFrame.buttonIndex .. ". " .. questTitle

        DGossipTitleButton_SetGossipText(titleButton, displayText)

        titleButton:SetID(titleIndex);
        titleButton.type = "active"
        titleButton.questIndex = titleIndex
        titleButton.isGossip = true
        titleButton.isComplete = isComplete

        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- Icon
        local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
        if not gossipIcon then
            local regions = {titleButton:GetRegions()}
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    gossipIcon = region
                    break
                end
            end
        end

        if gossipIcon then
            gossipIcon:ClearAllPoints()
            gossipIcon:SetWidth(24)
            gossipIcon:SetHeight(24)
            gossipIcon:SetPoint("LEFT", titleButton, "LEFT", 5, 0)

            -- Use correct paths with double backslashes
            local iconPath
            if isComplete then
                iconPath = "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\activeQuestIcon"
            else
                iconPath = "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\incompleteQuestIcon"
            end

            gossipIcon:SetTexture(iconPath)

            -- Check whether the texture loaded
            if not gossipIcon:GetTexture() then
                DebugMsg(string.format("DEBUG: WARNING - Icon not loaded, trying forward slashes"))
                -- Try with forward slashes
                iconPath = string.gsub(iconPath, "\\\\", "/")
                gossipIcon:SetTexture(iconPath)
                DebugMsg(string.format("DEBUG: Forward slash path result: %s", tostring(gossipIcon:GetTexture() ~= nil)))
            end

            gossipIcon:Show()
            DebugMsg(string.format("DEBUG: Set icon for '%s' - isComplete=%s, texture=%s", 
                questTitle, tostring(isComplete), tostring(gossipIcon:GetTexture())))
        else
            DebugMsg(string.format("DEBUG: ERROR - No gossipIcon found for button %d", DGossipFrame.buttonIndex))
        end

        -- Button setup
        titleButton:SetNormalTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-common")

        local btnText = titleButton:GetFontString()
        if btnText then
            btnText:ClearAllPoints()
            btnText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
        end

        titleButton:Show()

        -- Dynamic positioning
        if DGossipFrame.buttonIndex > 1 then
            local prevButton = getglobal("DGossipTitleButton" .. (DGossipFrame.buttonIndex - 1))
            if prevButton then
                titleButton:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT", 0, -5)
            end
        end

        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1
    end
end

-- Function to determine icon type like Storyline
function DetermineGossipIconType(gossipText)
    local text = string.lower(gossipText)
    
    -- Professions
    local professions = {
        "alchemy", "blacksmithing", "enchanting", "engineering", 
        "herbalism", "leatherworking", "mining", "skinning", 
        "tailoring", "jewelcrafting", "inscription", "cooking", "fishing", "first aid"
    }
    
    for _, profession in pairs(professions) do
        if string.find(text, profession) then
            return profession
        end
    end
    
    -- Classes
    local classes = {
        "warrior", "paladin", "hunter", "rogue", "priest", 
        "shaman", "mage", "warlock", "druid", "death knight"
    }
    
    for _, class in pairs(classes) do
        if string.find(text, class) then
            return class
        end
    end
    
    -- Special cases
    if string.find(text, "profession") and string.find(text, "trainer") then
        return "professionTrainer"
    elseif string.find(text, "class") and string.find(text, "trainer") then
        return "classTrainer"
    elseif string.find(text, "stable") then
        return "stablemaster"
    elseif string.find(text, "inn") then
        return "innkeeper"
    elseif string.find(text, "mailbox") then
        return "mailbox"
    elseif string.find(text, "guild master") then
        return "guildMaster"
    elseif string.find(text, "trainer") and string.find(text, "pet") then
        return "pettrainer"
    elseif string.find(text, "auction") then
        return "auctionHouse"
    elseif string.find(text, "weapon") and string.find(text, "trainer") then
        return "weaponsTrainer"
    elseif string.find(text, "deeprun") then
        return "deeprunTram"
    elseif string.find(text, "bat handler") or 
           string.find(text, "wind rider master") or 
           string.find(text, "gryphon master") or 
           string.find(text, "hippogryph master") or 
           string.find(text, "flight master") then
        return "flight"
    elseif string.find(text, "bank") then
        return "banker"
    else
        return "gossip"
    end
end

function DialogUI_GetGossipIconPath(iconType, gossipText)
    -- Mapping for various types
    local iconMap = {
        -- Professions
        ["alchemy"] = "alchemyGossipIcon",
        ["blacksmithing"] = "blacksmithingGossipIcon",
        ["enchanting"] = "enchantingGossipIcon",
        ["engineering"] = "engineeringGossipIcon",
        ["herbalism"] = "herbalismGossipIcon",
        ["leatherworking"] = "leatherworkingGossipIcon",
        ["mining"] = "miningGossipIcon",
        ["skinning"] = "skinningGossipIcon",
        ["tailoring"] = "tailoringGossipIcon",
        ["jewelcrafting"] = "jewelcraftingGossipIcon",
        ["inscription"] = "inscriptionGossipIcon",
        ["cooking"] = "cookingGossipIcon",
        ["fishing"] = "fishingGossipIcon",
        ["firstaid"] = "first aidGossipIcon",
        ["firstAid"] = "first aidGossipIcon",
        
        -- Classes
        ["warrior"] = "warriorGossipIcon",
        ["paladin"] = "paladinGossipIcon",
        ["hunter"] = "hunterGossipIcon",
        ["rogue"] = "rogueGossipIcon",
        ["priest"] = "priestGossipIcon",
        ["shaman"] = "shamanGossipIcon",
        ["mage"] = "mageGossipIcon",
        ["warlock"] = "warlockGossipIcon",
        ["druid"] = "druidGossipIcon",
        ["death knight"] = "deathKnightGossipIcon",
        ["deathKnight"] = "deathKnightGossipIcon",
        
        -- Special
        ["professionTrainer"] = "professionTrainerGossipIcon",
        ["classTrainer"] = "classTrainerGossipIcon",
        ["stablemaster"] = "stablemasterGossipIcon",
        ["innkeeper"] = "innkeeperGossipIcon",
        ["mailbox"] = "mailboxGossipIcon",
		["barber"] = "barber",
        ["guildMaster"] = "guildMasterGossipIcon",
        ["pettrainer"] = "pettrainerGossipIcon",
        ["weaponsTrainer"] = "weaponsTrainerGossipIcon",
        ["deeprunTram"] = "deeprunTramGossipIcon",
        ["flight"] = "flightGossipIcon",
        ["banker"] = "bankerGossipIcon",
        ["auctionHouse"] = "auctionHouseGossipIcon",
        ["battlemaster"] = "battlemasterGossipIcon",
    }
    
    local iconFile = iconMap[iconType] or "gossipIcon"
    local basePath = "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\"
    local fullPath = basePath .. iconFile
    
    -- Use GetValidIconPath for validation
    local validPath = GetValidIconPath(fullPath)
	
	if iconType == "barber" then
		iconFile = "barber"
	end
    
    if validPath then
        return validPath
    else
        -- Fallback to standard icon
        return GetValidIconPath(basePath .. "gossipIcon") or "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\gossipIcon"
    end
end

function ClearAllGossipIcons()
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton then
            -- Try to find the icon by name from XML
            local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
            if gossipIcon then
                gossipIcon:Hide()
                gossipIcon:SetTexture(nil)
            end
            
            -- Also check possible created icons (for options)
            local customIcon = _G[titleButton:GetName() .. "GossipIcon"]
            if customIcon then
                customIcon:Hide()
                customIcon:SetTexture(nil)
            end
        end
    end
end

function DialogUI_SavePosition()
    if not DialogUIFramePosition then
        DialogUIFramePosition = {};
    end

    local frame = this or DGossipFrame or DQuestFrame;
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

function CreateGossipButtons()
    local parent = DGossipGreetingScrollChildFrame
    if not parent then return end
    
    local prevButton = _G["DGossipTitleButton1"]
    
    for i = 2, NUMGOSSIPBUTTONS do
        local buttonName = "DGossipTitleButton" .. i
        local button = _G[buttonName]
        
        if not button then
            -- Create a new button
            button = CreateFrame("Button", buttonName, parent, "DQuestTitleButtonTemplate")
            
            -- Position relative to the previous button
            if prevButton then
                button:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT", 0, -10)
            end
            
            -- Set dimensions and text
            button:SetHeight(24)
            button:SetWidth(400)
            
            -- Don't create an icon; it already exists in the DQuestTitleButtonTemplate
            -- Just find the existing icon and configure it
            local icon = _G[buttonName .. "QuestIcon"]
            if icon then
                icon:SetWidth(24)
                icon:SetHeight(24)
                icon:SetPoint("LEFT", button, "LEFT", 5, 0)
                icon:SetTexture(nil) -- Clear the default texture
                icon:Hide() -- Hide until a specific texture is set
            end
            
            -- Configure button text
            local text = button:GetFontString()
            if text then
                text:ClearAllPoints()
                text:SetPoint("LEFT", button, "LEFT", 35, 0)
            end
            
            prevButton = button
        end
    end
end

function DebugGossipIcons()
    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i)
        if button and button:IsVisible() then
            local icon = _G[button:GetName() .. "QuestIcon"]
            if icon then
                local texture = icon:GetTexture()
                DebugMsg(string.format("Button %d: icon texture = %s", i, tostring(texture)))
                if not texture then
                    DebugMsg("  WARNING: No texture set!")
                end
            else
                DebugMsg(string.format("Button %d: NO ICON FOUND!", i))
            end
        end
    end
end

function DebugIconTextures()
    DebugMsg("=== DEBUG ICON TEXTURES ===")
    
    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i)
        if button then
            -- Check whether the button is visible
            if button:IsVisible() then
                local icon = _G[button:GetName() .. "QuestIcon"]
                
                if icon then
                    local texture = icon:GetTexture()
                    local alpha = icon:GetAlpha()
                    local layer = icon:GetDrawLayer()
                    local shown = icon:IsShown()
                    local parent = icon:GetParent()
                    local level = icon:GetFrameLevel()
                    local r, g, b, a = icon:GetVertexColor()
                    local width = icon:GetWidth()
                    local height = icon:GetHeight()
                    
                    DebugMsg(string.format(
                        "Button %d (%s):", 
                        i, 
                        button:GetText() or "no text"
                    ))
                    DebugMsg(string.format(
                        "  Icon: texture=%s, alpha=%s, layer=%s, shown=%s", 
                        tostring(texture), 
                        tostring(alpha),
                        tostring(layer),
                        tostring(shown)
                    ))
                    DebugMsg(string.format(
                        "  Icon: parent=%s, level=%s, size=%dx%d", 
                        tostring(parent and parent:GetName() or "nil"),
                        tostring(level),
                        width or 0,
                        height or 0
                    ))
                    DebugMsg(string.format(
                        "  Icon: color=%s,%s,%s,%s", 
                        tostring(r or 0),
                        tostring(g or 0),
                        tostring(b or 0),
                        tostring(a or 0)
                    ))
                    
                    -- Check whether the icon is covered by other textures
                    local regions = {button:GetRegions()}
                    DebugMsg(string.format("  Button has %d regions:", #regions))
                    for idx, region in ipairs(regions) do
                        if region:GetObjectType() == "Texture" then
                            local regName = region:GetName() or "unnamed"
                            local regTex = region:GetTexture() or "no texture"
                            local regLayer = region:GetDrawLayer()
                            local regAlpha = region:GetAlpha()
                            local regShown = region:IsShown()
                            DebugMsg(string.format(
                                "    Region %d: %s, tex=%s, layer=%s, alpha=%s, shown=%s",
                                idx, regName, tostring(regTex), tostring(regLayer), 
                                tostring(regAlpha), tostring(regShown)
                            ))
                        end
                    end
                else
                    DebugMsg(string.format(
                        "Button %d: NO ICON FOUND! (button exists but no QuestIcon)", 
                        i
                    ))
                end
            else
                DebugMsg(string.format("Button %d: hidden", i))
            end
        else
            DebugMsg(string.format("Button %d: does not exist", i))
        end
    end
    
    DebugMsg("=== END DEBUG ===")
end

-- Add command to invoke
SlashCmdList["DEBUG_ICONS"] = DebugIconTextures
SLASH_DEBUG_ICONS1 = "/debugicons"

function ShowAllGossipButtons()
    DebugMsg("=== SHOWING ALL GOSSIP BUTTONS ===")
    
    -- Show parent frames
    if DGossipFrame then
        DGossipFrame:Show()
    end
    
    if DGossipFrameGreetingPanel then
        DGossipFrameGreetingPanel:Show()
    end
    
    if DGossipGreetingScrollFrame then
        DGossipGreetingScrollFrame:Show()
    end
    
    if DGossipGreetingScrollChildFrame then
        DGossipGreetingScrollChildFrame:Show()
    end
    
    -- Show all buttons
    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i)
        if button then
            button:Show()
            DebugMsg("Showed button " .. i)
            
            -- Show icon
            local icon = _G[button:GetName() .. "QuestIcon"]
            if icon then
                icon:Show()
            end
        end
    end
end

SlashCmdList["SHOW_BUTTONS"] = ShowAllGossipButtons
SLASH_SHOW_BUTTONS1 = "/showbuttons"

function TestIconPaths()
    DebugMsg("=== TESTING ICON PATHS ===")
    
    local testPaths = {
        "Interface/AddOns/DialogUI/src/assets/art/icons/gossipIcon",
        "Interface/AddOns/DialogUI/src/assets/art/icons/mageGossipIcon",
        "Interface/AddOns/DialogUI/src/assets/art/icons/warriorGossipIcon",
        "Interface/AddOns/DialogUI/src/assets/art/icons/priestGossipIcon",
        "Interface/AddOns/DialogUI/src/assets/art/icons/bankerGossipIcon",
        "Interface/AddOns/DialogUI/src/assets/art/icons/innkeeperGossipIcon",
        "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\gossipIcon",
        "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\first aidGossipIcon",
    }
    
    for _, path in ipairs(testPaths) do
        local tex = DGossipFrame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(path)
        local loaded = tex:GetTexture()
        DebugMsg(string.format("Path: %s -> Loaded: %s", path, tostring(loaded ~= nil)))
        tex:SetTexture(nil)
    end
    
    DebugMsg("=== END TEST ===")
end

SlashCmdList["TESTICONS"] = TestIconPaths
SLASH_TESTICONS1 = "/testicons"

function TestBarberIcon()
    DebugMsg("=== TESTING BARBER ICON ===")
    
    local paths = {
        "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\barber.blp",
        "Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\barber.tga",
        "Interface/AddOns/DialogUI/src/assets/art/icons/barber.blp",
        "Interface/AddOns/DialogUI/src/assets/art/icons/barber.tga",
    }
    
    for _, path in ipairs(paths) do
        local tex = DGossipFrame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(path)
        local loaded = tex:GetTexture()
        DebugMsg(string.format("Path: %s -> Loaded: %s", path, tostring(loaded ~= nil)))
        tex:SetTexture(nil)
    end
    
    DebugMsg("=== END TEST ===")
end

SlashCmdList["TESTBARBER"] = TestBarberIcon
SLASH_TESTBARBER1 = "/testbarber"
