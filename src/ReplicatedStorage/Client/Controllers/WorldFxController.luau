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

local rng = Random.new()
local surgeUntil = 0
local snapshot: GameState.Snapshot? = nil

local function lightOf(part: BasePart): Light?
	return part:FindFirstChildWhichIsA("Light")
end

local function step()
	local now = os.clock()
	local surging = now < surgeUntil
	local s = snapshot
	for _, instance in CollectionService:GetTagged(Tags.PowerLight) do
		if instance:IsA("BasePart") then
			local light = lightOf(instance)
			if light then
				local base = (instance:GetAttribute("BaseBrightness") :: number?) or light.Brightness
				local kind = instance:GetAttribute(Tags.Attr.LightKind)
				local factor = 1
				if instance:GetAttribute(Tags.Attr.Flicker) == true and rng:NextNumber() < 0.18 then
					factor = rng:NextNumber(0.05, 0.5)
				end
				if kind == "Lamp" and rng:NextNumber() < 0.01 then
					factor = 0.2 -- lâmpadas velhas falham de vez em quando
				end
				if surging and kind ~= "Exit" then
					factor = if rng:NextNumber() < 0.5 then rng:NextNumber(0, 0.25) else rng:NextNumber(0.8, 1.6)
				end
				if kind == "Beacon" then
					local on = s ~= nil and s.powerOn and (now * 2.5) % 2 < 1
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

-- Pico de falha nas luzes por `duration` segundos.
function WorldFxController.surge(duration: number)
	surgeUntil = math.max(surgeUntil, os.clock() + duration)
end

function WorldFxController.Start()
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
		accumulator += dt
		if accumulator >= 1 / Config.Visual.FlickerRate then
			accumulator = 0
			step()
		end
	end)
end

return WorldFxController
