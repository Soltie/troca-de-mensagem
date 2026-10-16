--!strict
--[[
	Efeitos de luz no cliente, sempre "em passos" (12 Hz), sem mexer no estado do servidor
	(o servidor liga/desliga as luzes; aqui só modulamos o brilho localmente):
	- luzes marcadas com Flicker piscam;
	- sirene do portão alterna com a energia ligada;
	- picos de falha quando O Vigia acorda e quando a energia volta.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Profile = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local SettingsController = require("./SettingsController")

local rng = Random.new()
local surgeUntil = 0
local surgeOrigin: Vector3? = nil
local surgeRadius = math.huge
local snapshot: GameState.Snapshot? = nil
local fixtures: { [BasePart]: { light: Light, seed: number } } = {}
local nextSeed = 0
local shadowClock = 1
local shadowCount = 0

local function quality(): number
	local ok, value = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return if ok then value else 0
end

local function selectShadows()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local candidates: { Profile.Candidate } = {}
	for part, entry in fixtures do
		if part.Parent then
			table.insert(candidates, {
				id = tostring(entry.seed),
				enabled = entry.light.Enabled,
				distance = (part.Position - camera.CFrame.Position).Magnitude,
				range = (entry.light :: any).Range,
			})
		end
	end
	local chosen = Profile.selectShadows(candidates, Profile.shadowBudget(quality()))
	shadowCount = 0
	for _, entry in fixtures do
		entry.light.Shadows = chosen[tostring(entry.seed)] == true
		if entry.light.Shadows then
			shadowCount += 1
		end
	end
end

local function lightOf(part: BasePart): Light?
	return part:FindFirstChildWhichIsA("Light")
end

local function step()
	local now = os.clock()
	local flashes = SettingsController.get("flashes")
	local surging = flashes and now < surgeUntil
	local s = snapshot
	for instance, entry in fixtures do
		if instance.Parent then
			local light = entry.light
			if light.Parent then
				local base = (instance:GetAttribute("BaseBrightness") :: number?) or light.Brightness
				local kind = instance:GetAttribute(Tags.Attr.LightKind)
				local factor =
					Profile.flicker(now, entry.seed, instance:GetAttribute(Tags.Attr.Flicker) == true, flashes)
				if
					surging
					and kind ~= "Exit"
					and (surgeOrigin == nil or (instance.Position - surgeOrigin).Magnitude <= surgeRadius)
				then
					factor = if rng:NextNumber() < 0.5 then rng:NextNumber(0.25, 0.5) else rng:NextNumber(0.8, 1.2)
				end
				if kind == "Beacon" then
					local on = s ~= nil and s.powerOn and (not flashes or (now * 2.5) % 2 < 1)
					instance.Transparency = if on then 0 else 0.6
					factor = if on then 1 else 0
				end
				light.Brightness = base * factor
			end
		end
	end
end

local WorldFxController = {
	Name = "WorldFxController",
}

function WorldFxController.debugState(): { [string]: any }
	local count = 0
	for _ in fixtures do
		count += 1
	end
	return { fixtures = count, shadows = shadowCount, budget = Profile.shadowBudget(quality()) }
end

-- Pico de falha nas luzes por `duration` segundos.
function WorldFxController.surge(duration: number, origin: Vector3?, radius: number?)
	surgeUntil = math.max(surgeUntil, os.clock() + duration)
	surgeOrigin = origin
	surgeRadius = radius or math.huge
end

function WorldFxController.Start()
	local function add(instance: Instance)
		if not instance:IsA("BasePart") or fixtures[instance] then
			return
		end
		local light = lightOf(instance)
		if light then
			nextSeed += 1
			fixtures[instance] = { light = light, seed = nextSeed }
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.PowerLight) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.PowerLight):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.PowerLight):Connect(function(instance)
		if instance:IsA("BasePart") then
			local entry = fixtures[instance]
			if entry and entry.light.Parent then
				entry.light.Shadows = false
			end
			fixtures[instance] = nil
		end
	end)
	GameState.observe(function(next: GameState.Snapshot)
		local previous = snapshot
		snapshot = next
		if previous and next.phase == "Playing" then
			if next.creatureActive and not previous.creatureActive then
				WorldFxController.surge(1.4)
			end
			if next.powerOn and not previous.powerOn then
				WorldFxController.surge(1.8)
			end
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		shadowClock += dt
		if shadowClock >= 0.5 then
			shadowClock = 0
			selectShadows()
		end
		accumulator += dt
		if accumulator >= 1 / Config.Visual.FlickerRate then
			accumulator = 0
			step()
		end
	end)
end

return WorldFxController
