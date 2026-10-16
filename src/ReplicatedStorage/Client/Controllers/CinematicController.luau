--!strict
-- Cenas locais; a fase e o relógio da partida continuam sendo decididos pelo servidor.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local Camera = require("./CameraController")
local Settings = require("./SettingsController")
local Transition = require("./TransitionController")
local Store = require("./StoreController")
local Animator = require("./CharacterAnimatorController")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")

local player = Players.LocalPlayer
local sequence: Shots.Sequence? = nil
local elapsed = 0
local lastShot = 0
local lastKey = ""
local skipButton: TextButton? = nil
local tickClock = 0
local Controller = { Name = "CinematicController" }

local function vec(v: Shots.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function sink(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

function Controller.stop()
	sequence = nil
	player:SetAttribute("CinematicActive", false)
	if skipButton then
		skipButton.Visible = false
	end
	ContextActionService:UnbindAction("S9CinemaMovement")
	Camera.endCinema()
	Transition.reset()
end

function Controller.play(value: Shots.Sequence)
	Controller.stop()
	if Store.isOpen() then
		return
	end
	sequence = value
	elapsed = 0
	lastShot = 0
	tickClock = 0
	player:SetAttribute("CinematicActive", true)
	if skipButton then
		skipButton.Visible = true
	end
	ContextActionService:BindActionAtPriority(
		"S9CinemaMovement",
		sink,
		false,
		3000,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	task.spawn(Transition.setLetterbox, true, 0.35)
	Transition.stamp(value.shots[1].label, "PLAY", Shots.TAPE_START)
	if value.name == "Opening" then
		Transition.title("SUBESTAÇÃO 9", "03:12 · O ÚLTIMO TURNO")
		Transition.caption("A energia caiu. A equipe anterior não voltou.")
	elseif value.name == "Escape" then
		Transition.title("FIM DO TURNO", "GRAVAÇÃO RECUPERADA")
	end
end

function Controller.debugState(): { [string]: any }
	return { sequence = if sequence then sequence.name else "", elapsed = elapsed, shot = lastShot }
end

local function phaseKey(): (string, string)
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if Config.Campaign.Enabled and campaign then
		local phase = tostring(campaign:GetAttribute("Phase"))
		return phase, `{phase}:{campaign:GetAttribute("CampaignId")}:{campaign:GetAttribute("Stage")}`
	end
	local state = GameState.snapshot()
	return state.phase, `{state.phase}:{state.roundId}`
end

function Controller.Init()
	local gui = Create("ScreenGui", {
		Name = "CinematicControls",
		ResetOnSpawn = false,
		DisplayOrder = 121,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local button = Create("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(220, 32),
		BackgroundColor3 = Theme.Panel,
		TextColor3 = Theme.Text,
		FontFace = Theme.Font,
		TextSize = 16,
		Text = "PULAR CENA [ESPAÇO / A]",
		Modal = true,
		Visible = false,
		Parent = gui,
	}) :: TextButton
	skipButton = button
	button.Activated:Connect(Controller.stop)
	-- A ponte usa a VM real dos controllers (execute_luau roda em outra VM).
	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "AnimationDebugBridge"
		bridge.OnInvoke = function(command: string, value: any): any
			if command == "scene" then
				local selected = if value == "Escape" then Shots.Escape else Shots.Opening
				Controller.play(selected)
			elseif command == "skip" then
				Controller.stop()
			elseif command == "motion" then
				for _, key in { "bob", "tilt", "shake", "fov", "flashes" } do
					Settings.set(key :: Settings.Key, value == true)
				end
			end
			return {
				cinematic = Controller.debugState(),
				camera = Camera.debugState(),
				transition = Transition.debugState(),
				characters = Animator.debugState(),
			}
		end
		bridge.Parent = gui
	end
end

function Controller.Start()
	UserInputService.InputBegan:Connect(function(input, _processed)
		if
			UserInputService:GetFocusedTextBox() == nil
			and sequence
			and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA)
		then
			Controller.stop()
		end
	end)
	player.CharacterRemoving:Connect(Controller.stop)
	RunService:BindToRenderStep("S9Cinematic", Enum.RenderPriority.Camera.Value - 2, function(dt)
		local phase, key = phaseKey()
		if key ~= lastKey then
			local previous = lastKey
			lastKey = key
			Controller.stop()
			if phase == "Intro" or phase == "Lobby" then
				if not GameState.snapshot().fromCheckpoint then
					Controller.play(Shots.Opening)
				end
			elseif phase == "Won" then
				Controller.play(Shots.Escape)
			elseif phase == "Playing" and previous ~= "" then
				-- A rodada já começou: piscar curto sem retirar controle/câmera de combate.
				task.spawn(Transition.blink, 0.02)
			end
		end
		local current = sequence
		if not current then
			return
		end
		if Store.isOpen() or player:GetAttribute("CampaignStatus") == "Downed" then
			Controller.stop()
			return
		end
		elapsed += dt
		tickClock += dt
		if tickClock < 1 / 12 then
			return
		end
		tickClock = 0
		local index, alpha, done = Shots.locate(current, elapsed)
		if done then
			Controller.stop()
			return
		end
		local shot = current.shots[index]
		if lastShot ~= index then
			lastShot = index
			Transition.stamp(shot.label, "PLAY")
			if shot.cut == "static" then
				Transition.static(0.18, 0.45)
			end
		end
		local motion = Settings.motionEnabled()
		local position, look = Shots.sample(shot, if motion then alpha else 0.5)
		local frame = CFrame.lookAt(vec(position), vec(look))
		if motion and Settings.get("shake") then
			frame *= CFrame.Angles(math.noise(elapsed * 2) * shot.handheld * 0.008, 0, 0)
		end
		if not Camera.setCinema(frame, shot.fov, vec(look)) then
			Controller.stop()
		end
	end)
end
return Controller
