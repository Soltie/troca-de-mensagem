--!strict
--[[
	Puzzles do cap. 1 do banco v2 (roteiro "A Casa de Madeira"). A resposta nunca está escrita: vem de ouvir, olhar
	ou apagar a luz. Erro não zera nada; ele faz barulho e abre os Olhos no Veio (no cap. 1 o Tum Tum ainda dorme).
	- A Caixinha da Lia (chave da Lia): um de seis móveis de busca tem a caixinha tocando a música do sahur. Com
	  alguma lanterna acesa perto, ela para (tem medo de luz). O jogador apaga a luz e segue o som 3D.
	- A Tábua Oca (chave do Juca): seis tábuas soltas no chão. Bater (E) faz toc: a certa soa oca e grave, as outras
	  cheias. Bater de novo levanta; a errada estala alto (erro). Embaixo da oca: a chave e o pião do Juca.
	- O Banquinho que Foge (chave do Valdemar): a chave está num prego na viga alta. Dois banquinhos empilhados nas
	  marcas gastas do chão alcançam. Um dos três tem um boné no assento: é gente da vila. Usado com a lanterna
	  acesa, ele foge e a pilha desmonta (erro).
	Cada alvo tem `handle(player)`, chamado pelo CampaignRuntime antes da regra comum da tarefa:
	"solve" recolhe o item; "ok" só avança; "no" recusa sem castigo; "error" faz barulho (o runtime chama o Tum Tum).
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local PuzzleStyles = require("@game/ReplicatedStorage/Shared/Game/PuzzleStyles")
local SahurMelody = require("@game/ReplicatedStorage/Shared/Game/SahurMelody")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local HouseArt = require("../World/HouseArt")
local TaskProps = require("../World/HouseTaskProps")

local Mini = {}

export type Result = "solve" | "ok" | "no" | "loud" | "error"
export type Target = {
	taskId: string,
	button: number,
	focus: BasePart,
	-- Alvo bloqueado até outro passo liberar (a chave na viga antes da pilha de banquinhos).
	locked: boolean?,
	-- Usável antes de a tarefa ficar pronta (o quadro de luz recebe cada fusível assim que ele chega).
	anyTime: boolean?,
	handle: (player: Player) -> (Result, string),
}

local LOOSE = Color3.fromRGB(150, 112, 76)
local WOOD = Color3.fromRGB(92, 60, 38)
local DARK = Color3.fromRGB(52, 34, 24)
local BRASS = Color3.fromRGB(176, 136, 64)
local rng = Random.new()

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, collide: boolean?)
	return Build.part(parent, name, size, cframe, color, {
		material = Enum.Material.Wood,
		collide = collide == true,
		query = false,
	})
end

local function interactable(focus: BasePart, id: string, prompt: string, distance: number)
	focus.CanQuery = true
	focus:SetAttribute(Tags.Attr.InteractId, id)
	focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
	focus:SetAttribute(Tags.Attr.InteractDistance, distance)
	focus:SetAttribute(Tags.Attr.InteractEnabled, false)
	CollectionService:AddTag(focus, Tags.Interactable)
end

local function play(at: BasePart, clip: string, volume: number, speed: number, reach: number?)
	local info = Audio[clip]
	if not info then
		return
	end
	local sound = Build.sound(at, clip, info.id, volume, speed)
	sound.RollOffMaxDistance = reach or 80
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function flashlightNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and player:GetAttribute(Tags.Attr.Flashlight) == true
			and (root.Position - position).Magnitude < radius
		then
			return true
		end
	end
	return false
end

-- Badalada grave do relógio (erro nos puzzles de relógio): `count` batidas espaçadas, alto e de longe.
local function chime(at: BasePart, count: number)
	for n = 1, count do
		task.delay((n - 1) * 0.8, function()
			if at.Parent then
				play(at, "PianoKey", 2.4, 0.38, 140)
			end
		end)
	end
end

-- Olhos no Veio: dois olhos acendem na madeira perto do erro e somem (aviso de que a casa viu).
function Mini.eyes(position: Vector3)
	local folder = Instance.new("Model")
	folder.Name = "EyesInTheGrain"
	folder.Parent = workspace
	-- Acha a parede mais próxima (4 direções) e põe os olhos nela, à altura do rosto, virados para o cômodo. Sem parede
	-- por perto, ficam no ar a 4 studs do erro.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local origin = position + Vector3.new(0, 4.2, 0)
	local best: RaycastResult? = nil
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hit = workspace:Raycast(origin, dir * 14, params)
		if hit and math.abs(hit.Normal.Y) < 0.3 and (not best or hit.Distance < best.Distance) then
			best = hit
		end
	end
	local spot = if best then best.Position + best.Normal * 0.15 else origin + Vector3.xAxis * 4
	local normal = if best then best.Normal else -Vector3.xAxis
	local right = normal:Cross(Vector3.yAxis).Unit
	local first: BasePart? = nil
	for _, x in { -0.55, 0.55 } do
		local eye = Build.part(
			folder,
			"Eye",
			Vector3.new(0.5, 0.26, 0.12),
			CFrame.lookAt(spot + right * x, spot + right * x + normal),
			Color3.fromRGB(255, 120, 40),
			{ material = Enum.Material.Neon, collide = false, query = false }
		)
		eye.CastShadow = false
		eye.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 110, 40), 7, 0
		glow.Parent = eye
		TweenService:Create(eye, TweenInfo.new(0.35), { Transparency = 0 }):Play()
		TweenService:Create(glow, TweenInfo.new(0.35), { Brightness = 1.6 }):Play()
		first = first or eye
	end
	if first then
		play(first, "CreakWood", 1, 0.7, 70)
	end
	-- Pisca uma vez antes de sumir.
	task.delay(2.6, function()
		for _, eye in folder:GetChildren() do
			if eye:IsA("BasePart") then
				TweenService:Create(eye, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(folder, 3.5)
end

-- Caixinha da Lia: liga a música no móvel certo (já montado pelo HiddenStash) até ele ser aberto.
function Mini.musicBox(focus: BasePart, isOpen: () -> boolean, seed: number)
	local notes = SahurMelody.full(seed)
	-- Ao abrir o móvel certo, a caixinha de música aparece ao lado da chave (crítico: "sem caixinha visível").
	local box = Build.part(
		focus,
		"MusicBoxVisible",
		Vector3.new(1, 0.6, 0.7),
		focus.CFrame * CFrame.new(0.9, 0, 0),
		Color3.fromRGB(104, 66, 40),
		{ material = Enum.Material.Wood, collide = false, query = false, transparency = 1 }
	)
	local crank = Build.part(
		box,
		"MusicBoxCrank",
		Vector3.new(0.12, 0.12, 0.45),
		box.CFrame * CFrame.new(0.55, 0.1, 0),
		Color3.fromRGB(190, 150, 70),
		{ material = Enum.Material.Metal, collide = false, query = false, transparency = 1 }
	)
	task.spawn(function()
		while focus.Parent and not isOpen() do
			task.wait(0.3)
		end
		box.Transparency, crank.Transparency = 0, 0
		task.wait(3)
		box.Transparency, crank.Transparency = 1, 1
	end)
	task.spawn(function()
		while focus.Parent and not isOpen() do
			if flashlightNear(focus.Position, 26) then
				-- Com luz por perto ela fica muda (tem medo, como os móveis).
				task.wait(0.5)
				continue
			end
			for _, note in notes do
				if isOpen() or flashlightNear(focus.Position, 26) then
					break
				end
				play(focus, "PianoKey", 0.9, PuzzleStyles.PIANO_PITCH[note] * 1.9, 70)
				task.wait(0.38)
			end
			task.wait(1.4)
		end
	end)
end

-- Tábua Oca: seis tábuas soltas; `spot(avoid)` devolve um ponto livre no chão do cômodo.
function Mini.planks(root: Instance, spec: any, spot: ({ Vector3 }) -> Vector3, distance: number): { [string]: Target }
	local model = Build.model(root, `planks_{spec.id}`)
	local hollow = rng:NextInteger(1, 6)
	local taken: { Vector3 } = {}
	local targets: { [string]: Target } = {}
	for n = 1, 6 do
		local at = spot(taken)
		table.insert(taken, at)
		-- Irregulares (crítico, rodada 2): ângulo, comprimento e leve inclinação próprios.
		local yaw = (if rng:NextNumber() < 0.5 then 0 else 90) + rng:NextNumber() * 50 - 25
		local length = 3.6 + rng:NextNumber() * 1.8
		local tilt = (rng:NextNumber() - 0.5) * math.rad(5)
		local frame = CFrame.new(at + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, math.rad(yaw), tilt)
		local plank =
			part(model, `plank_{spec.id}_{n}`, Vector3.new(0.9 + rng:NextNumber() * 0.8, 0.14, length), frame, LOOSE)
		-- Prego saltado: o sinal de tábua solta ensinado no hall.
		Build.part(
			model,
			"LooseNail",
			Vector3.new(0.12, 0.3, 0.12),
			frame * CFrame.new(0.3, 0.14, length / 2 - 0.5),
			BRASS,
			{
				material = Enum.Material.Metal,
				collide = false,
				query = false,
			}
		)
		local id = `plank_{spec.id}_{n}`
		interactable(plank, id, "BATER NA TÁBUA", distance)
		local knocked = false
		local item: { BasePart } = {}
		if n == hollow then
			local holder = Instance.new("Model")
			holder.Name = "UnderPlank"
			holder.Parent = model
			TaskProps.build(holder, Vector3.zero, spec.item, "collect")
			pcall(function()
				local _, size = holder:GetBoundingBox()
				holder:ScaleTo(math.min(0.9 / math.max(size.X, size.Y, size.Z, 0.1), 1))
			end)
			holder:PivotTo(CFrame.new(at + Vector3.new(0, 0.3, 0)))
			-- O pião do Juca, com o barbante enrolado (prepara os fusíveis do cap. 2).
			Build.cylinder(
				holder,
				"JucaTop",
				at + Vector3.new(0.5, 0.35, -0.6),
				Vector3.yAxis,
				0.5,
				0.6,
				Color3.fromRGB(196, 60, 48),
				{ collide = false, query = false }
			)
			for _, d in holder:GetDescendants() do
				if d:IsA("BasePart") then
					d.Transparency = 1
					d.CanQuery = false
					d.CastShadow = false
					table.insert(item, d)
				end
			end
		end
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = plank,
			handle = function(_player: Player): (Result, string)
				if not knocked then
					knocked = true
					plank:SetAttribute(Tags.Attr.InteractPrompt, "LEVANTAR A TÁBUA")
					if n == hollow then
						-- Oca: toc grave, comprido.
						play(plank, "HammerNail", 1, 0.5, 60)
					else
						play(plank, "HammerNail", 0.8, 1.25, 60)
					end
					return "ok", "plank_knock"
				end
				if n ~= hollow then
					play(plank, "WoodSplinter", 1.2, 1, 90)
					return "error", "plank_wrong"
				end
				TweenService:Create(
					plank,
					TweenInfo.new(0.4),
					{ CFrame = frame * CFrame.new(1.4, 0.5, 0) * CFrame.Angles(0, 0, math.rad(70)) }
				):Play()
				for _, piece in item do
					piece.Transparency = 0
				end
				task.delay(2, function()
					for _, piece in item do
						piece.Transparency = 1
					end
				end)
				return "solve", "solved"
			end,
		}
	end
	return targets
end

-- Banquinho que Foge: a viga com a chave fica junto de `wall` (ponto no chão perto de uma parede, `facing` para
-- dentro do cômodo); os banquinhos começam espalhados em `spot(avoid)`.
function Mini.stools(
	root: Instance,
	spec: any,
	wall: Vector3,
	facing: Vector3,
	spot: ({ Vector3 }) -> Vector3,
	distance: number
): { [string]: Target }
	local model = Build.model(root, `stools_{spec.id}`)
	local frame = CFrame.lookAt(wall, wall + Vector3.new(facing.X, 0, facing.Z))
	-- Viga alta com o prego e a chave do Valdemar pendurada.
	part(model, "KeyBeam", Vector3.new(6, 0.8, 0.8), frame * CFrame.new(0, 9.2, 0.6), DARK)
	Build.part(model, "Nail", Vector3.new(0.1, 0.1, 0.5), frame * CFrame.new(0, 8.8, 0.2), BRASS, {
		material = Enum.Material.Metal,
		collide = false,
		query = false,
	})
	local holder = Instance.new("Model")
	holder.Name = "BeamKey"
	holder.Parent = model
	TaskProps.build(holder, Vector3.zero, spec.item, "collect")
	pcall(function()
		local _, size = holder:GetBoundingBox()
		holder:ScaleTo(math.min(0.8 / math.max(size.X, size.Y, size.Z, 0.1), 1))
	end)
	holder:PivotTo(frame * CFrame.new(0, 8.3, 0.2))
	-- Marcas gastas de pé de banquinho no chão (onde a pilha encaixa).
	local slot = frame * CFrame.new(0, 0, -1.6)
	Build.part(model, "StoolMarks", Vector3.new(1.8, 0.04, 1.8), slot * CFrame.new(0, 0.03, 0), DARK, {
		material = Enum.Material.Wood,
		collide = false,
		query = false,
	})
	local keyFocus = Build.part(
		model,
		`beamkey_{spec.id}`,
		Vector3.new(1.2, 1.2, 1.2),
		frame * CFrame.new(0, 8.3, 0.1),
		BRASS,
		{ collide = false, transparency = 1 }
	)
	interactable(keyFocus, `beamkey_{spec.id}`, "PEGAR A CHAVE NA VIGA", distance + 6)
	local person = rng:NextInteger(1, 3)
	local placed: { number } = {}
	type Stool = { base: CFrame, current: CFrame, parts: { BasePart }, focus: BasePart }
	local stools: { Stool } = {}
	local targets: { [string]: Target } = {}
	local keyTarget: Target = {
		taskId = spec.id,
		button = 1,
		focus = keyFocus,
		locked = true,
		handle = function(_player: Player): (Result, string)
			holder:Destroy()
			return "solve", "solved"
		end,
	}
	targets[`beamkey_{spec.id}`] = keyTarget
	-- Animação do Animador: o banquinho agacha e vai aos pulinhos (1 a 4 saltos de 1,1 stud, inclinando) até o destino.
	local function moveStool(stool: Stool, to: CFrame)
		local from = stool.current
		stool.current = to
		local relative: { [BasePart]: CFrame } = {}
		for _, piece in stool.parts do
			relative[piece] = from:ToObjectSpace(piece.CFrame)
		end
		local hops = math.clamp(math.ceil((to.Position - from.Position).Magnitude / 2.5), 1, 4)
		task.spawn(function()
			local duration = 0.22 * hops + 0.12
			local start = os.clock()
			while true do
				local t = math.min(1, (os.clock() - start) / duration)
				local squat = math.clamp((os.clock() - start) / 0.12, 0, 1)
				local travel = math.max(0, (os.clock() - start - 0.12) / (duration - 0.12))
				local hop = (travel * hops) % 1
				local height = if travel >= 1 then 0 else 1.1 * math.sin(hop * math.pi)
				local tilt = if travel >= 1 then 0 else math.rad(12) * math.cos(hop * math.pi)
				local sink = if travel > 0 then 0 else -0.15 * math.sin(squat * math.pi)
				local pose = from:Lerp(to, math.min(1, travel))
					* CFrame.new(0, height + sink, 0)
					* CFrame.Angles(tilt, 0, 0)
				for piece, rel in relative do
					piece.CFrame = pose * rel
				end
				if t >= 1 then
					break
				end
				task.wait(1 / 30)
			end
			for piece, rel in relative do
				piece.CFrame = to * rel
			end
		end)
	end
	local taken: { Vector3 } = {}
	for n = 1, 3 do
		local at = spot(taken)
		table.insert(taken, at)
		local base = CFrame.new(at) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0)
		local parts: { BasePart } = {}
		local seat = part(model, `stool_{spec.id}_{n}`, Vector3.new(1.7, 0.3, 1.7), base * CFrame.new(0, 2, 0), WOOD)
		table.insert(parts, seat)
		for _, leg in { { -0.6, -0.6 }, { 0.6, -0.6 }, { -0.6, 0.6 }, { 0.6, 0.6 } } do
			table.insert(
				parts,
				part(model, "StoolLeg", Vector3.new(0.22, 1.85, 0.22), base * CFrame.new(leg[1], 0.93, leg[2]), DARK)
			)
		end
		if n == person then
			-- Boné pequeno esquecido no assento: é gente da vila capturada anos atrás.
			table.insert(
				parts,
				Build.part(
					model,
					"TinyCap",
					Vector3.new(0.9, 0.35, 0.9),
					base * CFrame.new(0.1, 2.33, 0),
					Color3.fromRGB(44, 86, 160),
					{
						material = Enum.Material.Fabric,
						collide = false,
						query = false,
					}
				)
			)
		end
		local stool: Stool = { base = base, current = base, parts = parts, focus = seat }
		table.insert(stools, stool)
		local id = `stool_{spec.id}_{n}`
		interactable(
			seat,
			id,
			-- O banquinho de boné é gente da vila: a dica fica no próprio aviso, sem dar a resposta.
			if n == person
				then "LEVAR O BANQUINHO PARA AS MARCAS\nele não gosta de luz"
				else "LEVAR O BANQUINHO PARA AS MARCAS",
			distance
		)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = seat,
			handle = function(player: Player): (Result, string)
				if table.find(placed, n) or #placed >= 2 then
					return "no", "stool_ready"
				end
				if n == person and player:GetAttribute(Tags.Attr.Flashlight) == true then
					-- Com luz ele foge: corre para longe e a pilha desmonta.
					for _, other in placed do
						moveStool(stools[other], stools[other].base)
						targets[`stool_{spec.id}_{other}`].focus:SetAttribute(
							Tags.Attr.InteractPrompt,
							"LEVAR O BANQUINHO PARA AS MARCAS"
						)
					end
					table.clear(placed)
					keyTarget.locked = true
					for _, each in targets do
						if each ~= keyTarget then
							each.locked = false
						end
					end
					local away = stool.base * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
					moveStool(stool, away)
					stool.base = away
					play(seat, "WallScurry", 1, 1.3)
					play(seat, "WoodSplinter", 1, 0.8, 90)
					return "error", "stool_fled"
				end
				table.insert(placed, n)
				moveStool(stool, slot * CFrame.new(0, (#placed - 1) * 2.1, 0))
				play(seat, "CreakWood", 0.8, 1.2)
				-- Banquinho já na marca: sem aviso de "levar" (a trava tira o [E] do HouseActivities.refresh).
				targets[id].locked = true
				if #placed >= 2 then
					-- Pilha pronta: o terceiro banquinho também deixa de oferecer "levar".
					for _, each in targets do
						each.locked = each ~= keyTarget
					end
					keyTarget.locked = false
					return "ok", "stool_stack"
				end
				return "ok", "stool_placed"
			end,
		}
	end
	return targets
end

-- Fusíveis da Família (cap. 2): de quem é cada fusível e o desenho entalhado no encaixe da pessoa.
Mini.FUSE_OWNERS = table.freeze({
	fuse_1 = "CADEIRA", -- Dona Cida: enrolado em linha de tricô
	fuse_2 = "NOTA", -- Lia: enrolado na fita de cabelo
	fuse_3 = "PIÃO", -- Juca: enrolado no barbante do pião
} :: { [string]: string })
Mini.FUSE_WRAPS = table.freeze({
	fuse_1 = Color3.fromRGB(176, 44, 52),
	fuse_2 = Color3.fromRGB(232, 120, 170),
	fuse_3 = Color3.fromRGB(210, 190, 140),
} :: { [string]: Color3 })
Mini.CARRY_ATTRIBUTE = "CarryFuse"

-- Quadro de luz com três encaixes entalhados (cadeira de balanço, nota musical, pião), em ordem sorteada. Quem
-- carrega um fusível aperta o encaixe da pessoa dona do objeto enrolado nele. Certo: zumbe e acende a lâmpada
-- daquele desenho. Errado: faísca, o fusível volta para a mão e o Tum Tum vem (erro).
function Mini.fuseBoard(root: Instance, spec: any, at: Vector3, distance: number): { [string]: Target }
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Mini.CARRY_ATTRIBUTE, nil)
	end
	local model = Build.model(root, `fuseboard_{spec.id}`)
	local frame = CFrame.new(at)
	-- Quadro de luz do artista (FuseBox) atrás dos encaixes; sem ele, a tábua em bloco.
	HouseArt.swap(
		model,
		"FuseBox",
		CFrame.lookAt(at + Vector3.new(0, 0, -0.8), at + Vector3.new(0, 0, 1)),
		function(folder)
			part(folder, "BoardBack", Vector3.new(7, 5, 0.4), frame * CFrame.new(0, 4.5, -0.6), DARK, true)
		end
	)
	part(model, "BoardFrame", Vector3.new(7.4, 0.3, 0.6), frame * CFrame.new(0, 7.1, -0.5), WOOD)
	local owners = { "CADEIRA", "NOTA", "PIÃO" }
	for i = #owners, 2, -1 do
		local j = rng:NextInteger(1, i)
		owners[i], owners[j] = owners[j], owners[i]
	end
	local filled = 0
	local targets: { [string]: Target } = {}
	for n, owner in owners do
		local x = (n - 2) * 2.2
		local socket = Build.part(
			model,
			`fusesocket_{spec.id}_{n}`,
			Vector3.new(1.4, 1.8, 0.5),
			frame * CFrame.new(x, 3.8, -0.25),
			-- Cor decorativa sorteada: nunca é a pista.
			Color3.fromHSV(rng:NextNumber(), 0.35, 0.45),
			{ material = Enum.Material.Metal, collide = false, query = true }
		)
		Build.sign(
			model,
			"Carving",
			(frame * CFrame.new(x, 5.4, -0.35)).Position,
			Vector3.zAxis,
			Vector2.new(1.9, 0.8),
			owner,
			{ textColor = Color3.fromRGB(226, 196, 140), background = Color3.fromRGB(40, 26, 18), lit = false }
		)
		local lamp = Build.part(
			model,
			"OwnerLamp",
			Vector3.new(0.4, 0.4, 0.4),
			frame * CFrame.new(x, 6.4, -0.3),
			Color3.fromRGB(60, 50, 40),
			{ material = Enum.Material.Glass, collide = false, query = false }
		)
		local id = `fusesocket_{spec.id}_{n}`
		interactable(socket, id, `ENCAIXAR NO DESENHO: {owner}`, distance)
		local done = false
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = socket,
			anyTime = true,
			handle = function(player: Player): (Result, string)
				if done then
					return "no", "fuse_done"
				end
				local carry = player:GetAttribute(Mini.CARRY_ATTRIBUTE)
				if type(carry) ~= "string" then
					return "no", "fuse_need"
				end
				if Mini.FUSE_OWNERS[carry] ~= owner then
					play(socket, "BreakerFail", 1.2, 1, 90)
					return "error", "fuse_wrong"
				end
				done = true
				filled += 1
				player:SetAttribute(Mini.CARRY_ATTRIBUTE, nil)
				lamp.Material, lamp.Color = Enum.Material.Neon, Color3.fromRGB(255, 214, 140)
				play(socket, "BreakerToggle", 1, 0.9)
				if filled >= #owners then
					return "solve", "solved"
				end
				return "ok", "fuse_in"
			end,
		}
	end
	return targets
