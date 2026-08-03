local ASR = require "AshurSkillRecovery/Core"
local RecoveryMath = ASR.Math

local Journal = {}
local MAX_RECIPES = 4096
local MAX_RECIPE_ID_LENGTH = 256
local logError = ASR.logError or function(...) print("[AshurSkillRecovery] ERROR:", ...) end

local function newJournalId(item)
    local stamp = getTimestampMs and getTimestampMs() or 0
    local random = ZombRand and ZombRand(1000000000) or 0
    return "ASR:" .. tostring(stamp) .. ":" .. tostring(random) .. ":" .. tostring(item:getID())
end

local function setJournalName(item, playerObj)
    local name = ASR.getPlayerDisplayName(playerObj)
    if name ~= "" and item.setName then
        local label = getText and getText("UI_ASR_JournalName", name) or ("Journal " .. name)
        pcall(function() item:setName(label) end)
    end
end

local function createData(item, playerObj)
    local modData = ASR.getItemModData(item)
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    if not modData or not ownerId then return nil end
    local data = {
        schemaVersion = ASR.SCHEMA_VERSION,
        journalId = newJournalId(item),
        ownerId = ownerId,
        ownerName = ASR.getPlayerDisplayName(playerObj),
        revision = 0,
        earnedXP = {},
        recipes = {},
    }
    modData[ASR.ITEM_DATA_KEY] = data
    setJournalName(item, playerObj)
    return data
end

local function migrateData(item, data, playerObj)
    if data.schemaVersion ~= 1 then return nil end
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    if not ownerId then return nil end
    data.schemaVersion = ASR.SCHEMA_VERSION
    data.journalId = type(data.journalId) == "string" and data.journalId or newJournalId(item)
    data.ownerId = ownerId
    data.ownerName = ASR.getPlayerDisplayName(playerObj)
    data.revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    setJournalName(item, playerObj)
    return data
end

local function canMutateJournal()
    return not (isClient and isClient())
end

local function validateData(item, allowCreate, playerObj)
    if not ASR.isJournal(item) then return nil, "UI_ASR_InvalidJournal" end
    local data = ASR.getJournalData(item)
    if not data and allowCreate then data = createData(item, playerObj) end
    if not data then return nil, "UI_ASR_EmptyJournal" end
    if data.schemaVersion == 1 and canMutateJournal() then
        data = migrateData(item, data, playerObj)
    end
    if not data then return nil, "UI_ASR_OwnerUnavailable" end
    if data.schemaVersion ~= 1 and data.schemaVersion ~= ASR.SCHEMA_VERSION then
        return nil, "UI_ASR_IncompatibleJournal"
    end
    if type(data.earnedXP) ~= "table" or type(data.recipes) ~= "table" then
        return nil, "UI_ASR_CorruptJournal"
    end
    return data, nil
end

local function validateOwner(playerObj, item, allowCreate)
    local data, reason = validateData(item, allowCreate, playerObj)
    if not data then return nil, reason end
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    if not ownerId then return nil, "UI_ASR_OwnerUnavailable" end
    if data.ownerId ~= ownerId then return nil, "UI_ASR_NotJournalOwner" end
    if canMutateJournal() then setJournalName(item, playerObj) end
    return data, nil
end

local function hasOtherOwnedJournal(playerObj, item)
    return ASR.hasOtherOwnedJournal and ASR.hasOtherOwnedJournal(playerObj, item) or false
end

local function earnedXP(playerObj)
    local earned = ASR.calculateEarnedXP(playerObj)
    if type(earned) ~= "table" then return nil, "UI_ASR_DataUnavailable" end
    return earned
end

local function earnedRecipes(playerObj)
    local earned = ASR.calculateEarnedRecipes(playerObj)
    if type(earned) ~= "table" then return nil, "UI_ASR_DataUnavailable" end
    return earned
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

