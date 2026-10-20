--!strict
-- Silhuetas reconhecíveis para pistas/objetos. Detalhes não roubam o raycast do alvo.
local Build = require("./Build")
local Props = {}
local V3 = Vector3.new
local brass = Color3.fromRGB(190, 153, 78)
local paper = Color3.fromRGB(204, 190, 147)
local dark = Color3.fromRGB(46, 43, 46)
local function part(parent: Instance, name: string, p: Vector3, size: Vector3, color: Color3)
	local metal = string.find(name, "Key")
		or string.find(name, "Cap")
		or string.find(name, "Flashlight")
		or name == "FuseCabinet"
	local ceramic = string.find(name, "Fuse") or name == "PorcelainMask"
	local result = Build.block(parent, name, p, size, 0, color, {
		collide = false,
		query = false,
		material = if metal
			then Enum.Material.Metal
			elseif ceramic then Enum.Material.Marble
			else Enum.Material.SmoothPlastic,
	})
	result.CanTouch = false
	return result
end

local function cylinder(
	parent: Instance,
	name: string,
	center: Vector3,
	axis: Vector3,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local result = Build.cylinder(parent, name, center, axis, length, diameter, color, {
		collide = false,
		query = false,
		material = material or Enum.Material.Metal,
	})
	result.CanTouch = false
	return result
end

-- Argola vazada de dez segmentos, sem textura/asset novo; não vira um disco maciço.
local function ring(parent: Instance, center: Vector3, radius: number)
	for index = 0, 9 do
		local angle = index * math.pi / 5
		local nextAngle = (index + 1) * math.pi / 5
		local a = center + V3(math.cos(angle), 0, math.sin(angle)) * radius
		local b = center + V3(math.cos(nextAngle), 0, math.sin(nextAngle)) * radius
		cylinder(parent, "KeyBow", (a + b) / 2, b - a, (b - a).Magnitude + 0.025, 0.1, brass)
	end
end

local function cartridge(parent: Instance, at: Vector3, axis: Vector3, length: number, diameter: number)
	cylinder(parent, "FuseBody", at, axis, length, diameter, Color3.fromRGB(211, 207, 184), Enum.Material.Marble)
	for _, side in { -1, 1 } do
		cylinder(parent, "FuseCap", at + axis * side * (length / 2 - 0.12), axis, 0.3, diameter * 1.08, brass)
		cylinder(parent, "FuseContact", at + axis * side * (length / 2 + 0.045), axis, 0.09, diameter * 0.6, dark)
	end
	for index = -2, 2 do
		cylinder(
			parent,
			"CeramicRib",
			at + axis * index * length * 0.12,
			axis,
			0.045,
			diameter * 1.06,
			Color3.fromRGB(181, 176, 153),
			Enum.Material.Marble
		)
	end
end

-- O renderer de campanha cria os alvos depois dos objetos. Só o visual deles é substituído:
-- nome, CFrame, tamanho, query, tags, prompts e estado continuam nos alvos originais.
local function finishControls(parent: Instance, kind: string)
	-- Piano (PuzzleStyles): os botões já são as teclas brancas; nada de botão redondo por cima.
	if parent:GetAttribute("PuzzleStyle") == "piano" then
		return
	end
	if kind ~= "repair" and kind ~= "puzzle" then
		return
	end
	parent.ChildAdded:Connect(function(child)
		if not child:IsA("BasePart") then
			return
		end
		local matched = false
		for index = 1, (if kind == "repair" then 3 else 4) do
			matched = matched or child.Name == `{parent.Name}_{index}`
		end
		if not matched then
			return
		end
		task.defer(function()
			if not child.Parent then
				return
			end
			local at = child.Position + Vector3.zAxis * (child.Size.Z / 2 + 0.025)
			cylinder(parent, "ControlBezel", at, Vector3.zAxis, 0.1, 0.88, brass)
			local button =
				cylinder(parent, "ControlButton", at + Vector3.zAxis * 0.08, Vector3.zAxis, 0.11, 0.64, child.Color)
			local slot = part(parent, "ControlSlot", at + V3(-0.17, -0.025, 0.15), V3(0.34, 0.05, 0.025), dark)
			slot.Material = Enum.Material.Metal
			child.Transparency, child.CastShadow = 1, false
			child:GetPropertyChangedSignal("Transparency"):Connect(function()
				if child.Transparency ~= 1 then
					child.Transparency = 1
				end
			end)
			child:GetPropertyChangedSignal("Color"):Connect(function()
				button.Color = child.Color
			end)
		end)
	end)
end

-- Pistas e "ativar": o alvo único (`<tarefa>_1`) era um bloco cinza visível sobre o objeto. Ele continua sendo o
-- alvo (raycast, tags, prompt), mas fica invisível; a cor de estado (cinza, âmbar, verde) passa para `indicator`.
local function mirrorTarget(parent: Instance, indicator: BasePart)
	parent.ChildAdded:Connect(function(child)
		if not child:IsA("BasePart") or child.Name ~= `{parent.Name}_1` then
			return
		end
		task.defer(function()
			if not child.Parent then
				return
			end
			indicator.Color = child.Color
			child.Transparency, child.CastShadow = 1, false
			child:GetPropertyChangedSignal("Transparency"):Connect(function()
				if child.Transparency ~= 1 then
					child.Transparency = 1
				end
			end)
			child:GetPropertyChangedSignal("Color"):Connect(function()
				indicator.Color = child.Color
			end)
		end)
	end)
end

-- Pilha de madeira velha e panos onde se joga a gasolina (capítulo 5). A poça (`GasPuddle`) só aparece depois de
-- espalhar (HouseActivities.refresh); o alvo invisível fica no meio da pilha.
local function fuelPile(parent: Instance, p: Vector3, big: boolean)
	local wood = Color3.fromRGB(74, 52, 36)
	local crate = part(parent, "FuelCrate", p + V3(-0.7, 0, 0.2), V3(1.8, 1.3, 1.5), wood)
	crate.Material = Enum.Material.WoodPlanks
	crate.CFrame *= CFrame.Angles(0, math.rad(12), 0)
	local small = part(parent, "FuelCrate", p + V3(0.9, 0, -0.1), V3(1.3, 1, 1.2), wood:Lerp(Color3.new(0, 0, 0), 0.2))
	small.Material = Enum.Material.WoodPlanks
	small.CFrame *= CFrame.Angles(0, math.rad(-20), 0)
	for index, offset in { V3(-0.3, 1.3, 0.1), V3(0.5, 1, -0.4), V3(0.1, 0.05, 0.9) } do
		local plank = part(parent, "FuelPlank", p + offset, V3(2.6, 0.18, 0.4), wood:Lerp(Color3.new(1, 1, 1), 0.05))
		plank.Material = Enum.Material.Wood
		plank.CFrame *= CFrame.Angles(math.rad(index * 7), math.rad(index * 47), math.rad(index * 9 - 10))
	end
	local rag = part(parent, "FuelRag", p + V3(0.2, 1.2, 0.35), V3(1.4, 0.12, 1.1), Color3.fromRGB(122, 104, 82))
	rag.Material = Enum.Material.Fabric
	rag.CFrame *= CFrame.Angles(math.rad(8), math.rad(30), math.rad(-6))
	-- Poça escura e oleosa, irregular (três manchas sobrepostas).
	for index, spot in { { 0, 0.4, 1 }, { 1.3, -0.5, 0.65 }, { -1.4, 1.2, 0.55 } } do
		local size = (if big then 6 else 4.6) * spot[3]
		local puddle = cylinder(
			parent,
			"GasPuddle",
			p + V3(spot[1], 0.22 + index * 0.005, spot[2]),
			Vector3.yAxis,
			0.04,
			size,
			Color3.fromRGB(30, 24, 17),
			Enum.Material.SmoothPlastic
		)
		puddle.Reflectance = 0.12
		puddle.Transparency = 1
		puddle.CastShadow = false
	end
end

function Props.build(parent: Instance, p: Vector3, item: string?, kind: string)
	local center = p + V3(0, 1.8, 0)
	if item == "gas_pour" or item == "gas_ignite" then
		fuelPile(parent, p, item == "gas_ignite")
		return
	elseif item == "gasoline" then
		-- Galão vermelho de metal com alça e bico.
		local red = Color3.fromRGB(150, 30, 24)
		local can = part(parent, "GasCan", p + V3(0, 1.7, 0), V3(1.5, 1.9, 0.9), red)
		can.Material = Enum.Material.Metal
		part(parent, "GasCanRib", p + V3(0, 2.35, 0), V3(1.56, 0.08, 0.96), red:Lerp(Color3.new(0, 0, 0), 0.3)).Material =
			Enum.Material.Metal
		part(parent, "GasCanHandle", p + V3(-0.2, 3.6, 0), V3(0.9, 0.18, 0.3), red).Material = Enum.Material.Metal
		cylinder(parent, "GasCanSpout", p + V3(0.62, 3.75, 0), V3(1, 1.2, 0), 0.7, 0.24, Color3.fromRGB(60, 58, 56))
		return
	elseif item == "lighter" then
		-- Isqueiro de metal com a tampa aberta.
		local steel = Color3.fromRGB(150, 148, 140)
		part(parent, "LighterBody", p + V3(0, 1.7, 0), V3(0.5, 0.75, 0.25), steel).Material = Enum.Material.Metal
		local lid = part(parent, "LighterLid", p + V3(-0.3, 2.45, 0), V3(0.5, 0.3, 0.25), steel)
		lid.Material = Enum.Material.Metal
		lid.CFrame *= CFrame.Angles(0, 0, math.rad(40))
		part(parent, "LighterWheel", p + V3(0.08, 2.45, 0), V3(0.16, 0.16, 0.16), Color3.fromRGB(60, 58, 56))
		return
	end
	finishControls(parent, kind)
	if kind == "activate" then
		-- Fechadura de ferro com três buracos de chave; a lâmpada no topo mostra o estado.
		-- `part` posiciona pela base; cilindros, pelo centro.
		local box = part(parent, "LockBox", p + V3(0, 1.7, -0.1), V3(2.6, 1.3, 0.9), dark)
		box.Material = Enum.Material.Metal
		for index = -1, 1 do
			local at = p + V3(index * 0.75, 2.35, 0.37)
			cylinder(parent, "LockEscutcheon", at, Vector3.zAxis, 0.06, 0.42, brass)
			part(parent, "LockKeyhole", at + V3(0, -0.15, 0.035), V3(0.08, 0.22, 0.02), Color3.fromRGB(14, 12, 12))
		end
		local lamp =
			cylinder(parent, "LockLamp", p + V3(0, 3.05, -0.1), Vector3.yAxis, 0.12, 0.5, dark, Enum.Material.Glass)
		cylinder(parent, "LockLampRim", p + V3(0, 3.02, -0.1), Vector3.yAxis, 0.06, 0.62, brass)
		mirrorTarget(parent, lamp)
		return
	end
	if item == "forest_battery" then
		part(parent, "RescueBattery", center, V3(2.7, 1.8, 1.6), dark)
		for _, side in { -1, 1 } do
			part(parent, "BatteryTerminal", center + V3(side * 0.8, 1.8, 0), V3(0.35, 0.4, 0.35), brass)
		end
	elseif item == "forest_antenna" then
		part(parent, "Antenna", center, V3(4.5, 0.2, 0.2), brass)
		for i = 1, 4 do
			part(parent, "AntennaBar", center + V3(-2.5 + i, 0, 0), V3(0.15, 0.15, 2.5), dark)
		end
	elseif item == "forest_crank" then
		Build.cylinder(
			parent,
			"WinchWheel",
			center + V3(0, 0.2, 0),
			Vector3.yAxis,
			0.3,
			2.3,
			brass,
			{ collide = false, query = false }
		)
		part(parent, "CrankHandle", center + V3(0.8, 0.4, 0), V3(0.3, 0.7, 0.3), dark)
	elseif item == "forest_tape" then
		part(parent, "GuardCassette", center, V3(3, 0.4, 1.8), dark)
		for _, side in { -1, 1 } do
			Build.cylinder(
				parent,
				"TapeReel",
				center + V3(side * 0.7, 0.45, 0),
				Vector3.yAxis,
				0.1,
				0.7,
				paper,
				{ collide = false, query = false }
			)
		end
	elseif item == "forest_map" then
		part(parent, "TornMap", center, V3(3.3, 0.15, 2.7), paper)
		for i = 1, 3 do
			part(parent, "MapTrail", center + V3(-1.4 + i * 0.65, 0.16, 0), V3(0.14, 0.03, 1.7), dark)
		end
	elseif kind == "puzzle" and p.Z > 500 then
		part(parent, "RadioReceiver", center + V3(0, 0, -0.8), V3(7, 2.5, 1.5), dark)
		part(parent, "FrequencyDial", center + V3(0, 1.2, 0), V3(5.5, 0.6, 0.2), paper)
	elseif item and string.find(item, "key", 1, true) then
		local pad = part(parent, "KeyPad", p + V3(0, 1.7, 0), V3(1.4, 0.25, 1.95), dark)
		pad.Material, pad.Color = Enum.Material.Fabric, Color3.fromRGB(54, 31, 29)
		local at = p + V3(0, 2.015, 0)
		ring(parent, at + V3(0, 0, -0.5), 0.36)
		cylinder(parent, "KeyShaft", at + V3(0, 0, 0.2), Vector3.zAxis, 1.4, 0.15, brass)
		cylinder(parent, "KeyCollar", at + V3(0, 0, -0.1), Vector3.zAxis, 0.12, 0.24, brass)
		for index = 0, 2 do
			part(parent, "KeyTooth", at + V3(0.16, -0.065, 0.55 + index * 0.17), V3(0.38, 0.13, 0.11), brass)
		end
		-- A argola antiga é um cilindro cheio criado pelo renderer após esta função.
		parent.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") and child.Name == "KeyRing" then
				child.Transparency, child.CastShadow = 1, false
				child:GetPropertyChangedSignal("Transparency"):Connect(function()
					if child.Transparency ~= 1 then
						child.Transparency = 1
					end
				end)
			end
		end)
	elseif kind == "repair" then
		part(parent, "FuseCabinet", p + V3(0, 1.7, -0.8), V3(6.5, 2.6, 0.32), dark)
		local plate = part(parent, "FuseBackplate", p + V3(0, 1.85, -0.57), V3(6.1, 2.3, 0.04), brass)
		plate.Color, plate.Material = Color3.fromRGB(90, 86, 73), Enum.Material.Metal
		for i = 1, 3 do
			local at = p + V3((i - 2) * 1.8, 3.2, -0.2)
			cartridge(parent, at, Vector3.yAxis, 1.35, 0.38)
			for _, y in { -0.65, 0.65 } do
				part(parent, "FuseClip", at + V3(0, y - 0.065, -0.12), V3(0.6, 0.13, 0.24), brass)
			end
		end
	elseif item == "clock" then
		local at = p + V3(0, 2.85, 0)
		cylinder(parent, "ClockBezel", at, Vector3.zAxis, 0.28, 2.18, brass)
		cylinder(
			parent,
			"ClockFace",
			at + V3(0, 0, 0.16),
			Vector3.zAxis,
			0.03,
			1.96,
			paper,
			Enum.Material.SmoothPlastic
		)
		for hour = 0, 11 do
			local angle = hour * math.pi / 6
			local mark = part(
				parent,
				"ClockHour",
				at + V3(math.sin(angle) * 0.82, math.cos(angle) * 0.82 - 0.04, 0.19),
				V3(0.035, 0.08, 0.025),
				dark
			)
			mark.CFrame *= CFrame.Angles(0, 0, -angle)
		end
		part(parent, "ClockHand", at + V3(0, -0.035, 0.22), V3(0.07, 0.65, 0.03), dark)
		part(parent, "ClockHand", at + V3(0.22, -0.035, 0.23), V3(0.5, 0.07, 0.03), dark)
	elseif item == "photo" then
		local frame = part(parent, "PhotoFrame", center, V3(2.5, 2.1, 0.14), dark)
		frame.Material, frame.MaterialVariant = Enum.Material.Wood, "MansionDarkWood"
		part(parent, "PhotoPaper", center + V3(0, 0.16, 0.1), V3(2.18, 1.78, 0.025), paper)
		for i = -1, 1 do
			local torso = part(parent, "FamilySilhouette", center + V3(i * 0.61, 0.4, 0.15), V3(0.42, 0.7, 0.035), dark)
			local head = part(parent, "FamilyHead", center + V3(i * 0.61, 1.1, 0.15), V3(0.28, 0.32, 0.04), dark)
			if head:IsA("Part") then
				head.Shape = Enum.PartType.Ball
			end
			torso.Color, head.Color = Color3.fromRGB(83, 68, 53), Color3.fromRGB(83, 68, 53)
		end
		for _, x in { -1.18, 1.18 } do
			part(parent, "PhotoTrim", center + V3(x, 0.06, 0.11), V3(0.06, 1.98, 0.04), brass)
		end
	elseif item == "mask" then
		local mask = part(parent, "PorcelainMask", p + V3(0, 1.75, 0), V3(1.35, 1.9, 0.38), paper)
		if mask:IsA("Part") then
			mask.Shape = Enum.PartType.Ball
		end
		for _, side in { -1, 1 } do
			local eye = part(parent, "MaskEye", p + V3(side * 0.3, 2.78, 0.18), V3(0.27, 0.15, 0.04), dark)
			if eye:IsA("Part") then
				eye.Shape = Enum.PartType.Ball
			end
		end
		local mouth = part(parent, "MaskMouth", p + V3(0, 2.26, 0.19), V3(0.22, 0.3, 0.04), dark)
		if mouth:IsA("Part") then
			mouth.Shape = Enum.PartType.Ball
		end
	elseif item == "message" then
		-- Carta da Lia (crítico, rodada 2): uma folha lisa e fosca sobre a mesa, sem luz e sem cara de livro.
		local sheet = part(parent, "LetterSheet", center + V3(0, 0.02, 0), V3(1.9, 0.03, 2.5), paper)
		sheet.Material = Enum.Material.Fabric
		sheet.CFrame *= CFrame.Angles(0, math.rad(-9), 0)
		for line = 1, 7 do
			local ink = part(
				parent,
				"LetterInk",
				center + V3(0, 0.045, -1 + line * 0.28),
				V3(1.3 - (line % 3) * 0.2, 0.01, 0.03),
				Color3.fromRGB(70, 56, 42)
			)
			ink.Material = Enum.Material.Fabric
			ink.CFrame = sheet.CFrame * CFrame.new(0, 0.025, -1 + line * 0.28)
		end
		local seal =
			part(parent, "LetterSeal", center + V3(0.6, 0.06, 0.9), V3(0.35, 0.05, 0.35), Color3.fromRGB(96, 30, 28))
		seal.Material = Enum.Material.Fabric
		mirrorTarget(parent, seal)
	elseif kind == "clue" then
		local cover = part(parent, "BookCover", center + V3(0, -0.09, 0), V3(3.5, 0.12, 2.5), dark)
		cover.Material, cover.Color = Enum.Material.Leather, Color3.fromRGB(57, 27, 25)
		for _, side in { -1, 1 } do
			local page = part(parent, "OpenBookPage", center + V3(side * 0.86, 0.04, 0), V3(1.65, 0.12, 2.35), paper)
			page.CFrame *= CFrame.Angles(0, 0, side * math.rad(4))
			for line = 1, 5 do
				part(
					parent,
					"BookInk",
					center + V3(side * 0.86, 0.19, -0.9 + line * 0.3),
					V3(1.1, 0.012, 0.025),
					Color3.fromRGB(100, 85, 64)
				)
			end
		end
		-- Fita marcadora sobre a página e pendurada na frente: mostra o estado da pista.
		local ribbon = part(parent, "BookRibbon", center + V3(0.35, 0.21, 0.15), V3(0.16, 0.015, 2.1), paper)
		ribbon.Material = Enum.Material.Fabric
		local tail = part(parent, "BookRibbonTail", center + V3(0.35, -0.42, 1.27), V3(0.16, 0.62, 0.015), paper)
		tail.Material = Enum.Material.Fabric
		ribbon:GetPropertyChangedSignal("Color"):Connect(function()
			tail.Color = ribbon.Color
		end)
		mirrorTarget(parent, ribbon)
	elseif item == "artifact" then
		local gem = part(parent, "HouseHeart", center + V3(0, 0.6, 0), V3(2, 2, 2), Color3.fromRGB(137, 63, 70))
		gem.CFrame *= CFrame.Angles(0, 0, math.rad(45))
	elseif item and string.find(item, "fuse", 1, true) then
		cartridge(parent, p + V3(0, 2.06, 0), Vector3.xAxis, 2.2, 0.62)
	elseif item == "flashlight" then
		local at = p + V3(0, 2.2, 0)
		cylinder(parent, "FlashlightBody", at, Vector3.xAxis, 1.9, 0.58, dark)
		for index = -2, 2 do
			cylinder(parent, "FlashlightGrip", at + V3(index * 0.21, 0, 0), Vector3.xAxis, 0.045, 0.62, dark)
		end
		cylinder(parent, "FlashlightHead", at + V3(0.95, 0, 0), Vector3.xAxis, 0.36, 0.82, dark)
		cylinder(parent, "FlashlightRim", at + V3(1.15, 0, 0), Vector3.xAxis, 0.08, 0.86, brass)
		cylinder(
			parent,
			"FlashlightLens",
			at + V3(1.2, 0, 0),
			Vector3.xAxis,
			0.025,
			0.67,
			Color3.fromRGB(159, 168, 163),
			Enum.Material.Glass
		)
		part(parent, "FlashlightSwitch", at + V3(0.2, 0.28, 0), V3(0.3, 0.08, 0.18), brass)
	end
end
return Props