end

-- Tags lidas pelo cliente (DarkClueController): "DarkGlow" só aparece com a lanterna de quem olha apagada (e,
-- com o atributo FollowEyes, vira para a câmera); "FlashShadow" só aparece com a lanterna acesa e mirando perto.
Mini.DARK_GLOW = "DarkGlow"
Mini.FLASH_SHADOW = "FlashShadow"

-- O Retrato que Olha (cap. 3): seis retratos nas paredes; com a lanterna apagada, os olhos de um deles brilham
-- fraco e seguem quem anda. Tirar esse retrato revela a fotografia; tirar outro faz ele cair com estrondo (erro).
function Mini.portraits(
	root: Instance,
	spec: any,
	wallSpot: ({ Vector3 }) -> (Vector3, Vector3?),
	distance: number
): { [string]: Target }
	local model = Build.model(root, `portraits_{spec.id}`)
	local watcher = rng:NextInteger(1, 6)
	local taken: { Vector3 } = {}
	local targets: { [string]: Target } = {}
	for n = 1, 6 do
		local floor, facing = wallSpot(taken)
		table.insert(taken, floor)
		local out = facing or Vector3.zAxis
		local at = floor - out * 1.7 + Vector3.new(0, 5.6, 0)
		local frame = CFrame.lookAt(at, at + out)
		local canvas = Build.part(
			model,
			`portrait_{spec.id}_{n}`,
			Vector3.new(2.4, 3, 0.15),
			frame,
			Color3.fromHSV(rng:NextNumber(0.02, 0.12), 0.35, rng:NextNumber(0.25, 0.4)),
			{ material = Enum.Material.SmoothPlastic, collide = false, query = true }
		)
		local frameParts = { canvas }
		for _, edge in { { 0, 1.6, 2.8, 0.25 }, { 0, -1.6, 2.8, 0.25 }, { 1.3, 0, 0.25, 3.4 }, { -1.3, 0, 0.25, 3.4 } } do
			table.insert(
				frameParts,
				Build.part(
					model,
					"PortraitFrame",
					Vector3.new(edge[3], edge[4], 0.25),
					frame * CFrame.new(edge[1], edge[2], 0.02),
					BRASS,
					{ material = Enum.Material.Wood, collide = false, query = false }
				)
			)
		end
		-- Rosto pintado: dois olhos escuros em todos; no certo, olhos que brilham no escuro.
		for _, x in { -0.35, 0.35 } do
			Build.part(model, "PaintedEye", Vector3.new(0.22, 0.12, 0.02), frame * CFrame.new(x, 0.55, -0.09), DARK, {
				collide = false,
				query = false,
			})
			if n == watcher then
				local eye = Build.part(
					model,
					"WatchingEye",
					Vector3.new(0.16, 0.16, 0.02),
					frame * CFrame.new(x, 0.55, -0.11),
					Color3.fromRGB(255, 196, 120),
					{ material = Enum.Material.Neon, collide = false, query = false }
				)
				eye.Transparency = 1
				eye.CastShadow = false
				eye:SetAttribute("FollowEyes", true)
				eye:SetAttribute("Home", eye.CFrame)
				CollectionService:AddTag(eye, Mini.DARK_GLOW)
				table.insert(frameParts, eye)
			end
		end
		local photo: BasePart? = nil
		if n == watcher then
			photo = Build.part(
				model,
				"HiddenPhoto",
				Vector3.new(1.6, 1.1, 0.04),
				frame * CFrame.new(0, 0, 0.12),
				Color3.fromRGB(214, 200, 170),
				{ collide = false, query = false }
			);
			(photo :: BasePart).Transparency = 1
		end
		local id = `portrait_{spec.id}_{n}`
		interactable(canvas, id, "TIRAR O RETRATO DA PAREDE", distance)
		local fallen = false
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = canvas,
			handle = function(_player: Player): (Result, string)
				if fallen then
					return "no", "portrait_down"
				end
				fallen = true
				canvas:SetAttribute(Tags.Attr.InteractEnabled, false)
				local drop = frame * CFrame.new(0, -4.2, -0.6) * CFrame.Angles(math.rad(-80), 0, 0)
				for _, piece in frameParts do
					local relative = frame:ToObjectSpace(piece.CFrame)
					TweenService
						:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), { CFrame = drop * relative })
						:Play()
				end
				if n ~= watcher then
					play(canvas, "WoodSplinter", 1.3, 0.7, 100)
					return "error", "portrait_wrong"
				end
				if photo then
					photo.Transparency = 0
				end
				play(canvas, "Paper", 1, 1)
				return "solve", "solved"
			end,
		}
	end
	return targets
