--!strict
--[[
	Corrida roteirizada da fuga do capítulo 5 (ideia M; regras em Shared/Game/EscapeRun). Liga junto com o incêndio
	(atributos BlazeStart/BlazeSeed do mundo) e segue quem vai na frente pelo caminho de fuga:
	- bate as portas dos cômodos ao lado depois que o grupo passa;
	- derruba duas vigas em chamas no corredor do porão, à frente (peças sólidas: é preciso pular);
	- desaba o corredor atrás do grupo: entulho sólido vai fechando o caminho e quem fica para trás leva pancada
	  (CampaignRuntime registra o callback, causa "collapse").
	O cliente (EscapeRunController) põe fogo nas vigas e desenha o teto caindo, a poeira e o barulho.
	Tudo fica em Workspace.EscapeRun (atributo CollapseAt = início do desabamento, hora do servidor).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EscapeRun = require("@game/ReplicatedStorage/Shared/Game/EscapeRun")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local FireService = require("./FireService")
local WorldService = require("./WorldService")

local EscapeRunService = {
	Name = "EscapeRunService",
}

local TICK = 0.1
local log = Logger.new("EscapeRunService")
local FLOOR_Y = -16
local CEILING_Y = -1.2
-- Altura do corpo (HumanoidRootPart) em pé no chão do porão e quanto acima disso conta como "pulando".
local STANDING_Y = -12.4
local JUMP_CLEAR = 0.7

type Run = {
	seed: number,
	folder: Folder,
	beams: { [number]: BasePart },
	slammed: { [string]: boolean },
	doors: { { id: string, s: number, off: number } },
	collapseAt: number?,
	rubbleUpTo: number,
	caught: { [Player]: boolean },
}

local caughtCallbacks: { (Player) -> () } = {}
local run: Run? = nil
local rng = Random.new()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = true

function EscapeRunService.onCaught(callback: (Player) -> ())
	table.insert(caughtCallbacks, callback)
end

local function finish()
	local current = run
	if current then
		current.folder:Destroy()
		run = nil
	end
end

local function begin(seed: number)
	finish()
	local folder = Instance.new("Folder")
	folder.Name = "EscapeRun"
	folder.Parent = workspace
	-- Portas ao lado do caminho, projetadas uma vez.
	local doors = {}
	local ok, world = pcall(WorldService.get)
	if ok and world and world.doors then
		for id, door in world.doors do
			local center = door.center
			local s, off = EscapeRun.project(center.X, center.Y - 3, center.Z)
			if off >= EscapeRun.OnRoute and off <= EscapeRun.SlamReach then
				table.insert(doors, { id = id, s = s, off = off })
			end
		end
		params.FilterDescendantsInstances = { world.root }
	end
	run = {
		seed = seed,
		folder = folder,
		beams = {},
		slammed = {},
		doors = doors,
		collapseAt = nil,
		rubbleUpTo = EscapeRun.Collapse.from,
		caught = {},
	}
end

-- Largura do corredor no ponto (de parede a parede no eixo X; o corredor do porão corre em Z).
local function span(center: Vector3): (number, number)
	local left = workspace:Raycast(center, Vector3.new(-20, 0, 0), params)
	local right = workspace:Raycast(center, Vector3.new(20, 0, 0), params)
	local a = if left then left.Position.X else center.X - 7.5
	local b = if right then right.Position.X else center.X + 7.5
	return a, b
end

-- Viga em chamas despencando do teto e ficando atravessada no chão (sólida).
local function dropBeam(current: Run, index: number, at: number): BasePart
	local x, _, z = EscapeRun.point(at)
	local probe = Vector3.new(x, FLOOR_Y + 3, z)
	local a, b = span(probe)
	local length = b - a - 0.4
	local mid = Vector3.new((a + b) / 2, 0, z)
	local beam = Instance.new("Part")
	beam.Name = `EscapeBeam{index}`
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(length, 1.7, 1.7)
	beam.Material = Enum.Material.Wood
	beam.Color = Color3.fromRGB(46, 30, 22)
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = true
	-- Um lado apoiado num monte de entulho: o topo fica entre 1,7 e 2,2 (pula, não passa por cima andando).
	local tilt = if index % 2 == 0 then 0.03 else -0.03
	local rest = CFrame.new(mid.X, FLOOR_Y + 1.2, mid.Z) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), tilt)
	local high = CFrame.new(mid.X, CEILING_Y - 1, mid.Z) * CFrame.Angles(0.5, 0, tilt * 4)
	beam.CFrame = high
	beam:SetAttribute("LandAt", workspace:GetServerTimeNow() + EscapeRun.BeamFall)
	beam.Parent = current.folder
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < EscapeRun.BeamFall and beam.Parent do
			local k = (os.clock() - t0) / EscapeRun.BeamFall
			beam.CFrame = high:Lerp(rest, k * k)
			task.wait()
		end
		if beam.Parent then
			beam.CFrame = rest
			beam.CanCollide = true
		end
	end)
	return beam
