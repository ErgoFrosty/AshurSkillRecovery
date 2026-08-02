AshurSkillRecovery = AshurSkillRecovery or {}

local ASR = AshurSkillRecovery
local RecoveryMath = require "AshurSkillRecovery/Math"

ASR.MODULE = "AshurSkillRecovery"
ASR.ITEM_FULL_TYPE = "AshurSkillRecovery.RecoveryJournal"
ASR.PLAYER_DATA_KEY = "AshurSkillRecovery"
ASR.ITEM_DATA_KEY = "AshurSkillRecovery"
ASR.SCHEMA_VERSION = 1
ASR.Math = RecoveryMath

local perkCache = nil

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

function ASR.isSupportedPerk(perk)
    if not perk or not perk.getId or not perk.getParent then return false end
    local parent = perk:getParent()
    return parent ~= nil and parent:getId() ~= "None"
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
    local value = playerObj:getXp():getXP(perk)
    if not ASR.isFiniteNumber(value) then return 0 end
    return math.max(0, value)
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
    local root = playerObj:getModData()
    local state = {
        schemaVersion = ASR.SCHEMA_VERSION,
        lifeId = newLifeId(playerObj),
        capturedAtHours = playerObj:getHoursSurvived() or 0,
        baselineXP = {},
        baselineRecipes = knownRecipeSet(playerObj),
    }

    for _, perk in ipairs(ASR.getPerks()) do
        state.baselineXP[perk:getId()] = ASR.getCurrentXP(playerObj, perk)
    end

    root[ASR.PLAYER_DATA_KEY] = state
    return state
end

function ASR.ensureBaseline(playerObj)
    if not playerObj then return nil end
    local root = playerObj:getModData()
    local state = root[ASR.PLAYER_DATA_KEY]
    if type(state) ~= "table"
        or state.schemaVersion ~= ASR.SCHEMA_VERSION
        or type(state.baselineXP) ~= "table" then
        state = ASR.captureBaseline(playerObj)
    end

    state.baselineRecipes = type(state.baselineRecipes) == "table"
        and state.baselineRecipes
        or knownRecipeSet(playerObj)

    -- A perk added by another mod after this life began is treated
    -- conservatively: its current XP becomes the baseline on first sight.
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
    if perk:isPassiv() and ASR.getOption("RecoverPassiveSkills", true) ~= true then
        return false
    end
    return true
end

function ASR.calculateEarnedXP(playerObj)
    local state = ASR.ensureBaseline(playerObj)
    local earned = {}
    for _, perk in ipairs(ASR.getPerks()) do
        if ASR.perkRecoveryEnabled(perk) then
            local perkId = perk:getId()
            local amount = RecoveryMath.earned(
                ASR.getCurrentXP(playerObj, perk),
                state.baselineXP[perkId]
            )
            if amount > 0 then earned[perkId] = amount end
        end
    end
    return earned
end

function ASR.calculateEarnedRecipes(playerObj)
    local state = ASR.ensureBaseline(playerObj)
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
    local value = item:getModData()[ASR.ITEM_DATA_KEY]
    return type(value) == "table" and value or nil
end

function ASR.hasJournalContent(item)
    local data = ASR.getJournalData(item)
    if not data or data.schemaVersion ~= ASR.SCHEMA_VERSION then return false end
    if type(data.earnedXP) == "table" and next(data.earnedXP) ~= nil then return true end
    return type(data.recipes) == "table" and next(data.recipes) ~= nil
end

return ASR