end

-- O Relógio Pintado (cap. 3, escritório): vidro pintado de preto; duas manivelas giram, por uma corda que sobe
-- pela parede, os ponteiros do relógio do sótão logo acima. Uma mexe as horas e a outra os minutos (de 3 em 3),
-- sorteado. Parar em 03:12 abre a escada do porão. Passar de 03:12 faz o relógio de cima badalar (erro). Sozinho:
-- quando um ponteiro chega no 3 ou no 12 de 03:12, a manivela dá um estalo grave.
function Mini.paintedClock(root: Instance, spec: any, at: Vector3, distance: number): { [string]: Target }
	local model = Build.model(root, `paintedclock_{spec.id}`)
	local back = at + Vector3.new(0, 0, -2.4)
	-- Corpo do relógio com o vidro pintado de preto.
	part(model, "ClockCase", Vector3.new(2.8, 7, 1.5), CFrame.new(back + Vector3.new(0, 3.5, 0)), WOOD, true)
	Build.part(
		model,
		"PaintedGlass",
		Vector3.new(2.2, 2.2, 0.06),
		CFrame.new(back + Vector3.new(0, 5.6, 0.78)),
		Color3.fromRGB(10, 10, 12),
		{ material = Enum.Material.Glass, collide = false, query = false }
	)
	-- Corda grossa que sobe pela parede até o buraco no teto.
	Build.part(
		model,
		"CrankRope",
		Vector3.new(0.3, 8, 0.3),
		CFrame.new(Vector3.new(back.X, at.Y + 11, back.Z - 0.6)),
		Color3.fromRGB(150, 120, 80),
		{ material = Enum.Material.Fabric, collide = false, query = false }
	)
	-- O relógio do sótão, logo acima (o mostrador que mostra a hora de verdade).
	local upper = Vector3.new(back.X, at.Y + 16 + 6.2, back.Z)
	part(model, "AtticClockBody", Vector3.new(3, 8, 1.6), CFrame.new(upper - Vector3.new(0, 2.2, 0.2)), DARK, true)
	local face = CFrame.lookAt(upper + Vector3.new(0, 0, 0.7), upper + Vector3.new(0, 0, 2))
	local dial = Build.part(
		model,
		"AtticDial",
		Vector3.new(0.05, 2.4, 2.4),
		face * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(232, 224, 204),
		{ collide = false, query = false }
	);
	(dial :: Part).Shape = Enum.PartType.Cylinder
	for hour = 1, 12 do
		local angle = hour / 12 * math.pi * 2
		Build.part(
			model,
			"HourMark",
			Vector3.new(if hour % 3 == 0 then 0.16 else 0.09, 0.28, 0.02),
			face * CFrame.new(-math.sin(angle) * 0.95, math.cos(angle) * 0.95, -0.05) * CFrame.Angles(0, 0, angle),
			DARK,
			{ collide = false, query = false }
		)
	end
	local hourHand = Build.part(model, "AtticHourHand", Vector3.new(0.16, 0.6, 0.03), face, DARK, {
		material = Enum.Material.Metal,
		collide = false,
		query = false,
	})
	local minuteHand = Build.part(model, "AtticMinuteHand", Vector3.new(0.1, 0.9, 0.03), face, DARK, {
		material = Enum.Material.Metal,
		collide = false,
		query = false,
	})
	-- Estado: hora 1..12 e minuto em passos de 3 (0..19). Começa longe de 03:12.
	local hour = rng:NextInteger(5, 11)
	local minute = rng:NextInteger(8, 18)
	local function show()
		local m = minute * 3
		local hAngle = math.rad((hour % 12 + m / 60) * 30)
		local mAngle = math.rad(m * 6)
		hourHand.CFrame = face * CFrame.new(0, 0, -0.08) * CFrame.Angles(0, 0, hAngle) * CFrame.new(0, 0.3, 0)
		minuteHand.CFrame = face * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, mAngle) * CFrame.new(0, 0.45, 0)
	end
	show()
	local hoursFirst = rng:NextNumber() < 0.5
	local targets: { [string]: Target } = {}
	for n = 1, 2 do
		local isHours = (n == 1) == hoursFirst
		local crank = Build.cylinder(
			model,
			`crank_{spec.id}_{n}`,
			at + Vector3.new((n - 1.5) * 4.4, 3.2, -1.2),
			Vector3.zAxis,
			0.5,
			1.6,
			Color3.fromRGB(110, 90, 70),
			{ material = Enum.Material.Metal, collide = false, query = true }
		)
		part(model, "CrankHandle", Vector3.new(0.25, 1, 0.25), crank.CFrame * CFrame.new(0.3, 0.6, 0), WOOD)
		local id = `crank_{spec.id}_{n}`
		interactable(crank, id, "GIRAR A MANIVELA", distance)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = crank,
			handle = function(_player: Player): (Result, string)
				local wasOn = if isHours then hour == 3 else minute == 4
				if isHours then
					hour = hour % 12 + 1
				else
					minute = (minute + 1) % 20
				end
				show()
				crank.CFrame *= CFrame.Angles(math.rad(90), 0, 0)
				local nowOn = if isHours then hour == 3 else minute == 4
				-- Estalo grave no 3 e no 12 (para quem está sozinho); agudo nos outros.
				play(crank, "KeyTurn", 0.9, if nowOn then 0.45 else 1.4, 40)
				play(dial, "CreakWood", 0.5, 1.4, 50)
				if wasOn then
					-- Passou de 03:12: o relógio de cima badala e chama o Tum Tum.
					chime(dial, 3)
					return "error", "clock_overshoot"
				end
				if hour == 3 and minute == 4 then
					return "solve", "solved"
				end
				return "ok", if nowOn then "crank_heavy" else "crank_turn"
			end,
		}
	end
	return targets
