local addonName, addon = ...

local LOW_NEED_THRESHOLD = 25

function addon:UpdateStatistics(elapsed, consumptionState)
    local current = consumptionState or self:GetConsumptionState()
    local activity = self.statisticsActivity
    local now = time()

    if not activity then
        activity = {
            eating = current.eating,
            drinking = current.drinking,
        }
        self.statisticsActivity = activity
    else
        if current.eating and not activity.eating then
            self.db.statsFoodEaten = self.db.statsFoodEaten + 1
            self.db.statsLastAte = now
        end
        if current.drinking and not activity.drinking then
            self.db.statsDrinksDrank = self.db.statsDrinksDrank + 1
            self.db.statsLastDrank = now
        end
        activity.eating = current.eating
        activity.drinking = current.drinking
    end

    if self.db.hunger < LOW_NEED_THRESHOLD then
        self.db.statsTimeHungry = self.db.statsTimeHungry + elapsed
    end
    if self.db.thirst < LOW_NEED_THRESHOLD then
        self.db.statsTimeThirsty = self.db.statsTimeThirsty + elapsed
    end
    if IsResting and IsResting() then
        self.db.statsTimeResting = self.db.statsTimeResting + elapsed
    end
end

function addon:ResetStatisticsActivity()
    self.statisticsActivity = nil
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return string.format("%d hr %02d min", hours, minutes)
end

local function formatTimestamp(timestamp)
    if not timestamp or timestamp <= 0 then
        return "Never"
    end
    return date("%Y-%m-%d %H:%M", timestamp)
end

function addon:GetStatisticsText()
    return {
        string.format("Food eaten: %d", self.db.statsFoodEaten),
        string.format("Drinks drank: %d", self.db.statsDrinksDrank),
        string.format("Time resting: %s", formatDuration(self.db.statsTimeResting)),
        string.format("Time hungry (<25%%): %s", formatDuration(self.db.statsTimeHungry)),
        string.format("Time thirsty (<25%%): %s", formatDuration(self.db.statsTimeThirsty)),
        string.format("Last ate: %s", formatTimestamp(self.db.statsLastAte)),
        string.format("Last drank: %s", formatTimestamp(self.db.statsLastDrank)),
    }
end
