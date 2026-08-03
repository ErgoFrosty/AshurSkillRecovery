require "ISUI/ISInventoryPaneContextMenu"
require "AshurSkillRecovery/RecoveryAction"

local ASR = require "AshurSkillRecovery/Core"
local Journal = require "AshurSkillRecovery/Journal"

local Context = {}

local function tooltip(text)
    local value = ISInventoryPaneContextMenu.addToolTip()
    value.description = text
    return value
end

local function queueOperation(items, playerObj, mode)
    local actualItems = ISInventoryPane.getActualItems(items)
    for _, item in ipairs(actualItems) do
        if ASR.isJournal(item) then
            if item:getContainer() ~= nil then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
            end
            ISTimedActionQueue.add(ASRRecoveryAction:new(playerObj, item, mode))
            return
        end
    end
end

function Context.onFill(playerNum, context, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    local actualItems = ISInventoryPane.getActualItems(items)
    local journal = nil
    for _, item in ipairs(actualItems) do
        if ASR.isJournal(item) then journal = item; break end
    end
    if not journal then return end

    ASR.ensureBaseline(playerObj)
    local unavailable = playerObj:isAsleep() or playerObj:hasTrait(CharacterTrait.ILLITERATE)

    local writeSkills, writeRecipes, writeReason = Journal.previewWrite(playerObj, journal)
    local writeOption = context:addOptionOnTop(
        getText("UI_ASR_WriteAction"),
        actualItems,
        queueOperation,
        playerObj,
        "write"
    )
    if unavailable or writeReason or (writeSkills == 0 and writeRecipes == 0) then
        writeOption.notAvailable = true
        writeOption.toolTip = tooltip(getText(unavailable and "UI_ASR_CannotRead" or writeReason or "UI_ASR_NothingToWrite"))
    else
        writeOption.toolTip = tooltip(getText(
            "UI_ASR_WritePreview",
            tostring(writeSkills),
            tostring(writeRecipes)
        ))
    end

    local readSkills, readRecipes, readXP, readReason = Journal.previewRead(playerObj, journal)
    local readOption = context:addOptionOnTop(
        getText("UI_ASR_ReadAction"),
        actualItems,
        queueOperation,
        playerObj,
        "read"
    )
    if unavailable or readReason or not ASR.hasJournalContent(journal)
        or (readSkills == 0 and readRecipes == 0) then
        readOption.notAvailable = true
        local key = unavailable and "UI_ASR_CannotRead" or readReason
            or (not ASR.hasJournalContent(journal) and "UI_ASR_EmptyJournal")
            or "UI_ASR_NothingToRestore"
        readOption.toolTip = tooltip(getText(key))
    else
        readOption.toolTip = tooltip(getText(
            "UI_ASR_ReadPreview",
            tostring(readSkills),
            tostring(math.floor(readXP + 0.5)),
            tostring(readRecipes)
        ))
    end
end

Events.OnPreFillInventoryObjectContextMenu.Add(Context.onFill)

return Context
