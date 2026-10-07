local addonName, addon = ...

local function configureWindow(frame, width, height)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
end

local function createCloseButton(parent)
    local button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -5)
    button:SetScript("OnClick", function() parent:Hide() end)
end

local function createCheckbox(parent, text, y, setter)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    label:SetText(text)

    checkbox:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        addon:UpdateDisplay()
    end)
    return checkbox
end

local function createTitle(parent, text, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", parent, "TOP", 0, y)
    title:SetText(text)
    return title
end

local function registerEscapeClose(frame)
    table.insert(UISpecialFrames, frame:GetName())
end

function addon:CreateSettingsWindow()
    local panel = CreateFrame("Frame", "SurvivalNotJustForHuntersSettings",
        UIParent, "BackdropTemplate")
    configureWindow(panel, 360, 300)
    createTitle(panel, "Survival Settings", -22)

    local settingsTab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    settingsTab:SetSize(120, 24)
    settingsTab:SetPoint("TOPLEFT", panel, "TOPLEFT", 42, -48)
    settingsTab:SetText("Settings")

    local statisticsTab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    statisticsTab:SetSize(120, 24)
    statisticsTab:SetPoint("LEFT", settingsTab, "RIGHT", 12, 0)
    statisticsTab:SetText("Statistics")

    local settingsContent = CreateFrame("Frame", nil, panel)
    settingsContent:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -82)
    settingsContent:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 18)

    local statisticsContent = CreateFrame("Frame", nil, panel)
    statisticsContent:SetPoint("TOPLEFT", settingsContent, "TOPLEFT")
    statisticsContent:SetPoint("BOTTOMRIGHT", settingsContent, "BOTTOMRIGHT")
    statisticsContent:Hide()

    local description = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", settingsContent, "TOPLEFT", 4, -4)
    description:SetWidth(298)
    description:SetJustifyH("LEFT")
    description:SetText("Hunger and thirst decrease over time. Eat and drink to restore them.")

    local depletionCheckbox = createCheckbox(settingsContent,
        "Enable hunger and thirst depletion", -42,
        function(value) self.db.depletionEnabled = value end)
    local barsCheckbox = createCheckbox(settingsContent, "Show survival bars", -74,
        function(value) self.db.barsShown = value end)
    local instancesCheckbox = createCheckbox(settingsContent,
        "Disable in dungeons, raids, and battlegrounds", -106,
        function(value) self.db.disableInInstances = value end)

    local difficultyLabel = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    difficultyLabel:SetPoint("TOPLEFT", settingsContent, "TOPLEFT", 14, -137)

    local difficultySlider = CreateFrame("Slider", "SurvivalNeedDifficultySlider",
        settingsContent, "OptionsSliderTemplate")
    difficultySlider:SetPoint("TOPLEFT", settingsContent, "TOPLEFT", 20, -157)
    difficultySlider:SetSize(260, 18)
    difficultySlider:SetMinMaxValues(1, 3)
    difficultySlider:SetValueStep(1)
    local sliderName = difficultySlider:GetName()
    if sliderName then
        local lowLabel = _G[sliderName .. "Low"]
        local highLabel = _G[sliderName .. "High"]
        if lowLabel then
            lowLabel:Hide()
        end
        if highLabel then
            highLabel:Hide()
        end
    end

    local difficultyLabels = {
        { name = "Casual", value = 1 },
        { name = "Normal", value = 2 },
        { name = "Hardcore", value = 3 },
    }
    for _, option in ipairs(difficultyLabels) do
        local label = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOP", difficultySlider, "BOTTOM",
            (option.value - 2) * (difficultySlider:GetWidth() / 2), -4)
        label:SetText(option.name)
    end

    local difficultyValues = { "Casual", "Normal", "Hardcore" }
    local difficultyPositions = { Casual = 1, Normal = 2, Hardcore = 3 }
    local function updateDifficultyLabel()
        local selectedDifficulty = self.db.needDifficulty
        local multiplier = self:GetDifficultyMultiplier()
        difficultyLabel:SetText(string.format("Need depletion: %s (%.0f%%)",
            selectedDifficulty, multiplier * 100))
    end
    difficultySlider:SetValue(difficultyPositions[self.db.needDifficulty] or 2)
    difficultySlider:SetScript("OnValueChanged", function(_, value)
        local index = math.floor(value + 0.5)
        if value ~= index then
            difficultySlider:SetValue(index)
            return
        end
        self.db.needDifficulty = difficultyValues[index]
        updateDifficultyLabel()
    end)
    updateDifficultyLabel()
    self.difficultySlider = difficultySlider

    local statisticsLines = {}
    for index = 1, 7 do
        local line = statisticsContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetPoint("TOPLEFT", statisticsContent, "TOPLEFT", 12, -10 - (index - 1) * 24)
        line:SetWidth(285)
        line:SetJustifyH("LEFT")
        statisticsLines[index] = line
    end
    self.statisticsLines = statisticsLines

    local function selectTab(showStatistics)
        settingsContent:SetShown(not showStatistics)
        statisticsContent:SetShown(showStatistics)
        settingsTab:Disable()
        statisticsTab:Disable()
        if showStatistics then
            settingsTab:Enable()
        else
            statisticsTab:Enable()
        end
        self:UpdateStatisticsDisplay()
    end

    settingsTab:SetScript("OnClick", function() selectTab(false) end)
    statisticsTab:SetScript("OnClick", function() selectTab(true) end)
    self.selectSettingsTab = function() selectTab(false) end
    createCloseButton(panel)

    depletionCheckbox:SetChecked(self.db.depletionEnabled)
    barsCheckbox:SetChecked(self.db.barsShown)
    instancesCheckbox:SetChecked(self.db.disableInInstances)
    selectTab(false)

    panel:SetScript("OnUpdate", function(frame, elapsed)
        if not frame:IsShown() or not statisticsContent:IsShown() then
            return
        end
        frame.statisticsElapsed = (frame.statisticsElapsed or 0) + elapsed
        if frame.statisticsElapsed >= 1 then
            frame.statisticsElapsed = 0
            self:UpdateStatisticsDisplay()
        end
    end)

    panel:Hide()
    self.settingsFrame = panel
    registerEscapeClose(panel)
