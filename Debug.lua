local addonName, addon = ...

local function formatAura(aura, index)
    return string.format(
        "%d. %s (spellId=%s, duration=%s, expires=%s, source=%s)",
        index,
        tostring(aura.name or "unnamed"),
        tostring(aura.spellId or "unknown"),
        tostring(aura.duration or "unknown"),
        tostring(aura.expirationTime or "unknown"),
        tostring(aura.sourceUnit or "unknown"))
end

function addon:GetDebugText()
    local state = self:GetConsumptionState()
    local hungerRate, thirstRate, modifiers = self:GetDrainRates(state)
    local moving = GetUnitSpeed and GetUnitSpeed("player") > 0 or false
    local mounted = IsMounted and IsMounted() or false
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local lines = {
        string.format("Hunger: %.2f%%", self.db.hunger),
        string.format("Thirst: %.2f%%", self.db.thirst),
        "",
        "Current state",
        "Eating: " .. (state.eating and "yes" or "no"),
        "Drinking: " .. (state.drinking and "yes" or "no"),
        "Well Fed: " .. (state.wellFed and "yes" or "no"),
        "Moving: " .. (moving and "yes" or "no"),
        "Mounted: " .. (mounted and "yes" or "no"),
        "In combat: " .. (inCombat and "yes" or "no"),
        "",
        "Current drain modifiers",
        string.format("Well Fed: x%.2f", modifiers.wellFed),
        string.format("Unmounted movement: x%.2f", modifiers.movement),
        string.format("Combat: x%.2f", modifiers.combat),
        string.format("Combined: x%.2f", modifiers.total),
        "",
        string.format("Hunger drain: %.3f%% per second", hungerRate),
        string.format("Thirst drain: %.3f%% per second", thirstRate),
        string.format("Eating refill: %s", state.eatingDuration
            and string.format("%.3f%% per second (duration %.1fs)",
                100 / state.eatingDuration, state.eatingDuration) or "default rate"),
        string.format("Drinking refill: %s", state.drinkingDuration
            and string.format("%.3f%% per second (duration %.1fs)",
                100 / state.drinkingDuration, state.drinkingDuration) or "default rate"),
        "",
        "Active auras",
    }

    if #state.auras == 0 then
        lines[#lines + 1] = "No active helpful auras found."
    else
        for index, aura in ipairs(state.auras) do
            lines[#lines + 1] = formatAura(aura, index)
        end
    end

    if not self.db.depletionEnabled then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Need depletion is disabled."
    end

    return table.concat(lines, "\n")
end
