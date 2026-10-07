local addonName, addon = ...

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

local function pack(...)
    return { n = select("#", ...), ... }
end

local function getAuraRecords()
    local auras = {}
    local getBuff = UnitBuff or UnitAura
    if getBuff then
        for index = 1, 40 do
            local values = pack(getBuff("player", index))
            if not values[1] then
                break
            end
            auras[#auras + 1] = {
                raw = values,
                name = type(values[1]) == "string" and values[1] or nil,
                icon = values[3],
                duration = values[6],
                expirationTime = values[7],
                sourceUnit = values[8],
                spellId = values[10],
            }
        end
    elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then
                break
            end
            auras[#auras + 1] = aura
        end
    elseif GetPlayerBuff and GetPlayerBuffTexture then
        for index = 0, 31 do
            local buffIndex = GetPlayerBuff(index, "HELPFUL")
            if not buffIndex or buffIndex < 0 then
                break
            end
            auras[#auras + 1] = {
                name = GetPlayerBuffName and GetPlayerBuffName(buffIndex),
                icon = GetPlayerBuffTexture(buffIndex),
                spellId = GetPlayerBuffID and GetPlayerBuffID(buffIndex),
            }
        end
    end
    return auras
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

local function classifyAura(aura)
    local name = string.lower(aura.name or "")
    local icon = string.lower(tostring(aura.icon or ""))
    local isEating, isDrinking, isWellFed = getSpellFlags(aura.spellId)

    isEating = isEating or FOOD_SPELL_IDS[aura.spellId] == true
        or name:find("food", 1, true) ~= nil
        or name:find("eat", 1, true) ~= nil
        or icon:find("inv_misc_food", 1, true) ~= nil
        or aura.spellId == CANNIBALIZE_SPELL_ID
    isDrinking = isDrinking or DRINK_SPELL_IDS[aura.spellId] == true
        or name:find("drink", 1, true) ~= nil
        or icon:find("inv_drink", 1, true) ~= nil
    isWellFed = isWellFed or name:find("well fed", 1, true) ~= nil

    if aura.raw then
        for index = 1, aura.raw.n do
            local value = aura.raw[index]
            if type(value) == "string" then
                local candidate = string.lower(value)
                isEating = isEating or candidate:find("food", 1, true) ~= nil
                    or candidate:find("eating", 1, true) ~= nil
                isDrinking = isDrinking or candidate:find("drink", 1, true) ~= nil
                isWellFed = isWellFed or candidate:find("well fed", 1, true) ~= nil
            elseif type(value) == "number" then
                isEating = isEating or FOOD_SPELL_IDS[value] == true
                    or value == CANNIBALIZE_SPELL_ID
                isDrinking = isDrinking or DRINK_SPELL_IDS[value] == true
            end
        end
    end

    return isEating, isDrinking, isWellFed
end

function addon:ShouldSkipAuraQueries()
    if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function"
        and C_Secrets.ShouldAurasBeSecret() then
        return true, "secret restrictions"
    end

    if (UnitAffectingCombat and UnitAffectingCombat("player"))
        or (InCombatLockdown and InCombatLockdown()) then
        return true, "combat"
    end

    return false
end

function addon:GetConsumptionState()
    local skipAuraQueries, skipReason = self:ShouldSkipAuraQueries()
    if skipAuraQueries then
        return {
            eating = false,
            drinking = false,
            wellFed = self.lastKnownWellFed or false,
            eatingDuration = nil,
            drinkingDuration = nil,
            auras = {},
            auraQueriesSkipped = true,
            auraQueryReason = skipReason,
        }
    end

    local state = {
        eating = false,
        drinking = false,
        wellFed = false,
        eatingDuration = nil,
        drinkingDuration = nil,
        auras = getAuraRecords(),
        auraQueriesSkipped = false,
    }

    if UnitChannelInfo then
        local channel = pack(UnitChannelInfo("player"))
        if channel[8] == CANNIBALIZE_SPELL_ID
            or (channel[1] and GetSpellInfo
                and channel[1] == GetSpellInfo(CANNIBALIZE_SPELL_ID)) then
            state.eating = true
        end
    end

    for _, aura in ipairs(state.auras) do
        local eating, drinking, wellFed = classifyAura(aura)
        state.eating = state.eating or eating
        state.drinking = state.drinking or drinking
        state.wellFed = state.wellFed or wellFed
        if eating and type(aura.duration) == "number" and aura.duration > 0 then
            state.eatingDuration = aura.duration
        end
        if drinking and type(aura.duration) == "number" and aura.duration > 0 then
            state.drinkingDuration = aura.duration
        end
    end

    self.lastKnownWellFed = state.wellFed
    return state
end
