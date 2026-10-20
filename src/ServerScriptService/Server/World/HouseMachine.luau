--!strict
--[[
	A máquina de marceneiro do Valdemar (roteiro "A Casa de Madeira"): quem o Tum Tum pega é jogado no funil e sai
	como móvel. Fica na SALA DE MÁQUINAS (térreo, ala leste do fundo), no meio, com a boca virada para a porta (+Z).
	Por enquanto é um corpo provisório em blocos; o artista 3D troca pelo WoodMachine.glb dentro do mesmo modelo,
	mantendo os atributos que a captura lê do mapa:
	- ThrowTarget (Vector3): boca do funil, para onde o Tum Tum arremessa quem pegou.
	- SpawnPoint (Vector3): onde o móvel sai, na frente da saída de serragem.
]]

local Build = require("./Build")
local HouseArt = require("./HouseArt")

local HouseMachine = {}

-- Centro da base: 14 studs para dentro da parede da frente (z = −52,5), longe do esconderijo da Sala de Máquinas.
HouseMachine.CENTER = Vector3.new(29, 0, -66)
HouseMachine.THROW_TARGET = Vector3.new(29, 7, -66)
HouseMachine.SPAWN_POINT = Vector3.new(29, 3, -72.5)
-- As peças abaixo são desenhadas encostadas no fundo (z = −78,5, saída para +Z); a parede do fundo já tem a mesa
-- antiga e o quadro de força, então o corpo vai para perto da porta da frente, saída virada para o fundo (−Z).
local PLACE = CFrame.new(HouseMachine.CENTER) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-30, 0, 78.5)

local wood = Color3.fromRGB(78, 52, 34)
local dark = Color3.fromRGB(44, 30, 22)
local iron = Color3.fromRGB(70, 66, 60)
local sawdust = Color3.fromRGB(196, 164, 112)

function HouseMachine.build(parent: Instance): Model
	local model = Build.model(parent, "CarpenterMachine")
	model:SetAttribute("ThrowTarget", HouseMachine.THROW_TARGET)
	model:SetAttribute("SpawnPoint", HouseMachine.SPAWN_POINT)
	model:SetAttribute("Placeholder", true)
	local function piece(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material,
		solid: boolean
	)
		return Build.part(model, name, size, cframe, color, { material = material, collide = solid, query = solid })
	end
	-- Corpo de madeira com cintas de ferro.
	piece("MachineBody", Vector3.new(6, 5, 4), CFrame.new(30, 2.5, -78.5), wood, Enum.Material.WoodPlanks, true)
	for _, y in { 1, 4 } do
		piece("IronBand", Vector3.new(6.1, 0.3, 4.1), CFrame.new(30, y, -78.5), iron, Enum.Material.Metal, false)
	end
	-- Funil em cima (quatro tábuas inclinadas abrindo para cima).
	for side = -1, 1, 2 do
		piece(
			"FunnelBoard",
			Vector3.new(0.4, 3, 4),
			CFrame.new(30 + side * 2.2, 6.4, -78.5) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			dark,
			Enum.Material.Wood,
			false
		)
		piece(
			"FunnelBoard",
			Vector3.new(4, 3, 0.4),
			CFrame.new(30, 6.4, -78.5 + side * 1.8) * CFrame.Angles(math.rad(side * 25), 0, 0),
			dark,
			Enum.Material.Wood,
			false
		)
	end
	-- Engrenagens na lateral.
	for index, at in { Vector3.new(33.15, 3.2, -79.5), Vector3.new(33.15, 1.6, -77.6) } do
		Build.cylinder(
			model,
			"Gear",
			at,
			Vector3.xAxis,
			0.3,
			if index == 1 then 2.4 else 1.6,
			iron,
			{ material = Enum.Material.Metal, collide = false, query = false }
		)
	end
	-- Saída de serragem na frente e o montinho no chão.
	piece(
		"SawdustChute",
		Vector3.new(2, 0.4, 2.6),
		CFrame.new(30, 1.4, -75.4) * CFrame.Angles(math.rad(-20), 0, 0),
		dark,
		Enum.Material.Wood,
		false
	)
	local pile = Build.part(
		model,
		"SawdustPile",
		Vector3.new(0.6, 3.2, 3.2),
		CFrame.new(30, 0.15, -73.6) * CFrame.Angles(0, 0, math.rad(90)),
		sawdust,
		{ material = Enum.Material.Sand, collide = false, query = false }
	);
	(pile :: Part).Shape = Enum.PartType.Cylinder
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = PLACE * part.CFrame
		end
	end
	-- Modelo do artista (WoodMachine): a boca fica no +X dele; girar −90° deixa a boca virada para +Z (para a porta).
	-- Com ele no lugar, as peças provisórias saem e os alvos da captura seguem a caixa do modelo: o arremesso na
	-- frente da boca e o móvel saindo pelo outro lado.
	local pivot = CFrame.new(HouseMachine.CENTER) * CFrame.Angles(0, math.rad(-90), 0)
	-- Versão nova (boca funda com serras e rolos) primeiro; a antiga fica de reserva.
	local art = HouseArt.place(model, "WoodMachine_v3", pivot) or HouseArt.place(model, "WoodMachine", pivot)
	if art then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part:Destroy()
			end
		end
		local box, size = art:GetBoundingBox()
		local half = size.Z / 2
		model:SetAttribute(
			"ThrowTarget",
			Vector3.new(box.Position.X, box.Position.Y + size.Y * 0.1, box.Position.Z + half + 1)
		)
		model:SetAttribute("SpawnPoint", Vector3.new(box.Position.X, 3, box.Position.Z - half - 2))
		model:SetAttribute("Placeholder", false)
	end
	return model
end

return HouseMachine
