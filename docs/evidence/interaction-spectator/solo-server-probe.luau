--!strict
-- Script temporário de QA (Play, VM normal); não usar em Edit ou em jogo publicado.

local W=require(game.ServerScriptService.Server.Services.WorldService)
local P=require(game.ServerScriptService.Server.Services.PlayerStateService)
local R=require(game.ServerScriptService.Server.Services.RoundService)
local Creature=require(game.ServerScriptService.Server.Services.CreatureService)
local Http=game:GetService("HttpService")
Creature.setFrozen(true)
local bridge=Instance.new("BindableFunction"); bridge.Name="ContinuationQA"; bridge.Parent=game.ServerScriptService
bridge.OnInvoke=function(op,arg,pos)
 local p=game.Players:GetPlayers()[1]
 if op=="move" then
  local target=W.interactable(arg); assert(target,"target missing")
  p.Character:PivotTo(CFrame.lookAt(Vector3.new(unpack(pos)),target.focus.Position))
  P.markTeleported(p); task.wait(.2)
 elseif op=="grant" then R.debugGrant(arg,p); task.wait(.1)
 elseif op=="lose" then R.lose(p); task.wait(.2)
 elseif op=="restart" then R.restart(); Creature.setFrozen(true)
 end
 local items={}
 for id,item in W.features().interactables do table.insert(items,{id=id,kind=item.kind,position=tostring(item.focus.Position),enabled=item.enabled}) end
 return Http:JSONEncode({state=R.snapshot(),player=P.snapshot(p),items=items,door=W.door("door_generator").panel:GetAttribute("DoorState")})
end
