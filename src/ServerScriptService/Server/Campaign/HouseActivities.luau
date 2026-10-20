--!strict
-- Objetos de missão da casa, distintos das estações industriais preservadas para regressão.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local Plan = require("./HousePlan")
local Generator = require("./CampaignGenerator")
local TaskProps = require("../World/HouseTaskProps")
local Stash = require("./HiddenStash")
local Runaway = require("./RunawayStash")
local Progress = require("@game/ReplicatedStorage/Shared/Game/HouseProgression")
local WormTunnel = require("@game/ReplicatedStorage/Shared/Game/WormTunnel")
local PuzzleStyles = require("@game/ReplicatedStorage/Shared/Game/PuzzleStyles")
local PuzzleProps = require("../World/PuzzleProps")
local Mini = require("./HouseMiniPuzzles")
local Activities = {}
local repairSteps = { "ISOLAR O CIRCUITO", "ENCAIXAR OS FUSÍVEIS", "TESTAR A ENERGIA" }
local gold = Color3.fromRGB(219, 171, 80)
local symbols = { "LUA", "OLHO", "CHAMA", "PORTA" }
-- No escuro, a Lia (o piano) toca sozinha o começo da música: a cada 9 s, se alguém está perto com a lanterna
-- apagada, as duas primeiras teclas da ordem acendem e soam. O painel mostra a música inteira; a Lia confirma.
local function liaEcho(model: Instance, keys: { BasePart }, order: { number })
	task.spawn(function()
		while model.Parent do
			task.wait(9)
			local first = keys[order[1]]
			if not first or first:GetAttribute(Tags.Attr.InteractEnabled) ~= true then
				continue
			end
			local listening = false
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					root
					and root:IsA("BasePart")
					and (root.Position - first.Position).Magnitude < 22
					and player:GetAttribute(Tags.Attr.Flashlight) ~= true
				then
					listening = true
				end
			end
			if not listening then
				continue
			end
			for step = 1, 2 do
				local key = keys[order[step]]
				local sound = Build.sound(key, "LiaNote", Audio.PianoKey.id, 1.2, PuzzleStyles.PIANO_PITCH[order[step]])
				sound:Play()
				Debris:AddItem(sound, 3)
				local material = key.Material
				key.Material = Enum.Material.Neon
				task.wait(0.6)
				key.Material = material
				task.wait(0.25)
			end
		end
	end)
end

-- Cor do desenho de uma tecla do piano (LUA, SOL, BASTÃO, ESTRELA).
local function markColor(label: string): Color3
	local rgb = PuzzleStyles.MARK_COLORS[label] or { 232, 224, 204 }
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
-- Clipe (Shared/Game/Audio) tocado no cliente ao apertar um botão de cada enigma.
local PRESS_SOUNDS: { [string]: string } =
	{ piano = "PianoKey", safe = "KeyTurn", clock = "KeyTurn", radio = "RadioStatic" }
-- Gasolina: a pilha de madeira procura um pedaço livre do cômodo (sem móvel em cima) perto do ponto sorteado.
local OFFSETS = {
	{ 0, 0 },
	{ 4, 0 },
	{ -4, 0 },
	{ 0, 4 },
	{ 0, -4 },
	{ 5, 5 },
	{ -5, 5 },
	{ 5, -5 },
	{ -5, -5 },
	{ 8, 0 },
	{ -8, 0 },
	{ 0, 8 },
	{ 0, -8 },
	{ 7, 7 },
	{ -7, 7 },
	{ 7, -7 },
	{ -7, -7 },
	{ 10, 0 },
	{ -10, 0 },
	{ 0, 10 },
	{ 0, -10 },
}
local OBSTACLES =
	{ "Furniture", "Props", "Furnishings", "Dressing", "Architecture", "Finish", "PrimitiveFinish", "Doors" }
-- Móveis não respondem a consultas de física (CanQuery desligado); confere as caixas na mão, só por perto.
local function obstacles(world: Instance, p: Vector3, radius: number): { BasePart }
	local nearby: { BasePart } = {}
	for _, name in OBSTACLES do
		local folder = world:FindFirstChild(name)
		if not folder then
			continue
		end
		for _, part in folder:GetDescendants() do
			if
				part:IsA("BasePart")
				and part.Transparency < 1
				and (part.Position - p).Magnitude < radius
				and math.max(part.Size.X, part.Size.Z) > 0.6
			then
				table.insert(nearby, part)
			end
		end
	end
	return nearby
end

