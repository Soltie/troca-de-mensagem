--!strict
--[[
	Movimento dos móveis-pessoa, só no cliente (o servidor continua dono da posição):
	- A cadeira de balanço da Dona Cida balança sempre, devagar, como quem respira; perto de alguém ela balança um
	  pouco mais (está olhando); quando ela fala (FurnitureMotionController.talk), balança rápido e inclina para quem
	  está perto. Rangido no fim de cada ida e volta.
	O servidor também move a cadeira (porta que troca, susto no escuro): a base é relida sempre que a posição real
	muda, então o balanço daqui nunca briga com o servidor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AudioController = require("./AudioController")

local FurnitureMotionController = {
	Name = "FurnitureMotionController",
}

type Rocker = {
	model: Model,
	home: CFrame,
	-- Última pose escrita por este cliente (para saber se foi o servidor que moveu).
	written: CFrame?,
	phase: number,
	lastSign: number,
}

local rockers: { [Model]: Rocker } = {}
local talkUntil = 0

-- Amplitude (graus) e frequência (Hz) do balanço em cada estado.
local CALM = { amp = 2.2, hz = 0.32 }
local NEAR = { amp = 4, hz = 0.45 }
local TALK = { amp = 9, hz = 0.95 }
local NEAR_RANGE = 12

local function isRocker(inst: Instance): boolean
	return inst:IsA("Model") and string.find(inst.Name, "RockingChair", 1, true) ~= nil
end

local function track(model: Model)
	if rockers[model] then
		return
	end
	rockers[model] = { model = model, home = model:GetPivot(), written = nil, phase = math.random() * 6, lastSign = 1 }
end

local function nearestDistance(position: Vector3): number
	local best = math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			best = math.min(best, (root.Position - position).Magnitude)
		end
	end
	return best
end

-- A Dona Cida falou (legenda dela na tela): a cadeira balança rápido por `seconds` s.
function FurnitureMotionController.talk(seconds: number?)
	talkUntil = os.clock() + (seconds or 3.5)
end

local function step(dt: number)
	local now = os.clock()
	for model, r in rockers do
		if not model.Parent then
			rockers[model] = nil
			continue
		end
		local pivot = model:GetPivot()
		-- O servidor moveu a cadeira (troca de sala ou susto): a nova posição vira a base.
		local written = r.written
		if not written or (pivot.Position - written.Position).Magnitude > 0.05 then
			r.home = pivot
		end
		local distance = nearestDistance(r.home.Position)
		local mode = if now < talkUntil and distance < 30 then TALK elseif distance < NEAR_RANGE then NEAR else CALM
		r.phase += dt * mode.hz * math.pi * 2
		local s = math.sin(r.phase)
		-- Balanço com peso: mais tempo nos extremos (curva achatada) e um leve "tranco" de madeira ao voltar.
		local angle = math.rad(mode.amp) * math.sign(s) * math.abs(s) ^ 0.75
		local sign = if s >= 0 then 1 else -1
		if sign ~= r.lastSign then
			r.lastSign = sign
			if mode ~= CALM then
				local any = model:FindFirstChildWhichIsA("BasePart", true)
				if any then
					local creak =
						AudioController.playAt("CreakWood", any, if mode == TALK then 0.9 else 0.45, 0.75 + 0.1 * sign)
					creak.RollOffMaxDistance = 40
				end
			end
		end
		-- Pivô do balanço no chão, sob o assento (base das pernas curvas).
		local pose = r.home * CFrame.Angles(angle, 0, 0)
		model:PivotTo(pose)
		r.written = pose
	end
end

function FurnitureMotionController.Start()
	local function scan(inst: Instance)
		if isRocker(inst) then
			track(inst :: Model)
		end
	end
	for _, d in workspace:GetDescendants() do
		scan(d)
	end
	workspace.DescendantAdded:Connect(scan)
	RunService.RenderStepped:Connect(step)
end

return FurnitureMotionController
