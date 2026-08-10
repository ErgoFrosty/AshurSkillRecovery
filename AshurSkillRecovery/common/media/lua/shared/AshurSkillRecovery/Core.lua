AshurSkillRecovery = AshurSkillRecovery or {}

local ASR = AshurSkillRecovery
local RecoveryMath = require "AshurSkillRecovery/Math"

ASR.MODULE = "AshurSkillRecovery"
ASR.ITEM_FULL_TYPE = "AshurSkillRecovery.RecoveryJournal"
ASR.PLAYER_DATA_KEY = "AshurSkillRecovery"
ASR.ITEM_DATA_KEY = "AshurSkillRecovery"
ASR.SCHEMA_VERSION = 2
ASR.Math = RecoveryMath

function ASR.logError(...)
    print("[AshurSkillRecovery] ERROR:", ...)
end

local perkCache = nil

-- This is deliberately an allow-list of Build 42.20 vanilla skills. Skills
-- supplied by other mods are not journalled, even when they have a normal
-- Perk parent.
ASR.VANILLA_PERK_IDS = {
    Aiming = true, Axe = true, Blacksmith = true, Blunt = true, Butchering = true,
    Carving = true, Cooking = true, Doctor = true, Electricity = true,
    Farming = true, Fishing = true, Fitness = true, FlintKnapping = true,
    Glassmaking = true, Husbandry = true,
    Lightfoot = true, LongBlade = true, Maintenance = true, Masonry = true,
    Mechanics = true, MetalWelding = true, Nimble = true, PlantScavenging = true,
    Pottery = true, Reloading = true, SmallBlade = true, SmallBlunt = true,
    Sneak = true, Spear = true, Sprinting = true, Strength = true, Tailoring = true,
    Tracking = true, Trapping = true, Woodwork = true,
}

function ASR.isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function ASR.getOption(name, fallback)
    local page = SandboxVars and SandboxVars.AshurSkillRecovery
    if page and page[name] ~= nil then return page[name] end
    return fallback
end

function ASR.getItemModData(item)
    if not item or not item.getModData then return nil end
    local ok, data = pcall(function() return item:getModData() end)
    return ok and type(data) == "table" and data or nil
end

function ASR.getPlayerModData(playerObj)
    if not playerObj or not playerObj.getModData then return nil end
    local ok, data = pcall(function() return playerObj:getModData() end)
    return ok and type(data) == "table" and data or nil
end

function ASR.getPlayerOwnerId(playerObj)
    if not playerObj then return nil end
    local username = nil
    if playerObj.getUsername then
        local ok, value = pcall(function() return playerObj:getUsername() end)
        if ok and type(value) == "string" and value ~= "" then username = value end
    end
    if username then return "username:" .. username end
    if playerObj.getPlayerNum then
        local ok, number = pcall(function() return playerObj:getPlayerNum() end)
        if ok and ASR.isFiniteNumber(number) then return "local:" .. tostring(number) end
    end
    return nil
end

function ASR.getPlayerDisplayName(playerObj)
    if playerObj and playerObj.getFullName then
        local ok, value = pcall(function() return playerObj:getFullName() end)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return ""
end

function ASR.isSupportedPerk(perk)
    if not perk or not perk.getId or not perk.getParent then return false end
    local okId, perkId = pcall(function() return perk:getId() end)
    if not okId or ASR.VANILLA_PERK_IDS[perkId] ~= true then return false end
    local okParent, parent = pcall(function() return perk:getParent() end)
    if not okParent or not parent then return false end
    local okParentId, parentId = pcall(function() return parent:getId() end)
    return okParentId and parentId ~= "None"
end

