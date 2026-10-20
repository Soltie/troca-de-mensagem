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
	"solve" recolhe o item; "ok" só avança; "error" faz barulho (o runtime chama o Tum Tum).
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local PuzzleStyles = require("@game/ReplicatedStorage/Shared/Game/PuzzleStyles")
local SahurMelody = require("@game/ReplicatedStorage/Shared/Game/SahurMelody")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local TaskProps = require("../World/HouseTaskProps")

local Mini = {}

export type Result = "solve" | "ok" | "error"
export type Target = {
	taskId: string,
	button: number,
	focus: BasePart,
	-- Alvo bloqueado até outro passo liberar (a chave na viga antes da pilha de banquinhos).
	locked: boolean?,
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

-- Olhos no Veio: dois olhos acendem na madeira perto do erro e somem (aviso de que a casa viu).
function Mini.eyes(position: Vector3)
	local folder = Instance.new("Model")
	folder.Name = "EyesInTheGrain"
	folder.Parent = workspace
	for _, x in { -0.45, 0.45 } do
		local eye = Build.part(
			folder,
			"Eye",
			Vector3.new(0.35, 0.18, 0.35),
			CFrame.new(position + Vector3.new(x, 5.2, 0)),
			Color3.fromRGB(255, 120, 40),
			{ material = Enum.Material.Neon, collide = false, query = false }
		)
		eye.CastShadow = false
	end
	play(folder:GetChildren()[1] :: BasePart, "CreakWood", 1, 0.7)
	Debris:AddItem(folder, 3.5)
end

-- Caixinha da Lia: liga a música no móvel certo (já montado pelo HiddenStash) até ele ser aberto.
function Mini.musicBox(focus: BasePart, isOpen: () -> boolean, seed: number)
	local notes = SahurMelody.full(seed)
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
		local yaw = if rng:NextNumber() < 0.5 then 0 else 90
		local frame = CFrame.new(at + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
		local plank = part(model, `plank_{spec.id}_{n}`, Vector3.new(1.3, 0.14, 4.6), frame, LOOSE)
		-- Prego saltado: o sinal de tábua solta ensinado no hall.
		Build.part(model, "LooseNail", Vector3.new(0.12, 0.3, 0.12), frame * CFrame.new(0.4, 0.14, 1.8), BRASS, {
			material = Enum.Material.Metal,
			collide = false,
			query = false,
		})
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
	local function moveStool(stool: Stool, to: CFrame)
		local from = stool.current
		stool.current = to
		for _, piece in stool.parts do
			local relative = from:ToObjectSpace(piece.CFrame)
			TweenService:Create(piece, TweenInfo.new(0.35), { CFrame = to * relative }):Play()
		end
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
		interactable(seat, id, "LEVAR O BANQUINHO PARA AS MARCAS", distance)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = seat,
			handle = function(player: Player): (Result, string)
				if table.find(placed, n) or #placed >= 2 then
					return "ok", "stool_ready"
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
				if #placed >= 2 then
					keyTarget.locked = false
					return "ok", "stool_stack"
				end
				return "ok", "stool_placed"
			end,
		}
	end
	return targets
end

return Mini
