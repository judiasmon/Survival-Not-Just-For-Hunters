local addonName, addon = ...

local LOW_ENERGY_THRESHOLDS = { 10, 5, 0 }
local ZERO_NEED_SOUND_INTERVAL = 10

local noEnergySoundIds = {
    TaurenMale = 2567,
    UndeadFemale = 2570,
    DwarfMale = 2573,
    TrollMale = 2577,
}

local crySoundIds = {
    BloodElfFemale = 9647,
    BloodElfMale = 9651,
    DraeneiMale = 9701,
    DraeneiFemale = 9676,
    DwarfFemale = 6895,
    DwarfMale = 6901,
    GnomeMale = 6911,
    GnomeFemale = 6906,
    HumanFemale = 6916,
    HumanMale = 6921,
    NightElfFemale = 6926,
    NightElfMale = 6931,
    OrcFemale = 6936,
    OrcMale = 6941,
    UndeadFemale = 6967,
    UndeadMale = 6972,
    TaurenFemale = 6946,
    TaurenMale = 6951,
    TrollFemale = 6956,
}

local function getCharacterVoiceKey()
    if not UnitRace or not UnitSex then
        return nil, "Race or gender information is unavailable."
    end

    local _, race = UnitRace("player")
    local sex = UnitSex("player")
    if not race or (sex ~= 2 and sex ~= 3) then
        return nil, "Could not determine the player's race and gender."
    end

    race = string.gsub(race, "%s", "")
    if race == "Scourge" then
        race = "Undead"
    end
    return race .. (sex == 2 and "Male" or "Female")
end

local function playVoiceSound(soundId, soundName)
    if not PlaySound then
        return false, "PlaySound is unavailable."
    end
    if not soundId then
        return false, "No " .. soundName .. " sound ID is mapped for this race and gender."
    end

    if PlaySound(soundId) == false then
        return false, "Could not play " .. soundName .. " sound ID " .. soundId .. "."
    end
    return true
end

local function playCharacterSound(addon, soundIds, soundName)
    local voiceKey, errorMessage = getCharacterVoiceKey()
    if not voiceKey then
        addon.needFeedbackError = errorMessage
        return
    end

    local played, playError = playVoiceSound(soundIds[voiceKey], soundName)
    if not played then
        addon.needFeedbackError = playError
    else
        addon.needFeedbackError = nil
    end
end

function addon:ResetNeedFeedback()
    self.needFeedback = {
        thresholds = {
            hunger = {},
            thirst = {},
            fatigue = {},
        },
        zero = false,
        zeroElapsed = 0,
    }
end

function addon:UpdateNeedFeedback(elapsed)
    local feedback = self.needFeedback
    if not feedback then
        self:ResetNeedFeedback()
        feedback = self.needFeedback
    end

    local needs = {
        hunger = self.db.hunger,
        thirst = self.db.thirst,
        fatigue = self.db.fatigue,
    }
    local zero = false

    for name, value in pairs(needs) do
        local thresholds = feedback.thresholds[name]
        for _, threshold in ipairs(LOW_ENERGY_THRESHOLDS) do
            if value <= threshold then
                if not thresholds[threshold] then
                    thresholds[threshold] = true
                    playCharacterSound(self, noEnergySoundIds, "low-energy")
                end
            else
                thresholds[threshold] = false
            end
        end
        zero = zero or value <= 0
    end

    if not zero then
        feedback.zero = false
        feedback.zeroElapsed = 0
        return
    end

    if not feedback.zero then
        feedback.zero = true
        feedback.zeroElapsed = 0
        playCharacterSound(self, crySoundIds, "cry")
        return
    end

    feedback.zeroElapsed = feedback.zeroElapsed + elapsed
    if feedback.zeroElapsed >= ZERO_NEED_SOUND_INTERVAL then
        feedback.zeroElapsed = feedback.zeroElapsed % ZERO_NEED_SOUND_INTERVAL
        playCharacterSound(self, crySoundIds, "cry")
    end
end
