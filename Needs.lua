local addonName, addon = ...

function addon:GetDrainModifiers(state)
    state = state or self:GetConsumptionState()

    local movement = 1
    if GetUnitSpeed and GetUnitSpeed("player") > 0
        and not (IsMounted and IsMounted()) then
        movement = self.db.movementDrainMultiplier
    end

    local combat = UnitAffectingCombat and UnitAffectingCombat("player")
        and self.db.combatDrainMultiplier or 1
    local wellFed = state.wellFed and self.db.wellFedDrainMultiplier or 1

    return {
        movement = movement,
        combat = combat,
        wellFed = wellFed,
        total = movement * combat * wellFed,
    }
end

function addon:GetDrainRates(state)
    local modifiers = self:GetDrainModifiers(state)
    local multiplier = self.db.depletionEnabled and modifiers.total or 0
    return self.db.hungerDrain * multiplier,
        self.db.thirstDrain * multiplier,
        modifiers
end

function addon:UpdateNeeds(elapsed)
    local state = self:GetConsumptionState()
    local hungerDrain, thirstDrain = self:GetDrainRates(state)
    self.db.hunger = math.max(0, self.db.hunger - hungerDrain * elapsed)
    self.db.thirst = math.max(0, self.db.thirst - thirstDrain * elapsed)

    if state.eating then
        local rate = state.eatingDuration and state.eatingDuration > 0
            and 100 / state.eatingDuration or self.db.hungerRestore
        self.db.hunger = math.min(self.MAX_VALUE, self.db.hunger + rate * elapsed)
    end
    if state.drinking then
        local rate = state.drinkingDuration and state.drinkingDuration > 0
            and 100 / state.drinkingDuration or self.db.thirstRestore
        self.db.thirst = math.min(self.MAX_VALUE, self.db.thirst + rate * elapsed)
    end
end

function addon:RestoreNeeds(need, amount)
    if need == "hunger" or need == "both" then
        self.db.hunger = math.min(self.MAX_VALUE, self.db.hunger + amount)
    end
    if need == "thirst" or need == "both" then
        self.db.thirst = math.min(self.MAX_VALUE, self.db.thirst + amount)
    end
    self:UpdateDisplay()
end