end

-- Entulho sólido onde o teto já caiu (fecha o caminho de volta).
local function rubble(current: Run, s: number)
	local x, _, z = EscapeRun.point(s)
	local a, b = span(Vector3.new(x, FLOOR_Y + 3, z))
	for _ = 1, 3 do
		local piece = Instance.new("Part")
		piece.Name = "CollapseRubble"
		piece.Anchored = true
		piece.Material = if rng:NextNumber() < 0.5 then Enum.Material.Slate else Enum.Material.Wood
		piece.Color = if piece.Material == Enum.Material.Slate
			then Color3.fromRGB(62, 58, 54)
			else Color3.fromRGB(40, 28, 22)
		piece.Size = Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.5, 5), rng:NextNumber(2, 4))
		piece.CFrame = CFrame.new(
			rng:NextNumber(a + 1.5, b - 1.5),
			FLOOR_Y + piece.Size.Y / 2 - 0.3,
			z + rng:NextNumber(-1.5, 1.5)
		) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
		piece.Parent = current.folder
	end
end

local function step()
	local world = WorldService.get()
	local root = world and world.root
	local seed = root and root:GetAttribute("BlazeSeed")
	local start = root and root:GetAttribute("BlazeStart")
	if type(seed) ~= "number" or type(start) ~= "number" then
		finish()
		return
	end
	local current = run
	if not current or current.seed ~= seed then
		begin(seed)
		current = run
	end
	if not current then
		return
	end
	-- Quem está no caminho, e quem vai na frente.
	local runners: { { player: Player, s: number, off: number, at: Vector3 } } = {}
	local leader = -math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		if player:GetAttribute("CampaignStatus") == "Active" and body and body:IsA("BasePart") then
			local p = body.Position
			local s, off = EscapeRun.project(p.X, p.Y - 3, p.Z)
			table.insert(runners, { player = player, s = s, off = off, at = p })
			if off <= EscapeRun.OnPath then
				leader = math.max(leader, s)
			end
		end
	end
	if leader == -math.huge then
		return
	end
	for _, door in current.doors do
		if not current.slammed[door.id] and EscapeRun.shouldSlam(door.s, door.off, leader) then
			current.slammed[door.id] = true
			if WorldService.doorState(door.id) ~= "closed" then
				WorldService.slamDoor(door.id)
			end
		end
	end
	for index, beam in EscapeRun.Beams do
		if not current.beams[index] and leader >= beam.trigger then
			current.beams[index] = dropBeam(current, index, beam.at)
		end
	end
	-- Chão em chamas dos dois lados da viga caída: quem atravessa andando se queima; quem pula passa limpo
	-- (no ar o corpo fica acima de STANDING_Y + JUMP_CLEAR na maior parte da faixa).
	for _, beam in current.beams do
		if beam.Parent and beam.CanCollide then
			for _, runner in runners do
				local p = runner.at
				if
					math.abs(p.Z - beam.Position.Z) <= EscapeRun.BurnBand
					and math.abs(p.X - beam.Position.X) <= beam.Size.X / 2
					and p.Y <= STANDING_Y + JUMP_CLEAR
				then
					FireService.scorch(runner.player, TICK * EscapeRun.BurnRate)
				end
			end
		end
	end
	local now = workspace:GetServerTimeNow()
	if not current.collapseAt and leader >= EscapeRun.Collapse.trigger then
		current.collapseAt = now
		current.folder:SetAttribute("CollapseAt", now)
	end
	local collapseAt = current.collapseAt
	if collapseAt then
		local front = EscapeRun.collapseFront(now - collapseAt)
		-- Entulho a cada 6 studs, um pouco atrás da frente (o teto cai antes, o monte fica).
		while current.rubbleUpTo + 6 <= front - 2 do
			current.rubbleUpTo += 6
			rubble(current, current.rubbleUpTo)
		end
		for _, runner in runners do
			if not current.caught[runner.player] and EscapeRun.caught(front, runner.s, runner.off) then
				current.caught[runner.player] = true
				for _, callback in caughtCallbacks do
					task.spawn(callback, runner.player)
				end
			end
		end
	end
end

function EscapeRunService.Start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < TICK then
			return
		end
		clock = 0
		local ok: boolean, err: any = pcall(step)
		if not ok then
			log.warn("step failed: %s", tostring(err))
		end
	end)
end

return EscapeRunService