end

-- A Sombra do Pêndulo (cap. 3, sótão): três engrenagens prendem o pêndulo. Atrás do relógio há o contorno do Tum
-- Tum pequeno riscado na parede. Com a lanterna acesa mirando o buraco do pêndulo, aparece na parede a sombra das
-- engrenagens (peças trocadas por script, igual em qualquer gráfico). Cada engrenagem tem 4 posições; quando a
-- sombra dela encaixa no contorno, aquele trecho do risco brilha. As três certas soltam o pêndulo (03:12).
-- O 6º giro que não acerta nenhum trecho dá a badalada (erro).
function Mini.pendulum(root: Instance, spec: any, at: Vector3, distance: number): { [string]: Target }
	local model = Build.model(root, `pendulum_{spec.id}`)
	local back = at + Vector3.new(0, 0, -2.6)
	-- Relógio do sótão do artista (AtticClock) de frente para os jogadores; sem ele, o corpo em bloco.
	HouseArt.swap(model, "AtticClock", CFrame.lookAt(back, back + Vector3.zAxis), function(folder)
		part(
			folder,
			"PendulumClock",
			Vector3.new(3.2, 8.5, 1.8),
			CFrame.new(back + Vector3.new(0, 4.25, 0)),
			WOOD,
			true
		)
	end)
	-- Contorno riscado a faca na parede, logo acima do relógio (três trechos).
	local wall = back + Vector3.new(0, 10.5, -0.8)
	local segments: { BasePart } = {}
	for n = 1, 3 do
		local segment = Build.part(
			model,
			"Contour",
			Vector3.new(1.8, 0.18, 0.04),
			CFrame.new(wall + Vector3.new((n - 2) * 2, 0, 0)) * CFrame.Angles(0, 0, math.rad((n - 2) * 35)),
			Color3.fromRGB(120, 92, 64),
			{ material = Enum.Material.SmoothPlastic, collide = false, query = false }
		)
		table.insert(segments, segment)
	end
	local turns = { 0, 0, 0 }
	local goals = { 0, 0, 0 }
	for n = 1, 3 do
		goals[n] = rng:NextInteger(0, 3)
		turns[n] = (goals[n] + rng:NextInteger(1, 3)) % 4
	end
	local misses = 0
	local targets: { [string]: Target } = {}
	local shadows: { BasePart } = {}
	local function lit(n: number): boolean
		return turns[n] == goals[n]
	end
	local function show()
		for n = 1, 3 do
			local base = CFrame.new(wall + Vector3.new((n - 2) * 2, 0, 0.03))
				* CFrame.Angles(0, 0, math.rad((n - 2) * 35 + (turns[n] - goals[n]) * 90))
			shadows[n].CFrame = base
			segments[n].Material = if lit(n) then Enum.Material.Neon else Enum.Material.SmoothPlastic
			segments[n].Color = if lit(n) then Color3.fromRGB(255, 200, 120) else Color3.fromRGB(120, 92, 64)
		end
	end
	for n = 1, 3 do
		local shadow = Build.part(
			model,
			"GearShadow",
			Vector3.new(1.8, 0.35, 0.03),
			CFrame.new(wall),
			Color3.fromRGB(8, 6, 6),
			{ material = Enum.Material.SmoothPlastic, collide = false, query = false }
		)
		shadow.Transparency = 1
		shadow.CastShadow = false
		CollectionService:AddTag(shadow, Mini.FLASH_SHADOW)
		table.insert(shadows, shadow)
		local gear = Build.cylinder(
			model,
			`gear_{spec.id}_{n}`,
			back + Vector3.new((n - 2) * 1.1, 6.4 - math.abs(n - 2) * 0.5, 0.95),
			Vector3.zAxis,
			0.3,
			if n == 2 then 1.3 else 1,
			Color3.fromRGB(96, 70, 46),
			{ material = Enum.Material.Wood, collide = false, query = true }
		)
		local id = `gear_{spec.id}_{n}`
		interactable(gear, id, "GIRAR A ENGRENAGEM", distance)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = gear,
			handle = function(_player: Player): (Result, string)
				turns[n] = (turns[n] + 1) % 4
				gear.CFrame *= CFrame.Angles(math.rad(90), 0, 0)
				show()
				-- Estalo de catraca alto em todo giro.
				play(gear, "KeyTurn", 1.1, 0.8, 60)
				if lit(1) and lit(2) and lit(3) then
					play(gear, "Switch", 1, 0.7)
					return "solve", "solved"
				end
				if lit(n) then
					return "ok", "gear_fit"
				end
				misses += 1
				if misses >= 6 then
					misses = 0
					chime(gear, 3)
					return "error", "gear_chime"
				end
				return "ok", "gear_turn"
			end,
		}
	end
	show()
	return targets
