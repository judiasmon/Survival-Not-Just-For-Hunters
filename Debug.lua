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
    local temperature = self:GetTemperatureState()
    local fatigue = self:GetFatigueState()
    local instance = self:GetInstanceState()
    local lines = {
        string.format("Hunger: %.2f%%", self.db.hunger),
        string.format("Thirst: %.2f%%", self.db.thirst),
        string.format("Fatigue: %.2f%%", self.db.fatigue),
        "",
        "Current state",
        "Eating: " .. (state.eating and "yes" or "no"),
        "Drinking: " .. (state.drinking and "yes" or "no"),
        "Well Fed: " .. (state.wellFed and "yes" or "no"),
        "Moving: " .. (moving and "yes" or "no"),
        "Mounted: " .. (mounted and "yes" or "no"),
        "In combat: " .. (inCombat and "yes" or "no"),
        string.format("Instance: %s (%s)", instance.instanceType,
            instance.disabled and "addon paused" or "active"),
        "Resting: " .. (fatigue.resting and "yes" or "no"),
        string.format("Fatigue state: %s", fatigue.recovering
            and "recovering" or "depleting"),
        string.format("Location: %s%s", temperature.zone,
            temperature.subzone ~= "" and " - " .. temperature.subzone or ""),
        string.format("Indoors: %s", temperature.indoors and "yes" or "no"),
        string.format("Temperature: %s (%d)",
            temperature.value <= -2 and "Cold"
                or (temperature.value < 0 and "Cool"
                    or (temperature.value >= 2 and "Hot"
                        or (temperature.value > 0 and "Warm" or "Neutral"))),
            temperature.value),
        "",
        "Current drain modifiers",
        string.format("Well Fed: x%.2f", modifiers.wellFed),
        string.format("Unmounted movement: x%.2f", modifiers.movement),
        string.format("Combat: x%.2f", modifiers.combat),
        string.format("Combined: x%.2f", modifiers.total),
        string.format("Difficulty (%s): x%.2f",
            self.db.needDifficulty, modifiers.difficulty),
        string.format("Temperature hunger: x%.2f", modifiers.temperatureHunger),
        string.format("Temperature thirst: x%.2f", modifiers.temperatureThirst),
        string.format("Temperature effect per level: +%.0f%% drain",
            self.db.temperatureDrainPerLevel * 100),
        string.format("Fatigue drain: %.4f%% per second (%.1f hours at normal needs)",
            fatigue.drainRate, 100 / fatigue.drainRate / 3600),
        string.format("Low-hunger/thirst fatigue multiplier: x%.2f",
            fatigue.lowNeedMultiplier),
        string.format("Fatigue recovery: %.3f%% per second",
            fatigue.restorationRate),
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

    if not temperature.indoorDetectionAvailable then
        lines[#lines + 1] = "Indoor detection unavailable; zone temperature is used."
    end
    if not fatigue.restingAvailable then
        lines[#lines + 1] = "Rest-area detection unavailable; fatigue will not recover automatically."
    end
    if not instance.detectionAvailable then
        lines[#lines + 1] = "Instance detection unavailable."
    end

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

    if self.needFeedbackError then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Feedback warning: " .. self.needFeedbackError
    end

    return table.concat(lines, "\n")
end
