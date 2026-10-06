local addonName, addon = ...

local MAX_VALUE = 100
local UPDATE_INTERVAL = 1

addon.defaults = {
    hunger = MAX_VALUE,
    thirst = MAX_VALUE,
    lastUpdate = 0,
    hungerDrain = 0.012,
    thirstDrain = 0.018,
    depletionEnabled = true,
    barsShown = true,
    barX = 0,
    barY = -220,
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
    if not addon.db.depletionEnabled then
        return
    end

    addon.db.hunger = math.max(0, addon.db.hunger - addon.db.hungerDrain * elapsed)
    addon.db.thirst = math.max(0, addon.db.thirst - addon.db.thirstDrain * elapsed)
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

local function classifyConsumable(itemLink)
    if not itemLink then
        return nil
    end

    local itemName, itemType, itemSubType = GetItemInfo(itemLink)
    local classID, subclassID
    if GetItemInfoInstant then
        local itemData = { GetItemInfoInstant(itemLink) }
        classID, subclassID = itemData[6], itemData[7]
    end
    local foodDrinkSubType = GetItemSubClassInfo and GetItemSubClassInfo(0, 5)
    local isFoodOrDrink = (classID == 0 and subclassID == 5)
        or (foodDrinkSubType and itemSubType == foodDrinkSubType)

    if not isFoodOrDrink then
        local consumableType = GetItemClassInfo and GetItemClassInfo(0) or "Consumable"
        local subTypeName = string.lower(itemSubType or "")
        isFoodOrDrink = itemType == consumableType
            and (subTypeName:find("food", 1, true) or subTypeName:find("drink", 1, true))
    end
    if not isFoodOrDrink then
        return nil
    end

    local itemSpellName = GetItemSpell and GetItemSpell(itemLink)
    local drinkSpellName = GetSpellInfo and GetSpellInfo(430)
    local foodSpellName = GetSpellInfo and GetSpellInfo(433)
    if itemSpellName and drinkSpellName and itemSpellName == drinkSpellName then
        return "thirst"
    elseif itemSpellName and foodSpellName and itemSpellName == foodSpellName then
        return "hunger"
    end

    local name = string.lower(itemName or "")
    local isDrink = name:find("drink", 1, true)
        or name:find("water", 1, true)
        or name:find("beverage", 1, true)
        or name:find("juice", 1, true)
    local isFood = name:find("bread", 1, true)
        or name:find("meat", 1, true)
        or name:find("fish", 1, true)
        or name:find("fruit", 1, true)
        or name:find("cheese", 1, true)
        or name:find("steak", 1, true)
        or name:find("roast", 1, true)
        or name:find("sausage", 1, true)
        or name:find("egg", 1, true)
        or name:find("jerky", 1, true)
        or name:find("dumpling", 1, true)
        or name:find("biscuit", 1, true)
        or name:find("pie", 1, true)
        or name:find("stew", 1, true)
        or name:find("cake", 1, true)
        or name:find("berry", 1, true)

    if isDrink and not isFood then
        return "thirst"
    elseif isFood and not isDrink then
        return "hunger"
    end

    -- Some locales and item names do not identify which need is restored.
    return "both"
end

local function getContainerItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
end

local function onUseContainerItem(bag, slot)
    local itemLink = getContainerItemLink(bag, slot)
    local need = classifyConsumable(itemLink)
    if need then
        addon:RestoreNeeds(need, 25)
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

if hooksecurefunc then
    if C_Container and C_Container.UseContainerItem then
        hooksecurefunc(C_Container, "UseContainerItem", onUseContainerItem)
    elseif UseContainerItem then
        hooksecurefunc("UseContainerItem", onUseContainerItem)
    end
end
