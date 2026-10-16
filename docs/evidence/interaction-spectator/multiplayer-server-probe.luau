--!strict
-- Fixture temporária de QA: somente durante Play local no Studio, nunca como bootstrap.

local Runtime=require(game.ServerScriptService.Server.Campaign.CampaignRuntime)
local Creature=require(game.ServerScriptService.Server.Services.CreatureService)
local bridge=Instance.new("BindableFunction"); bridge.Name="ContinuationQA"; bridge.Parent=game.ServerScriptService
task.spawn(function() while bridge.Parent do Creature.setFrozen(true); task.wait(.1) end end)
bridge.OnInvoke=function(op,id)
 local p=game.Players:GetPlayerByUserId(id or -1)
 if op=="capture" then Runtime.lose(p)
 elseif op=="restart" then Runtime.restart()
 elseif op=="forceWait" then
  local s=Runtime.snapshot(); s.members[id].status="Waiting"; p:SetAttribute("CampaignStatus","Waiting")
 elseif op=="end" then game:GetService("StudioTestService"):EndTest({success=true,label="spectator QA complete"})
 end
 return game:GetService("HttpService"):JSONEncode(Runtime.snapshot())
end
