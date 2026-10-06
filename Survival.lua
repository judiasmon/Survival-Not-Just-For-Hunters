local addonName, addon = ...

local UPDATE_INTERVAL = 1

addon.MAX_VALUE = 100
addon.defaults = {
    hunger = addon.MAX_VALUE,
    thirst = addon.MAX_VALUE,
    fatigue = addon.MAX_VALUE,
    lastUpdate = 0,
    statsFoodEaten = 0,
    statsDrinksDrank = 0,
    statsTimeResting = 0,
    statsTimeHungry = 0,
    statsTimeThirsty = 0,
    statsLastAte = 0,
    statsLastDrank = 0,
    hungerDrain = 0.012,
    thirstDrain = 0.018,
    hungerRestore = 1,
    thirstRestore = 1.5,
    movementDrainMultiplier = 2,
    combatDrainMultiplier = 2,
    wellFedDrainMultiplier = 0.5,
    temperatureDrainPerLevel = 0.2,
    depletionEnabled = true,
    disableInInstances = true,
    barsShown = true,
    barX = 0,
    barY = -220,
    minimapAngle = 220,
}

function addon:InitializeDatabase()
    local database = SurvivalNotJustForHuntersDB
    if type(database) ~= "table" then
        database = {}
        SurvivalNotJustForHuntersDB = database
    end

    for key, value in pairs(self.defaults) do
        if database[key] == nil then
            database[key] = value
        end
    end
    self.db = database
end

function addon:GetInstanceState()
    if not IsInInstance then
        return {
            detectionAvailable = false,
            inInstance = false,
            instanceType = "unknown",
            disabled = false,
        }
    end

    local inInstance, instanceType = IsInInstance()
    local supportedInstance = instanceType == "party"
        or instanceType == "raid"
        or instanceType == "pvp"
        or instanceType == "arena"
    return {
        detectionAvailable = true,
        inInstance = inInstance and true or false,
        instanceType = instanceType or "none",
        disabled = self.db.disableInInstances and inInstance and supportedInstance or false,
    }
end

local function onEvent(_, event)
    if event == "PLAYER_LOGIN" then
        addon:InitializeDatabase()
        addon:UpdateTemperature()
        addon.instanceState = addon:GetInstanceState()
        local now = time()
        if addon.db.lastUpdate > 0 and not addon.instanceState.disabled then
            local offlineElapsed = math.max(0, now - addon.db.lastUpdate)
            addon:UpdateNeeds(offlineElapsed)
            addon:UpdateFatigue(offlineElapsed, false)
        end
        addon.db.lastUpdate = now
        if addon.instanceState.disabled then
            addon:ResetNeedFeedback()
            addon:ResetStatisticsActivity()
        else
            addon:UpdateNeedFeedback(0)
        end
        addon:CreateUI()
        addon:UpdateDisplay()
    elseif event == "PLAYER_DEAD" and addon.db then
        if not addon:GetInstanceState().disabled then
            addon.db.hunger = addon.MAX_VALUE
            addon.db.thirst = addon.MAX_VALUE
            addon:ResetNeedFeedback()
            addon:UpdateDisplay()
        end
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

    addon.instanceState = addon:GetInstanceState()
    if addon.instanceState.disabled then
        addon:ResetNeedFeedback()
        addon:ResetStatisticsActivity()
    else
        addon:UpdateTemperature()
        local consumptionState = addon:UpdateNeeds(self.elapsed)
        addon:UpdateFatigue(self.elapsed)
        addon:UpdateNeedFeedback(self.elapsed)
        addon:UpdateStatistics(self.elapsed, consumptionState)
    end
    addon.db.lastUpdate = time()
    self.elapsed = 0
    addon:UpdateDisplay()
end)
