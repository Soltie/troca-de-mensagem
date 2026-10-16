--!strict
-- Fixture temporária de Play no Studio; não registrar no bootstrap do jogo.

local p=game.Players.LocalPlayer
local Art=require(game.ReplicatedStorage.Client.Controllers.ArtController)
local S=require(game.ReplicatedStorage.Client.Controllers.SettingsController)
local gui=Instance.new("ScreenGui");gui.Name="VisualQA";gui.ResetOnSpawn=false;gui.Parent=p.PlayerGui
gui:SetAttribute("View","office")
local views={
 office={Vector3.new(-15,6,-12),Vector3.new(-30,3.5,-7)},
 control={Vector3.new(-9,6,-64),Vector3.new(-27,4,-74)},
 generator={Vector3.new(-12,6,-30),Vector3.new(-30,4,-39)},
 workshop={Vector3.new(-51,6,-32),Vector3.new(-66,4,-40)},
 locker={Vector3.new(31,4.55,-15.45),Vector3.new(31,4.55,-8)},
 vigia={Vector3.new(-12,6,-27),Vector3.new(-21,4.8,-33)},
 exterior={Vector3.new(22,7,28),Vector3.new(-6,6,0)}
}
local samples={}
game:GetService("RunService"):BindToRenderStep("ArtShot",Enum.RenderPriority.Camera.Value+20,function(dt)
 local view=views[gui:GetAttribute("View") or "office"];local camera=workspace.CurrentCamera
 camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=CFrame.lookAt(view[1],view[2]);camera.FieldOfView=70
 for _,g in p.PlayerGui:GetChildren()do if g:IsA("ScreenGui")then g.Enabled=false end end
 if #samples<600 then table.insert(samples,dt) end
end)
local b=Instance.new("BindableFunction");b.Name="Read";b.Parent=gui
b.OnInvoke=function(op,arg)
 if op=="view" then gui:SetAttribute("View",arg)
 elseif op=="comfort" then S.set("flashes",arg)
 elseif op=="sample" then table.clear(samples)
 end
 local perf=table.clone(samples);table.sort(perf);local sum=0;for _,dt in perf do sum+=dt end
 local data=Art.debugState()
 data.samples=#perf;data.averageFps=if sum>0 then #perf/sum else 0;data.p95FrameMs=if #perf>0 then perf[math.max(1,math.ceil(#perf*.95))]*1000 else 0
 data.viewport=tostring(workspace.CurrentCamera.ViewportSize)
 local native=0;local activeScreens=0;for _,v in workspace.Substation9:GetDescendants()do if v:IsA("Texture")and v.Name=="ArtTexture"then native+=1 elseif v:IsA("SurfaceGui")and v.Name=="ArtCRT"and v.Enabled then activeScreens+=1 end end
 data.nativeTextures=native;data.activeScreens=activeScreens
 return game.HttpService:JSONEncode(data)
end
