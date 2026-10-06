local addonName, addon = ...

local zoneTemperatures = {
    ["Dun Morogh"] = -2,
    ["Winterspring"] = -2,
    ["Alterac Mountains"] = -1,
    ["Hillsbrad Foothills"] = -1,
    ["Western Plaguelands"] = -1,
    ["Eastern Plaguelands"] = -1,
    ["The Hinterlands"] = -1,
    ["The Barrens"] = 1,
    ["Tanaris"] = 2,
    ["Searing Gorge"] = 2,
    ["Burning Steppes"] = 2,
    ["Stranglethorn Vale"] = 2,
    ["Badlands"] = 1,
    ["Blasted Lands"] = 1,
    ["Un'Goro Crater"] = 1,
    ["Silithus"] = 1,
}

local subzoneTemperatures = {
    ["Dun Morogh"] = {
        ["Ironforge"] = 0,
    },
    ["Winterspring"] = {
        ["Everlook"] = -1,
    },
    ["The Barrens"] = {
        ["Ratchet"] = 1,
        ["The Crossroads"] = 1,
    },
    ["Tanaris"] = {
        ["Gadgetzan"] = 1,
        ["Steamwheedle Port"] = 1,
        ["Caverns of Time"] = 0,
    },
    ["Stranglethorn Vale"] = {
        ["Booty Bay"] = 1,
    },
}

function addon:UpdateTemperature()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    local subzone = GetSubZoneText and GetSubZoneText() or ""
    local indoors = IsIndoors and IsIndoors() or false
    local temperature = 0

    if not indoors then
        local overrides = subzoneTemperatures[zone]
        temperature = overrides and overrides[subzone]
            or zoneTemperatures[zone] or 0
    end

    self.temperature = {
        value = temperature,
        zone = zone,
        subzone = subzone,
        indoors = indoors,
        indoorDetectionAvailable = IsIndoors ~= nil,
    }
end

function addon:GetTemperatureState()
    if not self.temperature then
        self:UpdateTemperature()
    end
    return self.temperature
end