function ASR.rebuildPerkCache()
    local byId = {}
    local ordered = {}
    for index = 0, Perks.getMaxIndex() - 1 do
        local perk = Perks.fromIndex(index)
        if ASR.isSupportedPerk(perk) then
            local perkId = perk:getId()
            byId[perkId] = perk
            ordered[#ordered + 1] = perk
        end
    end
    perkCache = { byId = byId, ordered = ordered }
    return perkCache
end

function ASR.getPerks()
    return (perkCache or ASR.rebuildPerkCache()).ordered
end

function ASR.getPerk(perkId)
    local cache = perkCache or ASR.rebuildPerkCache()
    local perk = cache.byId[perkId]
    if perk then return perk end
    return ASR.rebuildPerkCache().byId[perkId]
end

function ASR.getMaximumXP(perk)
    if not perk then return nil end
    local ok, maximum = pcall(function() return perk:getTotalXpForLevel(10) end)
    if not ok or not ASR.isFiniteNumber(maximum) or maximum <= 0 then return nil end
    return maximum
end

function ASR.getCurrentXP(playerObj, perk)
    if not playerObj or not perk then return 0 end
    local xp = playerObj.getXp and playerObj:getXp()
    if not xp or not xp.getXP then return 0 end
    local ok, value = pcall(function() return xp:getXP(perk) end)
    if not ok or not ASR.isFiniteNumber(value) then return 0 end
    return math.max(0, value)
end

local function javaStringSet(values)
    local result = {}
    if not values or not values.size or not values.get then return result end
    for index = 0, values:size() - 1 do
        local value = values:get(index)
        if type(value) == "string" and value ~= "" then
            result[value] = true
        end
    end
    return result
end

local function knownRecipeSet(playerObj)
    return javaStringSet(playerObj:getKnownRecipes())
end

function ASR.getReadRecipeMagazines(playerObj)
    if not playerObj or not playerObj.getAlreadyReadBook then return {} end
    local ok, values = pcall(function() return playerObj:getAlreadyReadBook() end)
    if not ok then return {} end
    -- Build 42 adds only completed literature with LearnedRecipes to this list.
    -- Skill books and their XP multipliers are tracked elsewhere and are not
    -- journalled by Ashur Skill Recovery.
    return javaStringSet(values)
end

local function newLifeId(playerObj)
    local stamp = getTimestampMs and getTimestampMs() or 0
    local random = ZombRand and ZombRand(1000000000) or 0
    local username = playerObj:getUsername() or "local"
    return tostring(username) .. ":" .. tostring(stamp) .. ":" .. tostring(random)
end

function ASR.captureBaseline(playerObj)
    local root = ASR.getPlayerModData(playerObj)
    if not root then return nil end
    local state = {
        schemaVersion = ASR.SCHEMA_VERSION,
        lifeId = newLifeId(playerObj),
        capturedAtHours = playerObj:getHoursSurvived() or 0,
        baselineXP = {},
        baselineRecipes = knownRecipeSet(playerObj),
    }

    for _, perk in ipairs(ASR.getPerks()) do
        local perkId = perk:getId()
        state.baselineXP[perkId] = ASR.getCurrentXP(playerObj, perk)
    end

    root[ASR.PLAYER_DATA_KEY] = state
    return state
end

function ASR.ensureBaseline(playerObj)
    if not playerObj then return nil end
    local root = ASR.getPlayerModData(playerObj)
    if not root then return nil end
    local state = root[ASR.PLAYER_DATA_KEY]
    if type(state) ~= "table"
        or type(state.baselineXP) ~= "table" then
        state = ASR.captureBaseline(playerObj)
    end
    if not state then return nil end
    state.schemaVersion = ASR.SCHEMA_VERSION

    state.baselineRecipes = type(state.baselineRecipes) == "table"
        and state.baselineRecipes
        or knownRecipeSet(playerObj)
    -- Missing entries (for example after a schema/game update) are initialized
    -- conservatively from the current XP instead of creating free progress.
    for _, perk in ipairs(ASR.getPerks()) do
        local perkId = perk:getId()
        if not ASR.isFiniteNumber(state.baselineXP[perkId]) then
            state.baselineXP[perkId] = ASR.getCurrentXP(playerObj, perk)
        end
    end
    return state
end

function ASR.recoveryFraction()
    local percentage = tonumber(ASR.getOption("RecoveryPercentage", 100)) or 100
    return RecoveryMath.clamp(percentage / 100, 0, 1)
end

function ASR.perkRecoveryEnabled(perk)
    if not perk then return false end
    local perkId = perk:getId()
    return ASR.getOption("Enable" .. perkId, true) == true
end

function ASR.perkRecordingEnabled(perk)
    if not perk then return false end
    local perkId = perk:getId()
    return ASR.getOption("Enable" .. perkId, true) == true
end

function ASR.calculateEarnedXP(playerObj)
    local state = ASR.ensureBaseline(playerObj)
    if not state then return nil end
    local earned = {}
    for _, perk in ipairs(ASR.getPerks()) do
        if ASR.perkRecordingEnabled(perk) then
            local perkId = perk:getId()
            local baselineXP = state.baselineXP[perkId]
            local currentXP = ASR.getCurrentXP(playerObj, perk)
            local amount = RecoveryMath.earned(currentXP, baselineXP)

            if amount > 0 then earned[perkId] = amount end
        end
    end
    return earned
end

function ASR.calculateEarnedRecipes(playerObj)
    local state = ASR.ensureBaseline(playerObj)
    if not state then return nil end
    local current = knownRecipeSet(playerObj)
    local earned = {}
    for recipeId in pairs(current) do
        if state.baselineRecipes[recipeId] ~= true then earned[recipeId] = true end
    end
    return earned
end

function ASR.isJournal(item)
    return item ~= nil and item:getFullType() == ASR.ITEM_FULL_TYPE
end

function ASR.getJournalData(item)
    if not ASR.isJournal(item) then return nil end
    local modData = ASR.getItemModData(item)
    if not modData then return nil end
    local value = modData[ASR.ITEM_DATA_KEY]
    return type(value) == "table" and value or nil
end

local function hasEntries(value)
    for _ in pairs(value) do return true end
    return false
end

function ASR.hasJournalContent(item)
    local data = ASR.getJournalData(item)
    if not data or data.schemaVersion ~= ASR.SCHEMA_VERSION then return false end
    if type(data.earnedXP) == "table" and hasEntries(data.earnedXP) then return true end
    if type(data.recipes) == "table" and hasEntries(data.recipes) then return true end
    return type(data.readRecipeMagazines) == "table" and hasEntries(data.readRecipeMagazines)
end

return ASR
