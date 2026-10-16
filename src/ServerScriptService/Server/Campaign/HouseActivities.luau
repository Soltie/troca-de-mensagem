--!strict
-- Objetos de missão da casa, distintos das estações industriais preservadas para regressão.
local CollectionService = game:GetService("CollectionService")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local Plan = require("./HousePlan")
local Generator = require("./CampaignGenerator")
local Activities = {}
local gold = Color3.fromRGB(219, 171, 80)
local symbols = { "LUA", "OLHO", "CHAMA", "PORTA" }
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
		local base = Build.block(model, "AntiquePedestal", p, Vector3.new(4, 1.7, 2), 0, Color3.fromRGB(53, 35, 29))
		base.Material = Enum.Material.Wood
		if spec.kind == "clue" then
			local solution: { number }? = nil
			if spec.item == "book" then
				solution = plan.activities[5].order
			elseif spec.item == "panel_clue" then
				solution = plan.activities[2].order
			elseif spec.item == "safe_clue" then
				solution = plan.activities[4].order
			end
			local text = if solution
				then `LUA=1 OLHO=2 CHAMA=3 PORTA=4\nORDEM: {table.concat(solution, " - ")}`
				else "NÃO ACORDE O DONO.\nO CORAÇÃO ESTÁ SOB A CASA."
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
		local count = if spec.kind == "puzzle" then 4 else 1
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
				if spec.kind == "puzzle" then `PRESSIONAR {symbols[button]}` else spec.title
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
					`{button} {symbols[button]}`,
					{ textColor = gold, lit = true }
				)
			end
		end
	end
	return built
end
function Activities.refresh(built: any, tasks: any)
	local current: string? = nil
	for _, spec in built.plan.activities do
		if not tasks[spec.id].solved then
			current = spec.id
			break
		end
	end
	for _, target in built.targets do
		local state = tasks[target.taskId]
		if not state then
			continue
		end
		local spec = state.spec
		local enabled = current == target.taskId
			and spec.kind ~= "hide"
			and spec.kind ~= "breath"
			and spec.kind ~= "explore"
		target.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
		target.focus.Transparency = if state.solved and spec.kind == "collect" then 1 else 0
		target.focus.Color = if state.solved then Color3.fromRGB(63, 105, 76) else Color3.fromRGB(219, 171, 80)
	end
end
return Activities