end

-- Dueto da Lia (cap. 4), painel do porão: os quatro desenhos das teclas riscados na madeira. Tocar num desenho
-- canta a nota dele baixinho (a Lia sussurrando): é o lugar seguro para testar. Alvos da tarefa do piano.
function Mini.panelMarks(parent: Instance, pianoTask: string, at: Vector3, distance: number): { [string]: Target }
	local targets: { [string]: Target } = {}
	for n, label in PuzzleStyles.PIANO.labels do
		local rgb = PuzzleStyles.MARK_COLORS[label] or { 232, 224, 204 }
		local mark = Build.part(
			parent,
			`panelmark_{pianoTask}_{n}`,
			Vector3.new(1.5, 1.5, 0.15),
			CFrame.new(at + Vector3.new((n - 2.5) * 1.9, 6.9, -0.45)),
			Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
			{ material = Enum.Material.Wood, collide = false, query = true }
		)
		Build.sign(
			parent,
			"MarkName",
			at + Vector3.new((n - 2.5) * 1.9, 8, -0.4),
			Vector3.zAxis,
			Vector2.new(1.8, 0.5),
			label,
			-- Sem brilho próprio (Luz: era o ponto mais claro do porão); lê-se com a lanterna, como madeira riscada.
			{
				textColor = Color3.fromRGB(rgb[1], rgb[2], rgb[3]):Lerp(Color3.fromRGB(60, 44, 32), 0.35),
				lit = false,
				font = Enum.Font.Merriweather,
			}
		)
		local id = `panelmark_{pianoTask}_{n}`
		interactable(mark, id, `TOCAR NO DESENHO: {label}`, distance)
		targets[id] = {
			taskId = pianoTask,
			button = 1,
			focus = mark,
			anyTime = true,
			handle = function(_player: Player): (Result, string)
				play(mark, "PianoKey", 0.35, PuzzleStyles.PIANO_PITCH[n], 18)
				return "ok", "panel_note"
			end,
		}
	end
	return targets
