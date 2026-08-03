local ASR = require "AshurSkillRecovery/Core"

local function showResult(playerObj, args)
    if not playerObj then return end
    local message
    if args.ok == true and args.mode == "rename" then
        HaloTextHelper.addGoodText(playerObj, getText("UI_ASR_RenameSuccess", args.name or ""))
    elseif args.ok == true and args.mode == "write" then
        message = getText("UI_ASR_WriteSuccess", tostring(args.skills or 0), tostring(args.recipes or 0))
        HaloTextHelper.addGoodText(playerObj, message)
    elseif args.ok == true then
        message = getText(
            "UI_ASR_ReadSuccess",
            tostring(args.skills or 0),
            tostring(math.floor((tonumber(args.xp) or 0) + 0.5)),
            tostring(args.recipes or 0)
        )
        HaloTextHelper.addGoodText(playerObj, message)
    else
        HaloTextHelper.addBadText(playerObj, getText(args.reason or "UI_ASR_ServerRejected"))
    end
end

local function onServerCommand(module, command, args)
    if module ~= ASR.MODULE or command ~= "result" then return end
    args = args or {}
    local playerObj = getSpecificPlayer(tonumber(args.playerNum) or 0) or getPlayer()
    showResult(playerObj, args)
end

ASR.dispatchClientCommand = function(command, args)
    onServerCommand(ASR.MODULE, command, args)
end

Events.OnServerCommand.Add(onServerCommand)
