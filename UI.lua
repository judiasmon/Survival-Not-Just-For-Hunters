local addonName, addon = ...

local function createStatusBar(parent, label, y)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(220, 20)
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

function addon:CreateUI()
    local status = CreateFrame("Frame", "SurvivalNotJustForHuntersStatus", UIParent, "BackdropTemplate")
    status:SetSize(246, 74)
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

    local panel = CreateFrame("Frame", "SurvivalNotJustForHuntersSettings", UIParent, "BackdropTemplate")
    panel:SetSize(300, 190)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -22)
    title:SetText("Survival Settings")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -56)
    description:SetWidth(248)
    description:SetJustifyH("LEFT")
    description:SetText("Hunger and thirst decrease over time. Eat and drink to restore them.")

    local depletionCheckbox = createCheckbox(panel, "Enable hunger and thirst depletion", -105,
        function(value) self.db.depletionEnabled = value end)
    local barsCheckbox = createCheckbox(panel, "Show survival bars", -137,
        function(value) self.db.barsShown = value end)

    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() panel:Hide() end)

    depletionCheckbox:SetChecked(self.db.depletionEnabled)
    barsCheckbox:SetChecked(self.db.barsShown)
    panel:Hide()
    self.settingsFrame = panel
    table.insert(UISpecialFrames, panel:GetName())

    function self:ToggleSettings()
        if panel:IsShown() then
            panel:Hide()
        else
            panel:Show()
        end
    end

    SLASH_SURVIVALNOTJUSTFORHUNTERS1 = "/survival"
    SLASH_SURVIVALNOTJUSTFORHUNTERS2 = "/snjh"
    SlashCmdList.SURVIVALNOTJUSTFORHUNTERS = function()
        self:ToggleSettings()
    end

    local minimapButton = CreateFrame("Button", "SurvivalNotJustForHuntersMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bonfire_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    minimapButton.icon = icon

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

    local function positionMinimapButton()
        local angle = math.rad(self.db.minimapAngle or 220)
        local radius = (Minimap:GetWidth() / 2) + 4
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * radius, math.sin(angle) * radius)
    end

    minimapButton:SetScript("OnClick", function() self:ToggleSettings() end)
    minimapButton:SetScript("OnDragStart", function(button)
        button:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            x = x / scale - Minimap:GetLeft() - Minimap:GetWidth() / 2
            y = y / scale - Minimap:GetBottom() - Minimap:GetHeight() / 2
            self.db.minimapAngle = math.deg(math.atan2(y, x))
            positionMinimapButton()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
    end)
    minimapButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Survival Settings")
        GameTooltip:AddLine("Click to open or close", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    positionMinimapButton()
    self.minimapButton = minimapButton
end

function addon:UpdateDisplay()
    if not self.db or not self.statusFrame then
        return
    end

    self.statusFrame:SetShown(self.db.barsShown)
    local hunger = math.max(0, math.min(100, self.db.hunger))
    local thirst = math.max(0, math.min(100, self.db.thirst))
    self.hungerBar:SetValue(hunger)
    self.thirstBar:SetValue(thirst)
    self.hungerBar.text:SetText(string.format("%s: %d%%", self.hungerBar.label, math.floor(hunger)))
    self.thirstBar.text:SetText(string.format("%s: %d%%", self.thirstBar.label, math.floor(thirst)))
end
