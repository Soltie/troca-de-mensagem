--!strict
-- Converte um plano em estações sem colisão e bloqueios somente nos atalhos opcionais.
local CollectionService = game:GetService("CollectionService")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local Palette = require("../World/Palette")
local Generator = require("./CampaignGenerator")
local Session = require("./CoopSession")

export type Target = { taskId: string, button: number, focus: BasePart }
export type Built = { root: Folder, targets: { [string]: Target }, lamps: { [string]: BasePart } }
local Builder = {}

function Builder.build(parent: Instance, plan: Generator.Plan, distance: number): Built
	local valid, reason = Generator.validate(plan)
	assert(valid, `[CampaignBuilder] invalid plan: {reason}`)
	local previous = parent:FindFirstChild("CampaignActivities")
	if previous then
		previous:Destroy()
	end
	local root = Build.folder(parent, "CampaignActivities")
	local built: Built = { root = root, targets = {}, lamps = {} }
	for index, activity in plan.activities do
		local model = Build.model(root, activity.id)
		model:SetAttribute("RoomLabel", Catalog.RoomNames[activity.room])
		local p = Vector3.new(activity.x, 0, activity.z)
		Build.block(model, "Station", p, Vector3.new(3.4, 3, 0.9), 0, Palette.MetalDark, { collide = false })
		local lamp = Build.block(
			model,
			"Status",
			p + Vector3.new(0, 3.5, 0),
			Vector3.new(0.45, 0.4, 0.3),
			0,
			Palette.Red,
			{ collide = false }
		)
		built.lamps[activity.id] = lamp
		local clue = if activity.kind == "sequence"
			then `SEQUÊNCIA {table.concat(activity.order, " - ")}`
			elseif activity.kind == "relay" then "RELÉ: DUAS PESSOAS CONFIRMAM"
			else "REPARAR: 3 ETAPAS"
		Build.sign(
			model,
			"Instructions",
			p + Vector3.new(0, 5.2, 0),
			Vector3.zAxis,
			Vector2.new(5.5, 1.5),
			string.format("%02d / %s\n%s", index, activity.title or Catalog.RoomNames[activity.room] or "SETOR", clue),
			{
				textColor = Palette.Hazard,
				background = Palette.Black,
				lit = true,
			}
		)
		for button = 1, (if activity.kind == "sequence" then 3 else 1) do
			local id = `{activity.id}_{button}`
			local x = if activity.kind == "sequence" then (button - 2) * 0.9 else 0
			local focus = Build.block(
				model,
				id,
				p + Vector3.new(x, 2.3, 0.6),
				Vector3.new(0.7, 0.6, 0.25),
				0,
				Palette.Hazard,
				{ collide = false }
			)
			focus:SetAttribute(Tags.Attr.InteractId, id)
			focus:SetAttribute(
				Tags.Attr.InteractPrompt,
				if activity.kind == "sequence" then `ACIONAR {button}` else "CONFIRMAR ESTAÇÃO"
			)
			focus:SetAttribute(Tags.Attr.InteractDistance, distance)
			focus:SetAttribute(Tags.Attr.InteractEnabled, true)
			CollectionService:AddTag(focus, Tags.Interactable)
			built.targets[id] = { taskId = activity.id, button = button, focus = focus }
		end
	end
	for _, id in plan.closedLinks do
		for _, link in Catalog.Links do
			if link.id == id then
				local size = if link.axis == "X" then Vector3.new(6, 9, 0.8) else Vector3.new(0.8, 9, 6)
				local shutter = Build.block(
					root,
					`Shutter_{id}`,
					Vector3.new(link.x, 0, link.z),
					size,
					0,
					Palette.WallLowerCold,
					{ material = Enum.Material.Metal }
				)
				shutter:SetAttribute("OptionalLink", id)
			end
		end
	end
	return built
end

function Builder.refresh(built: Built, tasks: { [string]: Session.TaskState })
	for _, target in built.targets do
		local state = tasks[target.taskId]
		target.focus:SetAttribute(Tags.Attr.InteractEnabled, state ~= nil and not state.solved)
		local lamp = built.lamps[target.taskId]
		if state and lamp then
			lamp.Color = if state.solved
				then Palette.ExitGreen
				elseif state.progress > 0 then Palette.Hazard
				else Palette.Red
			lamp.Material = Enum.Material.Neon
			lamp:SetAttribute("Progress", state.progress)
			lamp:SetAttribute("Solved", state.solved)
		end
	end
end

return Builder