local function blocked(
	nearby: { BasePart },
	at: Vector3,
	floorY: number,
	avoid: { Vector3 }?,
	reach: number,
	ignore: Instance?
): boolean
	for _, other in (avoid or {}) :: { Vector3 } do
		if (other - at).Magnitude < 4.6 then
			return true
		end
	end
	for _, part in nearby do
		if part == ignore then
			continue
		end
		-- Caixa alinhada ao mundo (paredes longas e finas continuam finas).
		local cf, size = part.CFrame, part.Size / 2
		local hx = math.abs(cf.RightVector.X) * size.X
			+ math.abs(cf.UpVector.X) * size.Y
			+ math.abs(cf.LookVector.X) * size.Z
		local hy = math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z
		local hz = math.abs(cf.RightVector.Z) * size.X
			+ math.abs(cf.UpVector.Z) * size.Y
			+ math.abs(cf.LookVector.Z) * size.Z
		if
			part.Position.Y + hy > floorY + 0.8
			and part.Position.Y - hy < floorY + 3.5
			and math.abs(part.Position.X - at.X) < hx + reach
			and math.abs(part.Position.Z - at.Z) < hz + reach
		then
			return true
		end
	end
	return false
end

local function clearSpot(world: Instance, p: Vector3, avoid: { Vector3 }?): Vector3
	local nearby = obstacles(world, p, 24)
	for _, offset in OFFSETS do
		local at = p + Vector3.new(offset[1], 0, offset[2])
		if not blocked(nearby, at, p.Y, avoid, 2.3) then
			return at
		end
	end
	return p
end

-- Frente dos buracos do túnel de minhoca fica livre (o Tung sai por ali; móvel na frente esconderia a boca).
local function nearHole(at: Vector3): boolean
	for _, hole in WormTunnel.Holes do
		if math.abs(at.Y - hole.y) < 6 and Vector3.new(at.X - hole.x, 0, at.Z - hole.z).Magnitude < 6 then
			return true
		end
	end
	return false
end

-- Móvel de busca encostado numa parede do cômodo, de frente para o meio dele. A parede é achada com raios
-- saindo do centro; ao longo dela tenta alguns pontos livres de móveis.
local function wallSpot(world: Instance, center: Vector3, avoid: { Vector3 }?): (Vector3, Vector3?)
	local architecture = world:FindFirstChild("Architecture")
	if not architecture then
		return clearSpot(world, center, avoid), nil
	end
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { architecture }
	local nearby = obstacles(world, center, 30)
	local origin = center + Vector3.new(0, 3, 0)
	local sides = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
	-- Começa por uma parede diferente a cada móvel (espalha pelo cômodo).
	local start = #(avoid or {}) % 4
	for k = 1, 4 do
		local side = sides[(start + k - 1) % 4 + 1]
		local hit = workspace:Raycast(origin, side * 24, rays)
		if not hit or (hit.Position - origin).Magnitude < 4 then
			continue
		end
		local along = Vector3.new(side.Z, 0, -side.X)
		local wall = center + side * ((hit.Position - origin).Magnitude - 2)
		for _, shift in { 0, 3, -3, 6, -6, 9, -9, 12, -12 } do
			local at = wall + along * shift
			if not blocked(nearby, at, center.Y, avoid, 1.4, hit.Instance) and not nearHole(at) then
				return at, -side
			end
		end
	end
	return clearSpot(world, center, avoid), nil
end

