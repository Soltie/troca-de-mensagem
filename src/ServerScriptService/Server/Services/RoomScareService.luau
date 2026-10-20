--!strict
--[[
	Sustos de cenário do cap. 1 (regras em Shared/Game/RoomScares). Um por cômodo, na primeira entrada, só no modo
	História. Sem Tum Tum e sem dano: som + um objeto que mexe + legenda (CampaignState.Caption/CaptionSerial).
	- Hall: três batidas e serragem na parede; Cozinha: panelas balançam; Jantar: uma cadeira vira para a porta;
	  Biblioteca: um livro cai; Sala de estar: a cadeira de balanço para de repente.
	- Corredor (depois da 2ª chave): entalhe com dois olhos + sussurro, some em 4 s.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local RoomScares = require("@game/ReplicatedStorage/Shared/Game/RoomScares")
local Activities = require("../Campaign/HouseActivities")
local Build = require("../World/Build")

local RoomScareService = {
	Name = "RoomScareService",
}

local log = Logger.new("RoomScare")
local done: { [string]: boolean } = {}
local keys = 0
local keysPlan: any = nil
local eyesDone = false
local captionSerial = 0

local function caption(text: string)
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if not campaign then
		return
	end
	captionSerial += 1
	campaign:SetAttribute("Caption", text)
	campaign:SetAttribute("CaptionSerial", captionSerial)
end

local function house(): Instance?
	return Workspace:FindFirstChild("CursedHouse")
end

local function anchor(at: Vector3): BasePart
	local part = Build.part(
		Workspace,
		"RoomScareAnchor",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(at),
		Color3.new(),
		{ collide = false, query = false, transparency = 1 }
	)
	task.delay(8, function()
		part:Destroy()
	end)
	return part
end

local function play(part: BasePart, sound: { id: string, volume: number }, speed: number?, delay: number?)
	task.delay(delay or 0, function()
		if part.Parent then
			Build.sound(part, "Scare", sound.id, sound.volume, speed):Play()
		end
	end)
end

local function dust(part: BasePart, count: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(196, 168, 120))
	e.Size = NumberSequence.new(0.25, 0.05)
	e.Speed = NumberRange.new(1, 3)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Rate = 0
	e.Parent = part
	e:Emit(count)
end

-- Primeiro modelo do cômodo cujo nome contém `fragment` (a casa é montada por código; nomes vêm do HouseProps).
local function findModel(room: string, fragment: string): Model?
	local root = house()
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, fragment, 1, true) then
			local pivot = d:GetPivot().Position
			if RoomScares.roomAt(pivot.X, pivot.Y, pivot.Z) == room then
				return d
			end
		end
	end
	return nil
end

local function wiggle(model: Model, degrees: number, seconds: number)
	local base = model:GetPivot()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			local k = (os.clock() - t0) / seconds
			model:PivotTo(base * CFrame.Angles(0, 0, math.rad(degrees) * math.sin(k * 30) * (1 - k)))
			task.wait()
		end
		model:PivotTo(base)
	end)
end

local runners: { [string]: (at: Vector3) -> () } = {}

runners.pounding = function(at)
	local part = anchor(at + Vector3.new(0, 4, 0))
	dust(part, 30)
	for n = 0, 2 do
		play(part, Audio.DoorBang, 0.7, 0.5 + n * 0.6)
	end
end

runners.pans = function(at)
	local part = anchor(at + Vector3.new(0, 4, 0))
	local pans = findModel("Kitchen", "Pan") or findModel("Kitchen", "Stove")
	if pans then
		wiggle(pans, 4, 2.5)
	end
	play(part, Audio.BreakerFail, 1.6)
	play(part, Audio.BreakerFail, 1.9, 0.7)
end

runners.chair_turn = function(at)
	local part = anchor(at + Vector3.new(0, 2, 0))
	local chair = findModel("Dining", "Chair")
	if chair then
		local pivot = chair:GetPivot()
		local door = Vector3.new(-8, pivot.Y, -36)
		chair:PivotTo(CFrame.lookAt(pivot.Position, Vector3.new(door.X, pivot.Position.Y, door.Z)))
	end
	play(part, Audio.CreakWood, 0.8)
end

runners.book_fall = function(at)
	local part = anchor(at + Vector3.new(0, 5, 0))
	local book = Build.part(
		Workspace,
		"FallingBook",
		Vector3.new(0.8, 0.2, 1.2),
		CFrame.new(at + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0.3, 0.4, 0.1),
		Color3.fromRGB(70, 40, 30),
		{ collide = true, query = false }
	)
	book.Anchored = false
	task.delay(1, function()
		play(part, Audio.Paper, 1.0)
	end)
	task.delay(10, function()
		book:Destroy()
	end)
end

runners.rocking = function(at)
	local part = anchor(at + Vector3.new(0, 2, 0))
	play(part, Audio.CreakWood, 0.6)
end

runners.carving_eyes = function(at)
	local root = Workspace
	local eyes = Instance.new("Model")
	eyes.Name = "CorridorEyes"
	for _, side in { -0.9, 0.9 } do
		local eye = Build.part(
			eyes,
			"Eye",
			Vector3.new(0.5, 0.25, 0.1),
			CFrame.new(at + Vector3.new(-7.9, 5, side)),
			Color3.fromRGB(255, 190, 70),
			{ collide = false, query = false, material = Enum.Material.Neon }
		)
		eye.CastShadow = false
	end
	eyes.Parent = root
	local part = anchor(at + Vector3.new(-7.9, 5, 0))
	play(part, Audio.Whisper, 0.8)
	task.delay(4, function()
		eyes:Destroy()
	end)
end

local function fire(scare: RoomScares.Scare, at: Vector3)
	log.info("scare %s in %s", scare.kind, scare.room)
	caption(scare.caption)
	local run = runners[scare.kind]
	if run then
		run(at)
	end
end

function RoomScareService.Start()
	-- 2ª chave: o corredor abre os olhos no entalhe (uma vez).
	Activities.onSolved(function(plan, index)
		if plan.stage ~= 1 or plan.mode ~= "Story" then
			return
		end
		if keysPlan ~= plan then
			keysPlan = plan
			keys = 0
			eyesDone = false
			table.clear(done)
		end
		local spec = plan.activities[index]
		if spec and type(spec.item) == "string" and string.find(spec.item, "key_", 1, true) then
			keys += 1
			if keys == 2 and not eyesDone then
				eyesDone = true
				task.delay(2, function()
					fire(RoomScares.CorridorEyes, Vector3.new(0, 0, -52))
				end)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
			if not campaign or campaign:GetAttribute("Stage") ~= 1 or keysPlan == nil then
				continue
			end
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not (root and root:IsA("BasePart")) or player:GetAttribute("CampaignStatus") ~= "Active" then
					continue
				end
				local room = RoomScares.roomAt(root.Position.X, root.Position.Y, root.Position.Z)
				local scare = room and RoomScares.pick(room, done)
				if room and scare then
					done[room] = true
					local at = root.Position
					task.delay(scare.delay, function()
						fire(scare, at)
					end)
				end
			end
		end
	end)
end

function RoomScareService.reset()
	table.clear(done)
	keys = 0
	eyesDone = false
	keysPlan = nil
end

return RoomScareService
