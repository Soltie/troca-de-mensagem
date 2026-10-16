--!strict
--[[
	Moedas da casa no cliente (só visual): giram e flutuam, e cada coleta solta brilho e "plim".
	A coleta é decidida pelo servidor (CoinService); aqui só lemos os atributos CoinPickup* do jogador.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AudioController = require("./AudioController")

local player = Players.LocalPlayer
local TAG = "HouseCoin"

local bases: { [BasePart]: CFrame } = {}
local clock = 0

local CoinController = { Name = "CoinController" }

local function track(part: Instance)
	if part:IsA("BasePart") then
		bases[part] = part.CFrame
		part.AncestryChanged:Connect(function(_, parent)
			if not parent then
				bases[part] = nil
			end
		end)
	end
end

local function burst(position: Vector3, gem: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(if gem then Color3.fromRGB(210, 130, 255) else Color3.fromRGB(255, 214, 70))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(if gem then 40 else 18)
	Debris:AddItem(anchor, 1.5)
end

function CoinController.Start()
	for _, part in CollectionService:GetTagged(TAG) do
		track(part)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
		local at = player:GetAttribute("CoinPickupAt")
		local gem = player:GetAttribute("CoinPickupGem") == true
		if typeof(at) == "Vector3" then
			burst(at, gem)
		end
		AudioController.play("Coin", if gem then 1.2 else 1, if gem then 0.9 else 1.25 + math.random() * 0.15, true)
		if gem then
			AudioController.play("StingerWin", 0.5, 1.2, true)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local spin = clock * 2.6
		for part, base in bases do
			local bob = math.sin(clock * 2 + base.Position.X * 0.3) * 0.35
			part.CFrame = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, math.rad(90), 0)
		end
	end)
end

return CoinController