end

-- O Sussurro do Juca (cap. 4, catacumba): metade do código do cofre está riscada num de seis nichos. O Juca
-- sussurra "aqui..." de lá, mas só quando ninguém por perto anda em pé por 3 s (agachado não interrompe). O som 3D
-- diz o lado. Revistar um nicho vazio só gasta tempo.
function Mini.whisper(
	root: Instance,
	spec: any,
	spot: ({ Vector3 }) -> Vector3,
	clueText: string,
	distance: number
): { [string]: Target }
	local model = Build.model(root, `whisper_{spec.id}`)
	local right = rng:NextInteger(1, 6)
	local taken: { Vector3 } = {}
	local targets: { [string]: Target } = {}
	local voice: BasePart? = nil
	local found = false
	for n = 1, 6 do
		local at = spot(taken)
		table.insert(taken, at)
		local niche = Build.model(model, `niche_{n}`)
		local crate = part(
			niche,
			`niche_{spec.id}_{n}`,
			Vector3.new(2.2, 1.6, 1.6),
			CFrame.new(at + Vector3.new(0, 0.8, 0)),
			DARK
		)
		crate.CanQuery = true
		local id = `niche_{spec.id}_{n}`
		interactable(crate, id, "REVISTAR O NICHO", distance)
		local sign: BasePart? = nil
		if n == right then
			voice = crate
			sign =
				Build.sign(niche, "Clue", at + Vector3.new(0, 2.6, 0.9), Vector3.zAxis, Vector2.new(5, 1.7), clueText, {
					textColor = Color3.fromRGB(219, 171, 80),
					background = Color3.fromRGB(28, 21, 19),
					lit = true,
				})
			local gui = (sign :: BasePart):FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = false
			end
			(sign :: BasePart).Transparency = 1
		end
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = crate,
			handle = function(_player: Player): (Result, string)
				if n ~= right then
					play(crate, "LockerLatch", 0.7, 0.9, 30)
					return "no", "niche_empty"
				end
				found = true
				if sign then
					sign.Transparency = 0
					local gui = sign:FindFirstChildOfClass("SurfaceGui")
					if gui then
						gui.Enabled = true
					end
				end
				return "solve", "solved"
			end,
		}
	end
	-- O sussurro: depois de 3 s com todo mundo por perto parado ou agachado.
	task.spawn(function()
		local stillSince = os.clock()
		while model.Parent and not found do
			task.wait(0.5)
			local source = voice
			if not source then
				break
			end
			local moving = false
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if
					humanoid
					and rootPart
					and rootPart:IsA("BasePart")
					and (rootPart.Position - source.Position).Magnitude < 45
					and humanoid.MoveDirection.Magnitude > 0.1
					and player:GetAttribute("Stance") ~= "Crouch"
				then
					moving = true
				end
			end
			if moving then
				stillSince = os.clock()
			elseif os.clock() - stillSince >= 3 then
				play(source, "Whisper", 1.4, 1.15, 45)
				stillSince = os.clock() - 0.5
				task.wait(2.5)
			end
		end
	end)
	return targets
end

-- A caixinha da Lia em cima do piano (a casa devolveu ao dono): dar corda toca a música inteira de novo, alto.
-- Pode repetir quantas vezes quiser; cada vez o Tum Tum ouve (resultado "loud").
function Mini.windBox(parent: Instance, spec: any, at: Vector3, seed: number, distance: number): { [string]: Target }
	local box = Build.part(
		parent,
		`windbox_{spec.id}`,
		Vector3.new(1.2, 0.8, 0.9),
		CFrame.new(at + Vector3.new(-2.6, 5.85, -2.2)),
		Color3.fromRGB(120, 70, 50),
		{ material = Enum.Material.Wood, collide = false, query = true }
	)
	Build.part(
		parent,
		"HairRibbon",
		Vector3.new(0.15, 0.5, 0.95),
		box.CFrame * CFrame.new(0.4, 0.2, 0),
		Mini.FUSE_WRAPS.fuse_2,
		{ material = Enum.Material.Fabric, collide = false, query = false }
	)
	local id = `windbox_{spec.id}`
	interactable(box, id, "DAR CORDA NA CAIXINHA", distance)
	local playing = false
	return {
		[id] = {
			taskId = spec.id,
			button = 1,
			focus = box,
			handle = function(_player: Player): (Result, string)
				if playing then
					return "no", "box_playing"
				end
				playing = true
				task.spawn(function()
					for _, note in SahurMelody.full(seed) do
						play(box, "PianoKey", 1.6, PuzzleStyles.PIANO_PITCH[note] * 1.9, 120)
						task.wait(0.42)
					end
					playing = false
				end)
				return "loud", "box_wound"
			end,
		},
	}
end