function Activities.build(parent: Instance, plan: Generator.Plan, distance: number): any
	assert(Plan.validate(plan))
	local old = parent:FindFirstChild("CampaignActivities")
	if old then
		old:Destroy()
	end
	local root = Build.folder(parent, "CampaignActivities")
	local built: any = { root = root, targets = {}, lamps = {}, labels = {}, meters = {}, styles = {}, plan = plan }
	-- Só uma chave por capítulo foge (sorteada a cada partida): surpresa, não rotina.
	local keys: { string } = {}
	for _, spec in plan.activities do
		-- No cap. 1 as três chaves são puzzles do banco v2 (HouseMiniPuzzles); nenhuma foge.
		if spec.kind == "collect" and string.find(spec.item or "", "key", 1, true) and plan.stage ~= 1 then
			table.insert(keys, spec.id)
		end
	end
	local runawayId = if #keys > 0 then keys[math.random(1, #keys)] else nil
	for index, spec in plan.activities do
		local model = Build.model(root, spec.id)
		model:SetAttribute("RoomLabel", spec.room)
		local p = Vector3.new(spec.x, spec.y or 0, spec.z)
		-- Gasolina (capítulo 5) vai direto na pilha de madeira do chão, sem pedestal.
		local fuel = spec.item == "gas_pour" or spec.item == "gas_ignite"
		if fuel then
			p = clearSpot(parent, p)
			spec.x, spec.z = p.X, p.Z
		end
		-- Referência transparente para o marcador existente do FieldHud.
		Build.block(
			model,
			"Station",
			p,
			Vector3.new(0.2, 0.2, 0.2),
			0,
			gold,
			{ collide = false, query = false, transparency = 1 }
		)
		-- Cap. 1 (banco v2): Tábua Oca (chave do Juca) e Banquinho que Foge (chave do Valdemar).
		if plan.stage == 1 and (spec.item == "key_kitchen" or spec.item == "key_dining") then
			local center = Stash.center(spec) or p
			local function floorSpot(avoid: { Vector3 }): Vector3
				return clearSpot(parent, center, avoid)
			end
			local made
			if spec.item == "key_kitchen" then
				made = Mini.planks(root, spec, floorSpot, distance)
			else
				local wall, facing = wallSpot(parent, center)
				made = Mini.stools(root, spec, wall, facing or Vector3.zAxis, floorSpot, distance)
			end
			for id, target in made do
				built.targets[id] = target
			end
			continue
		end
		-- Itens pequenos ficam escondidos em um de três móveis do cômodo (HiddenStash).
		if Stash.hideable(plan.stage, spec) then
			local center = Stash.center(spec) or p
			-- Caixinha da Lia (cap. 1): seis móveis, e o certo toca a música do sahur.
			local music = plan.stage == 1 and spec.item == "key_living"
			for id, target in
				Stash.build(root, spec, center, function(avoid)
					return wallSpot(parent, center, avoid)
				end, distance, if music then 6 else nil)
			do
				built.targets[id] = target
				if music and not target.decoy then
					Mini.musicBox(target.focus, function()
						return target.opened
					end, plan.seed)
				end
				-- Chave para continuar: o móvel certo cria perninhas e foge quando alguém chega perto.
				if not target.decoy and spec.id == runawayId then
					Runaway.attach(target, center)
				end
			end
			continue
		end
		if spec.kind == "hide" or spec.kind == "breath" or spec.kind == "explore" then
			continue
		end
		-- Na floresta o item fica num toco de árvore (pedestal de casa destoava na mata).
		local base = if plan.stage >= 6
			then Build.cylinder(
				model,
				"ForestStump",
				p + Vector3.new(0, 0.85, 0),
				Vector3.yAxis,
				1.7,
				3.6,
				Color3.fromRGB(86, 64, 44),
				{ material = Enum.Material.Wood }
			)
			else Build.block(
				model,
				-- Sem pedestal na gasolina: o PrimitiveFinish veste todo "AntiquePedestal" com uma mesinha.
				if fuel then "FuelBase" else "AntiquePedestal",
				p,
				Vector3.new(4, 1.7, 2),
				0,
				Color3.fromRGB(53, 35, 29),
				{ transparency = if fuel then 1 else 0, collide = not fuel, query = not fuel }
			)
		base.Material = Enum.Material.Wood
		local style = if spec.kind == "puzzle" then PuzzleStyles.forTask(plan.stage, index, plan.seed) else nil
		if style then
			model:SetAttribute("PuzzleStyle", style.id)
			built.styles[spec.id] = style
		end
		TaskProps.build(model, p, spec.item, spec.kind)
		if style then
			PuzzleProps.build(model, p, style.id)
		end
		if spec.kind == "clue" then
			-- Qual enigma esta pista resolve (e, no painel do porão, a metade final do código do cofre).
			local solvedBy: number? = nil
			if plan.stage >= 6 then
				for n, candidate in plan.activities do
					if candidate.kind == "puzzle" then
						solvedBy = n
						break
					end
				end
			elseif spec.item == "book" then
				solvedBy = 5
			elseif spec.item == "panel_clue" then
				solvedBy = 2
			elseif spec.item == "safe_clue" then
				solvedBy = 4
			end
			local target = if solvedBy then plan.activities[solvedBy] else nil
			local extra = if spec.item == "panel_clue"
					and plan.activities[4]
					and plan.activities[4].kind == "puzzle"
				then PuzzleStyles.answer(PuzzleStyles.forTask(plan.stage, 4, plan.seed), plan.activities[4].order)
				else nil
			local text = if target and solvedBy
				then PuzzleStyles.clue(PuzzleStyles.forTask(plan.stage, solvedBy, plan.seed), target.order, extra)
				elseif plan.stage >= 6 then "O ECO SOBREVIVEU À CASA.\nCHAMEM O RESGATE PELA TORRE."
				else "ELE NÃO É O DONO.\nO CORAÇÃO ESTÁ SOB A CASA."
			Build.sign(
				model,
				"Clue",
				p + Vector3.new(0, 4.5, -0.4),
				Vector3.zAxis,
				Vector2.new(8, 2.7),
				text,
				{ textColor = gold, background = Color3.fromRGB(28, 21, 19), lit = true }
			)
			-- Painel do porão: a música do sahur pintada em bolinhas, da esquerda para a direita, nas cores das teclas.
			if spec.item == "panel_clue" and target then
				for slot, key in target.order do
					local label = PuzzleStyles.forTask(plan.stage, solvedBy :: number, plan.seed).labels[key]
					local rgb = PuzzleStyles.MARK_COLORS[label] or { 232, 224, 204 }
					local dot = Build.cylinder(
						model,
						"NoteColor",
						p + Vector3.new((slot - 2.5) * 1.7, 6.8, -0.45),
						Vector3.zAxis,
						0.15,
						1.3,
						Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
						{ material = Enum.Material.Neon, collide = false, query = false }
					)
					dot.CastShadow = false
				end
			end
		end
		if spec.kind == "collect" and spec.item and string.find(spec.item, "key") then
			Build.cylinder(
				model,
				"KeyRing",
				p + Vector3.new(0, 2.3, 0),
				Vector3.yAxis,
				0.2,
				1.4,
				gold,
				{ collide = false }
			)
		elseif spec.item == "flashlight" then
			Build.light(base, "Street", Color3.fromRGB(255, 210, 139), 18, 0.9, true)
		end
		local count = if spec.kind == "puzzle" then 4 elseif spec.kind == "repair" then 3 else 1
		local piano = style ~= nil and style.id == "piano"
		for button = 1, count do
			local id = `{spec.id}_{button}`
			local focus = Build.block(
				model,
				id,
				p + Vector3.new((button - (count + 1) / 2) * 1.8, 2, 0.5),
				if piano
					then PuzzleProps.KEY_SIZE
					else Vector3.new(1.2, if spec.kind == "collect" then 1.6 else 0.8, 0.9),
				0,
				if piano and style then markColor(style.labels[button]) else gold,
				{ collide = false }
			)
			focus:SetAttribute(Tags.Attr.InteractId, id)
			focus:SetAttribute(
				Tags.Attr.InteractPrompt,
				if style
					then `{style.prompt} {style.labels[button]}`
					elseif spec.kind == "repair" then repairSteps[button]
					else spec.title
			)
			focus:SetAttribute(Tags.Attr.InteractDistance, distance)
			focus:SetAttribute(Tags.Attr.InteractEnabled, index == 1 and spec.kind ~= "hide" and spec.kind ~= "breath")
			-- Som de cada botão no cliente que apertou (a nota do piano, o clique do cofre, o chiado do rádio).
			if style and PRESS_SOUNDS[style.id] then
				focus:SetAttribute("PressSound", PRESS_SOUNDS[style.id])
				focus:SetAttribute(
					"PressPitch",
					if piano then PuzzleStyles.PIANO_PITCH[button] else 0.9 + button * 0.12
				)
			end
			CollectionService:AddTag(focus, Tags.Interactable)
			built.targets[id] = {
				taskId = spec.id,
				button = button,
				focus = focus,
				piano = piano,
				color = if piano and style then markColor(style.labels[button]) else nil,
			}
			if count > 1 then
				Build.sign(
					model,
					"Symbol",
					focus.Position + Vector3.new(0, if piano then 1.1 else 1.5, if piano then 0.7 else 0),
					Vector3.zAxis,
					Vector2.new(1.7, 0.7),
					if style
						then style.labels[button]
						elseif spec.kind == "repair" then `{button} {repairSteps[button]}`
						else `{button} {symbols[button]}`,
					{ textColor = if piano and style then markColor(style.labels[button]) else gold, lit = true }
				)
			end
		end
		if piano then
			local pianoKeys: { BasePart } = {}
			for button = 1, count do
				table.insert(pianoKeys, built.targets[`{spec.id}_{button}`].focus)
			end
			liaEcho(model, pianoKeys, spec.order)
		end
		if spec.kind == "repair" or spec.kind == "puzzle" then
			local status = Build.sign(
				model,
				"TaskProgress",
				p + Vector3.new(0, 6, 0),
				Vector3.zAxis,
				Vector2.new(9, 1.2),
				"",
				{ textColor = gold, lit = true }
			)
			built.labels[spec.id] = status:FindFirstChildWhichIsA("TextLabel", true)
		end
	end
	return built
