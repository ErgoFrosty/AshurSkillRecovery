SandboxVars = {
    AshurSkillRecovery = {
        RecoveryPercentage = 100,
        RecoverRecipes = true,
        RecoverPassiveSkills = true,
    },
}

function isServer() return false end
function getTimestampMs() return 1000 end
function getTimestamp() return 1 end
function ZombRand() return 42 end
function addXpNoMultiplier(playerObj, targetPerk, amount)
    playerObj:getXp():AddXPNoMultiplier(targetPerk, amount)
end

local parent = { getId = function() return "PhysicalCategory" end }

local function perk(id, passive, maximum)
    return {
        getId = function() return id end,
        getParent = function() return parent end,
        isPassiv = function() return passive end,
        getTotalXpForLevel = function(_, level)
            if level == 10 then return maximum end
            return 0
        end,
    }
end

local strength = perk("Strength", true, 32775)
local sprinting = perk("Sprinting", false, 32775)
local levelState = { currentLevel = 1 }
local levelProgress = perk("LevelProgress", false, 32775)
levelProgress.getLevel = function() return levelState.currentLevel end
levelProgress.getTotalXpForLevel = function(_, level)
    if level == 10 then return 32775 end
    return level * 100
end
local perks = { strength, sprinting, levelProgress }

Perks = {
    getMaxIndex = function() return #perks end,
    fromIndex = function(index) return perks[index + 1] end,
}

local function javaList(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
    }
end

local function player(initialXP, initialRecipes, username)
    local value = {
        xp = initialXP or {},
        recipes = initialRecipes or {},
        modData = {},
        username = username or "tester",
    }
    value.xpObject = {
        getXP = function(_, targetPerk) return value.xp[targetPerk:getId()] or 0 end,
        AddXPNoMultiplier = function(_, targetPerk, amount)
            local id = targetPerk:getId()
            value.xp[id] = (value.xp[id] or 0) + amount
        end,
    }
    function value:getModData() return self.modData end
    function value:getXp() return self.xpObject end
    function value:getKnownRecipes()
        local result = {}
        for recipeId in pairs(self.recipes) do result[#result + 1] = recipeId end
        table.sort(result)
        return javaList(result)
    end
    function value:getHoursSurvived() return 0 end
    function value:getUsername() return self.username end
    function value:getFullName() return self.username end
    function value:isRecipeActuallyKnown(recipeId) return self.recipes[recipeId] == true end
    function value:learnRecipe(recipeId) self.recipes[recipeId] = true end
    return value
end

local function journal()
    local value = { modData = {} }
    function value:getFullType() return "AshurSkillRecovery.RecoveryJournal" end
    function value:getModData() return self.modData end
    function value:getID() return 7 end
    function value:setName(name) self.name = name end
    return value
end

local ASR = require "AshurSkillRecovery/Core"
local Journal = require "AshurSkillRecovery/Journal"
ASR.addXpNoMultiplier = addXpNoMultiplier

local emptyJournal = journal()
emptyJournal.modData.AshurSkillRecovery = {
    schemaVersion = ASR.SCHEMA_VERSION,
    earnedXP = {},
    recipes = {},
}
local savedNext = next
next = nil
assert(ASR.hasJournalContent(emptyJournal) == false)
emptyJournal.modData.AshurSkillRecovery.earnedXP.Strength = 1
assert(ASR.hasJournalContent(emptyJournal) == true)
emptyJournal.modData.AshurSkillRecovery.earnedXP = {}
emptyJournal.modData.AshurSkillRecovery.recipes.LearnedFromItem = true
assert(ASR.hasJournalContent(emptyJournal) == true)
next = savedNext

assert(ASR.getPerk("LevelProgress") == nil)

local source = player({ Strength = 225, Sprinting = 0 }, { StartingRecipe = true }, "owner")
ASR.captureBaseline(source)
source.xp.Strength = 1275
source.xp.Sprinting = 400
source.recipes.LearnedFromItem = true

local item = journal()
local writeResult = Journal.write(source, item)
assert(writeResult.ok == true)
assert(item.modData.AshurSkillRecovery.earnedXP.Strength == 1050)
assert(item.modData.AshurSkillRecovery.earnedXP.Sprinting == 400)
assert(item.modData.AshurSkillRecovery.recipes.LearnedFromItem == true)
assert(item.modData.AshurSkillRecovery.recipes.StartingRecipe == nil)

local second = player({ Strength = 0, Sprinting = 0 }, {}, "owner")
ASR.captureBaseline(second)
local firstRead = Journal.read(second, item)
assert(firstRead.ok == true)
assert(second.xp.Strength == 1050)
assert(second.xp.Sprinting == 400)
assert(second.recipes.LearnedFromItem == true)

local repeatedRead = Journal.read(second, item)
assert(repeatedRead.ok == false)
assert(repeatedRead.reason == "UI_ASR_NothingToRestore")
assert(second.xp.Strength == 1050)
assert(second.xp.Sprinting == 400)

local third = player({ Strength = 0, Sprinting = 0 }, {}, "owner")
ASR.captureBaseline(third)
local thirdRead = Journal.read(third, item)
assert(thirdRead.ok == true)
assert(third.xp.Strength == 1050)
assert(third.xp.Sprinting == 400)
assert(third.recipes.LearnedFromItem == true)

local failedRestore = player({ Strength = 0, Sprinting = 0 }, { LearnedFromItem = true }, "owner")
ASR.captureBaseline(failedRestore)
local savedAddXpNoMultiplier = addXpNoMultiplier
local savedASRAddXpNoMultiplier = ASR.addXpNoMultiplier
addXpNoMultiplier = nil
ASR.addXpNoMultiplier = nil
local failedResult = Journal.read(failedRestore, item)
assert(failedResult.ok == false)
assert(failedRestore.xp.Strength == 0)
addXpNoMultiplier = savedAddXpNoMultiplier
ASR.addXpNoMultiplier = savedASRAddXpNoMultiplier

local recipientWithOwnBonus = player({ Strength = 225, Sprinting = 0 }, {}, "owner")
ASR.captureBaseline(recipientWithOwnBonus)
assert(Journal.read(recipientWithOwnBonus, item).ok == true)
assert(recipientWithOwnBonus.xp.Strength == 1275)

local foreign = player({ Strength = 0, Sprinting = 0 }, {}, "foreign")
ASR.captureBaseline(foreign)
local foreignRead = Journal.read(foreign, item)
assert(foreignRead.ok == false)
assert(foreignRead.reason == "UI_ASR_NotJournalOwner")

local legacy = journal()
legacy.modData.AshurSkillRecovery = {
    schemaVersion = 1, earnedXP = { Strength = 100 }, recipes = {},
}
local legacyOwner = player({ Strength = 0 }, {}, "legacy-owner")
ASR.captureBaseline(legacyOwner)
assert(Journal.read(legacyOwner, legacy).ok == true)
assert(legacy.modData.AshurSkillRecovery.schemaVersion == ASR.SCHEMA_VERSION)
assert(legacy.modData.AshurSkillRecovery.ownerId == "username:legacy-owner")
assert(legacy.name == "Journal legacy-owner")

SandboxVars.AshurSkillRecovery.RecordStrength = false
assert(ASR.calculateEarnedXP(source).Strength == nil)
SandboxVars.AshurSkillRecovery.RecordStrength = true
SandboxVars.AshurSkillRecovery.RecoverStrength = false
assert(Journal.previewRead(second, item) == 0)
SandboxVars.AshurSkillRecovery.RecoverStrength = true

print("journal integration: all tests passed")
