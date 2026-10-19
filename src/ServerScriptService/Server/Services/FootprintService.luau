--!strict
--[[
	Rastro molhado: quem toma chuva lá fora deixa pegadas dentro de casa (o cliente desenha; aqui só a regra).
	O servidor calcula o próprio "molhado" (Weather.wetness, telhado por raycast) e guarda as pegadas de cada
	jogador (FootTrail). Se o Tung Tung passar perto de uma pegada fresca, ele segue o rastro até a mais nova.
	Não bloqueia progresso: é só mais um jeito de ele achar quem anda molhado (as pegadas secam em ~40 s).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FootTrail = require("@game/ReplicatedStorage/Shared/Game/FootTrail")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Weather = require("@game/ReplicatedStorage/Shared/Game/Weather")
local CreatureService = require("./CreatureService")

local FootprintService = {
	Name = "FootprintService",
}

-- Distância (studs) em que ele sente a pegada e intervalo mínimo entre "faros" por jogador.
local SCENT_RANGE = 9
local SCENT_COOLDOWN = 3

type Body = { wet: number, outdoor: number, last: Vector3?, trail: FootTrail.Trail, sniffedAt: number }
local bodies: { [Player]: Body } = {}

function FootprintService.trail(player: Player): FootTrail.Trail?
	local body = bodies[player]
	return if body then body.trail else nil
end

function FootprintService.Start()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = true
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.25 then
			return
		end
		local step = clock
		clock = 0
		local now = os.clock()
		local world = workspace:FindFirstChild(Tags.WorldFolder)
		params.FilterDescendantsInstances = if world then { world } else {}
		local feet = CreatureService.feetPosition()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
				bodies[player] = nil
				continue
			end
			local body = bodies[player]
			if not body then
				body = { wet = 0, outdoor = 0, last = nil, trail = FootTrail.new(), sniffedAt = 0 }
				bodies[player] = body
			end
			local roofed = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 80, 0), params)
			body.outdoor = if roofed then 0 else 1
			body.wet = Weather.wetness(body.wet, body.outdoor, step)
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			local hidden = player:GetAttribute("Hidden")
			if Weather.footprintAlpha(body.wet) > 0 and body.outdoor < 0.5 and grounded and not hidden then
				local at = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
				local last = body.last
				if not last or (at - last).Magnitude >= Weather.FootprintStride then
					FootTrail.add(body.trail, at.X, at.Y, at.Z, now)
					body.last = at
				end
			else
				body.last = nil
			end
			FootTrail.prune(body.trail, now, Weather.FootprintLife)
			if feet and now - body.sniffedAt >= SCENT_COOLDOWN then
				local target =
					FootTrail.scent(body.trail, feet.X, feet.Y, feet.Z, now, SCENT_RANGE, Weather.FootprintLife)
				if target then
					body.sniffedAt = now
					CreatureService.followScent(Vector3.new(target.x, target.y, target.z))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		bodies[player] = nil
	end)
end

return FootprintService
