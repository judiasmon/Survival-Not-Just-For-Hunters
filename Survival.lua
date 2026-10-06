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
    movementDrainMultiplier = 2,
    combatDrainMultiplier = 2,
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
    local isEating, isDrinking, isWellFed, eatingDuration, drinkingDuration = getConsumptionBuffs()

    if addon.db.depletionEnabled then
        local drainMultiplier = isWellFed and addon.db.wellFedDrainMultiplier or 1
        local isMoving = GetUnitSpeed and GetUnitSpeed("player") > 0
        local isMounted = IsMounted and IsMounted()
        local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
        if isMoving and not isMounted then
            drainMultiplier = drainMultiplier * addon.db.movementDrainMultiplier
        end
        if inCombat then
            drainMultiplier = drainMultiplier * addon.db.combatDrainMultiplier
        end
        addon.db.hunger = math.max(0,
            addon.db.hunger - addon.db.hungerDrain * drainMultiplier * elapsed)
        addon.db.thirst = math.max(0,
            addon.db.thirst - addon.db.thirstDrain * drainMultiplier * elapsed)
    end

    if isEating then
        if eatingDuration and eatingDuration > 0 then
            addon.db.hunger = math.min(MAX_VALUE,
                addon.db.hunger + MAX_VALUE / eatingDuration * elapsed)
        else
            addon.db.hunger = math.min(MAX_VALUE,
                addon.db.hunger + addon.db.hungerRestore * elapsed)
        end
    end
    if isDrinking then
        if drinkingDuration and drinkingDuration > 0 then
            addon.db.thirst = math.min(MAX_VALUE,
                addon.db.thirst + MAX_VALUE / drinkingDuration * elapsed)
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
    local eatingDuration, drinkingDuration

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

            local duration = aura.duration
            if auraEating and duration and duration > 0 then
                eatingDuration = duration
            end
            if auraDrinking and duration and duration > 0 then
                drinkingDuration = duration
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

        local duration = aura[6]
        if isEating and type(duration) == "number" and duration > 0 then
            eatingDuration = duration
        end
        if isDrinking and type(duration) == "number" and duration > 0 then
            drinkingDuration = duration
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

    return isEating, isDrinking, isWellFed, eatingDuration, drinkingDuration
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

function addon:GetDebugText()
    local isEating, isDrinking, isWellFed, eatingDuration, drinkingDuration = getConsumptionBuffs()
    local isMoving = GetUnitSpeed and GetUnitSpeed("player") > 0 or false
    local isMounted = IsMounted and IsMounted() or false
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local wellFedMultiplier = isWellFed and self.db.wellFedDrainMultiplier or 1
    local movementMultiplier = isMoving and not isMounted and self.db.movementDrainMultiplier or 1
    local combatMultiplier = inCombat and self.db.combatDrainMultiplier or 1
    local totalMultiplier = wellFedMultiplier * movementMultiplier * combatMultiplier
    local hungerRate = self.db.depletionEnabled and self.db.hungerDrain * totalMultiplier or 0
    local thirstRate = self.db.depletionEnabled and self.db.thirstDrain * totalMultiplier or 0
    local lines = {
        string.format("Hunger: %.2f%%", self.db.hunger),
        string.format("Thirst: %.2f%%", self.db.thirst),
        "",
        "Current state",
        "Eating: " .. (isEating and "yes" or "no"),
        "Drinking: " .. (isDrinking and "yes" or "no"),
        "Well Fed: " .. (isWellFed and "yes" or "no"),
        "Moving: " .. (isMoving and "yes" or "no"),
        "Mounted: " .. (isMounted and "yes" or "no"),
        "In combat: " .. (inCombat and "yes" or "no"),
        "",
        "Current drain modifiers",
        string.format("Well Fed: x%.2f", wellFedMultiplier),
        string.format("Unmounted movement: x%.2f", movementMultiplier),
        string.format("Combat: x%.2f", combatMultiplier),
        string.format("Combined: x%.2f", totalMultiplier),
        "",
        string.format("Hunger drain: %.3f%% per second", hungerRate),
        string.format("Thirst drain: %.3f%% per second", thirstRate),
        string.format("Eating refill: %s", eatingDuration and eatingDuration > 0
            and string.format("%.3f%% per second (duration %.1fs)",
                MAX_VALUE / eatingDuration, eatingDuration) or "default rate"),
        string.format("Drinking refill: %s", drinkingDuration and drinkingDuration > 0
            and string.format("%.3f%% per second (duration %.1fs)",
                MAX_VALUE / drinkingDuration, drinkingDuration) or "default rate"),
        "",
        "Active auras",
    }

    local auraCount = 0
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then
                break
            end
            auraCount = auraCount + 1
            lines[#lines + 1] = string.format(
                "%d. %s (spellId=%s, duration=%s, expires=%s, source=%s)",
                auraCount,
                tostring(aura.name or "unnamed"),
                tostring(aura.spellId or "unknown"),
                tostring(aura.duration or "unknown"),
                tostring(aura.expirationTime or "unknown"),
                tostring(aura.sourceUnit or "unknown"))
        end
    else
        local getBuff = UnitBuff or UnitAura
        if getBuff then
            for index = 1, 40 do
                local aura = pack(getBuff("player", index))
                if not aura[1] then
                    break
                end
                auraCount = auraCount + 1
                local name = type(aura[1]) == "string" and aura[1] or aura[2]
                lines[#lines + 1] = string.format("%d. %s | %s",
                    auraCount, tostring(name or "unknown"), table.concat({
                        formatAuraValue(aura[1]),
                        formatAuraValue(aura[2]),
                        formatAuraValue(aura[3]),
                        formatAuraValue(aura[10]),
                    }, " | "))
            end
        end
    end
    if auraCount == 0 then
        lines[#lines + 1] = "No active helpful auras found."
    end

    if not self.db.depletionEnabled then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Need depletion is disabled."
    end

    return table.concat(lines, "\n")
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
    elseif event == "PLAYER_DEAD" and addon.db then
        addon.db.hunger = MAX_VALUE
        addon.db.thirst = MAX_VALUE
        addon:UpdateDisplay()
    elseif event == "PLAYER_LOGOUT" and addon.db then
        addon.db.lastUpdate = time()
    end
end

local ticker = CreateFrame("Frame")
ticker:RegisterEvent("PLAYER_LOGIN")
ticker:RegisterEvent("PLAYER_DEAD")
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
