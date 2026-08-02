local ASR = require "AshurSkillRecovery/Core"

local function initializePlayer(_, playerObj)
    if playerObj then ASR.ensureBaseline(playerObj) end
end

local function resetPerkCache()
    ASR.rebuildPerkCache()
end

Events.OnCreatePlayer.Add(initializePlayer)
Events.OnGameTimeLoaded.Add(resetPerkCache)

print("[AshurSkillRecovery] loaded schema " .. tostring(ASR.SCHEMA_VERSION))
