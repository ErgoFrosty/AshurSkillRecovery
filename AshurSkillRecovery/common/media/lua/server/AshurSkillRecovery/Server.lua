if isClient() then return end

local ASR = require "AshurSkillRecovery/Core"
local Journal = require "AshurSkillRecovery/Journal"

local function reply(playerObj, result, mode)
    local payload = {}
    for key, value in pairs(result or {}) do payload[key] = value end
    payload.mode = mode
    payload.playerNum = playerObj:getPlayerNum()
    if isServer() then
        sendServerCommand(playerObj, ASR.MODULE, "result", payload)
    elseif ASR.dispatchClientCommand then
        ASR.dispatchClientCommand("result", payload)
    end
end

local function resolveOwnedJournal(playerObj, itemId)
    local numericId = tonumber(itemId)
    if not numericId then return nil end
    local item = playerObj:getInventory():getItemWithIDRecursiv(numericId)
    if not ASR.isJournal(item) then return nil end
    return item
end

function ASR.commitOperation(playerObj, args)
    args = type(args) == "table" and args or {}
    local mode = args.mode == "read" and "read" or (args.mode == "write" and "write" or nil)
    if not playerObj or playerObj:isDead() or not mode then return end

    local item = resolveOwnedJournal(playerObj, args.itemId)
    if not item then
        reply(playerObj, { ok = false, reason = "UI_ASR_InvalidJournal" }, mode)
        return
    end
    if playerObj:isAsleep() or playerObj:hasTrait(CharacterTrait.ILLITERATE) then
        reply(playerObj, { ok = false, reason = "UI_ASR_CannotRead" }, mode)
        return
    end

    ASR.ensureBaseline(playerObj)
    local result = mode == "read" and Journal.read(playerObj, item) or Journal.write(playerObj, item)
    reply(playerObj, result, mode)
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= ASR.MODULE or command ~= "commit" or not playerObj then return end
    ASR.commitOperation(playerObj, args)
end

Events.OnClientCommand.Add(onClientCommand)

