local addonName, addon = ...

local MAX_VALUE = 100
local UPDATE_INTERVAL = 1
local CANNIBALIZE_SPELL_ID = 20577
local getConsumptionBuffs

local function pack(...)
    return { n = select("#", ...), ... }
end

addon.defaults = {
    hunger = MAX_VALUE,
    thirst = MAX_VALUE,
    lastUpdate = 0,
    hungerDrain = 0.012,
    thirstDrain = 0.018,
    hungerRestore = 1,
    thirstRestore = 1.5,
    depletionEnabled = true,
    barsShown = true,
    barX = 0,
    barY = -220,
    minimapAngle = 220,
}

local function copyDefaults()
    local database = SurvivalNotJustForHuntersDB
    if type(database) ~= "table" then
        database = {}
        SurvivalNotJustForHuntersDB = database
    end

    for key, value in pairs(addon.defaults) do
        if database[key] == nil then
            database[key] = value
        end
    end
    addon.db = database
end

local function updateNeeds(elapsed)
    if addon.db.depletionEnabled then
        addon.db.hunger = math.max(0, addon.db.hunger - addon.db.hungerDrain * elapsed)
        addon.db.thirst = math.max(0, addon.db.thirst - addon.db.thirstDrain * elapsed)
    end

    local isEating, isDrinking = getConsumptionBuffs()
    if isEating then
        addon.db.hunger = math.min(MAX_VALUE, addon.db.hunger + addon.db.hungerRestore * elapsed)
    end
    if isDrinking then
        addon.db.thirst = math.min(MAX_VALUE, addon.db.thirst + addon.db.thirstRestore * elapsed)
    end
end

function addon:RestoreNeeds(need, amount)
    if need == "hunger" or need == "both" then
        self.db.hunger = math.min(MAX_VALUE, self.db.hunger + amount)
    end
    if need == "thirst" or need == "both" then
        self.db.thirst = math.min(MAX_VALUE, self.db.thirst + amount)
    end
    self:UpdateDisplay()
end

getConsumptionBuffs = function()
    local isEating, isDrinking = false, false
    if UnitChannelInfo then
        local channel = pack(UnitChannelInfo("player"))
        if channel[8] == CANNIBALIZE_SPELL_ID then
            isEating = true
        elseif channel[1] and GetSpellInfo then
            isEating = channel[1] == GetSpellInfo(CANNIBALIZE_SPELL_ID)
        end
    end

    local getBuff = UnitBuff or UnitAura
    if not getBuff then
        return isEating, isDrinking
    end

    for index = 1, 40 do
        local aura = pack(getBuff("player", index))
        if not aura[1] then
            break
        end

        local name, icon
        if type(aura[1]) == "string" and aura[1]:find("^Interface") then
            icon = aura[1]
        else
            name, icon = aura[1], aura[2]
        end

        local buffName = type(name) == "string" and string.lower(name) or ""
        local buffIcon = type(icon) == "string" and string.lower(icon) or ""
        local isFoodSpell, isDrinkSpell = false, false
        for auraIndex = 1, aura.n do
            local value = aura[auraIndex]
            if value == 430 then
                isFoodSpell = true
            elseif value == 431 then
                isDrinkSpell = true
            elseif type(value) == "string" and not value:find("^Interface") then
                local candidate = string.lower(value)
                if candidate:find("food", 1, true) or candidate:find("eating", 1, true) then
                    buffName = candidate
                elseif candidate:find("drink", 1, true) then
                    buffName = candidate
                end
            end
        end

        isEating = isEating or isFoodSpell
            or buffName:find("food", 1, true) ~= nil
            or buffName:find("eating", 1, true) ~= nil
            or buffIcon:find("inv_misc_food_15", 1, true) ~= nil
        isDrinking = isDrinking or isDrinkSpell
            or buffName:find("drinking", 1, true) ~= nil
            or buffName:find("drink", 1, true) ~= nil
            or buffIcon:find("inv_drink_05", 1, true) ~= nil
    end

    return isEating, isDrinking
end

local function onEvent(_, event, ...)
    if event == "PLAYER_LOGIN" then
        copyDefaults()
        local now = time()
        if addon.db.lastUpdate > 0 then
            updateNeeds(math.max(0, now - addon.db.lastUpdate))
        end
        addon.db.lastUpdate = now
        addon:CreateUI()
        addon:UpdateDisplay()
    elseif event == "PLAYER_LOGOUT" and addon.db then
        addon.db.lastUpdate = time()
    end
end

local ticker = CreateFrame("Frame")
ticker:RegisterEvent("PLAYER_LOGIN")
ticker:RegisterEvent("PLAYER_LOGOUT")
ticker:SetScript("OnEvent", onEvent)
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_INTERVAL or not addon.db then
        return
    end

    updateNeeds(self.elapsed)
    addon.db.lastUpdate = time()
    self.elapsed = 0
    addon:UpdateDisplay()
end)
