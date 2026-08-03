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
    return value
end

local ASR = require "AshurSkillRecovery/Core"
local Journal = require "AshurSkillRecovery/Journal"

local function levelTestPlayer(initialXP, initialRecipes, username)
    local value = player(initialXP, initialRecipes, username)
    value.xpObject.getLevel = function(self) return value.xp.LevelProgress or 0 end
    return value
end

local levelPerk = perk("LevelProgress", false, 32775)

local levelSource = levelTestPlayer({ LevelProgress = 0 }, {}, "levelsource")
ASR.captureBaseline(levelSource)
levelSource.xp.LevelProgress = 2
assert(ASR.getPerkLevel(levelSource, levelPerk) == 2)

local source = player({ Strength = 225, Sprinting = 0 }, { StartingRecipe = true }, "source")
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

local second = player({ Strength = 0, Sprinting = 0 }, {}, "second")
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

local third = player({ Strength = 0, Sprinting = 0 }, {}, "third")
ASR.captureBaseline(third)
local thirdRead = Journal.read(third, item)
assert(thirdRead.ok == true)
assert(third.xp.Strength == 1050)
assert(third.xp.Sprinting == 400)
assert(third.recipes.LearnedFromItem == true)

local recipientWithOwnBonus = player({ Strength = 225, Sprinting = 0 }, {}, "bonus")
ASR.captureBaseline(recipientWithOwnBonus)
assert(Journal.read(recipientWithOwnBonus, item).ok == true)
assert(recipientWithOwnBonus.xp.Strength == 1275)

local levelSource = player({ LevelProgress = 0 }, {}, "levelsource")
ASR.captureBaseline(levelSource)
levelState.currentLevel = 2
levelSource.xp.LevelProgress = 1000
local earnedByLevel = ASR.calculateEarnedXP(levelSource)
assert(earnedByLevel.LevelProgress == 100)

local levelJournal = journal()
assert(Journal.write(levelSource, levelJournal).ok == true)

local levelRecipient = player({ LevelProgress = 0 }, {}, "levelrecipient")
ASR.captureBaseline(levelRecipient)
local levelRead = Journal.read(levelRecipient, levelJournal)
assert(levelRead.ok == true)
assert(levelRead.xp == 100)
assert(levelRecipient.xp.LevelProgress == 100)

print("journal integration: all tests passed")
