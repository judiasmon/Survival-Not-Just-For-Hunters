local addonName, addon = ...

local FATIGUE_DEPLETION_SECONDS = 8 * 60 * 60
local FATIGUE_RESTORATION_SECONDS = 5 * 60
local LOW_NEED_THRESHOLD = 25
local LOW_NEED_MAX_MULTIPLIER = 4

function addon:GetFatigueState()
    local restingAvailable = IsResting ~= nil
    local resting = restingAvailable and IsResting() or false
    local lowestNeed = math.min(self.db.hunger, self.db.thirst)
    local lowNeedMultiplier = 1

    if lowestNeed < LOW_NEED_THRESHOLD then
        lowNeedMultiplier = 1 + (LOW_NEED_MAX_MULTIPLIER - 1)
            * (LOW_NEED_THRESHOLD - math.max(0, lowestNeed))
            / LOW_NEED_THRESHOLD
    end

    return {
        resting = resting,
        restingAvailable = restingAvailable,
        recovering = resting,
        lowNeedMultiplier = lowNeedMultiplier,
        drainRate = 100 / FATIGUE_DEPLETION_SECONDS * lowNeedMultiplier,
        restorationRate = 100 / FATIGUE_RESTORATION_SECONDS,
    }
end

function addon:UpdateFatigue(elapsed, allowRestingRecovery)
    local state = self:GetFatigueState()
    local recover = allowRestingRecovery ~= false and state.resting
    if recover then
        self.db.fatigue = math.min(self.MAX_VALUE,
            self.db.fatigue + state.restorationRate * elapsed)
    else
        self.db.fatigue = math.max(0, self.db.fatigue - state.drainRate * elapsed)
    end

    state.recovering = recover
    self.fatigueState = state
end
