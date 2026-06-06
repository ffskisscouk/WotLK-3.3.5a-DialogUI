-- Dynamic camera configuration integration
-- Extends the DialogUI configuration window with camera controls
-- Compatible with WoW 3.3.5
-- FIXED: Added offsetY parameter for positioning
-- FIXED: Fixed issue with self indexing

-- Global variable for controlling debug messages
-- Set to false to disable all debug messages
DialogUI_DebugEnabled = false;

-- Helper function for printing debug messages
function DialogUI_DebugMessage(message)
    if DialogUI_DebugEnabled and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(message);
    end
end

-- Debug message confirming file load
DialogUI_DebugMessage("DialogUI: camera.config.lua is loading...");

-- Add camera controls to the configuration window
-- FIXED: Added offsetY parameter for positioning
function DynamicCamera:AddConfigControls(offsetY)
    DialogUI_DebugMessage("DialogUI: Attempting to add camera controls...");

    -- FIXED: Use self to access object methods
    local self = DynamicCamera; -- Ensure self is defined

    -- FIXED: Use getglobal for safe frame retrieval
    local parent = getglobal("DConfigScrollChild") or getglobal("DConfigFrame");
    if not parent then
        DialogUI_DebugMessage("DialogUI: ERROR - DConfigScrollChild or DConfigFrame not found");
        return;
    end

    DialogUI_DebugMessage("DialogUI: Parent element found: " .. (parent:GetName() or "unknown"));

    -- Check existence of DConfigFontSelectLabel
    local fontSelectLabel = getglobal("DConfigFontSelectLabel");
    if not fontSelectLabel then
        DialogUI_DebugMessage("DialogUI: ERROR - DConfigFontSelectLabel does not exist");
        return;
    end

    DialogUI_DebugMessage("DialogUI: DConfigFontSelectLabel found, creating camera section...");

    -- Prevent duplicate camera section
    if getglobal("DCameraSectionTitle") then
        self:UpdateConfigControls();
        return;
    end

    -- FIXED: Use offsetY for positioning if provided
    local yOffset = offsetY or 40; -- Default 40 if not provided

    -- Create camera section title
    local cameraTitle = parent:CreateFontString("DCameraSectionTitle", "OVERLAY", "DQuestButtonTitleGossip");
    cameraTitle:SetPoint("TOPLEFT", fontSelectLabel, "BOTTOMLEFT", 0, -yOffset);
    cameraTitle:SetText("Camera Settings");
    cameraTitle:SetJustifyH("LEFT");
    if SetFontColor then
        SetFontColor(cameraTitle, "DarkBrown");
    end

    -- Camera enabled checkbox
    local cameraEnabledCheckbox = CreateFrame("CheckButton", "DCameraEnabledCheckbox", parent, "UICheckButtonTemplate");
    cameraEnabledCheckbox:SetPoint("TOPLEFT", cameraTitle, "BOTTOMLEFT", 0, -15);
    cameraEnabledCheckbox:SetScale(0.8);
    cameraEnabledCheckbox:SetChecked(DynamicCamera.config.enabled);

    local cameraEnabledLabel = parent:CreateFontString("DCameraEnabledLabel", "OVERLAY", "DQuestButtonTitleGossip");
    cameraEnabledLabel:SetPoint("LEFT", cameraEnabledCheckbox, "RIGHT", 5, 0);
    cameraEnabledLabel:SetText("Enable Dynamic Camera");
    if SetFontColor then
        SetFontColor(cameraEnabledLabel, "DarkBrown");
    end

    cameraEnabledCheckbox:SetScript("OnClick", function()
        local newState = cameraEnabledCheckbox:GetChecked();
        DynamicCamera:SetEnabled(newState);
        
        -- Update UI display
        if DynamicCamera.UpdateConfigControls then
            DynamicCamera:UpdateConfigControls();
        end
    end);

    -- Face View checkbox
    local faceViewCheckbox = CreateFrame("CheckButton", "DCameraFaceViewCheckbox", parent, "UICheckButtonTemplate");
    faceViewCheckbox:SetPoint("TOPLEFT", cameraEnabledCheckbox, "BOTTOMLEFT", 0, -5);
    faceViewCheckbox:SetScale(0.8);
    faceViewCheckbox:SetChecked(self.config.useFaceView);

    local faceViewLabel = parent:CreateFontString("DCameraFaceViewLabel", "OVERLAY", "DQuestButtonTitleGossip");
    faceViewLabel:SetPoint("LEFT", faceViewCheckbox, "RIGHT", 5, 0);
    faceViewLabel:SetText("Face View Mode (face NPC)");
    if SetFontColor then
        SetFontColor(faceViewLabel, "DarkBrown");
    end

    faceViewCheckbox:SetScript("OnClick", function()
        DynamicCamera.config.useFaceView = faceViewCheckbox:GetChecked();
        DynamicCamera:SaveConfig();

        local status = DynamicCamera.config.useFaceView and "enabled" or "disabled";
        DialogUI_DebugMessage("DialogUI: Face View " .. status);
    end);

    -- Settings display
    local settingsRow = parent:CreateFontString("DCameraSettingsLabel", "OVERLAY", "DQuestButtonTitleGossip");
    settingsRow:SetPoint("TOPLEFT", faceViewCheckbox, "BOTTOMLEFT", 0, -25);
    settingsRow:SetText("Distance: " .. string.format("%.1f", self.config.faceViewDistance) .. 
                       " | Mode: " .. (self.config.useFaceView and "Face" or "Normal"));
    if SetFontColor then
        SetFontColor(settingsRow, "DarkBrown");
    end

    -- Save reference for updates
    self.settingsLabel = settingsRow;

    -- Interaction types
    local typesLabel = parent:CreateFontString("DInteractionTypesLabel", "OVERLAY", "DQuestButtonTitleGossip");
    typesLabel:SetPoint("TOPLEFT", settingsRow, "BOTTOMLEFT", 0, -25);
    typesLabel:SetText("Enable for:");
    if SetFontColor then
        SetFontColor(typesLabel, "DarkBrown");
    end

    -- Checkbox data
    local checkboxData = {
        {name = "Gossip", config = "enableForGossip"},
        {name = "Vendors", config = "enableForVendors"},
        {name = "Trainers", config = "enableForTrainers"},
        {name = "Quests", config = "enableForQuests"}
    };

    -- Create checkboxes vertically
    for i, data in ipairs(checkboxData) do
        local checkbox = CreateFrame("CheckButton", "DCamera" .. data.name .. "Checkbox", parent, "UICheckButtonTemplate");
        
        checkbox:SetPoint("TOPLEFT", typesLabel, "BOTTOMLEFT", 0, -15 - ((i-1) * 25));
        checkbox:SetScale(0.7);
        checkbox:SetChecked(self.config[data.config]);
        
        local label = parent:CreateFontString("DCamera" .. data.name .. "Label", "OVERLAY", "DQuestButtonTitleGossip");
        label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0);
        label:SetText(data.name);
        if SetFontColor then
            SetFontColor(label, "DarkBrown");
        end
        
        checkbox:SetScript("OnClick", function()
            DynamicCamera.config[data.config] = checkbox:GetChecked();
            DynamicCamera:SaveConfig();
        end);
    end

    -- Preset section
    local presetsLabel = parent:CreateFontString("DCameraPresetsLabel", "OVERLAY", "DQuestButtonTitleGossip");
    presetsLabel:SetPoint("TOPLEFT", typesLabel, "BOTTOMLEFT", 0, -140);
    presetsLabel:SetText("Quick Setup (Face View):");
    if SetFontColor then
        SetFontColor(presetsLabel, "DarkBrown");
    end

    -- Save preset button
    local savePresetBtn = CreateFrame("Button", "DSavePresetButton", parent, "DUIPanelButtonTemplate");
    savePresetBtn:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -10);
    savePresetBtn:SetWidth(150);
    savePresetBtn:SetHeight(25);
    savePresetBtn:SetText("Save Current View");
    savePresetBtn:SetScript("OnClick", function()
        if DynamicCamera.SaveCameraPreset then
            DynamicCamera:SaveCameraPreset();
            DialogUI_DebugMessage("DialogUI: Current view saved as custom preset");
        else
            DialogUI_DebugMessage("DialogUI: ERROR - SaveCameraPreset method not found");
        end
    end);

    -- Preset info
    local presetInfo = parent:CreateFontString("DCameraPresetInfo", "OVERLAY", "DQuestButtonTitleGossip");
    presetInfo:SetPoint("TOPLEFT", savePresetBtn, "BOTTOMLEFT", 0, -10);
    presetInfo:SetWidth(300);
    presetInfo:SetJustifyH("LEFT");
    presetInfo:SetText("Adjust the camera to how you want it to look after talking to an NPC, then save the view.");
    if SetFontColor then
        SetFontColor(presetInfo, "LightBrown");
    end

    -- Preset buttons
    local presets = {"Cinematic", "Close", "Normal", "Wide"};
    local presetNames = {"Cinematic", "Close", "Normal", "Wide"};
    for i, presetName in ipairs(presets) do
        local button = CreateFrame("Button", "DCamera" .. presetName .. "Button", parent, "DUIPanelButtonTemplate");
        button:SetText(presetNames[i]);
        button:SetWidth(80);
        button:SetHeight(22);

        button:SetPoint("TOPLEFT", presetInfo, "BOTTOMLEFT", (i-1) * 85, -15);
        button:SetScript("OnClick", function()
            if DynamicCamera.ApplyPreset then
                DynamicCamera:ApplyPreset(string.lower(presetName));
                DialogUI_DebugMessage("DialogUI: View '" .. presetNames[i] .. "' applied");

                if DynamicCamera.settingsLabel then
                    DynamicCamera.settingsLabel:SetText("Distance: " .. string.format("%.1f", DynamicCamera.config.faceViewDistance) .. 
                                                       " | Mode: " .. (DynamicCamera.config.useFaceView and "Face" or "Normal"));
                end
            else
                DialogUI_DebugMessage("DialogUI: ERROR - ApplyPreset method not found");
            end
        end);
    end

    -- Debug: confirm creation
    DialogUI_DebugMessage("DialogUI: Camera section created with " .. #presets .. " preset buttons");
end

function DynamicCamera:UpdateConfigControls()
    local self = DynamicCamera;
    
    -- Check existence before updating
    local checkbox = getglobal("DCameraEnabledCheckbox");
    if checkbox and checkbox.SetChecked then
        checkbox:SetChecked(self.config.enabled);
    end

    local faceViewCheckbox = getglobal("DCameraFaceViewCheckbox");
    if faceViewCheckbox and faceViewCheckbox.SetChecked then
        faceViewCheckbox:SetChecked(self.config.useFaceView);
    end

    if self.settingsLabel then
        self.settingsLabel:SetText("Distance: " .. string.format("%.1f", self.config.faceViewDistance) .. 
                                   " | Mode: " .. (self.config.useFaceView and "Face" or "Normal"));
    end

    -- Update checkboxes
    local checkboxData = {
        {name = "Gossip", config = "enableForGossip"},
        {name = "Vendors", config = "enableForVendors"},
        {name = "Trainers", config = "enableForTrainers"},
        {name = "Quests", config = "enableForQuests"}
    };

    for i, data in ipairs(checkboxData) do
        local checkbox = getglobal("DCamera" .. data.name .. "Checkbox");
        if checkbox and checkbox.SetChecked then
            checkbox:SetChecked(self.config[data.config]);
        end
    end
end

-- Camera preset logic
function DynamicCamera:ApplyPreset(presetName)
    local self = DynamicCamera; -- Ensure self is defined
    
    if presetName == "cinematic" then
        self.config.faceViewDistance = 2.0;
        self.config.useFaceView = true;
    elseif presetName == "close" then
        self.config.faceViewDistance = 1.5;
        self.config.useFaceView = true;
    elseif presetName == "normal" then
        self.config.faceViewDistance = 2.5;
        self.config.useFaceView = true;
    elseif presetName == "wide" then
        self.config.useFaceView = false;
        self.config.interactionDistance = 8;
    end

    self:SaveConfig();
    DialogUI_DebugMessage("DialogUI: Camera view '" .. presetName .. "' applied");
end

-- Preset commands
SlashCmdList["CAMERA_PRESET"] = function(msg)
    local preset = string.lower(msg or "");
    if preset == "cinematic" or preset == "close" or preset == "normal" or preset == "wide" then
        DynamicCamera:ApplyPreset(preset);
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Available views: cinematic, close, normal, wide");
            DEFAULT_CHAT_FRAME:AddMessage("Usage: /camerapreset [view_name]");
        end
    end
end;
SLASH_CAMERA_PRESET1 = "/camerapreset";

-- Confirm function defined
DialogUI_DebugMessage("DialogUI: AddConfigControls function successfully defined");