local function restoreXP(playerObj, perk, amount)
    local addXP = ASR.addXpNoMultiplier or addXpNoMultiplier
    if type(addXP) ~= "function" then
        logError("Cannot restore XP: addXpNoMultiplier unavailable", perk:getId())
        return false
    end

    local before = ASR.getCurrentXP(playerObj, perk)
    local ok, err = pcall(addXP, playerObj, perk, amount)
    if not ok then
        logError("addXpNoMultiplier failed for perk", perk:getId(), err)
        return false
    end
    return ASR.getCurrentXP(playerObj, perk) > before
end

function Journal.previewWrite(playerObj, item)
    if not ASR.isJournal(item) then return nil, nil, "UI_ASR_InvalidJournal" end
    local existing = ASR.getJournalData(item)
    if existing then
        local _, reason = validateOwner(playerObj, item, false)
        if reason then return nil, nil, reason end
    elseif not ASR.getPlayerOwnerId(playerObj) then
        return nil, nil, "UI_ASR_OwnerUnavailable"
    elseif hasOtherOwnedJournal(playerObj, item) then
        return nil, nil, "UI_ASR_AlreadyHasJournal"
    end
    local saved = existing and type(existing.earnedXP) == "table" and existing.earnedXP or {}
    local savedRecipes = existing and type(existing.recipes) == "table" and existing.recipes or {}
    local skills = 0
    local recipes = 0
    local earnedXP, earnedReason = earnedXP(playerObj)
    if not earnedXP then return nil, nil, earnedReason end

    for perkId, amount in pairs(earnedXP) do
        if amount > (tonumber(saved[perkId]) or 0) then skills = skills + 1 end
    end
    if ASR.getOption("RecoverRecipes", true) == true then
        local earnedRecipeSet, recipeReason = earnedRecipes(playerObj)
        if not earnedRecipeSet then return nil, nil, recipeReason end
        for recipeId in pairs(earnedRecipeSet) do
            if savedRecipes[recipeId] ~= true then recipes = recipes + 1 end
        end
    end
    return skills, recipes
end

function Journal.previewRead(playerObj, item)
    local data, reason = validateOwner(playerObj, item, false)
    if not data then return nil, nil, nil, reason end
    local state = ASR.ensureBaseline(playerObj)
    if not state then return nil, nil, nil, "UI_ASR_DataUnavailable" end
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
    local skillChanges, recipeChanges, previewReason = Journal.previewWrite(playerObj, item)
    if skillChanges == nil then
        return { ok = false, reason = previewReason or "UI_ASR_DataUnavailable" }
    end
    if skillChanges == 0 and recipeChanges == 0 then
        return { ok = false, reason = "UI_ASR_NothingToWrite" }
    end

    if not ASR.getJournalData(item) and hasOtherOwnedJournal(playerObj, item) then
        return { ok = false, reason = "UI_ASR_AlreadyHasJournal" }
    end

    local data, reason = validateOwner(playerObj, item, true)
    if not data then return { ok = false, reason = reason } end

    local currentEarnedXP, earnedReason = earnedXP(playerObj)
    if not currentEarnedXP then return { ok = false, reason = earnedReason } end
    for perkId, amount in pairs(currentEarnedXP) do
        local perk = ASR.getPerk(perkId)
        local candidate = safeSavedXP(perk, amount)
        data.earnedXP[perkId] = RecoveryMath.mergeMaximum(data.earnedXP[perkId], candidate)
    end

    if ASR.getOption("RecoverRecipes", true) == true then
        local currentEarnedRecipes, recipeReason = earnedRecipes(playerObj)
        if not currentEarnedRecipes then return { ok = false, reason = recipeReason } end
        for recipeId in pairs(currentEarnedRecipes) do
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
    local data, reason = validateOwner(playerObj, item, false)
    if not data then return { ok = false, reason = reason } end

    local state = ASR.ensureBaseline(playerObj)
    if not state then return { ok = false, reason = "UI_ASR_DataUnavailable" } end
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
                if restoreXP(playerObj, perk, grant) then
                    changedSkills = changedSkills + 1
                    totalXP = totalXP + grant
                end
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