-- O Ritmo da Sobrecarga (cap. 5, Oficina secreta): a máquina bate TUM TUM TUM e para meio segundo. Na pausa dá para
-- ver e ouvir: a serragem para de cair, a lamparina para de balançar e o barulho corta. Encaixar o coração só na
-- pausa; três encaixes certos (dois sozinho) sobrecarregam a máquina. Fora da pausa: o 1º erro é aviso (a máquina
-- puxa, a Dona Cida grita "Na pausa!"); do 2º em diante chama o Tum Tum (erro).
function Mini.overload(root: Instance, spec: any, at: Vector3, distance: number): { [string]: Target }
	local model = Build.model(root, `overload_{spec.id}`)
	local back = at + Vector3.new(0, 0, -2.6)
	part(model, "MachineCore", Vector3.new(5, 4.5, 3), CFrame.new(back + Vector3.new(0, 2.25, 0)), WOOD, true)
	for side = -1, 1, 2 do
		part(
			model,
			"FunnelBoard",
			Vector3.new(0.4, 2.4, 3),
			CFrame.new(back + Vector3.new(side * 1.8, 5.6, 0)) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			DARK
		)
	end
	local sawdust = Build.part(
		model,
		"FallingSawdust",
		Vector3.new(0.6, 3, 0.6),
		CFrame.new(back + Vector3.new(0, 1.6, 1.7)),
		Color3.fromRGB(196, 164, 112),
		{ material = Enum.Material.Sand, collide = false, query = false }
	)
	local lamp = Build.part(
		model,
		"HangingLamp",
		Vector3.new(0.6, 0.8, 0.6),
		CFrame.new(back + Vector3.new(1.8, 7.6, 1.4)),
		Color3.fromRGB(255, 190, 110),
		{ material = Enum.Material.Neon, collide = false, query = false }
	)
	local lampHome = lamp.CFrame
	local socket = Build.part(
		model,
		`heartsocket_{spec.id}`,
		Vector3.new(1.4, 1.4, 0.5),
		CFrame.new(back + Vector3.new(0, 3, 1.6)),
		Color3.fromRGB(176, 136, 64),
		{ material = Enum.Material.Metal, collide = false, query = true }
	)
	local id = `heartsocket_{spec.id}`
	interactable(socket, id, "UNTAR AS ENGRENAGENS COM O ÓLEO", distance)
	-- Primeiro o óleo nas engrenagens: a máquina dispara e o ritmo fica mais rápido (mais difícil de acertar a pausa).
	local oiled = false
	local paused = false
	local fits = 0
	local mistakes = 0
	local done = false
	-- Andamento sorteado: 3 ou 4 batidas antes de cada pausa.
	local beats = rng:NextInteger(3, 4)
	local tempo = rng:NextNumber(0.42, 0.55)
	task.spawn(function()
		while model.Parent and not done do
			for _ = 1, beats do
				if done then
					break
				end
				paused = false
				sawdust.Transparency = 0
				lamp.CFrame = lampHome * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12)))
				play(socket, "HammerNail", 1.3, 0.6, 70)
				task.wait(tempo)
			end
			paused = true
			sawdust.Transparency = 1
			lamp.CFrame = lampHome
			task.wait(0.8)
		end
		paused = false
	end)
	return {
		[id] = {
			taskId = spec.id,
			button = 1,
			focus = socket,
			handle = function(_player: Player): (Result, string)
				if done then
					return "no", "overload_done"
				end
				if not oiled then
					oiled = true
					tempo *= 0.72
					socket:SetAttribute(Tags.Attr.InteractPrompt, "ENCAIXAR O CORAÇÃO NA PAUSA")
					play(socket, "GasPour", 1, 1, 50)
					return "loud", "overload_oiled"
				end
				if paused then
					fits += 1
					play(socket, "Switch", 1.2, 0.7)
					local needed = if #Players:GetPlayers() <= 1 then 2 else 3
					if fits >= needed then
						done = true
						return "solve", "solved"
					end
					return "ok", "overload_fit"
				end
				mistakes += 1
				play(socket, "WoodSplinter", 1.2, 0.8, 90)
				if mistakes == 1 then
					return "no", "overload_warning"
				end
				return "error", "overload_wrong"
			end,
		},
	}
end

-- Os Sons da Margem (cap. 7): seis marcos fixos na trilha da margem sul até o cais, cada um com um som. Nesta
-- partida só quatro ainda tocam (os outros dois estão quebrados, dá para ver). Eles tocam sempre que alguém passa
-- perto. O diário do guarda tem o mapinha da trilha com os seis na ordem do caminho; o rádio da ilha pede os sons
-- vivos nessa ordem. Canal errado: chiado alto, as lanternas da margem apagam e o Tum Tum bate no cais (erro).
type Marker = { name: string, clip: string, speed: number, color: Color3 }
local MARKERS: { Marker } = {
	{ name = "BOIA COM SINO", clip = "PianoKey", speed = 0.5, color = Color3.fromRGB(196, 60, 48) },
	{ name = "APITO DO GUARDA", clip = "UiBlip", speed = 1.7, color = Color3.fromRGB(200, 200, 190) },
	{ name = "JUNCO QUE ASSOBIA", clip = "Whisper", speed = 1.8, color = Color3.fromRGB(110, 140, 70) },
	{ name = "TOCO OCO", clip = "HammerNail", speed = 0.45, color = Color3.fromRGB(96, 70, 46) },
	{ name = "SINO DE VENTO", clip = "PianoKey", speed = 2.2, color = Color3.fromRGB(176, 136, 64) },
	{ name = "LATA DE CORVOS", clip = "CrowCaw", speed = 1, color = Color3.fromRGB(80, 84, 90) },
}
Mini.MARGIN_DIARY = "MAPINHA DO GUARDA, DO SUL AO CAIS:\nBOIA · APITO · JUNCO · TOCO · SINO DE VENTO · CORVOS\n"
	.. "O RÁDIO SÓ ACEITA OS SONS QUE AINDA TOCAM, NA ORDEM DA TRILHA."

-- Pontos ao longo da trilha (lista de x/z) entre o início e `stopZ`, espalhados em `count` posições iguais.
local function alongTrail(trail: { { x: number, z: number } }, stopZ: number, count: number): { Vector3 }
	local points: { Vector3 } = {}
	for _, point in trail do
		table.insert(points, Vector3.new(point.x, 0, point.z))
		if point.z >= stopZ then
			break
		end
	end
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	local out: { Vector3 } = {}
	for k = 1, count do
		local want = total * k / (count + 1)
		for i = 2, #points do
			local segment = (points[i] - points[i - 1]).Magnitude
			if want <= segment then
				local dir = (points[i] - points[i - 1]).Unit
				-- 4 studs para o lado, fora do caminho.
				table.insert(out, points[i - 1] + dir * want + Vector3.new(dir.Z, 0, -dir.X) * 4)
				break
			end
			want -= segment
		end
	end
	return out
end

function Mini.marginSounds(
	root: Instance,
	spec: any,
	at: Vector3,
	trail: { { x: number, z: number } },
	stopZ: number,
	ground: (number, number) -> number,
	distance: number
): { [string]: Target }
	local model = Build.model(root, `margin_{spec.id}`)
	local broken: { [number]: boolean } = {}
	while true do
		table.clear(broken)
		broken[rng:NextInteger(1, 6)] = true
		broken[rng:NextInteger(1, 6)] = true
		local n = 0
		for _ in broken do
			n += 1
		end
		if n == 2 then
			break
		end
	end
	local alive: { number } = {}
	local spots = alongTrail(trail, stopZ, #MARKERS)
	for n, marker in MARKERS do
		local spot = spots[n] or (at + Vector3.new(n * 3, 0, 0))
		local y = ground(spot.X, spot.Z)
		local post = part(model, `marker_{n}`, Vector3.new(0.5, 4, 0.5), CFrame.new(spot.X, y + 2, spot.Z), DARK, true)
		local thing = Build.part(
			model,
			"MarkerThing",
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(spot.X, y + 4.3, spot.Z) * if broken[n] then CFrame.Angles(0, 0, math.rad(60)) else CFrame.new(),
			if broken[n] then Color3.fromRGB(70, 66, 60) else marker.color,
			{ material = Enum.Material.Metal, collide = false, query = false }
		)
		if broken[n] then
			-- Quebrado: torto, sem cor e com uma rachadura (sino sem badalo, apito rachado).
			Build.part(model, "Crack", Vector3.new(0.08, 1.2, 0.05), thing.CFrame * CFrame.new(0, 0, -0.56), DARK, {
				collide = false,
				query = false,
			})
		else
			table.insert(alive, n)
			task.spawn(function()
				local last = 0
				while model.Parent do
					task.wait(0.5)
					if os.clock() - last < 3 then
						continue
					end
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local rootPart = character and character:FindFirstChild("HumanoidRootPart")
						if
							rootPart
							and rootPart:IsA("BasePart")
							and (rootPart.Position - post.Position).Magnitude < 12
						then
							last = os.clock()
							play(post, marker.clip, 1.2, marker.speed, 60)
							break
						end
					end
				end
			end)
		end
	end
	-- Rádio da ilha: seis botões, um por som; tocar o som do botão é girar o dial até ele.
	local radio =
		part(model, "MarginRadio", Vector3.new(5.6, 2.2, 1.6), CFrame.new(at + Vector3.new(0, 2.6, -1)), DARK, true)
	local progress = 0
	local targets: { [string]: Target } = {}
	for n, marker in MARKERS do
		local knob = Build.part(
			model,
			`dial_{spec.id}_{n}`,
			Vector3.new(0.8, 0.8, 0.4),
			radio.CFrame * CFrame.new((n - 3.5) * 0.9, 0.3, -0.9),
			marker.color,
			{ material = Enum.Material.Metal, collide = false, query = true }
		)
		local id = `dial_{spec.id}_{n}`
		interactable(knob, id, `SINTONIZAR: {marker.name}`, distance)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = knob,
			handle = function(_player: Player): (Result, string)
				play(knob, marker.clip, 1, marker.speed, 40)
				if alive[progress + 1] ~= n then
					play(radio, "RadioStatic", 2, 1, 120)
					return "error", "radio_static"
				end
				progress += 1
				if progress >= #alive then
					return "solve", "solved"
				end
				return "ok", "radio_ok"
			end,
		}
	end
	return targets
