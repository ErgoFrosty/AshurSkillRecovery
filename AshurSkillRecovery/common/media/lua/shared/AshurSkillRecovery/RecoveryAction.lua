require "TimedActions/ISBaseTimedAction"

local ASR = require "AshurSkillRecovery/Core"

ASRRecoveryAction = ISBaseTimedAction:derive("ASRRecoveryAction")

function ASRRecoveryAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if self.character:tooDarkToRead() then return false end

    local vehicle = self.character:getVehicle()
    if vehicle and vehicle:isDriver(self.character) then
        return not vehicle:isEngineRunning() or vehicle:getSpeed2D() == 0
    end

    -- Build 42 may reconstruct a networked action server-side without the
    -- original InventoryItem reference. Server.lua resolves and validates
    -- itemId against the authoritative player inventory before committing.
    if not self.item then return isServer() end
    return self.character:getInventory():containsRecursive(self.item)
end

function ASRRecoveryAction:start()
    if self.item then
        self.item:setJobType(getText(self.mode == "read" and "UI_ASR_Restoring" or "UI_ASR_Writing"))
        self.item:setJobDelta(0)
    end
    self:setAnimVariable("ReadType", "book")
    self:setActionAnim(CharacterActionAnims.Read)
    self:setOverrideHandModels(nil, self.item)
    self.character:setReading(true)
    self.character:reportEvent("EventRead")
end

function ASRRecoveryAction:update()
    if self.item then self.item:setJobDelta(self:getJobDelta()) end
end

local function clearVisualState(action)
    action.character:setReading(false)
    if action.item then action.item:setJobDelta(0) end
end

function ASRRecoveryAction:stop()
    clearVisualState(self)
    ISBaseTimedAction.stop(self)
end

function ASRRecoveryAction:perform()
    clearVisualState(self)
    local args = { mode = self.mode, itemId = self.itemId }
    if isClient() then
        sendClientCommand(self.character, ASR.MODULE, "commit", args)
    elseif not isServer() and ASR.commitOperation then
        ASR.commitOperation(self.character, args)
    end
    ISBaseTimedAction.perform(self)
end

-- The client request is emitted only after B42's networked timed action has
-- completed. Gameplay state is still recalculated and committed on the server.
function ASRRecoveryAction:complete()
    return true
end

function ASRRecoveryAction:getDuration()
    if self.character and self.character:isTimedActionInstant() then return 1 end
    local option = self.mode == "read" and "ReadActionTime" or "WriteActionTime"
    return math.max(1, math.floor(tonumber(ASR.getOption(option, 300)) or 300))
end

function ASRRecoveryAction:new(character, item, mode)
    local action = ISBaseTimedAction.new(self, character)
    action.character = character
    action.item = item
    action.itemId = item and item:getID() or -1
    action.mode = mode == "read" and "read" or "write"
    action.stopOnWalk = true
    action.stopOnRun = true
    action.stopOnAim = true
    action.ignoreHandsWounds = true
    action.forceProgressBar = true
    action.useProgressBar = true
    action.maxTime = action:getDuration()
    return action
end

return ASRRecoveryAction
