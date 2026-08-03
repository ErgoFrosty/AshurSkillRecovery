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

-- This is deliberately an allow-list.  Skills supplied by other mods are not
-- journalled, even when they have a normal Perk parent.
ASR.VANILLA_PERK_IDS = {
    Aiming = true, Axe = true, Blacksmith = true, Blunt = true, Butchering = true,
    Carving = true, Carpentry = true, Cooking = true, Electricity = true,
    Farming = true, FirstAid = true, Fishing = true, Fitness = true,
    FlintKnapping = true, Foraging = true, Glassmaking = true, Husbandry = true,
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

function ASR.getPerkLevel(playerObj, perk)
    if not playerObj or not perk then return nil end
    local xp = playerObj and playerObj.getXp and playerObj:getXp()
    if not xp then return nil end

    local function tryGetter(fn)
        if not fn then return nil end
        local ok, value = pcall(fn)
        if ok and ASR.isFiniteNumber(value) then
            return value
        end
        return nil
    end

    local getters = {
        function()
            if perk.getLevel then
                return tryGetter(function() return perk:getLevel() end)
                    or tryGetter(function() return perk:getLevel(playerObj) end)
            end
            return nil
        end,
        function()
            if xp.getPerkLevel then
                return tryGetter(function() return xp:getPerkLevel(perk) end)
            end
            return nil
        end,
        function()
            if xp.getLevel then
                return tryGetter(function() return xp:getLevel() end)
                    or tryGetter(function() return xp:getLevel(perk) end)
            end
            return nil
        end,
        function()
            if xp.getXpLevel then
                return tryGetter(function() return xp:getXpLevel(perk) end)
            end
            return nil
        end,
    }

    for _, getter in ipairs(getters) do
        local value = getter()
        if ASR.isFiniteNumber(value) then
            return math.max(0, math.floor(value))
        end
    end
    return nil
end

function ASR.getLevelXP(perk, level)
    if not perk then return nil end
    local resolvedLevel = math.max(0, math.floor(tonumber(level) or 0))
    local ok, total = pcall(function() return perk:getTotalXpForLevel(resolvedLevel) end)
    if not ok or not ASR.isFiniteNumber(total) then return nil end
    return math.max(0, total)
end

local function knownRecipeSet(playerObj)
    local recipes = {}
    local known = playerObj:getKnownRecipes()
    if not known then return recipes end
    for index = 0, known:size() - 1 do
        local recipeId = known:get(index)
        if type(recipeId) == "string" and recipeId ~= "" then
            recipes[recipeId] = true
        end
    end
    return recipes
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
        baselineLevels = {},
        baselineRecipes = knownRecipeSet(playerObj),
    }

    for _, perk in ipairs(ASR.getPerks()) do
        local perkId = perk:getId()
        state.baselineXP[perkId] = ASR.getCurrentXP(playerObj, perk)
        state.baselineLevels[perkId] = ASR.getPerkLevel(playerObj, perk)
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
    state.baselineLevels = type(state.baselineLevels) == "table"
        and state.baselineLevels
        or {}

    -- A perk added by another mod after this life began is treated
    -- conservatively: its current XP becomes the baseline on first sight.
    for _, perk in ipairs(ASR.getPerks()) do
        local perkId = perk:getId()
        if not ASR.isFiniteNumber(state.baselineXP[perkId]) then
            state.baselineXP[perkId] = ASR.getCurrentXP(playerObj, perk)
        end
        if not ASR.isFiniteNumber(state.baselineLevels[perkId]) then
            state.baselineLevels[perkId] = ASR.getPerkLevel(playerObj, perk)
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
    if perkId == "Fitness" or perkId == "Strength" then
        return ASR.getOption("RecoverPassiveSkills", true) == true
    end
    return ASR.getOption("Recover" .. perkId, true) == true
end

function ASR.perkRecordingEnabled(perk)
    if not perk then return false end
    local perkId = perk:getId()
    if perkId == "Fitness" or perkId == "Strength" then
        return ASR.getOption("RecoverPassiveSkills", true) == true
    end
    return ASR.getOption("Record" .. perkId, true) == true
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
            local baselineLevel = state.baselineLevels[perkId]
            local currentLevel = ASR.getPerkLevel(playerObj, perk)
            local amount = nil

            if ASR.isFiniteNumber(currentLevel) and ASR.isFiniteNumber(baselineLevel)
                and currentLevel > baselineLevel then
                local baselineThreshold = ASR.getLevelXP(perk, baselineLevel)
                local currentThreshold = ASR.getLevelXP(perk, currentLevel)
                if ASR.isFiniteNumber(baselineThreshold) and ASR.isFiniteNumber(currentThreshold) then
                    amount = math.max(0, currentThreshold - baselineThreshold)
                end
            end

            if not ASR.isFiniteNumber(amount) then
                amount = RecoveryMath.earned(currentXP, baselineXP)
            end

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
    return type(data.recipes) == "table" and hasEntries(data.recipes)
end

return ASR
