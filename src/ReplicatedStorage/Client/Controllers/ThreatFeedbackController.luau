--!strict
-- Captura é uma transição pessoal. Nunca prende a câmera de colegas ou de quem já foi resgatado.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local Audio = require("./AudioController")
local Camera = require("./CameraController")
local Fear = require("./FearController")
local Jumpscare = require("./JumpscareController")
local ScreenFx = require("./ScreenFxController")

local player = Players.LocalPlayer
local previousStatus: string? = nil
local previousPhase: string? = nil
local previousRound = -1
local previousMode = "Dormant"
local captureUntil = 0
local captureCount = 0
local chaseCount = 0

local function target(): Vector3?
	local visual = workspace:FindFirstChild("VigiaVisual")
	local head = visual and visual:FindFirstChild("Head", true)
	-- Malha única (Body): a cabeça fica no alto dela, não na raiz (+2 caía na cintura).
	local body = visual and visual:FindFirstChild("Body")
	if not head and body and body:IsA("BasePart") then
		return body.Position + Vector3.new(0, body.Size.Y * 0.32, 0)
	end
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 2, 0) else nil
end

local Controller = { Name = "ThreatFeedbackController" }

-- Ponto da cabeça do Tung (a tela de derrota usa a mesma câmera de captura).
Controller.creatureHead = target

function Controller.debugState(): { [string]: any }
	return { captures = captureCount, chases = chaseCount, mode = previousMode, capturing = captureUntil > 0 }
end

function Controller.Start()
	-- Um único observador amostra fase/status juntos, evitando duplicar feedback por ordem de atributos.
	local state: GameState.Snapshot? = nil
	GameState.observe(function(next)
		state = next
	end)
	RunService.RenderStepped:Connect(function()
		local s = state
		if not s then
			return
		end
		local status = player:GetAttribute("CampaignStatus") :: string?
		local now = os.clock()
		local reset = previousRound ~= s.roundId or s.phase == "Intro" or s.phase == "Loading" or s.phase == "Won"
		if reset or (captureUntil > 0 and (now >= captureUntil or status == "Active")) then
			if captureUntil > 0 or previousRound ~= s.roundId then
				Camera.reset()
				ScreenFx.reset()
			end
			captureUntil = 0
		end
		if not reset and Presentation.captured(previousStatus, status, previousPhase, s.phase) then
			captureCount += 1
			-- Pego pelo Tung Tung (pancada ou porta do armário): o jumpscare 3D cuida da câmera e do som.
			local cause = player:GetAttribute("LastCaptureCause")
			local scared = (cause == "tung" or cause == "search") and Jumpscare.play()
			captureUntil = now + (if scared then 1.7 else 1.1)
			if not scared then
				Camera.capture(target)
			end
			ScreenFx.capture()
			Fear.spike(0.45)
			Audio.muffle(1.2)
			-- O áudio de derrota solo já pertence ao AudioController. No coop o susto é pessoal.
			if status ~= nil and not scared then
				Audio.play("StingerCapture", 1, nil, true)
				Audio.play("Roar", 1, 0.8, true)
			end
		end
		local model = workspace:FindFirstChild(Tags.CreatureModel)
		local root = model and model:FindFirstChild(Tags.CreatureRoot)
		local mode = "Dormant"
		if root then
			mode = Presentation.mode(
				(root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant",
				root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number?,
				player.UserId,
				status
			)
		end
		if Presentation.playing(s.phase, status) and mode == "Chase" and previousMode ~= "Chase" then
			chaseCount += 1
			Camera.punch()
			Camera.addTrauma(0.35)
		end
		previousMode = mode
		previousStatus = status
		previousPhase = s.phase
		previousRound = s.roundId
	end)
end

return Controller
