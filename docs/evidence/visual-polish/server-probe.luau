--!strict
-- Fixture temporária de Play no Studio; não registrar no bootstrap do jogo.

local W=require(game.ServerScriptService.Server.Services.WorldService)
local G=require(game.ReplicatedStorage.Shared.Game.GameState)
local Creature=require(game.ServerScriptService.Server.Services.CreatureService)
Creature.setFrozen(true)
local b=Instance.new("BindableFunction");b.Name="VisualQA";b.Parent=game.ServerScriptService
b.OnInvoke=function(op)
 if op=="on" then W.setPower(true);G.set("PowerOn",true)
 elseif op=="off" then W.setPower(false);G.set("PowerOn",false)
 elseif op=="vigia" then Creature.activate(Vector3.new(-21,0,-33));Creature.setFrozen(true);Creature.debugPlace(Vector3.new(-21,0,-33));local root=workspace.Vigia.Root;root.CFrame=CFrame.lookAt(root.Position,Vector3.new(-12,root.Position.Y,-27))
 elseif op=="spark" then local box=W.features().breakers.box;box:SetAttribute("Spark",not box:GetAttribute("Spark"))
 end
 return {power=W.isPowered(),creature=Creature.state()}
end
W.setPower(true);G.set("PowerOn",true)
