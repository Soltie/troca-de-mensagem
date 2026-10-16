--!strict
-- Acompanha apenas colegas ativos; nenhuma ação de jogo é enviada por este controller.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Rules = require("@game/ReplicatedStorage/Shared/Game/SpectatorRules")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Camera = require("./CameraController")
local Create = require("../UI/Create")

local player = Players.LocalPlayer
local selected: number? = nil
local direction = 0
local Controller = { Name = "SpectatorController" }

function Controller.debugState(): { [string]: any }
	return { target = selected }
end

function Controller.cycle(step: number)
	direction = if step < 0 then -1 else 1
end

function Controller.Start()
	local banner = Create("TextLabel", {
		Name = "SpectatorStatus",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.9, 0, 0, 64),
		BackgroundColor3 = Color3.fromRGB(12, 16, 18),
		BackgroundTransparency = 0.1,
		TextColor3 = Color3.fromRGB(222, 216, 198),
		Font = Enum.Font.Code,
		TextSize = 15,
		TextWrapped = true,
		Visible = false,
		Parent = Create("ScreenGui", {
			Name = "SpectatorUi",
			ResetOnSpawn = false,
			DisplayOrder = 65,
			Parent = player:WaitForChild("PlayerGui"),
		}),
	}) :: TextLabel
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and banner.Visible then
			if input.KeyCode == Enum.KeyCode.Right then
				Controller.cycle(1)
			elseif input.KeyCode == Enum.KeyCode.Left then
				Controller.cycle(-1)
			end
		end
	end)
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		local phase = if state then state:GetAttribute("Phase") else ""
		local allowed = Rules.allowed(tostring(phase), player:GetAttribute("CampaignStatus") :: string?)
		banner.Visible = allowed
		if not allowed then
			selected = nil
			direction = 0
			Camera.setSpectator(nil)
			return
		end
		local ids, candidates = {}, {}
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local h = character and character:FindFirstChildOfClass("Humanoid")
			local head = character and character:FindFirstChild("Head")
			if other ~= player and other:GetAttribute("CampaignStatus") == "Active" and h and h.Health > 0 and head then
				table.insert(ids, other.UserId)
				candidates[other.UserId] = other
			end
		end
		selected = Rules.choose(ids, selected, direction)
		direction = 0
		local target = if selected then candidates[selected] else nil
		Camera.setSpectator(target)
		banner.Text = PixelText.normalize(
			(if target then `ACOMPANHANDO {target.DisplayName} · [← / →] TROCAR` else "AGUARDANDO COLEGAS ATIVOS.")
				.. (
					if player:GetAttribute("CampaignStatus") == "Downed"
						then "\nVOCÊ AINDA PODE SER RESGATADO POR UM COLEGA."
						else "\nVOCÊ RETORNA NO PRÓXIMO ESTÁGIO."
				)
		)
	end)
end

return Controller
