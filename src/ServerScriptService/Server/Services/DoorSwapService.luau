--!strict
--[[
	A Porta que Troca (aprovada pelo crítico, 9,1; só no modo História). A casa é o corpo do Tum Tum e brinca com as
	portas. Regras desta versão (cap. 1, uma troca sutil, sem o Tum Tum):
	- Gatilho: a 3ª chave sai do cômodo e a porta dele para o hall bate e fecha sozinha na mesma hora.
	- Aviso de 3 s: a porta bate sozinha, cai serragem do batente e vêm três batidas abafadas; ela não abre.
	- Quem abrir primeiro atravessa para outro cômodo já visitado (chave na sala → sala de jantar; chave na cozinha
	  ou na sala de jantar → sala de estar). Por 3 s, quem passar pela mesma porta vai junto. Depois ela volta ao
	  normal. Se ninguém abrir em 20 s, a troca se desfaz com um rangido.
	- No destino, a cadeira da Dona Cida está virada para a porta e ela fala.
	- Portas com o entalhe do Tum Tum pequeno nunca trocam (o corredor das três chaves).
	O cliente (DoorSwapController) faz o escurecimento de 0,2 s com a serragem no rosto e a fala.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Activities = require("../Campaign/HouseActivities")
local Build = require("../World/Build")
local WorldService = require("./WorldService")

local DoorSwapService = {
	Name = "DoorSwapService",
}

local log = Logger.new("DoorSwap")

DoorSwapService.LINE = "Ele está brincando com vocês... a porta com o desenho dele ele não mexe."

-- Porta de cada cômodo para o hall (DoorWall em x = ±8, no meio do cômodo), o ponto de chegada lá dentro e onde a
-- cadeira da Dona Cida espera (o modelo da cadeira tem a frente no +Z: o pivô olha para longe da porta).
type Room = { door: Vector3, arrive: CFrame, chair: CFrame }
local ROOMS: { [string]: Room } = {
	Living = {
		door = Vector3.new(-8, 5, -4),
		arrive = CFrame.lookAt(Vector3.new(-12.5, 3.6, -4), Vector3.new(-30, 3.6, -4)),
		chair = CFrame.lookAt(Vector3.new(-20, 0, -4), Vector3.new(-32, 0, -4)),
	},
	Kitchen = {
		door = Vector3.new(8, 5, -4),
		arrive = CFrame.lookAt(Vector3.new(12.5, 3.6, -4), Vector3.new(30, 3.6, -4)),
		chair = CFrame.lookAt(Vector3.new(20, 0, -4), Vector3.new(32, 0, -4)),
	},
	Dining = {
		door = Vector3.new(-8, 5, -36),
		arrive = CFrame.lookAt(Vector3.new(-12.5, 3.6, -36), Vector3.new(-30, 3.6, -36)),
		chair = CFrame.lookAt(Vector3.new(-20, 0, -36), Vector3.new(-32, 0, -36)),
	},
}
local DESTINATION: { [string]: string } = { Living = "Dining", Kitchen = "Living", Dining = "Living" }

local WARNING = 3
local CARRY = 3
local UNDO = 20

type Swap = { doorId: string, from: string, to: string, armedAt: number, openUntil: number?, triggered: boolean }
local current: Swap? = nil
local keysThisChapter: { [string]: boolean } = {}
local keysPlan: any = nil

local function doorIdNear(position: Vector3): string?
	local root = Workspace:FindFirstChild("CursedHouse")
	local doors = root and root:FindFirstChild("Doors")
	if not doors then
		return nil
	end
	local best, bestDistance = nil, 7
	-- Cada porta é uma peça (o painel) ou um modelo com o nome do id usado pelo WorldService.
	for _, child in doors:GetChildren() do
		local door = WorldService.door(child.Name)
		if door then
			local center = door.center
			local d = (Vector3.new(center.X, position.Y, center.Z) - position).Magnitude
			if d < bestDistance then
				best, bestDistance = child.Name, d
			end
		end
	end
	return best
end

local function sawdustAndKnocks(at: Vector3)
	local anchor = Build.part(
		Workspace,
		"DoorSwapNoise",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(at),
		Color3.new(),
		{ collide = false, query = false, transparency = 1 }
	)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 168, 120))
	dust.Size = NumberSequence.new(0.25, 0.05)
	dust.Speed = NumberRange.new(1, 3)
	dust.Lifetime = NumberRange.new(1, 1.6)
	dust.Acceleration = Vector3.new(0, -8, 0)
	dust.Rate = 0
	dust.Parent = anchor
	dust:Emit(40)
	for n = 0, 2 do
		task.delay(0.6 + n * 0.55, function()
			local knock = Build.sound(anchor, "Knock", Audio.DoorBang.id, 0.55, 0.7)
			knock:Play()
		end)
	end
	task.delay(5, function()
		anchor:Destroy()
	end)
