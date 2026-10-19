--!strict
--[[
	Susto da janela (capítulo 1): com o jogador dentro de casa, perto de uma janela do térreo e olhando para ela,
	cai um relâmpago e uma silhueta do Tung Tung passa correndo do lado de fora por ~1,6 s.
	Só visual e só no cliente: é uma cópia do corpo animado (TungTungRig), sem IA, colisão, som de passos reais ou
	efeito em regra/progresso. No máximo 2 vezes por capítulo, com intervalo mínimo.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local TungTungRig = require("../Creature/TungTungRig")
local RainController = require("./RainController")

local controller = { Name = "WindowScareController" }

local COOLDOWN = 120
local FIRST_DELAY = 40
local MAX_PER_CHAPTER = 2
local RUN_TIME = 1.6
local RUN_SPAN = 34

local running = false
local lastAt = -math.huge
local count = 0
local chapter = 0
local chapterStart = 0

local function run(hole: Layout.FacadeWindow)
	running = true
	RainController.strikeNow()
	task.delay(0.12, function()
		local rig = TungTungRig.build(nil)
		if not rig then
			running = false
			return
		end
		-- Nome próprio: medo/tensão procuram "VigiaVisual" no workspace e não podem confundir a silhueta.
		rig.model.Name = "WindowScareVisual"
		rig.model.Parent = workspace
		rig.eyeLight.Brightness = 1.6
		TungTungRig.play(rig, "run", 0, 1.25)
		-- 9 studs para fora da fachada (x ±44): perto o bastante para ver o corpo inteiro pelo vão.
		local x = hole.side * 53
		local dir = if math.random() < 0.5 then 1 else -1
		local start = Vector3.new(x, hole.y, hole.z - dir * RUN_SPAN / 2)
		local finish = Vector3.new(x, hole.y, hole.z + dir * RUN_SPAN / 2)
		local t = 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local alpha = math.min(1, t / RUN_TIME)
			local at = start:Lerp(finish, alpha)
			TungTungRig.place(rig, CFrame.lookAt(at, at + (finish - start).Unit))
			TungTungRig.step(rig, dt, 0)
			if alpha >= 1 then
				if connection then
					connection:Disconnect()
				end
				rig.model:Destroy()
				running = false
			end
		end)
	end)
end

function controller.Start()
	local windows: { Layout.FacadeWindow } = {}
	for _, hole in Layout.facadeWindows(House.Rooms) do
		if hole.y == 0 then
			table.insert(windows, hole)
		end
	end
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.25 then
			return
		end
		clock = 0
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		local stage = if state then tonumber(state:GetAttribute("Stage")) or 0 else 0
		local now = os.clock()
		if stage ~= chapter then
			chapter, chapterStart, count = stage, now, 0
		end
		if running or stage ~= 1 or count >= MAX_PER_CHAPTER then
			return
		end
		if now - chapterStart < FIRST_DELAY or now - lastAt < COOLDOWN then
			return
		end
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		if not camera or not character then
			return
		end
		local eye = camera.CFrame.Position
		for _, hole in windows do
			local window = Vector3.new(hole.side * 44, hole.y + 7.5, hole.z)
			local offset = window - eye
			local inside = math.abs(eye.X) < 44 and eye.Y > hole.y and eye.Y < hole.y + 16
			if inside and offset.Magnitude < 18 and camera.CFrame.LookVector:Dot(offset.Unit) > 0.75 then
				lastAt, count = now, count + 1
				run(hole)
				return
			end
		end
	end)
end

-- Ponte de QA no Studio: dispara o susto na janela mais próxima.
function controller.debugRun()
	local camera = workspace.CurrentCamera
	local best: Layout.FacadeWindow? = nil
	local bestDistance = math.huge
	for _, hole in Layout.facadeWindows(House.Rooms) do
		local distance = (Vector3.new(hole.side * 44, hole.y + 7.5, hole.z) - camera.CFrame.Position).Magnitude
		if distance < bestDistance then
			best, bestDistance = hole, distance
		end
	end
	if best then
		run(best)
	end
end

return controller
