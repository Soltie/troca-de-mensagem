--!strict
--[[
	Sustos roteirizados por capítulo (só neste cliente, nunca machucam): cada um dispara uma vez por capítulo quando
	o jogador entra numa área. Dão medo em momentos certos mesmo quando o Tung Tung está longe (no capítulo 1 ele
	nem acordou ainda).
	1: a porta bate atrás de você; a TV da sala chia sozinha com sussurros; passos no andar de cima.
	2: rádio chia "tum... tum... tum" na cozinha; as luzes do corredor morrem.
	3: algo é arrastado no sótão; sussurros atrás de você nos retratos.
	4: três pancadas na parede do porão; o rugido dele lá embaixo, perto dos símbolos.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FlashlightController = require("./FlashlightController")

local WorldFxController = require("./WorldFxController")

local player = Players.LocalPlayer

local ScareController = {
	Name = "ScareController",
}

type Scare = {
	chapter: number,
	center: Vector3,
	radius: number,
	delay: number,
	run: () -> (),
}

local rng = Random.new()

local function sound(name: string, at: Vector3, volume: number?, speed: number?)
	local s = AudioController.playAtPosition(name, at, volume, speed)
	s.RollOffMinDistance = 14
	s.RollOffMaxDistance = 110
end

local SCARES: { Scare } = {
	-- Capítulo 1 -------------------------------------------------------------------------------------------------
	{
		chapter = 1,
		center = Vector3.new(0, 0, 48),
		radius = 12,
		delay = 1.2,
		run = function()
			-- A porta da frente bate atrás de você.
			sound("DoorBang", Vector3.new(0, 5, 63), 1.6, 0.7)
			sound("Fall_box", Vector3.new(0, 3, 63), 1.2, 0.6)
			CameraController.addTrauma(0.5)
			WorldFxController.surge(0.9, Vector3.new(0, 4, 50), 40)
		end,
	},
	{
		chapter = 1,
		center = Vector3.new(-26, 0, -4),
		radius = 11,
		delay = 2,
		run = function()
			-- A TV da sala chia sozinha, as luzes falham e alguém sussurra (o vulto na janela é do WindowScare).
			sound("RadioStatic", Vector3.new(-20, 4, -14), 1.5, 0.75)
			WorldFxController.surge(1.6, Vector3.new(-26, 4, -4), 30)
			task.delay(0.9, function()
				AudioController.play("Whisper", 0.9, 0.8)
			end)
		end,
	},
	{
		chapter = 1,
		center = Vector3.new(-26, 0, -36),
		radius = 11,
		delay = 1,
		run = function()
			-- Passos pesados atravessando o andar de cima, com o teto rangendo.
			for i = 0, 5 do
				task.delay(i * 0.55, function()
					sound("CreatureStep", Vector3.new(-34 + i * 3.2, 17, -36), 1.4, 0.4)
					if i % 2 == 0 then
						sound("CreakWood", Vector3.new(-34 + i * 3.2, 15, -36), 1.4, 0.6)
					end
					CameraController.addTrauma(0.08)
				end)
			end
		end,
	},
	-- Capítulo 2 -------------------------------------------------------------------------------------------------
	{
		chapter = 2,
		center = Vector3.new(26, 0, -4),
		radius = 11,
		delay = 1.5,
		run = function()
			-- O rádio liga sozinho chiando e o bastão responde: tum... tum... tum.
			sound("RadioStatic", Vector3.new(36, 3, -10), 1.4, 0.9)
			for i = 1, 3 do
				task.delay(0.8 + i * 0.75, function()
					sound("DoorBang", Vector3.new(40, 4, -4), 0.9, 0.62)
					FlashlightController.flicker(0.25)
				end)
			end
		end,
	},
	{
		chapter = 2,
		center = Vector3.new(0, 0, -30),
		radius = 9,
		delay = 0.5,
		run = function()
			-- As luzes do corredor morrem com um estalo da fiação.
			sound("BreakerFail", Vector3.new(0, 8, -30), 1.2, 0.8)
			WorldFxController.surge(3, Vector3.new(0, 4, -30), 50)
			FlashlightController.flicker(1)
			CameraController.addTrauma(0.3)
		end,
	},
	-- Capítulo 3 -------------------------------------------------------------------------------------------------
	{
		chapter = 3,
		center = Vector3.new(-26, 32, -4),
		radius = 12,
		delay = 1.5,
		run = function()
			-- Algo pesado é arrastado do outro lado do sótão.
			for i = 0, 3 do
				task.delay(i * 0.5, function()
					sound("CreakWood", Vector3.new(-38 + i * 2, 34, -16), 1.5, 0.45)
					sound("Fall_box", Vector3.new(-38 + i * 2, 33, -16), 0.5, 0.45)
				end)
			end
		end,
	},
	{
		chapter = 3,
		center = Vector3.new(26, 32, -36),
		radius = 11,
		delay = 2.5,
		run = function()
			-- Sussurros bem atrás de você entre os retratos; a lanterna falha.
			local camera = workspace.CurrentCamera
			local behind = if camera
				then camera.CFrame.Position - camera.CFrame.LookVector * 3
				else Vector3.new(26, 35, -36)
			sound("Whisper", behind, 1.6, 0.85)
			FlashlightController.flicker(1.2)
		end,
	},
	-- Capítulo 4 -------------------------------------------------------------------------------------------------
	{
		chapter = 4,
		center = Vector3.new(-26, -16, -4),
		radius = 11,
		delay = 2,
		run = function()
			-- Três pancadas do outro lado da parede.
			for i = 0, 2 do
				task.delay(i * 0.7, function()
					sound("DoorBang", Vector3.new(-42, -12, -4), 1.5, 0.55)
					CameraController.addTrauma(0.25)
				end)
			end
		end,
	},
	{
		chapter = 4,
		center = Vector3.new(26, -16, -4),
		radius = 11,
		delay = 1,
		run = function()
			-- O rugido dele ecoa no porão e as luzes morrem.
			sound("Roar", Vector3.new(26, -12, -40), 1.3, 0.7)
			WorldFxController.surge(2.5, Vector3.new(26, -12, -4), 45)
			FlashlightController.flicker(0.8)
			CameraController.addTrauma(0.35)
		end,
	},
}

local fired: { [Scare]: boolean } = {}
local pending: { [Scare]: boolean } = {}
local chapter = 0
local phase: GameState.Phase = "Loading"

local function stage(): number
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
	local value = state and state:GetAttribute("Stage")
	return if type(value) == "number" then value else 0
end

function ScareController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < 0.25 then
			return
		end
		clock = 0
		local current = stage()
		if current ~= chapter then
			chapter = current
			table.clear(fired)
			table.clear(pending)
		end
		if phase ~= "Playing" or player:GetAttribute("CinematicActive") == true then
			return
		end
		if player:GetAttribute("CampaignStatus") ~= "Active" then
			return
		end
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		if not body or not body:IsA("BasePart") then
			return
		end
		local position = body.Position - Vector3.new(0, 3, 0)
		for _, scare in SCARES do
			if scare.chapter ~= chapter or fired[scare] or pending[scare] then
				continue
			end
			local offset = position - scare.center
			if math.abs(offset.Y) < 6 and Vector3.new(offset.X, 0, offset.Z).Magnitude < scare.radius then
				pending[scare] = true
				task.delay(scare.delay + rng:NextNumber(0, 0.6), function()
					pending[scare] = nil
					if fired[scare] or stage() ~= scare.chapter then
						return
					end
					fired[scare] = true
					scare.run()
				end)
			end
		end
	end)
end

return ScareController
