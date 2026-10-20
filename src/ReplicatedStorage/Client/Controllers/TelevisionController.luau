--!strict
-- Atualização limitada a 8 Hz e só perto da TV; nenhuma câmera ou regra de missão é alterada.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Broadcast = require("@game/ReplicatedStorage/Shared/Game/HouseBroadcast")
local Settings = require("./SettingsController")
local AudioController = require("./AudioController")
local GameUiController = require("./GameUiController")
local Controller = { Name = "TelevisionController" }
function Controller.Start()
	local elapsed = 0
	-- A fita toca sozinha quando alguém chega perto da TV (uma vez por capítulo): chiado e a voz da Dona Cida.
	local playedStage: number? = nil
	local lastSpawnAt = os.clock()
	Players.LocalPlayer.CharacterAdded:Connect(function()
		lastSpawnAt = os.clock()
	end)
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
			-- Quem conta é o corpo do jogador (não a câmera de carregamento) e só depois de uns segundos em jogo.
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local offset = if root and root:IsA("BasePart") then root.Position - screen.Position else nil
			if
				playedStage ~= stage
				and state
				and state:GetAttribute("Phase") == "Playing"
				and offset
				and os.clock() - lastSpawnAt > 4
				and Vector3.new(offset.X, 0, offset.Z).Magnitude < 20
				and math.abs(offset.Y) < 8
			then
				playedStage = stage
				AudioController.play("RadioStatic", 0.8)
				for n, text in Broadcast[stage] do
					task.delay(0.6 + (n - 1) * 4.2, function()
						GameUiController.caption(`FITA: {text}`, 4)
					end)
				end
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