end
local solvedListeners: { (plan: Generator.Plan, index: number) -> () } = {}

-- Momentos roteirizados (ChapterMomentService): chamado uma vez por tarefa, quando ela acaba de ser resolvida.
function Activities.onSolved(callback: (plan: Generator.Plan, index: number) -> ())
	table.insert(solvedListeners, callback)
end

function Activities.refresh(built: any, tasks: any)
	-- A primeira passada só anota o que já veio resolvido (checkpoint), sem disparar nada.
	local first = built.seen == nil
	if first then
		built.seen = {}
	end
	for index, spec in built.plan.activities do
		local state = tasks[spec.id]
		if state and state.solved and not built.seen[spec.id] then
			built.seen[spec.id] = true
			if not first then
				for _, callback in solvedListeners do
					task.spawn(callback, built.plan, index)
				end
			end
		end
	end
	local ready: { [string]: boolean } = {}
	for index, spec in built.plan.activities do
		ready[spec.id] = not tasks[spec.id].solved
			and Progress.ready(built.plan.mode, built.plan.stage, index, function(n)
				return tasks[built.plan.activities[n].id].solved
			end)
	end
	for _, target in built.targets do
		local state = tasks[target.taskId]
		if not state then
			continue
		end
		-- Puzzles do cap. 1 (HouseMiniPuzzles): liberados com a tarefa; a chave da viga espera a pilha.
		if target.handle then
			target.focus:SetAttribute(
				Tags.Attr.InteractEnabled,
				ready[target.taskId] == true and not state.solved and not target.locked
			)
			continue
		end
		-- Móvel de busca (HiddenStash): abre uma vez, só quando a tarefa está liberada.
		if target.search then
			target.focus:SetAttribute(
				Tags.Attr.InteractEnabled,
				ready[target.taskId] == true and not state.solved and not target.opened
			)
			continue
		end
		local spec = state.spec
		if built.labels[spec.id] then
			built.labels[spec.id].Text = if state.solved
				then "CONCLUÍDO"
				elseif not ready[spec.id] then "ENCONTRE AS PISTAS E OS ITENS NECESSÁRIOS"
				elseif spec.kind == "repair" then `{state.progress}/3 · {repairSteps[state.progress + 1]}`
				elseif built.styles[spec.id] then PuzzleStyles.progress(
					built.styles[spec.id],
					spec.order,
					state.progress
				)
				else `{state.progress}/4 · CONSULTE A PISTA RECUPERADA`
		end
		local enabled = ready[target.taskId]
			and spec.kind ~= "hide"
			and spec.kind ~= "breath"
			and spec.kind ~= "explore"
		if spec.kind == "repair" then
			enabled = enabled and target.button == state.progress + 1
		end
		target.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
		target.focus.Transparency = if spec.kind == "collect"
				or spec.item == "gas_pour"
				or spec.item == "gas_ignite"
			then 1
			else 0
		if spec.kind == "collect" and target.focus.Parent then
			for _, object in target.focus.Parent:GetDescendants() do
				if
					object:IsA("BasePart")
					and object ~= target.focus
					and object.Name ~= "Station"
					and object.Name ~= "AntiquePedestal"
				then
					object.Transparency = if state.solved then 1 else 0
				end
			end
		end
		-- Gasolina espalhada: a poça aparece embaixo da pilha (e é dela que o fogo estoura no fim).
		if (spec.item == "gas_pour" or spec.item == "gas_ignite") and target.focus.Parent then
			for _, puddle in target.focus.Parent:GetChildren() do
				if puddle:IsA("BasePart") and puddle.Name == "GasPuddle" then
					puddle.Transparency = if state.solved then 0.05 else 1
				end
			end
		end
		-- Teclas do piano na cor da música (apagadas enquanto bloqueadas, clareadas depois de resolvido).
		if target.piano then
			local color: Color3 = target.color or PuzzleProps.IVORY
			target.focus.Color = if state.solved
				then color:Lerp(PuzzleProps.IVORY, 0.55)
				elseif enabled then color
				else color:Lerp(Color3.fromRGB(70, 66, 60), 0.6)
			continue
		end
		target.focus.Color = if state.solved or (spec.kind == "repair" and target.button <= state.progress)
			then Color3.fromRGB(63, 105, 76)
			elseif enabled then Color3.fromRGB(219, 171, 80)
			else Color3.fromRGB(97, 91, 77)
	end
end
return Activities
