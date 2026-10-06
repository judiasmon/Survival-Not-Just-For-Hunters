local addonName, addon = ...

local UPDATE_INTERVAL = 1

addon.MAX_VALUE = 100
addon.defaults = {
    hunger = addon.MAX_VALUE,
    thirst = addon.MAX_VALUE,
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

local function onEvent(_, event)
    if event == "PLAYER_LOGIN" then
        addon:InitializeDatabase()
        local now = time()
        if addon.db.lastUpdate > 0 then
            addon:UpdateNeeds(math.max(0, now - addon.db.lastUpdate))
        end
        addon.db.lastUpdate = now
        addon:CreateUI()
        addon:UpdateDisplay()
    elseif event == "PLAYER_DEAD" and addon.db then
        addon.db.hunger = addon.MAX_VALUE
        addon.db.thirst = addon.MAX_VALUE
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

    addon:UpdateNeeds(self.elapsed)
    addon.db.lastUpdate = time()
    self.elapsed = 0
    addon:UpdateDisplay()
end)
