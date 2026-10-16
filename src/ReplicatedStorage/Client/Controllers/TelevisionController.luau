--!strict
-- Atualização limitada a 8 Hz e só perto da TV; nenhuma câmera ou regra de missão é alterada.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Broadcast = require("@game/ReplicatedStorage/Shared/Game/HouseBroadcast")
local Settings = require("./SettingsController")
local Controller = { Name = "TelevisionController" }
function Controller.Start()
	local elapsed = 0
	local screens: { [BasePart]: boolean } = {}
	local function track(inst: Instance)
		if inst:IsA("BasePart") then
			screens[inst] = true
		end
	end
	for _, inst in CollectionService:GetTagged("HouseTelevision") do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal("HouseTelevision"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("HouseTelevision"):Connect(function(inst)
		if inst:IsA("BasePart") then
			screens[inst] = nil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.125 then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		local stage = math.clamp(tonumber(state and state:GetAttribute("Stage")) or 1, 1, #Broadcast)
		local now = workspace:GetServerTimeNow()
		for screen in screens do
			if not screen.Parent or (camera.CFrame.Position - screen.Position).Magnitude > 55 then
				continue
			end
			local gui = screen:FindFirstChildOfClass("SurfaceGui")
			local label = gui and gui:FindFirstChildOfClass("TextLabel")
			if label then
				local phase = state and state:GetAttribute("Phase")
				local line = math.floor(now / 6) % #Broadcast[stage] + 1
				label.Text = if phase == "Extracting" or phase == "Won"
					then "CANAL 03 / AO VIVO\nSAIAM. AGORA."
					else string.format("CANAL 03 / FITA %02d\n%s", stage, Broadcast[stage][line])
			end
			local scan = gui and gui:FindFirstChild("Scan")
			if scan and scan:IsA("Frame") then
				scan.Visible = Settings.motionEnabled() and Settings.get("flashes")
				scan.Position = UDim2.fromScale(0, (now * 0.12) % 1)
			end
		end
	end)
	-- Mantém o ciclo de vida associado ao controller, sem remotes ou objetos por quadro.
	Players.LocalPlayer:SetAttribute("TelevisionReady", true)
end
return Controller