end

local function moveChair(to: CFrame)
	local root = Workspace:FindFirstChild("CursedHouse")
	if not root then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, "RockingChair", 1, true) then
			d:PivotTo(to)
			return
		end
	end
end

local function finish(reason: string)
	local swap = current
	if not swap then
		return
	end
	current = nil
	ReplicatedStorage:SetAttribute("DoorSwapArmed", nil)
	log.info("swap %s ended (%s)", swap.doorId, reason)
end

-- Arma a troca na porta do cômodo `room` para o hall (cap. 1: chamado quando a 3ª chave sai daquele cômodo).
function DoorSwapService.arm(room: string)
	local spec = ROOMS[room]
	local destination = DESTINATION[room]
	if not spec or not destination then
		return
	end
	local id = doorIdNear(spec.door)
	if not id then
		log.warn("no door near %s", room)
		return
	end
	current = { doorId = id, from = room, to = destination, armedAt = os.clock(), triggered = false }
	-- Para depuração e testes: qual porta está armada (some quando a troca termina).
	ReplicatedStorage:SetAttribute("DoorSwapArmed", id)
	-- Crítico (rodada 2): a porta bate e fecha sozinha no instante em que a chave sai, então ninguém passa por ela
	-- aberta sem a troca. O aviso de 3 s começa aqui.
	local door = WorldService.door(id)
	if door and current then
		current.triggered = true
		current.armedAt = os.clock()
		WorldService.slamDoor(id)
		sawdustAndKnocks(door.center + Vector3.new(0, 4, 0))
	end
end

-- Chamado pelo RoundService antes de abrir uma porta. Devolve uma resposta quando a troca cuida da porta.
function DoorSwapService.intercept(player: Player, id: string): { [string]: any }?
	local swap = current
	if not swap or swap.doorId ~= id or not swap.triggered then
		return nil
	end
	local now = os.clock()
	if not swap.openUntil then
		if now - swap.armedAt < WARNING then
			-- Durante o aviso a porta não abre.
			WorldService.rattleDoor(id)
			return { accepted = false, message = "door_locked", kind = "DoorLocked" }
		end
		swap.openUntil = now + CARRY
		moveChair(ROOMS[swap.to].chair)
	end
	if now > (swap.openUntil :: number) then
		finish("carried")
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- O escurecimento do cliente cobre o salto; a direção do olhar segue para dentro do cômodo novo.
		player:SetAttribute("DoorSwapAt", Workspace:GetServerTimeNow())
		task.delay(0.1, function()
			root.CFrame = ROOMS[swap.to].arrive
		end)
	end
	return { accepted = true, message = "door_swapped", kind = "Door" }
end

function DoorSwapService.Start()
	-- Cap. 1: a terceira chave (de qualquer cômodo) arma a troca da porta daquele cômodo.
	Activities.onSolved(function(plan, index)
		if plan.stage ~= 1 or plan.mode ~= "Story" then
			return
		end
		local spec = plan.activities[index]
		if not spec or type(spec.item) ~= "string" or not string.find(spec.item, "key_", 1, true) then
			return
		end
		-- Capítulo recomeçado (plano novo): conta de novo.
		if keysPlan ~= plan then
			keysPlan = plan
			table.clear(keysThisChapter)
		end
		keysThisChapter[spec.item] = true
		local count = 0
		for _ in keysThisChapter do
			count += 1
		end
		if count >= 3 then
			table.clear(keysThisChapter)
			DoorSwapService.arm(spec.room)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local swap = current
			if not swap then
				continue
			end
			-- Saiu do cap. 1 (capítulo novo, derrota, menu): nada fica armado.
			local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
			if not campaign or campaign:GetAttribute("Stage") ~= 1 then
				finish("chapter")
				continue
			end
			local door = WorldService.door(swap.doorId)
			if not door then
				finish("missing")
				continue
			end
			if not swap.triggered then
				-- Gatilho: alguém do lado de dentro chega a 5 studs da porta.
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and (root.Position - door.center).Magnitude < 5 then
						swap.triggered = true
						swap.armedAt = os.clock()
						WorldService.slamDoor(swap.doorId)
						sawdustAndKnocks(door.center + Vector3.new(0, 4, 0))
						break
					end
				end
			elseif not swap.openUntil and os.clock() - swap.armedAt > UNDO then
				-- Ninguém abriu: a troca se desfaz com um rangido (no cap. 1, sem castigo).
				local creak = Build.sound(door.panel, "SwapUndo", Audio.CreakWood.id, 0.8, 0.6)
				creak:Play()
				task.delay(4, function()
					creak:Destroy()
				end)
				finish("undone")
			end
		end
	end)
end

-- Capítulo novo ou partida nova: nada armado.
function DoorSwapService.reset()
	current = nil
	table.clear(keysThisChapter)
end

return DoorSwapService
