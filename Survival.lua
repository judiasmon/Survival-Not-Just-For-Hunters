local addonName, addon = ...

local MAX_VALUE = 100
local UPDATE_INTERVAL = 1
-- Undead racial ability channel; counted as eating for hunger recovery.
local CANNIBALIZE_SPELL_ID = 20577
-- Food/eating aura spell IDs.
local FOOD_SPELL_IDS = {
    [433] = true,
    [434] = true,
    [435] = true,
    [1127] = true,
    [1129] = true,
    [1131] = true,
}
-- Drink/drinking aura spell IDs.
local DRINK_SPELL_IDS = {
    [430] = true,
    [431] = true,
    [432] = true,
    [1133] = true,
    [1135] = true,
    [1137] = true,
    [10250] = true,
}
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

    local function classifyAura(aura)
        local name, icon, spellID
        local stringValues = {}
        for auraIndex = 1, aura.n do
            local value = aura[auraIndex]
            if type(value) == "number" then
                if FOOD_SPELL_IDS[value] then
                    isEating = true
                elseif DRINK_SPELL_IDS[value] then
                    isDrinking = true
                end
                spellID = value
            elseif type(value) == "string" then
                if value:find("^Interface") then
                    icon = icon or value
                else
                    stringValues[#stringValues + 1] = value
                end
            end
        end

        if stringValues[1] and stringValues[1]:find("^Interface") then
            icon = icon or stringValues[1]
        else
            name = stringValues[1]
            icon = icon or stringValues[2]
        end

        if not icon then
            for _, value in ipairs(stringValues) do
                if value:find("^Interface") then
                    icon = value
                    break
                end
            end
        end

        local buffName = string.lower(name or "")
        local buffIcon = string.lower(icon or "")
        local eatingName = buffName:find("food", 1, true)
            or buffName:find("eat", 1, true)
        local drinkingName = buffName:find("drink", 1, true)
        local eatingIcon = buffIcon:find("inv_misc_food", 1, true)
        local drinkingIcon = buffIcon:find("inv_drink", 1, true)

        if not eatingName and not drinkingName and not eatingIcon and not drinkingIcon then
            for _, value in ipairs(stringValues) do
                local candidate = string.lower(value)
                eatingName = eatingName or candidate:find("food", 1, true)
                    or candidate:find("eating", 1, true)
                drinkingName = drinkingName or candidate:find("drink", 1, true)
            end
        end

        isEating = isEating or eatingName ~= nil or eatingIcon ~= nil
        isDrinking = isDrinking or drinkingName ~= nil or drinkingIcon ~= nil

        if spellID == CANNIBALIZE_SPELL_ID then
            isEating = true
        end
    end

    local getBuff = UnitBuff or UnitAura
    if getBuff then
        for index = 1, 40 do
            local aura = pack(getBuff("player", index))
            if not aura[1] then
                break
            end
            classifyAura(aura)
        end
    elseif GetPlayerBuff and GetPlayerBuffTexture then
        for index = 0, 31 do
            local buffIndex = GetPlayerBuff(index, "HELPFUL")
            if not buffIndex or buffIndex < 0 then
                break
            end
            local aura = pack(GetPlayerBuffName and GetPlayerBuffName(buffIndex),
                GetPlayerBuffTexture(buffIndex), GetPlayerBuffID and GetPlayerBuffID(buffIndex))
            classifyAura(aura)
        end
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