end

-- A cadeira da Dona Cida (cap. 1): ela é gente e tem medo de luz. Quem chega com a lanterna acesa a 9 studs faz a
-- cadeira deslizar rangendo para outro canto da sala. Com a luz apagada, apertar E nela dá a dica da caixinha.
local CHAIR_SPOTS = {
	Vector3.new(-22.5, 0, 4.5),
	Vector3.new(-38, 0, 6),
	Vector3.new(-37, 0, -12),
	Vector3.new(-18, 0, -13),
}
function Mini.cidaChair(root: Instance, world: Instance, spec: any, distance: number): { [string]: Target }
	local _ = root
	local chair: Model? = nil
	for _, d in world:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, "RockingChair", 1, true) then
			local p = d:GetPivot().Position
			if p.X < -8 and p.X > -44 and p.Z > -20 and p.Z < 12 and p.Y > -1 and p.Y < 4 then
				chair = d
				break
			end
		end
	end
	local model = Build.model(root, `cida_{spec.id}`)
	local focus = Build.part(
		model,
		`cida_{spec.id}`,
		Vector3.new(2.6, 4, 2.6),
		CFrame.new((if chair then chair:GetPivot().Position else CHAIR_SPOTS[1]) + Vector3.new(0, 2, 0)),
		WOOD,
		{ collide = false, transparency = 1 }
	)
	-- O marcador da tarefa (Station do HouseActivities) acompanha a cadeira, não o ponto sorteado do plano.
	local stationHost = root:FindFirstChild(spec.id)
	local stationPart = stationHost and stationHost:FindFirstChild("Station")
	local station: BasePart? = if stationPart and stationPart:IsA("BasePart") then stationPart else nil
	if station then
		station.Position = focus.Position
	end
	local id = `cida_{spec.id}`
	interactable(focus, id, "FALAR COM A CADEIRA (NO ESCURO)", distance)
	local spot = 1
	local busy = false
	local function flee()
		if busy or not chair then
			return
		end
		busy = true
		spot = spot % #CHAIR_SPOTS + 1
		local from = chair:GetPivot()
		local to = CFrame.new(CHAIR_SPOTS[spot]) * from.Rotation
		local any = chair:FindFirstChildWhichIsA("BasePart", true)
		-- Aviso antes de mexer: legenda, rangido e um tremor de 1,2 s (o jogador entende que a luz a assusta).
		local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
		if campaign then
			campaign:SetAttribute("Caption", "A cadeira range e treme... ela tem medo da luz.")
			campaign:SetAttribute("CaptionSerial", (campaign:GetAttribute("CaptionSerial") or 0) + 1)
		end
		if any then
			play(any, "CreakWood", 1, 0.7, 60)
		end
		for t = 1, 24 do
			chair:PivotTo(from * CFrame.Angles(0, 0, math.rad(math.sin(t * 1.6) * 5)))
			task.wait(0.05)
		end
		chair:PivotTo(from)
		if campaign then
			campaign:SetAttribute("Caption", "A cadeira recuou da luz…")
			campaign:SetAttribute("CaptionSerial", (campaign:GetAttribute("CaptionSerial") or 0) + 1)
		end
		if any then
			-- Arrasto: madeira pesada raspando o piso enquanto ela desliza.
			play(any, "CreakMetal", 1, 0.55, 60)
			play(any, "CreakWood", 1, 0.9, 60)
		end
		for t = 1, 25 do
			chair:PivotTo(from:Lerp(to, t / 25))
			focus.Position = chair:GetPivot().Position + Vector3.new(0, 2, 0)
			if station then
				station.Position = focus.Position
			end
			task.wait(1 / 25)
		end
		busy = false
	end
	local solved = false
	task.spawn(function()
		while model.Parent and not solved do
			task.wait(0.4)
			if
				chair
				and focus:GetAttribute(Tags.Attr.InteractEnabled) == true
				and flashlightNear(chair:GetPivot().Position, 9)
			then
				flee()
				task.wait(2)
			end
		end
	end)
	return {
		[id] = {
			taskId = spec.id,
			button = 1,
			focus = focus,
			handle = function(player: Player): (Result, string)
				if player:GetAttribute(Tags.Attr.Flashlight) == true then
					task.spawn(flee)
					return "no", "cida_light"
				end
				solved = true
				return "solve", "solved"
			end,
		},
	}
end

-- A Melodia do Corredor (cap. 1, nota 9): quatro teclas na parede do hall. A ordem certa são as três primeiras notas
-- da música da caixinha da Lia (sala). Nota errada: pancada forte e `onWrong` (o Tum Tum desce antes, com aviso curto).
-- Acertar as três em sequência destranca o corredor sem o Tum Tum.
function Mini.melodyLock(
	root: Instance,
	spec: any,
	at: Vector3,
	distance: number,
	onWrong: () -> ()
): { [string]: Target }
	local model = Build.model(root, `melody_{spec.id}`)
	local order = { SahurMelody.FIRST[1], SahurMelody.FIRST[2], SahurMelody.FIRST[3] }
	local step = 0
	local targets: { [string]: Target } = {}
	for n, label in PuzzleStyles.PIANO.labels do
		local rgb = PuzzleStyles.MARK_COLORS[label] or { 232, 224, 204 }
		local key = Build.part(
			model,
			`melodykey_{spec.id}_{n}`,
			Vector3.new(0.3, 1.3, 1.3),
			CFrame.new(-7.3, 3.4, at.Z + (n - 2.5) * 1.8),
			Color3.fromRGB(rgb[1], rgb[2], rgb[3]):Lerp(Color3.fromRGB(60, 44, 32), 0.3),
			{ material = Enum.Material.Wood, collide = false, query = true }
		)
		local id = `melodykey_{spec.id}_{n}`
		interactable(key, id, `TOCAR A TECLA DA {label}`, distance)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = key,
			handle = function(_player: Player): (Result, string)
				play(key, "PianoKey", 0.9, PuzzleStyles.PIANO_PITCH[n], 60)
				if n ~= order[step + 1] then
					step = 0
					play(key, "BreakerFail", 1, 0.8, 90)
					task.spawn(onWrong)
					return "error", "melody_wrong"
				end
				step += 1
				if step >= #order then
					return "solve", "melody_solved"
				end
				return "ok", "melody_note"
			end,
		}
	end
	return targets
end

return Mini
