local addonName, addon = ...

local temperatureColors = {
    [-2] = { 0.12, 0.32, 0.85 },
    [-1] = { 0.2, 0.65, 0.95 },
    [0] = { 0.4, 0.75, 0.5 },
    [1] = { 0.98, 0.67, 0.2 },
    [2] = { 0.95, 0.28, 0.12 },
}

local function createStatusBar(parent, label, y, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(220, height or 20)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(100)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(0.12, 0.12, 0.12, 0.9)
    bar.background = background

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", bar, "CENTER")
    bar.text = text
    bar.label = label
    return bar
end

local function createTemperatureBar(parent)
    local bar = createStatusBar(parent, "Temperature", -68, 16)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarColor(0.28, 0.28, 0.28)

    local neutralMarker = bar:CreateTexture(nil, "OVERLAY")
    neutralMarker:SetColorTexture(1, 1, 1, 0.9)
    neutralMarker:SetSize(2, 16)
    neutralMarker:SetPoint("CENTER", bar, "CENTER")
    bar.neutralMarker = neutralMarker

    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(0.2, 0.5, 0.95)
    marker:SetSize(4, 20)

    local labels = {
        { text = "Cold", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", justify = "LEFT" },
        { text = "Hot", point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT", justify = "RIGHT" },
    }
    for _, data in ipairs(labels) do
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint(data.point, bar, data.relativePoint, 0, -2)
        label:SetJustifyH(data.justify)
        label:SetText(data.text)
    end

    return bar, marker
end

local function createMinimapButton(addon)
    local button = CreateFrame("Button", "SurvivalNotJustForHuntersMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(7808144)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local function reposition()
        local angle = math.rad(addon.db.minimapAngle or 220)
        local radius = Minimap:GetWidth() / 2 + 4
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * radius, math.sin(angle) * radius)
    end

    button:SetScript("OnClick", function() addon:ToggleSettings() end)
    button:SetScript("OnDragStart", function(frame)
        frame:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            x = x / scale - Minimap:GetLeft() - Minimap:GetWidth() / 2
            y = y / scale - Minimap:GetBottom() - Minimap:GetHeight() / 2
            addon.db.minimapAngle = math.deg(math.atan2(y, x))
            reposition()
        end)
    end)
    button:SetScript("OnDragStop", function(frame)
        frame:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:SetText("Survival Settings")
        GameTooltip:AddLine("Click to open or close", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    reposition()
    return button
end

function addon:CreateUI()
    local status = CreateFrame("Frame", "SurvivalNotJustForHuntersStatus",
        UIParent, "BackdropTemplate")
    status:SetSize(246, 142)
    status:SetPoint("CENTER", UIParent, "CENTER", self.db.barX, self.db.barY)
    status:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    status:SetMovable(true)
    status:EnableMouse(true)
    status:RegisterForDrag("LeftButton")
    status:SetScript("OnDragStart", status.StartMoving)
    status:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local _, _, _, x, y = frame:GetPoint(1)
        self.db.barX, self.db.barY = x, y
    end)

    self.statusFrame = status
    self.hungerBar = createStatusBar(status, "Hunger", -12)
    self.thirstBar = createStatusBar(status, "Thirst", -40)
    self.hungerBar:SetStatusBarColor(0.78, 0.47, 0.16)
    self.thirstBar:SetStatusBarColor(0.16, 0.52, 0.88)
    self.temperatureBar, self.temperatureMarker = createTemperatureBar(status)
    self.fatigueBar = createStatusBar(status, "Fatigue", -102, 16)
    self.fatigueBar:SetStatusBarColor(0.63, 0.42, 0.78)

    self:CreateWindows()
    self.minimapButton = createMinimapButton(self)
end

function addon:UpdateStatisticsDisplay()
    if not self.db or not self.statisticsLines then
        return
    end

    for index, text in ipairs(self:GetStatisticsText()) do
        self.statisticsLines[index]:SetText(text)
    end
end

function addon:UpdateDisplay()
    if not self.db or not self.statusFrame then
        return
    end

    self.instanceState = self:GetInstanceState()
    self.statusFrame:SetShown(self.db.barsShown and not self.instanceState.disabled)

    local hunger = math.max(0, math.min(self.MAX_VALUE, self.db.hunger))
    local thirst = math.max(0, math.min(self.MAX_VALUE, self.db.thirst))
    local fatigue = math.max(0, math.min(self.MAX_VALUE, self.db.fatigue))
    self.hungerBar:SetValue(hunger)
    self.thirstBar:SetValue(thirst)
    self.fatigueBar:SetValue(fatigue)

    local temperature = self:GetTemperatureState()
    local position = (temperature.value + 2) / 4
    if temperature.value == 0 then
        self.temperatureBar.neutralMarker:Show()
    else
        self.temperatureBar.neutralMarker:Hide()
    end
    self.temperatureMarker:ClearAllPoints()
    self.temperatureMarker:SetPoint("CENTER", self.temperatureBar, "LEFT",
        2 + position * (self.temperatureBar:GetWidth() - 4), 0)

    local temperatureColor = temperatureColors[temperature.value] or temperatureColors[0]
    self.temperatureBar:SetStatusBarColor(unpack(temperatureColor))
    self.temperatureMarker:SetColorTexture(unpack(temperatureColor))
    local temperatureLabel = temperature.value <= -2 and "Cold"
        or (temperature.value < 0 and "Cool"
            or (temperature.value >= 2 and "Hot"
                or (temperature.value > 0 and "Warm" or "Neutral")))
    self.temperatureBar.text:SetText("Temperature: " .. temperatureLabel)

    self.hungerBar.text:SetText(string.format("%s: %d%%",
        self.hungerBar.label, math.floor(hunger)))
    self.thirstBar.text:SetText(string.format("%s: %d%%",
        self.thirstBar.label, math.floor(thirst)))
    self.fatigueBar.text:SetText(string.format("%s: %d%%",
        self.fatigueBar.label, math.floor(fatigue)))
end
