--!strict
--[[
	Efeitos de luz no cliente, sempre "em passos" (12 Hz), sem mexer no estado do servidor
	(o servidor liga/desliga as luzes; aqui só modulamos o brilho localmente):
	- luzes marcadas com Flicker piscam;
	- sirene do portão alterna com a energia ligada;
	- picos de falha quando O Vigia acorda e quando a energia volta.
]]

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
type Fixture = { part: BasePart, seed: number, brightness: number, range: number, visibility: number, visible: boolean }
local fixtures: { [Light]: Fixture } = {}
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
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if world then { world } else {}
	params.RespectCanCollide = true
	for light, entry in fixtures do
		local part = entry.part
		if part.Parent and light.Parent then
			local direction = part.Position - camera.CFrame.Position
			local hit = if direction.Magnitude <= Profile.ShadowDistance
				then workspace:Raycast(camera.CFrame.Position, direction, params)
				else nil
			entry.visible = hit == nil or hit.Instance == part or (hit.Position - part.Position).Magnitude < 1.5
			table.insert(candidates, {
				id = tostring(entry.seed),
				enabled = light.Enabled and light.Brightness > 0.01 and entry.visible,
				distance = (part.Position - camera.CFrame.Position).Magnitude,
				range = (light :: any).Range,
			})
		end
	end
	local chosen = Profile.selectShadows(candidates, Profile.shadowBudget(quality()))
	shadowCount = 0
	for light, entry in fixtures do
		light.Shadows = chosen[tostring(entry.seed)] == true
		if light.Shadows then
			shadowCount += 1
		end
	end
end

local function step()
	local now = os.clock()
	local flashes = SettingsController.get("flashes")
	local surging = flashes and now < surgeUntil
	local s = snapshot
	for light, entry in fixtures do
		local instance = entry.part
		if instance.Parent then
			if light.Parent then
				local raw = (instance:GetAttribute("BaseBrightness") :: number?) or entry.brightness
				local base, reach = Profile.fixture(instance.Name, raw, entry.range)
				local ranged = light :: any
				ranged.Range = reach
				local kind = instance:GetAttribute(Tags.Attr.LightKind)
				local architectural = kind ~= nil or instance.Name == "NightLight"
				local factor = if architectural
					then Profile.flicker(now, entry.seed, instance:GetAttribute(Tags.Attr.Flicker) == true, flashes)
					else 1
				-- Luzes sem sombra de outros cômodos não atravessam paredes/tetos na visão local.
				local target = if architectural and kind ~= "Exit" and not entry.visible then 0.12 else 1
				entry.visibility += (target - entry.visibility) * 0.22
				factor *= entry.visibility
				if
					surging
					and architectural
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
		if not instance:IsA("Light") or fixtures[instance] then
			return
		end
		local part = instance.Parent
		if not part or not part:IsA("BasePart") then
			return
		end
		nextSeed += 1
		fixtures[instance] = {
			part = part,
			seed = nextSeed,
			brightness = instance.Brightness,
			range = (instance :: any).Range,
			visibility = 1,
			visible = true,
		}
	end
	-- Inclui luzes decorativas sem tag, sem tocar nas lanternas dos jogadores.
	task.spawn(function()
		local world = workspace:WaitForChild(Tags.WorldFolder, 30)
		if not world then
			return
		end
		for _, instance in world:GetDescendants() do
			add(instance)
		end
		world.DescendantAdded:Connect(add)
		world.DescendantRemoving:Connect(function(instance)
			if instance:IsA("Light") then
				fixtures[instance] = nil
			end
		end)
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
