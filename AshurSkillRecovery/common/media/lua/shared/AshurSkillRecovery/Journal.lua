local ASR = require "AshurSkillRecovery/Core"
local RecoveryMath = ASR.Math

local Journal = {}
local MAX_RECIPES = 4096
local MAX_RECIPE_ID_LENGTH = 256

local function newJournalId(item)
    local stamp = getTimestampMs and getTimestampMs() or 0
    local random = ZombRand and ZombRand(1000000000) or 0
    return "ASR:" .. tostring(stamp) .. ":" .. tostring(random) .. ":" .. tostring(item:getID())
end

local function createData(item)
    local data = {
        schemaVersion = ASR.SCHEMA_VERSION,
        journalId = newJournalId(item),
        revision = 0,
        earnedXP = {},
        recipes = {},
    }
    item:getModData()[ASR.ITEM_DATA_KEY] = data
    return data
end

local function validateData(item, allowCreate)
    if not ASR.isJournal(item) then return nil, "UI_ASR_InvalidJournal" end
    local data = ASR.getJournalData(item)
    if not data and allowCreate then data = createData(item) end
    if not data then return nil, "UI_ASR_EmptyJournal" end
    if data.schemaVersion ~= ASR.SCHEMA_VERSION then
        return nil, "UI_ASR_IncompatibleJournal"
    end
    if type(data.earnedXP) ~= "table" or type(data.recipes) ~= "table" then
        return nil, "UI_ASR_CorruptJournal"
    end
    return data, nil
end

local function syncJournal(playerObj, item)
    if isServer() then syncItemModData(playerObj, item) end
end

local function safeSavedXP(perk, value)
    if not ASR.isFiniteNumber(value) or value <= 0 then return 0 end
    local maximum = ASR.getMaximumXP(perk)
    if maximum then return math.min(value, maximum) end
    return value
end

function Journal.previewWrite(playerObj, item)
    local existing = ASR.getJournalData(item)
    local saved = existing and type(existing.earnedXP) == "table" and existing.earnedXP or {}
    local savedRecipes = existing and type(existing.recipes) == "table" and existing.recipes or {}
    local skills = 0
    local recipes = 0

    for perkId, amount in pairs(ASR.calculateEarnedXP(playerObj)) do
        if amount > (tonumber(saved[perkId]) or 0) then skills = skills + 1 end
    end
    if ASR.getOption("RecoverRecipes", true) == true then
        for recipeId in pairs(ASR.calculateEarnedRecipes(playerObj)) do
            if savedRecipes[recipeId] ~= true then recipes = recipes + 1 end
        end
    end
    return skills, recipes
end

function Journal.previewRead(playerObj, item)
    local data = ASR.getJournalData(item)
    if not data or type(data.earnedXP) ~= "table" then return 0, 0, 0 end
    local state = ASR.ensureBaseline(playerObj)
    local fraction = ASR.recoveryFraction()
    local skills = 0
    local totalXP = 0

    for perkId, stored in pairs(data.earnedXP) do
        local perk = ASR.getPerk(perkId)
        if perk and ASR.perkRecoveryEnabled(perk) then
            local saved = safeSavedXP(perk, stored)
            local target = RecoveryMath.target(
                state.baselineXP[perkId] or 0,
                saved,
                fraction,
                ASR.getMaximumXP(perk)
            )
            local grant = RecoveryMath.grant(ASR.getCurrentXP(playerObj, perk), target)
            if grant > 0 then
                skills = skills + 1
                totalXP = totalXP + grant
            end
        end
    end

    local recipes = 0
    if ASR.getOption("RecoverRecipes", true) == true and type(data.recipes) == "table" then
        for recipeId, recorded in pairs(data.recipes) do
            if recorded == true and type(recipeId) == "string"
                and not playerObj:isRecipeActuallyKnown(recipeId) then
                recipes = recipes + 1
            end
        end
    end
    return skills, recipes, totalXP
end

function Journal.write(playerObj, item)
    local skillChanges, recipeChanges = Journal.previewWrite(playerObj, item)
    if skillChanges == 0 and recipeChanges == 0 then
        return { ok = false, reason = "UI_ASR_NothingToWrite" }
    end

    local data, reason = validateData(item, true)
    if not data then return { ok = false, reason = reason } end

    for perkId, amount in pairs(ASR.calculateEarnedXP(playerObj)) do
        local perk = ASR.getPerk(perkId)
        local candidate = safeSavedXP(perk, amount)
        data.earnedXP[perkId] = RecoveryMath.mergeMaximum(data.earnedXP[perkId], candidate)
    end

    if ASR.getOption("RecoverRecipes", true) == true then
        for recipeId in pairs(ASR.calculateEarnedRecipes(playerObj)) do
            if type(recipeId) == "string" and #recipeId <= MAX_RECIPE_ID_LENGTH then
                data.recipes[recipeId] = true
            end
        end
    end

    data.revision = math.max(0, math.floor(tonumber(data.revision) or 0)) + 1
    data.author = playerObj:getFullName()
    data.updatedAt = getTimestamp and getTimestamp() or 0
    syncJournal(playerObj, item)

    return {
        ok = true,
        skills = skillChanges,
        recipes = recipeChanges,
        revision = data.revision,
    }
end

function Journal.read(playerObj, item)
    local data, reason = validateData(item, false)
    if not data then return { ok = false, reason = reason } end

    local state = ASR.ensureBaseline(playerObj)
    local fraction = ASR.recoveryFraction()
    local changedSkills = 0
    local totalXP = 0

    for perkId, stored in pairs(data.earnedXP) do
        local perk = ASR.getPerk(perkId)
        if perk and ASR.perkRecoveryEnabled(perk) then
            local target = RecoveryMath.target(
                state.baselineXP[perkId] or 0,
                safeSavedXP(perk, stored),
                fraction,
                ASR.getMaximumXP(perk)
            )
            local grant = RecoveryMath.grant(ASR.getCurrentXP(playerObj, perk), target)
            if grant > 0 then
                playerObj:getXp():AddXPNoMultiplier(perk, grant)
                changedSkills = changedSkills + 1
                totalXP = totalXP + grant
            end
        end
    end

    local learnedRecipes = 0
    if ASR.getOption("RecoverRecipes", true) == true then
        local inspected = 0
        for recipeId, recorded in pairs(data.recipes) do
            inspected = inspected + 1
            if inspected > MAX_RECIPES then break end
            if recorded == true and type(recipeId) == "string"
                and #recipeId <= MAX_RECIPE_ID_LENGTH
                and not playerObj:isRecipeActuallyKnown(recipeId) then
                playerObj:learnRecipe(recipeId)
                learnedRecipes = learnedRecipes + 1
            end
        end
    end

    if changedSkills == 0 and learnedRecipes == 0 then
        return { ok = false, reason = "UI_ASR_NothingToRestore" }
    end

    return {
        ok = true,
        skills = changedSkills,
        recipes = learnedRecipes,
        xp = totalXP,
    }
end

return Journal
