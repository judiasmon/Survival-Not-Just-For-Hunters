local addonName, addon = ...

local MAX_VALUE = 100
local UPDATE_INTERVAL = 1
local CANNIBALIZE_SPELL_ID = 20577
local FOOD_SPELL_IDS = {
    [433] = true,
    [434] = true,
    [435] = true,
    [1127] = true,
    [1129] = true,
    [1131] = true,
}
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
    wellFedDrainMultiplier = 0.5,
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
    local isEating, isDrinking, isWellFed, eatingRemaining, drinkingRemaining = getConsumptionBuffs()

    if addon.db.depletionEnabled then
        local drainMultiplier = isWellFed and addon.db.wellFedDrainMultiplier or 1
        addon.db.hunger = math.max(0,
            addon.db.hunger - addon.db.hungerDrain * drainMultiplier * elapsed)
        addon.db.thirst = math.max(0,
            addon.db.thirst - addon.db.thirstDrain * drainMultiplier * elapsed)
    end

    if isEating then
        local remaining = eatingRemaining
        if remaining and remaining > 0 then
            local missing = MAX_VALUE - addon.db.hunger
            addon.db.hunger = math.min(MAX_VALUE,
                addon.db.hunger + missing * math.min(elapsed / remaining, 1))
        else
            addon.db.hunger = math.min(MAX_VALUE,
                addon.db.hunger + addon.db.hungerRestore * elapsed)
        end
    end
    if isDrinking then
        local remaining = drinkingRemaining
        if remaining and remaining > 0 then
            local missing = MAX_VALUE - addon.db.thirst
            addon.db.thirst = math.min(MAX_VALUE,
                addon.db.thirst + missing * math.min(elapsed / remaining, 1))
        else
            addon.db.thirst = math.min(MAX_VALUE,
                addon.db.thirst + addon.db.thirstRestore * elapsed)
        end
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
    local isEating, isDrinking, isWellFed = false, false, false
    local eatingRemaining, drinkingRemaining

    local function getRemainingAuraTime(duration, expirationTime)
        if not duration or duration <= 0 or not expirationTime or expirationTime <= 0 then
            return nil
        end
        local now = GetTime and GetTime() or time()
        return math.max(0, expirationTime - now)
    end

    if UnitChannelInfo then
        local channel = pack(UnitChannelInfo("player"))
        if channel[8] == CANNIBALIZE_SPELL_ID then
            isEating = true
        elseif channel[1] and GetSpellInfo then
            isEating = channel[1] == GetSpellInfo(CANNIBALIZE_SPELL_ID)
        end
    end

    local function getSpellFlags(spellID)
        if not spellID or not GetSpellInfo then
            return false, false, false
        end

        local spellName = GetSpellInfo(spellID)
        if type(spellName) ~= "string" then
            return false, false, false
        end

        spellName = string.lower(spellName)
        return spellName:find("food", 1, true) ~= nil
                or spellName:find("eating", 1, true) ~= nil,
            spellName:find("drink", 1, true) ~= nil,
            spellName:find("well fed", 1, true) ~= nil
    end

    local function classifySpellName(spellID)
        local eating, drinking, wellFed = getSpellFlags(spellID)
        isEating = isEating or eating
        isDrinking = isDrinking or drinking
        isWellFed = isWellFed or wellFed
    end

    local function classifyAura(aura)
        if aura.spellId or aura.name then
            local auraName = type(aura.name) == "string" and string.lower(aura.name) or ""
            local spellEating, spellDrinking, spellWellFed = getSpellFlags(aura.spellId)
            local auraEating = FOOD_SPELL_IDS[aura.spellId] == true
                or spellEating
                or auraName:find("food", 1, true) ~= nil
                or auraName:find("eat", 1, true) ~= nil
                or aura.spellId == CANNIBALIZE_SPELL_ID
            local auraDrinking = DRINK_SPELL_IDS[aura.spellId] == true
                or spellDrinking
                or auraName:find("drink", 1, true) ~= nil
            local auraWellFed = spellWellFed or auraName:find("well fed", 1, true) ~= nil

            local remaining = getRemainingAuraTime(aura.duration, aura.expirationTime)
            if auraEating and remaining then
                eatingRemaining = remaining
            end
            if auraDrinking and remaining then
                drinkingRemaining = remaining
            end

            isEating = isEating or auraEating
            isDrinking = isDrinking or auraDrinking
            isWellFed = isWellFed or auraWellFed
            return
        end

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

        classifySpellName(aura[9])
        classifySpellName(aura[10])
        classifySpellName(spellID)

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
        for _, value in ipairs(stringValues) do
            if string.lower(value):find("well fed", 1, true) then
                isWellFed = true
            end
        end

        local remaining = getRemainingAuraTime(aura[6], aura[7])
        if isEating and remaining then
            eatingRemaining = remaining
        end
        if isDrinking and remaining then
            drinkingRemaining = remaining
        end

        if spellID == CANNIBALIZE_SPELL_ID then
            isEating = true
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then
                break
            end
            classifyAura(aura)
        end
    else
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
    end

    return isEating, isDrinking, isWellFed, eatingRemaining, drinkingRemaining
end

local function formatAuraValue(value)
    if type(value) == "table" then
        local fields = {}
        for _, key in ipairs({
            "name", "icon", "spellId", "applications", "duration",
            "expirationTime", "sourceUnit",
        }) do
            if value[key] ~= nil then
                fields[#fields + 1] = key .. "=" .. tostring(value[key])
            end
        end
        return "{" .. table.concat(fields, ", ") .. "}"
    end
    return tostring(value)
end

function addon:DebugAuras()
    local function report(message)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSurvival:|r " .. message)
        else
            print("Survival: " .. message)
        end
    end

    local isEating, isDrinking = getConsumptionBuffs()
    report(string.format("Detected eating=%s, drinking=%s",
        tostring(isEating), tostring(isDrinking)))

    local getBuff = UnitBuff or UnitAura
    if getBuff then
        report("Raw aura results from " .. (UnitBuff and "UnitBuff" or "UnitAura") .. ":")
        local foundAura = false
        for index = 1, 40 do
            local aura = pack(getBuff("player", index))
            if not aura[1] then
                break
            end

            foundAura = true
            local values = {}
            for auraIndex = 1, aura.n do
                if aura[auraIndex] ~= nil then
                    values[#values + 1] = auraIndex .. "=" .. formatAuraValue(aura[auraIndex])
                end
            end
            report(string.format("%d: %s", index, table.concat(values, " | ")))
        end
        if not foundAura then
            report("No auras returned.")
        end
    else
        report("UnitBuff and UnitAura are unavailable.")
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        report("Raw aura results from C_UnitAuras:")
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then
                break
            end
            report(string.format("%d: %s", index, formatAuraValue(aura)))
        end
    end
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
