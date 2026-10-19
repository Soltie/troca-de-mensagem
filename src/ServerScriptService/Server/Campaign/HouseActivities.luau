--!strict
-- Objetos de missão da casa, distintos das estações industriais preservadas para regressão.
local CollectionService = game:GetService("CollectionService")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local Plan = require("./HousePlan")
local Generator = require("./CampaignGenerator")
local TaskProps = require("../World/HouseTaskProps")
local Progress = require("@game/ReplicatedStorage/Shared/Game/HouseProgression")
local Activities = {}
local repairSteps = { "ISOLAR O CIRCUITO", "ENCAIXAR OS FUSÍVEIS", "TESTAR A ENERGIA" }
local gold = Color3.fromRGB(219, 171, 80)
local symbols = { "LUA", "OLHO", "CHAMA", "PORTA" }
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
}
local OBSTACLES = { "Furniture", "Props", "Furnishings", "Dressing", "Architecture", "Finish", "PrimitiveFinish" }
local function clearSpot(world: Instance, p: Vector3): Vector3
	-- Móveis não respondem a consultas de física (CanQuery desligado); confere as caixas na mão, só por perto.
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
				and (part.Position - p).Magnitude < 24
				and math.max(part.Size.X, part.Size.Z) > 0.6
			then
				table.insert(nearby, part)
			end
		end
	end
	for _, offset in OFFSETS do
		local at = p + Vector3.new(offset[1], 0, offset[2])
		local blocked = false
		for _, part in nearby do
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
				part.Position.Y + hy > p.Y + 0.4
				and part.Position.Y - hy < p.Y + 3.5
				and math.abs(part.Position.X - at.X) < hx + 2.3
				and math.abs(part.Position.Z - at.Z) < hz + 2.3
			then
				blocked = true
				break
			end
		end
		if not blocked then
			return at
		end
	end
	return p
end

function Activities.build(parent: Instance, plan: Generator.Plan, distance: number): any
	assert(Plan.validate(plan))
	local old = parent:FindFirstChild("CampaignActivities")
	if old then
		old:Destroy()
	end
	local root = Build.folder(parent, "CampaignActivities")
	local built: any = { root = root, targets = {}, lamps = {}, labels = {}, meters = {}, plan = plan }
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
		if spec.kind == "hide" or spec.kind == "breath" or spec.kind == "explore" then
			continue
		end
		local base = Build.block(
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
		TaskProps.build(model, p, spec.item, spec.kind)
		if spec.kind == "clue" then
			local solution: { number }? = nil
			if plan.stage >= 6 then
				for _, candidate in plan.activities do
					if candidate.kind == "puzzle" then
						solution = candidate.order
						break
					end
				end
			elseif spec.item == "book" then
				solution = plan.activities[5].order
			elseif spec.item == "panel_clue" then
				solution = plan.activities[2].order
			elseif spec.item == "safe_clue" then
				solution = plan.activities[4].order
			end
			local text = if solution
				then `LUA=1 OLHO=2 CHAMA=3 PORTA=4\nORDEM: {table.concat(solution, " - ")}`
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
		for button = 1, count do
			local id = `{spec.id}_{button}`
			local focus = Build.block(
				model,
				id,
				p + Vector3.new((button - (count + 1) / 2) * 1.8, 2, 0.5),
				Vector3.new(1.2, if spec.kind == "collect" then 1.6 else 0.8, 0.9),
				0,
				gold,
				{ collide = false }
			)
			focus:SetAttribute(Tags.Attr.InteractId, id)
			focus:SetAttribute(
				Tags.Attr.InteractPrompt,
				if spec.kind == "puzzle"
					then `PRESSIONAR {symbols[button]}`
					elseif spec.kind == "repair" then repairSteps[button]
					else spec.title
			)
			focus:SetAttribute(Tags.Attr.InteractDistance, distance)
			focus:SetAttribute(Tags.Attr.InteractEnabled, index == 1 and spec.kind ~= "hide" and spec.kind ~= "breath")
			CollectionService:AddTag(focus, Tags.Interactable)
			built.targets[id] = { taskId = spec.id, button = button, focus = focus }
			if count > 1 then
				Build.sign(
					model,
					"Symbol",
					focus.Position + Vector3.new(0, 1.5, 0),
					Vector3.zAxis,
					Vector2.new(1.7, 0.7),
					if spec.kind == "repair" then `{button} {repairSteps[button]}` else `{button} {symbols[button]}`,
					{ textColor = gold, lit = true }
				)
			end
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
function Activities.refresh(built: any, tasks: any)
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
		local spec = state.spec
		if built.labels[spec.id] then
			built.labels[spec.id].Text = if state.solved
				then "CONCLUÍDO"
				elseif not ready[spec.id] then "ENCONTRE AS PISTAS E OS ITENS NECESSÁRIOS"
				elseif spec.kind == "repair" then `{state.progress}/3 · {repairSteps[state.progress + 1]}`
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
		target.focus.Color = if state.solved or (spec.kind == "repair" and target.button <= state.progress)
			then Color3.fromRGB(63, 105, 76)
			elseif enabled then Color3.fromRGB(219, 171, 80)
			else Color3.fromRGB(97, 91, 77)
	end
end
return Activities
