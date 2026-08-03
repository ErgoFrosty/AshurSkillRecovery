if isClient() then return end

local ASR = require "AshurSkillRecovery/Core"
local Journal = require "AshurSkillRecovery/Journal"

local journalRegistry = {}

local function itemId(item)
    if not item or not item.getID then return nil end
    local ok, value = pcall(function() return item:getID() end)
    return ok and tonumber(value) or nil
end

local function journalStillExists(item)
    if not item then return false end
    if not item.getContainer then return true end
    local ok, container = pcall(function() return item:getContainer() end)
    return ok and container ~= nil
end

local function listItems(container)
    if not container or not container.getItems then return nil end
    local ok, items = pcall(function() return container:getItems() end)
    return ok and items or nil
end

local registerJournal

local function findOwnedJournal(playerObj, ignoredItem)
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    if not ownerId or not playerObj.getInventory then return nil end

    local ignoredId = itemId(ignoredItem)
    local visited = {}
    local function visit(container)
        if not container or visited[container] then return nil end
        visited[container] = true
        local items = listItems(container)
        if not items or not items.size or not items.get then return nil end
        for index = 0, items:size() - 1 do
            local item = items:get(index)
            if itemId(item) ~= ignoredId then
                local data = ASR.getJournalData(item)
                if ASR.isJournal(item) and data and data.ownerId == ownerId then return item end
            end
            if item and item.getItemContainer then
                local ok, nested = pcall(function() return item:getItemContainer() end)
                local found = ok and visit(nested) or nil
                if found then return found end
            end
        end
        return nil
    end

    return visit(playerObj:getInventory())
end

function ASR.hasOtherOwnedJournal(playerObj, item)
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    local entry = ownerId and journalRegistry[ownerId] or nil
    if entry then
        if entry.itemId == itemId(item) then return false end
        if journalStillExists(entry.item) then return true end
        journalRegistry[ownerId] = nil
    end

    local existing = findOwnedJournal(playerObj, item)
    if not existing then return false end
    registerJournal(playerObj, existing)
    return true
end

registerJournal = function(playerObj, item)
    local ownerId = ASR.getPlayerOwnerId(playerObj)
    local id = itemId(item)
    if ownerId and id then journalRegistry[ownerId] = { item = item, itemId = id } end
end

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
    local data = ASR.getJournalData(item)
    if data and data.ownerId == ASR.getPlayerOwnerId(playerObj) then registerJournal(playerObj, item) end
    if playerObj:isAsleep() or playerObj:hasTrait(CharacterTrait.ILLITERATE) then
        reply(playerObj, { ok = false, reason = "UI_ASR_CannotRead" }, mode)
        return
    end

    ASR.ensureBaseline(playerObj)
    local result = mode == "read" and Journal.read(playerObj, item) or Journal.write(playerObj, item)
    if result.ok and mode == "write" then registerJournal(playerObj, item) end
    if isServer() then syncItemModData(playerObj, item) end
    reply(playerObj, result, mode)
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= ASR.MODULE or command ~= "commit" or not playerObj then return end
    ASR.commitOperation(playerObj, args)
end

Events.OnClientCommand.Add(onClientCommand)
