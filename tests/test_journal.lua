SandboxVars = {
    AshurSkillRecovery = {
        RecoveryPercentage = 100,
        RecoverRecipes = true,
        EnableFitness = true,
        EnableStrength = true,
    },
}

local serverMode = false
function isServer() return serverMode end
function isClient() return false end
function getTimestampMs() return 1000 end
function getTimestamp() return 1 end
function ZombRand() return 42 end
function addXpNoMultiplier(playerObj, targetPerk, amount)
    playerObj:getXp():AddXPNoMultiplier(targetPerk, amount)
end
function syncItemModData() end
local syncPlayerFieldCalls = {}
function sendSyncPlayerFields(playerObj, mask)
    syncPlayerFieldCalls[#syncPlayerFieldCalls + 1] = { player = playerObj, mask = mask }
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

local fitness = perk("Fitness", true, 32775)
local strength = perk("Strength", true, 32775)
local sprinting = perk("Sprinting", false, 32775)
local levelProgress = perk("LevelProgress", false, 32775)
local perks = { fitness, strength, sprinting, levelProgress }

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

local function javaStringSet(values)
    local function ordered()
        local result = {}
        for value in pairs(values) do result[#result + 1] = value end
        table.sort(result)
        return result
    end
    return {
        size = function() return #ordered() end,
        get = function(_, index) return ordered()[index + 1] end,
        contains = function(_, value) return values[value] == true end,
        add = function(_, value) values[value] = true end,
    }
end

local function player(initialXP, initialRecipes, username, initialReadRecipeMagazines)
    local value = {
        xp = initialXP or {},
        recipes = initialRecipes or {},
        readRecipeMagazines = initialReadRecipeMagazines or {},
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
    function value:getAlreadyReadBook() return javaStringSet(self.readRecipeMagazines) end
    function value:getHoursSurvived() return 0 end
    function value:getUsername() return self.username end
    function value:getFullName() return self.username end
    function value:getPlayerNum() return 0 end
    function value:isDead() return false end
    function value:isAsleep() return false end
    function value:hasTrait() return false end
    function value:isRecipeActuallyKnown(recipeId) return self.recipes[recipeId] == true end
    function value:learnRecipe(recipeId) self.recipes[recipeId] = true end
    return value
end

local nextItemId = 7
local function journal()
    local value = { modData = {}, id = nextItemId }
    nextItemId = nextItemId + 1
    function value:getFullType() return "AshurSkillRecovery.RecoveryJournal" end
    function value:getModData() return self.modData end
    function value:getID() return self.id end
    function value:getContainer() return self.container end
    function value:setName(name) self.name = name end
    function value:setCustomName(value) self.customName = value end
    function value:syncItemFields() self.syncCount = (self.syncCount or 0) + 1 end
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
    readRecipeMagazines = {},
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
source.readRecipeMagazines["Base.MechanicMag1"] = true

local item = journal()
local writeResult = Journal.write(source, item)
assert(writeResult.ok == true)
assert(item.modData.AshurSkillRecovery.customName == "Recovery Journal")
assert(item.name == "Recovery Journal")
assert(item.customName == true)
assert(item.modData.AshurSkillRecovery.earnedXP.Strength == 1050)
assert(item.modData.AshurSkillRecovery.earnedXP.Sprinting == 400)
assert(item.modData.AshurSkillRecovery.recipes.LearnedFromItem == true)
assert(item.modData.AshurSkillRecovery.recipes.StartingRecipe == nil)
assert(item.modData.AshurSkillRecovery.readRecipeMagazines["Base.MechanicMag1"] == true)
assert(writeResult.magazines == 1)

local exactSource = player({ Strength = 225 }, {}, "owner")
ASR.captureBaseline(exactSource)
exactSource.xp.Strength = 1300
assert(ASR.calculateEarnedXP(exactSource).Strength == 1075)

local second = player({ Strength = 0, Sprinting = 0 }, {}, "owner")
ASR.captureBaseline(second)
local firstRead = Journal.read(second, item)
assert(firstRead.ok == true)
assert(second.xp.Strength == 1050)
assert(second.xp.Sprinting == 400)
assert(second.recipes.LearnedFromItem == true)
assert(second.readRecipeMagazines["Base.MechanicMag1"] == true)
assert(firstRead.magazines == 1)
assert(syncPlayerFieldCalls[#syncPlayerFieldCalls].mask == 0x00000005)

local repeatedRead = Journal.read(second, item)
assert(repeatedRead.ok == false)
assert(repeatedRead.reason == "UI_ASR_NothingToRestore")
assert(second.xp.Strength == 1050)
assert(second.xp.Sprinting == 400)
assert(repeatedRead.magazines == nil)

local third = player({ Strength = 0, Sprinting = 0 }, {}, "owner")
ASR.captureBaseline(third)
local thirdRead = Journal.read(third, item)
assert(thirdRead.ok == true)
assert(third.xp.Strength == 1050)
assert(third.xp.Sprinting == 400)
assert(third.recipes.LearnedFromItem == true)
assert(third.readRecipeMagazines["Base.MechanicMag1"] == true)

local failedRestore = player(
    { Strength = 0, Sprinting = 0 },
    { LearnedFromItem = true },
    "owner",
    { ["Base.MechanicMag1"] = true }
)
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

local magazineOnlySource = player({ Strength = 0 }, { StartingRecipe = true }, "owner")
ASR.captureBaseline(magazineOnlySource)
magazineOnlySource.readRecipeMagazines["Base.MechanicMag1"] = true
local magazineOnlyJournal = journal()
local magazineOnlyWrite = Journal.write(magazineOnlySource, magazineOnlyJournal)
assert(magazineOnlyWrite.ok == true)
assert(magazineOnlyWrite.skills == 0)
assert(magazineOnlyWrite.recipes == 0)
assert(magazineOnlyWrite.magazines == 1)
local magazineOnlyRecipient = player({ Strength = 0 }, { StartingRecipe = true }, "owner")
ASR.captureBaseline(magazineOnlyRecipient)
local magazineOnlyRead = Journal.read(magazineOnlyRecipient, magazineOnlyJournal)
assert(magazineOnlyRead.ok == true)
assert(magazineOnlyRead.recipes == 0)
assert(magazineOnlyRead.magazines == 1)
assert(magazineOnlyRecipient.readRecipeMagazines["Base.MechanicMag1"] == true)
assert(syncPlayerFieldCalls[#syncPlayerFieldCalls].mask == 0x00000004)

local foreign = player({ Strength = 0, Sprinting = 0 }, {}, "foreign")
ASR.captureBaseline(foreign)
local foreignRead = Journal.read(foreign, item)
assert(foreignRead.ok == false)
assert(foreignRead.reason == "UI_ASR_NotJournalOwner")

local legacy = journal()
legacy.modData.AshurSkillRecovery = {
    schemaVersion = 1, customName = "Старый дневник", earnedXP = { Strength = 100 }, recipes = {},
}
local legacyOwner = player({ Strength = 0 }, {}, "legacy-owner")
ASR.captureBaseline(legacyOwner)
assert(Journal.read(legacyOwner, legacy).ok == true)
assert(legacy.modData.AshurSkillRecovery.schemaVersion == ASR.SCHEMA_VERSION)
assert(legacy.modData.AshurSkillRecovery.ownerId == "username:legacy-owner")
assert(legacy.modData.AshurSkillRecovery.customName == "Старый дневник")
assert(legacy.name == "Старый дневник")

local previousDevJournal = journal()
previousDevJournal.modData.AshurSkillRecovery = {
    schemaVersion = ASR.SCHEMA_VERSION,
    journalId = "ASR:previous-dev",
    ownerId = "username:previous-dev-owner",
    ownerName = "previous-dev-owner",
    customName = "Дневник 0.2.0-dev",
    revision = 1,
    earnedXP = {},
    recipes = { LegacyRecipe = true },
}
local previousDevOwner = player({ Strength = 0 }, {}, "previous-dev-owner")
ASR.captureBaseline(previousDevOwner)
local previousDevRead = Journal.read(previousDevOwner, previousDevJournal)
assert(previousDevRead.ok == true)
assert(previousDevOwner.recipes.LegacyRecipe == true)
assert(type(previousDevJournal.modData.AshurSkillRecovery.readRecipeMagazines) == "table")
assert(syncPlayerFieldCalls[#syncPlayerFieldCalls].mask == 0x00000001)

CharacterTrait = { ILLITERATE = "Illiterate" }
Events = { OnClientCommand = { Add = function() end } }
local Server = require "AshurSkillRecovery/Server"

local function inventory(items)
    local value = { items = items }
    local list = {
        size = function() return #items end,
        get = function(_, index) return items[index + 1] end,
    }
    function value:getItems() return list end
    function value:getItemWithIDRecursiv(id)
        for _, item in ipairs(items) do
            if item:getID() == id then return item end
        end
        return nil
    end
    return value
end

local owner = player({ Strength = 0 }, {}, "owner")
ASR.captureBaseline(owner)
owner.xp.Strength = 100
local secondJournal = journal()
local craftedJournal = journal()
local craftRecipeData = {
    getFirstCreatedItem = function() return craftedJournal end,
}
AshurSkillRecovery.onCreateRecoveryJournal(craftRecipeData, owner)
assert(craftedJournal.modData.AshurSkillRecovery.ownerId == "username:owner")

local ownerItems = { item, secondJournal }
owner.getInventory = function() return inventory(ownerItems) end
local serverResult = nil
ASR.dispatchClientCommand = function(_, payload) serverResult = payload end
local createdData = Journal.initialize(owner, secondJournal)
assert(createdData ~= nil)
assert(createdData.ownerId == "username:owner")
assert(createdData.journalId ~= item.modData.AshurSkillRecovery.journalId)
assert(createdData.customName == "Recovery Journal")
assert(secondJournal.name == "Recovery Journal")
assert(secondJournal.customName == true)
ASR.commitOperation(owner, { mode = "write", itemId = secondJournal:getID() })
assert(serverResult.ok == true)
assert(secondJournal.modData.AshurSkillRecovery.journalId ~= item.modData.AshurSkillRecovery.journalId)
assert(secondJournal.modData.AshurSkillRecovery.ownerId == "username:owner")

ASR.renameJournal(owner, { itemId = secondJournal:getID(), customName = "Запасной дневник" })
assert(serverResult.ok == true)
assert(secondJournal.modData.AshurSkillRecovery.customName == "Запасной дневник")
assert(secondJournal.name == "Запасной дневник")

local latinName = string.rep("A", 64)
assert(Journal.rename(owner, secondJournal, latinName).ok == true)
assert(secondJournal.name == latinName)
assert(Journal.rename(owner, secondJournal, string.rep("A", 65)).ok == false)

local cyrillicName = string.rep("Я", 64)
assert(Journal.rename(owner, secondJournal, cyrillicName).ok == true)
assert(secondJournal.name == cyrillicName)
assert(Journal.rename(owner, secondJournal, string.rep("Я", 65)).ok == false)

local trimmedRename = Journal.rename(owner, secondJournal, "  Дневник Journal  ")
assert(trimmedRename.ok == true)
assert(trimmedRename.name == "Дневник Journal")

serverMode = true
assert(Journal.rename(owner, secondJournal, "Сетевой Journal").ok == true)
assert(secondJournal.syncCount == 1)
serverMode = false

local reloadedJournal = journal()
reloadedJournal.modData.AshurSkillRecovery = secondJournal.modData.AshurSkillRecovery
local restartItems = { reloadedJournal }
owner.getInventory = function() return inventory(restartItems) end
ASR.renameJournal(owner, { itemId = reloadedJournal:getID(), customName = "После перезапуска" })
assert(serverResult.ok == true)
assert(reloadedJournal.modData.AshurSkillRecovery.customName == "После перезапуска")

foreign.getInventory = function() return inventory({ item }) end
ASR.renameJournal(foreign, { itemId = item:getID(), customName = "Чужой дневник" })
assert(serverResult.ok == false)
assert(serverResult.reason == "UI_ASR_NotJournalOwner")
ASR.commitOperation(foreign, { mode = "write", itemId = item:getID() })
assert(serverResult.ok == false)
assert(serverResult.reason == "UI_ASR_NotJournalOwner")

SandboxVars.AshurSkillRecovery.EnableFitness = false
SandboxVars.AshurSkillRecovery.EnableStrength = false
assert(ASR.perkRecordingEnabled(fitness) == false)
assert(ASR.perkRecoveryEnabled(fitness) == false)
assert(ASR.perkRecordingEnabled(strength) == false)
assert(ASR.perkRecoveryEnabled(strength) == false)
assert(ASR.calculateEarnedXP(source).Strength == nil)
SandboxVars.AshurSkillRecovery.EnableFitness = true
SandboxVars.AshurSkillRecovery.EnableStrength = true

print("journal integration: all tests passed")