end

function addon:CreateDebugWindow()
    local panel = CreateFrame("Frame", "SurvivalNotJustForHuntersDebug",
        UIParent, "BackdropTemplate")
    configureWindow(panel, 560, 460)
    createTitle(panel, "Survival Debug", -18)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -48)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 18)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(490, 1)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(480)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)

    panel:SetScript("OnUpdate", function(frame, elapsed)
        if not frame:IsShown() then
            return
        end
        frame.refreshElapsed = (frame.refreshElapsed or 0) + elapsed
        if frame.refreshElapsed >= 1 then
            frame.refreshElapsed = 0
            text:SetText(self:GetDebugText())
            content:SetHeight(math.max(text:GetStringHeight(), 1))
        end
    end)

    createCloseButton(panel)
    panel:Hide()
    self.debugFrame = panel
    self.debugText = text
    self.debugContent = content
    registerEscapeClose(panel)
end

function addon:CreateWindows()
    self:CreateSettingsWindow()
    self:CreateDebugWindow()

    function self:ToggleSettings()
        if self.settingsFrame:IsShown() then
            self.settingsFrame:Hide()
        else
            self.selectSettingsTab()
            self.settingsFrame:Show()
        end
    end

    function self:ToggleDebug()
        if self.debugFrame:IsShown() then
            self.debugFrame:Hide()
        else
            self.debugText:SetText(self:GetDebugText())
            self.debugContent:SetHeight(math.max(self.debugText:GetStringHeight(), 1))
            self.debugFrame:Show()
        end
    end

    SLASH_SURVIVALNOTJUSTFORHUNTERS1 = "/survival"
    SLASH_SURVIVALNOTJUSTFORHUNTERS2 = "/snjh"
    SlashCmdList.SURVIVALNOTJUSTFORHUNTERS = function(message)
        local command = string.lower(string.match(message or "", "^%s*(.-)%s*$"))
        if command == "debug" or command == "auras" then
            self:ToggleDebug()
        else
            self:ToggleSettings()
        end
    end
end
