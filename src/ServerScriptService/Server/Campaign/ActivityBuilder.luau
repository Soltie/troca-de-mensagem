--!strict
-- Converte um plano em estações sem colisão e bloqueios somente nos atalhos opcionais.
local CollectionService = game:GetService("CollectionService")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Build = require("../World/Build")
local Palette = require("../World/Palette")
local Generator = require("./CampaignGenerator")
local Session = require("./CoopSession")

export type Target = { taskId: string, button: number, focus: BasePart }
export type Built = {
	root: Folder,
	targets: { [string]: Target },
	lamps: { [string]: BasePart },
	labels: { [string]: TextLabel },
	meters: { [string]: { BasePart } },
	plan: Generator.Plan,
}
local HouseActivities = require("./HouseActivities")
local Builder = {}
local repairNames = { "ISOLAR CIRCUITO", "ENCAIXAR FUSIVEL", "TESTAR ENERGIA" }

function Builder.build(parent: Instance, plan: Generator.Plan, distance: number): Built
	if plan.house then
		return HouseActivities.build(parent, plan, distance)
	end
	local valid, reason = Generator.validate(plan)
	assert(valid, `[CampaignBuilder] invalid plan: {reason}`)
	local previous = parent:FindFirstChild("CampaignActivities")
	if previous then
		previous:Destroy()
	end
	local root = Build.folder(parent, "CampaignActivities")
	local built: Built = { root = root, targets = {}, lamps = {}, labels = {}, meters = {}, plan = plan }
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
		local instructions = Build.sign(
			model,
			"Instructions",
			p + Vector3.new(0, 5.2, 0),
			Vector3.zAxis,
			Vector2.new(6.5, 2.4),
			string.format("%02d / %s\n%s", index, activity.title or Catalog.RoomNames[activity.room] or "SETOR", clue),
			{
				textColor = Palette.Hazard,
				background = Palette.Black,
				lit = true,
			}
		)
		built.labels[activity.id] = instructions:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
		built.meters[activity.id] = {}
		for step = 1, 3 do
			table.insert(
				built.meters[activity.id],
				Build.block(
					model,
					`Step{step}`,
					p + Vector3.new((step - 2) * 0.8, 2.95, 0.6),
					Vector3.new(0.6, 0.12, 0.15),
					0,
					Palette.MetalDark,
					{ collide = false, query = false }
				)
			)
		end
		Build.sign(
			model,
			"Reward",
			p + Vector3.new(0, 0.6, 0.7),
			Vector3.zAxis,
			Vector2.new(5.8, 0.6),
			"EQUIPE +12 F / 24 XP | AJUDA +8 F / 16 XP",
			{ textColor = Palette.ExitGreen, background = Palette.Black, lit = true }
		)
		for button = 1, (if activity.kind == "relay" then 1 else 3) do
			local id = `{activity.id}_{button}`
			local x = if activity.kind ~= "relay" then (button - 2) * 1.05 else 0
			local focus = Build.block(
				model,
				id,
				p + Vector3.new(x, 2.3, 0.6),
				Vector3.new(0.9, 0.7, 0.3),
				0,
				Palette.Hazard,
				{ collide = false }
			)
			Build.sign(
				model,
				`ButtonLabel{button}`,
				p + Vector3.new(x, 1.45, 0.65),
				Vector3.zAxis,
				Vector2.new(0.95, 0.7),
				if activity.kind == "repair"
					then `{button}\n{({ "ISOLAR", "TROCAR", "TESTAR" })[button]}`
					elseif activity.kind == "sequence" then tostring(button)
					else "RELE",
				{ textColor = Palette.Hazard, background = Palette.Black, lit = true }
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

function Builder.refresh(built: Built, tasks: { [string]: Session.TaskState }, now: number?, activePlayers: number?)
	if built.plan.house then
		HouseActivities.refresh(built, tasks)
		return
	end
	local clock = now or workspace:GetServerTimeNow()
	local active = activePlayers or built.plan.players
	local current: string? = nil
	for _, spec in built.plan.activities do
		local state = tasks[spec.id]
		if state and not state.solved then
			current = spec.id
			break
		end
	end
	for index, spec in built.plan.activities do
		local state = tasks[spec.id]
		if not state then
			continue
		end
		local locked = built.plan.mode == "Story" and spec.id ~= current and not state.solved
		local clue = if state.solved
			then "CONCLUIDA - EQUIPE AVANCOU"
			elseif locked then "AGUARDE O OBJETIVO ATUAL"
			elseif spec.kind == "repair" then `{state.progress}/3 | PROXIMO: {repairNames[state.progress + 1]}`
			elseif
				spec.kind == "sequence"
			then `ORDEM: {table.concat(spec.order, " - ")}\n{state.progress}/3 | ACIONE {spec.order[state.progress + 1]} (ACERTOS SALVOS)`
			elseif state.relayBy and active == 1 then `CONFIRME SOZINHO: E EM {math.max(
				0,
				math.ceil(state.relayUntil - clock)
			)}s`
			elseif state.relayBy then `COLEGA: CONFIRME COM E EM {math.max(0, math.ceil(state.relayUntil - clock))}s`
			elseif active == 1 then "ULTIMO ATIVO: E, DEPOIS E DE NOVO"
			else "VENHAM EM DUPLA: E, DEPOIS OUTRO COLEGA USA E"
		local title = spec.title or Catalog.KindNames[spec.kind]
		built.labels[spec.id].Text = PixelText.normalize(string.format("%02d / %s\n%s", index, title, clue))
		for step, meter in built.meters[spec.id] do
			meter.Color = if state.solved or step <= state.progress then Palette.ExitGreen else Palette.MetalDark
			meter.Material = Enum.Material.Neon
		end
	end
	for _, target in built.targets do
		local state = tasks[target.taskId]
		local locked = built.plan.mode == "Story" and target.taskId ~= current
		target.focus:SetAttribute(Tags.Attr.InteractEnabled, state ~= nil and not state.solved and not locked)
		if state then
			local kind = state.spec.kind
			local nextButton = if kind == "sequence" then state.spec.order[state.progress + 1] else state.progress + 1
			local prompt = if kind == "repair"
				then repairNames[target.button]
				elseif kind == "sequence" then `ACIONAR {target.button}`
				elseif state.relayBy then "CONFIRMAR RELE (OUTRO COLEGA)"
				else "ARMAR RELE - CHAME UM COLEGA"
			if kind == "relay" and active == 1 then
				prompt = if state.relayBy then "CONFIRMAR RELE SOZINHO" else "ARMAR RELE SOZINHO"
			end
			target.focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
			target.focus.Color = if state.solved
				then Palette.ExitGreen
				elseif locked then Palette.MetalDark
				elseif kind == "relay" or target.button == nextButton then Palette.Hazard
				else Palette.MetalDark
			target.focus.Material = if not locked and (target.button == nextButton or kind == "relay")
				then Enum.Material.Neon
				else Enum.Material.Metal
		end
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
