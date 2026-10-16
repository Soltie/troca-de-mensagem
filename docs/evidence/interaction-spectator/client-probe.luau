--!strict
-- Executar somente como LocalScript temporário durante QA no Studio; não é bootstrap do jogo.

local p=game.Players.LocalPlayer
local C=game.ReplicatedStorage.Client.Controllers
local I=require(C.InteractionController)
local Camera=require(C.CameraController)
local Fx=require(C.ScreenFxController)
local Settings=require(C.SettingsController)
local bridge=Instance.new("BindableFunction")
bridge.Name="ContinuationQA"; bridge.Parent=p.PlayerGui
local function inspect()
 local ui=p.PlayerGui.InteractionUi
 return {camera=Camera.debugState(),hidden=p:GetAttribute("Hidden"),holding=p:GetAttribute("HoldBreath"),target=I.currentTarget(),prompt=ui.Prompt.Text,promptVisible=ui.Prompt.Visible,note=ui.Note.Body.Text,noteOpen=require(C.GameUiController).isNoteOpen(),pulse=Fx.debugState(),flashlight=require(C.FlashlightController).isOn(),spectator=require(C.SpectatorController).debugState(),banner=p.PlayerGui.SpectatorUi.SpectatorStatus.Text,bannerVisible=p.PlayerGui.SpectatorUi.SpectatorStatus.Visible,highlight=workspace.InteractionFocus.Adornee and workspace.InteractionFocus.Adornee.Name}
end
bridge.OnInvoke=function(op,id,action)
 if op=="aim" then
  for _,part in game:GetService("CollectionService"):GetTagged("Interactable") do
   if part:GetAttribute("InteractId")==id then
    workspace.CurrentCamera.CameraType=Enum.CameraType.Custom; task.wait(.15); workspace.CurrentCamera.CFrame=CFrame.lookAt(p.Character.Head.Position,part.Position)
    task.wait(.2)
    return inspect()
   end
  end
  error("missing target "..tostring(id))
 elseif op=="activate" then I.activate(action); task.wait(.18)
 elseif op=="breath" then require(game.ReplicatedStorage.Shared.Net.Remotes).clientEvent("SetHoldBreath"):FireServer(id); task.wait(.2)
 elseif op=="settings" then Settings.set("flashes",id)
 elseif op=="pulse" then Fx.pulse(Color3.new(0,1,0)); task.wait(.1)
 elseif op=="cycle" then require(C.SpectatorController).cycle(id); task.wait(.2)
 end
 return inspect()
end
