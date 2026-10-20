--!strict
--[[
	Cenografia da casa por cômodo (reforma "A Casa de Madeira", plano do Level designer aprovado como direção pelo
	crítico). Começa pela fatia vertical da SALA DE ESTAR do cap. 1:
	- leitura no escuro: lambri de madeira até a meia parede com papel de parede gasto em cima, vigas aparentes no teto
	  e batentes mais claros que as paredes; marco da sala = lareira com brasa (laranja);
	- história: lençol sobre o sofá, cesto de tricô ao lado da cadeira de balanço da Dona Cida, porta-retratos na
	  lareira, o pião do Juca no tapete, bilhete da Dona Cida, entalhe do Tum Tum pequeno no batente;
	- guia: rastro de serragem saindo da Oficina (Sala de Máquinas) e passando pelo hall;
	- medo: com a lanterna apagada perto dela, a cadeira de balanço balança sozinha (é a Dona Cida).
	Tudo é só visual (sem colisão, fora dos raycasts) e sai dos pontos dos puzzles.
]]

local Players = game:GetService("Players")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("./Build")
local HouseArt = require("./HouseArt")

local Dressing = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB

local WOOD = rgb(90, 62, 43) -- #5A3E2B
local DARK = rgb(46, 31, 22) -- #2E1F16
local FRAME = rgb(122, 88, 62) -- batente mais claro que a parede
local SAWDUST = rgb(196, 168, 120)

local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local part = Build.part(parent, name, size, cframe, color, {
		material = material or Enum.Material.Wood,
		collide = false,
		query = false,
	})
	part.CanTouch = false
	return part
end

-- Primeiro modelo/peça com `name` no nome dentro da caixa (x0..x1, z0..z1) e altura y0..y1.
-- Esconde o modelo original que o lençol do artista cobre (continua com colisão).
local function hideOriginal(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
end

local function find(
	root: Instance,
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number
): Model?
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and string.find(d.Name, name, 1, true) then
			local ok, cf = pcall(function()
				return d:GetPivot()
			end)
			if ok then
				local p = cf.Position
				if p.X > x0 and p.X < x1 and p.Z > z0 and p.Z < z1 and p.Y > y0 and p.Y < y1 then
					return d
				end
			end
		end
	end
	return nil
end

-- Entalhe do Tum Tum pequeno com o bastão erguido, em relevo raso numa parede (`facing` = para onde ele olha).
-- `variant` muda a pose (1 bastão erguido, 2 bastão no ombro, 3 de braços abertos).
function Dressing.carving(parent: Instance, at: Vector3, facing: Vector3, scale: number, variant: number)
	local model = Build.model(parent, "TumTumCarving")
	local frame = CFrame.lookAt(at, at + facing)
	local function cut(name: string, size: Vector3, offset: CFrame)
		deco(model, name, size * scale, frame * CFrame.new(offset.Position * scale) * offset.Rotation, DARK)
	end
	cut("Body", V3(0.5, 0.9, 0.06), CFrame.new(0, 0, 0))
	cut("Head", V3(0.42, 0.4, 0.06), CFrame.new(0, 0.68, 0))
	cut("Leg", V3(0.14, 0.45, 0.06), CFrame.new(-0.13, -0.66, 0))
	cut("Leg", V3(0.14, 0.45, 0.06), CFrame.new(0.13, -0.66, 0))
	if variant == 1 then
		cut("Stick", V3(0.1, 0.9, 0.06), CFrame.new(0.42, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-20)))
	elseif variant == 2 then
		cut("Stick", V3(0.1, 0.9, 0.06), CFrame.new(0.3, 0.45, 0) * CFrame.Angles(0, 0, math.rad(55)))
	else
		cut("Arm", V3(0.7, 0.1, 0.06), CFrame.new(0.42, 0.2, 0) * CFrame.Angles(0, 0, math.rad(25)))
		cut("Arm", V3(0.7, 0.1, 0.06), CFrame.new(-0.42, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-25)))
	end
	return model
end

-- Rastro de serragem: manchinhas claras no chão de `from` até `to`, com um pouco de desvio (a linha guia).
function Dressing.sawdustTrail(parent: Instance, points: { Vector3 }, spacing: number, rng: Random)
	local folder = Build.folder(parent, "SawdustTrail")
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local steps = math.max(1, math.floor((b - a).Magnitude / spacing))
		for s = 0, steps - 1 do
			local p = a:Lerp(b, s / steps) + V3(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
			local blot = deco(
				folder,
				"Sawdust",
				V3(0.04, rng:NextNumber(0.8, 1.6), rng:NextNumber(0.8, 1.6)),
				CFrame.new(p + V3(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)),
				SAWDUST,
				Enum.Material.Sand
			);
			(blot :: Part).Shape = Enum.PartType.Cylinder
			blot.CastShadow = false
		end
	end
end

-- A cadeira da Dona Cida balança sozinha quando alguém chega perto com a lanterna apagada (pausa de 25 s).
local function rockingScare(chair: Model)
	local home = chair:GetPivot()
	task.spawn(function()
		local last = -math.huge
		while chair.Parent do
			task.wait(0.5)
			if os.clock() - last < 25 then
				continue
			end
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					root
					and root:IsA("BasePart")
					and (root.Position - home.Position).Magnitude < 14
					and player:GetAttribute(Tags.Attr.Flashlight) ~= true
				then
					last = os.clock()
					local any = chair:FindFirstChildWhichIsA("BasePart", true)
					if any then
						local sound = Build.sound(any, "RockingCreak", Audio.CreakWood.id, 0.9, 0.8)
						sound:Play()
						task.delay(4, function()
							sound:Destroy()
						end)
					end
					for t = 0, 60 do
						chair:PivotTo(home * CFrame.Angles(math.rad(math.sin(t / 6) * 7 * (1 - t / 60)), 0, 0))
						task.wait(1 / 20)
					end
					chair:PivotTo(home)
					break
				end
			end
		end
	end)
end

-- SALA DE ESTAR (x −44..−8, z −20..12, piso y = 0, teto y = 15).
function Dressing.living(root: Instance)
	local folder = Build.folder(root, "LivingDressing")
	local rng = Random.new(7)
	-- Lambri até 4 studs nas três paredes da sala (a do corredor tem a lareira e a porta).
	deco(folder, "Wainscot", V3(35, 4, 0.2), CFrame.new(-26, 2, -19.4), WOOD)
	deco(folder, "Wainscot", V3(0.2, 4, 31), CFrame.new(-43.4, 2, -4), WOOD)
	deco(folder, "WainscotRail", V3(35, 0.25, 0.35), CFrame.new(-26, 4.05, -19.35), DARK)
	deco(folder, "WainscotRail", V3(0.35, 0.25, 31), CFrame.new(-43.35, 4.05, -4), DARK)
	-- Vigas aparentes no teto, cruzando a sala.
	for _, x in { -36, -26, -16 } do
		deco(folder, "CeilingBeam", V3(1.1, 0.9, 31.5), CFrame.new(x, 14.45, -4), DARK)
	end
	-- Batente da porta do corredor mais claro que a parede (lê como saída no escuro).
	for _, z in { 1.1, -9.1 } do
		deco(folder, "DoorFrame", V3(0.5, 11.4, 0.5), CFrame.new(-8.6, 5.7, z), FRAME)
	end
	deco(folder, "DoorFrame", V3(0.5, 0.5, 10.7), CFrame.new(-8.6, 11.4, -4), FRAME)
	-- Canto entre a folha aberta da porta da sala (house_door_3) e a DoorWall: uma cunha invisível chanfra o ângulo de
	-- 90° onde o jogador ficava preso (crítico, cap. 1). Não toca a folha fechada (z ≥ −9).
	local chamfer = Build.part(
		folder,
		"DoorCornerChamfer",
		V3(0.4, 11, 2.6),
		CFrame.new(-8.9, 5.5, -10.1) * CFrame.Angles(0, math.rad(45), 0),
		DARK,
		{ transparency = 1, collide = true, query = false }
	)
	chamfer.CanTouch = false
	-- Entalhe do Tum Tum pequeno ao lado da porta (o primeiro que o jogador vê).
	-- Modelos do artista (Assets.HouseArt) quando existem; senão, as peças primitivas.
	type Carving = { name: string, at: Vector3, facing: Vector3, pose: number }
	local carvings: { Carving } = {
		{ name = "Living_CarvingDoorFrame", at = V3(-8.7, 5.2, 2.6), facing = -Vector3.xAxis, pose = 1 },
		{ name = "Living_CarvingWallDrum", at = V3(-43.3, 5, 6), facing = Vector3.xAxis, pose = 2 },
		{ name = "Living_CarvingWallNight", at = V3(-38, 5, -19.3), facing = Vector3.zAxis, pose = 3 },
	}
	for _, c in carvings do
		if not HouseArt.place(folder, c.name, CFrame.lookAt(c.at, c.at - c.facing)) then
			Dressing.carving(folder, c.at + V3(0, 1, 0), c.facing, 1.1, c.pose)
		end
	end
	-- Tapete oval gasto no meio da sala.
	local rugArt = HouseArt.place(folder, "Living_OvalRug", CFrame.new(-27, 0, -3))
	local rug = if rugArt
		then nil
		else deco(
			folder,
			"WornRug",
			V3(0.06, 12, 15),
			CFrame.new(-27, 0.04, -3) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(92, 38, 34),
			Enum.Material.Fabric
		)
	if rug then
		(rug :: Part).Shape = Enum.PartType.Cylinder
	end
	-- O pião do Juca esquecido no tapete.
	-- Pião deitado: corpo em disco, ponta e o barbante enrolado (um cubo vermelho lia como bloco solto).
	local topAt = CFrame.new(-23, 0.32, 0.5) * CFrame.Angles(0, math.rad(30), math.rad(75))
	local body = deco(folder, "JucaTop", V3(0.35, 0.65, 0.65), topAt, rgb(196, 60, 48));
	(body :: Part).Shape = Enum.PartType.Cylinder
	local tip = deco(folder, "JucaTopTip", V3(0.3, 0.2, 0.2), topAt * CFrame.new(-0.3, 0, 0), DARK);
	(tip :: Part).Shape = Enum.PartType.Cylinder
	local string = deco(
		folder,
		"JucaTopString",
		V3(0.12, 0.68, 0.68),
		topAt * CFrame.new(0.05, 0, 0),
		rgb(210, 190, 140),
		Enum.Material.Fabric
	);
	(string :: Part).Shape = Enum.PartType.Cylinder
	-- Lençol sobre o sofá (a sala foi fechada há anos).
	local sofa = find(root, "Sofa", -44, -8, -20, 12, -1, 4)
	if sofa then
		-- Só o lençol do artista: uma caixa por cima do sofá lia como colchão, então sem ele o sofá fica à mostra.
		if HouseArt.place(folder, "Living_SheetSofa", sofa:GetPivot()) then
			hideOriginal(sofa)
		end
	end
	-- Poltrona da sala também coberta (o lençol do artista substitui o modelo original).
	local armchair = find(root, "Armchair", -44, -8, -20, 12, -1, 4)
	if armchair and HouseArt.place(folder, "Living_SheetArmchair", armchair:GetPivot()) then
		hideOriginal(armchair)
	end
	-- Cesto de tricô e bilhete ao lado da cadeira de balanço da Dona Cida.
	local chair = find(root, "RockingChair", -44, -8, -20, 12, -1, 4)
	local chairAt = if chair then chair:GetPivot().Position else V3(-22.5, 0, 4.5)
	local basketArt = HouseArt.place(folder, "Living_KnitBasket", CFrame.new(chairAt + V3(-1.8, 0, 1.6)))
	local basket = if basketArt
		then nil
		else deco(
			folder,
			"KnittingBasket",
			V3(1, 1.4, 1.4),
			CFrame.new(chairAt + V3(-1.8, 0.5, 1.6)) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(150, 112, 64),
			Enum.Material.Fabric
		)
	if basket then
		(basket :: Part).Shape = Enum.PartType.Cylinder
	end
	local yarn: { Color3 } = if basketArt then {} else { rgb(176, 44, 52), rgb(220, 200, 150) }
	for i, color in yarn do
		local ball = deco(
			folder,
			"YarnBall",
			V3(0.6, 0.6, 0.6),
			CFrame.new(chairAt + V3(-1.8 + (i - 1.5) * 0.5, 1.15, 1.6)),
			color,
			Enum.Material.Fabric
		);
		(ball :: Part).Shape = Enum.PartType.Ball
	end
	local note = Build.sign(
		folder,
		"CidaNote",
		chairAt + V3(-1.8, 1.25, 2.6),
		V3(0, 1, 0.35).Unit,
		Vector2.new(1.4, 1),
		"JUCA, NÃO DEIXE O PIÃO NO TAPETE.\nE NINGUÉM ACENDE LUZ PERTO DOS MÓVEIS.\n— MAMÃE",
		{ textColor = rgb(40, 30, 24), background = rgb(226, 214, 186), font = Enum.Font.Fantasy }
	)
	note.CanQuery = false
	-- Porta-retratos em cima da lareira (família; as crianças com o Tum Tum pequeno; o Valdemar).
	local fireplace = find(root, "Fireplace", -44, -8, -20, 12, -1, 4)
	if fireplace then
		local box, size = fireplace:GetBoundingBox()
		local top = box.Position.Y + size.Y / 2
		local family = V3(box.Position.X - 0.4, top, box.Position.Z)
		local placed = HouseArt.place(folder, "Living_PhotoFamily", CFrame.lookAt(family, family + Vector3.xAxis))
		local frames: { Color3 } = if placed then {} else { rgb(150, 120, 90), rgb(110, 90, 70), rgb(130, 100, 80) }
		for i, color in frames do
			local at = V3(box.Position.X - 0.4, top + 0.5, box.Position.Z + (i - 2) * 1.3)
			deco(
				folder,
				"PhotoFrame",
				V3(0.12, 0.9, 0.7),
				CFrame.lookAt(at, at - Vector3.xAxis) * CFrame.Angles(math.rad(-8), 0, 0),
				color
			)
		end
		-- Brasa na lareira: o marco laranja da sala (a chama já existe).
		local ember = deco(
			folder,
			"Embers",
			V3(2.2, 0.3, 1),
			CFrame.new(box.Position.X - 0.6, 0.35, box.Position.Z),
			rgb(255, 110, 40),
			Enum.Material.Neon
		)
		ember.CastShadow = false
	end
	-- Retratos de parede acima do lambri: as crianças com o Tum Tum pequeno e o Valdemar.
	type Photo = { name: string, at: Vector3 }
	local photos: { Photo } = {
		{ name = "Living_PhotoKidsTumTum", at = V3(-31, 6.5, -19.3) },
		{ name = "Living_PhotoValdemar", at = V3(-21, 6.5, -19.3) },
	}
	for _, photo in photos do
		HouseArt.place(folder, photo.name, CFrame.lookAt(photo.at, photo.at - Vector3.zAxis))
	end
	-- Lamparina de querosene acesa na mesinha: fonte de luz prática da sala (luz quente pequena).
	local tableModel = find(root, "AntiqueTable", -44, -8, -20, 12, -1, 4)
	local lampAt = if tableModel
		then (function()
			local box, size = tableModel:GetBoundingBox()
			return V3(box.Position.X + 1, box.Position.Y + size.Y / 2, box.Position.Z)
		end)()
		else V3(-25, 2.5, -15)
	local lamp = HouseArt.place(folder, "Living_KeroseneLamp", CFrame.new(lampAt))
	local flame = lamp and lamp:FindFirstChild("KeroseneLamp_Flame", true)
	if not (flame and flame:IsA("BasePart")) then
		flame = deco(
			folder,
			"KeroseneFlame",
			V3(0.25, 0.4, 0.25),
			CFrame.new(lampAt + V3(0, 0.9, 0)),
			rgb(255, 190, 110),
			Enum.Material.Neon
		)
		deco(
			folder,
			"KeroseneBase",
			V3(0.7, 0.7, 0.7),
			CFrame.new(lampAt + V3(0, 0.35, 0)),
			rgb(120, 96, 60),
			Enum.Material.Metal
		)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = rgb(255, 170, 90), 14, 1.5, true
	light.Parent = flame
	if chair then
		rockingScare(chair)
	end
	-- Rastro de serragem da Oficina (porta da Sala de Máquinas, x = 8) pelo corredor até o hall: a linha guia.
	Dressing.sawdustTrail(
		folder,
		{ V3(7, 0, -68), V3(2, 0, -60), V3(1, 0, -44), V3(-1, 0, -26), V3(0, 0, -10) },
		2.6,
		rng
	)
end

-- A porta segura (A Porta que Troca): o portão do corredor das três chaves tem o entalhe do Tum Tum pequeno, que brilha
-- fraco quando a lanterna bate nele (tag FlashShadow do DarkClueController). Portas com o entalhe nunca trocam.
function Dressing.safeDoor(root: Instance)
	local folder = Build.folder(root, "SafeDoorCarvings")
	for _, x in { -9.6, 9.6 } do
		local at = V3(x, 6.2, -51.3)
		if
			not HouseArt.place(
				folder,
				"Living_CarvingDoorFrame",
				CFrame.lookAt(at - V3(0, 1, 0), at - V3(0, 1, 0) - Vector3.zAxis)
			)
		then
			Dressing.carving(folder, at, Vector3.zAxis, 1.1, 1)
		end
		local glow = deco(
			folder,
			"SafeDoorGlow",
			V3(1, 1.8, 0.05),
			CFrame.lookAt(at + V3(0, 0, 0.12), at + V3(0, 0, 1)),
			rgb(242, 163, 58),
			Enum.Material.Neon
		)
		glow.Transparency = 1
		glow.CastShadow = false
		glow:AddTag("FlashShadow")
	end
end

-- Tábuas irregulares por cima do piso (crítico: o chão liso parecia greybox): tons e larguras diferentes, um giro
-- leve e frestas escuras entre algumas. Só visual, a 0,03 do piso.
function Dressing.floorboards(parent: Instance, x0: number, x1: number, z0: number, z1: number, y: number, rng: Random)
	local folder = Build.folder(parent, "Floorboards")
	local tones = { rgb(78, 54, 38), rgb(64, 44, 31), rgb(92, 64, 44), rgb(56, 38, 27) }
	local x = x0 + 0.6
	while x < x1 - 0.6 do
		local width = rng:NextNumber(0.9, 1.5)
		local z = z0 + rng:NextNumber(0, 2)
		while z < z1 - 1 do
			local length = math.min(rng:NextNumber(4, 9), z1 - z)
			if rng:NextNumber() < 0.55 then
				local board = deco(
					folder,
					"Floorboard",
					V3(width - 0.08, 0.05, length - 0.1),
					CFrame.new(x + width / 2, y + 0.03 + rng:NextNumber(0, 0.03), z + length / 2)
						* CFrame.Angles(0, math.rad(rng:NextNumber(-1.2, 1.2)), 0),
					tones[rng:NextInteger(1, #tones)],
					Enum.Material.WoodPlanks
				)
				board.CastShadow = false
			end
			z += length
		end
		if rng:NextNumber() < 0.3 then
			-- Fresta escura entre duas tábuas.
			deco(folder, "FloorGap", V3(0.08, 0.04, z1 - z0), CFrame.new(x + width, y + 0.02, (z0 + z1) / 2), DARK)
		end
		x += width
	end
end

-- Um susto de cenário por cômodo (cap. 1), uma vez por partida do capítulo, quando alguém entra no cômodo.
-- Legenda curta de cada susto (o MomentController mostra CampaignState.Caption), para o jogador notar o que viu.
local SCARE_CAPTIONS: { [string]: string } = {
	hall = "Alguém bate lá em cima.",
	kitchen = "As panelas balançam sozinhas.",
	dining = "A cadeira virou para você.",
	library = "Um livro caiu da estante.",
	corridor = "O entalhe na parede abriu os olhos.",
}
local captionSerial = 0
type Scare = { name: string, x0: number, x1: number, z0: number, z1: number, y: number, run: () -> () }
local function scareLoop(scares: { Scare })
	task.spawn(function()
		local done: { [string]: boolean } = {}
		local key = ""
		while true do
			task.wait(0.4)
			local campaign = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
			local stage = campaign and campaign:GetAttribute("Stage")
			local now = `{campaign and campaign:GetAttribute("Seed")}:{stage}`
			if now ~= key then
				key = now
				table.clear(done)
			end
			if stage ~= 1 or (campaign and campaign:GetAttribute("Phase")) ~= "Playing" then
				continue
			end
			for _, scare in scares do
				if done[scare.name] then
					continue
				end
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					if rootPart and rootPart:IsA("BasePart") then
						local p = rootPart.Position
						if
							p.X > scare.x0
							and p.X < scare.x1
							and p.Z > scare.z0
							and p.Z < scare.z1
							and math.abs(p.Y - scare.y - 3) < 6
						then
							done[scare.name] = true
							task.spawn(scare.run)
							if campaign and SCARE_CAPTIONS[scare.name] then
								captionSerial += 1
								campaign:SetAttribute("Caption", SCARE_CAPTIONS[scare.name])
								campaign:SetAttribute("CaptionSerial", captionSerial)
							end
							break
						end
					end
				end
			end
		end
	end)
end

local function play(at: BasePart, clip: string, volume: number, speed: number)
	local info = (Audio :: any)[clip]
	if not info then
		return
	end
	local sound = Build.sound(at, clip, info.id, volume, speed)
	sound:Play()
	task.delay(6, function()
		sound:Destroy()
	end)
end

function Dressing.scares(root: Instance)
	local folder = Build.folder(root, "RoomScares")
	local anchor = function(at: Vector3): BasePart
		local part = deco(folder, "ScareSound", V3(0.2, 0.2, 0.2), CFrame.new(at), DARK)
		part.Transparency = 1
		return part
	end
	-- Cozinha: panelas penduradas num varal de ferro; batem umas nas outras quando alguém entra.
	local pans: { BasePart } = {}
	deco(folder, "PanRail", V3(0.15, 0.15, 6), CFrame.new(34, 11.5, -6), rgb(60, 58, 54), Enum.Material.Metal)
	for n = 0, 3 do
		local pan = deco(
			folder,
			"HangingPan",
			V3(0.12, 1.3, 1.3),
			CFrame.new(34, 10.6, -8.4 + n * 1.6) * CFrame.Angles(0, math.rad(90), 0),
			rgb(90, 80, 70),
			Enum.Material.Metal
		);
		(pan :: Part).Shape = Enum.PartType.Cylinder
		table.insert(pans, pan)
	end
	-- Biblioteca: um livro na beira da estante do fundo que cai sozinho.
	local book =
		deco(folder, "FallingBook", V3(0.5, 1.4, 1), CFrame.new(-40, 7.2, -82.6), rgb(90, 36, 30), Enum.Material.Fabric)
	-- Marco da sala de jantar: relógio de parede parado (hora do desaparecimento) e um retrato torto que cai no susto.
	local clock = deco(folder, "DiningClock", V3(1.1, 5.5, 2.2), CFrame.new(-42.7, 5.2, -26), rgb(46, 30, 22))
	deco(
		folder,
		"DiningClockFace",
		V3(0.1, 1.5, 1.5),
		CFrame.new(-42.05, 6.8, -26),
		rgb(214, 198, 160),
		Enum.Material.Fabric
	)
	deco(
		folder,
		"DiningClockHand",
		V3(0.06, 0.9, 0.08),
		CFrame.new(-41.95, 7, -26) * CFrame.Angles(math.rad(35), 0, 0),
		rgb(30, 22, 18)
	)
	clock:SetAttribute("Landmark", "dining")
	local portrait = deco(
		folder,
		"DiningPortrait",
		V3(0.2, 3, 2.2),
		CFrame.new(-43.3, 8.4, -37) * CFrame.Angles(math.rad(6), 0, 0),
		rgb(58, 40, 28)
	)
	-- Marco do corredor: retrato da família virado para a parede, só o verso à mostra.
	deco(folder, "CorridorTurnedPortrait", V3(0.2, 3.4, 2.6), CFrame.new(-7.3, 6.5, -36), rgb(52, 36, 26))
	local scares: { Scare } = {
		{
			-- Hall: três pancadas no andar de cima e poeira caindo do teto.
			name = "hall",
			x0 = -8,
			x1 = 8,
			z0 = -18,
			z1 = 20,
			y = 0,
			run = function()
				local up = anchor(V3(0, 14.5, -4))
				for n = 0, 2 do
					task.delay(n * 0.7, function()
						play(up, "DoorBang", 0.7, 0.55)
					end)
				end
				local dust = Instance.new("ParticleEmitter")
				dust.Color = ColorSequence.new(rgb(170, 150, 120))
				dust.Size = NumberSequence.new(0.2, 0.05)
				dust.Speed = NumberRange.new(0.5, 1.5)
				dust.Acceleration = V3(0, -6, 0)
				dust.Lifetime = NumberRange.new(2, 3)
				dust.SpreadAngle = Vector2.new(60, 60)
				dust.Rate = 0
				dust.Parent = up
				dust:Emit(60)
			end,
		},
		{
			name = "kitchen",
			x0 = 8,
			x1 = 44,
			z0 = -20,
			z1 = 12,
			y = 0,
			run = function()
				for n, pan in pans do
					local home = pan.CFrame
					task.delay(n * 0.12, function()
						play(pan, "HammerNail", 0.6, 1.6 + n * 0.1)
						for t = 0, 30 do
							pan.CFrame = home * CFrame.Angles(math.rad(math.sin(t / 3) * 18 * (1 - t / 30)), 0, 0)
							task.wait(1 / 20)
						end
						pan.CFrame = home
					end)
				end
			end,
		},
		{
			-- Sala de jantar: uma das cadeiras da mesa gira devagar para olhar quem entrou.
			name = "dining",
			x0 = -44,
			x1 = -8,
			z0 = -52,
			z1 = -20,
			y = 0,
			run = function()
				-- O retrato da parede despenca no chão, com estrondo de moldura.
				task.delay(2.2, function()
					local from = portrait.CFrame
					for t = 1, 14 do
						portrait.CFrame = from * CFrame.new(0, -t * 0.5, 0) * CFrame.Angles(math.rad(t * 4), 0, 0)
						task.wait(1 / 30)
					end
					play(portrait, "WoodSplinter", 0.9, 0.9)
				end)
				local chair = find(root, "Chair", -44, -8, -52, -20, -1, 4)
				local target = Players:GetPlayers()[1]
				local character = target and target.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if not chair or not rootPart or not rootPart:IsA("BasePart") then
					return
				end
				local from = chair:GetPivot()
				local look = Vector3.new(rootPart.Position.X, from.Position.Y, rootPart.Position.Z)
				local goal = CFrame.lookAt(from.Position, from.Position + (from.Position - look).Unit)
				local any = chair:FindFirstChildWhichIsA("BasePart", true)
				if any then
					play(any, "CreakWood", 0.9, 0.7)
				end
				for t = 1, 30 do
					chair:PivotTo(from:Lerp(goal, t / 30))
					task.wait(1 / 20)
				end
			end,
		},
		{
			name = "library",
			x0 = -44,
			x1 = -8,
			z0 = -84,
			z1 = -52,
			y = 0,
			run = function()
				task.wait(1.5)
				local from = book.CFrame
				for t = 1, 12 do
					book.CFrame = from * CFrame.new(0, -t * 0.55, 0.35 * t / 12) * CFrame.Angles(math.rad(t * 7), 0, 0)
					task.wait(1 / 30)
				end
				play(book, "HammerNail", 0.9, 0.6)
			end,
		},
		{
			-- Corredor das três chaves: os olhos do entalhe acendem por um instante e um sussurro.
			name = "corridor",
			x0 = -8,
			x1 = 8,
			z0 = -51,
			z1 = -20,
			y = 0,
			run = function()
				-- Uma porta lá no fundo do corredor bate sozinha antes de os olhos acenderem.
				local slam = anchor(V3(0, 4, -51))
				play(slam, "DoorBang", 1, 0.6)
				task.wait(0.9)
				local eyes: { BasePart } = {}
				for _, x in { -9.85, -9.35, 9.35, 9.85 } do
					local eye = deco(
						folder,
						"CarvingEye",
						V3(0.18, 0.12, 0.05),
						CFrame.new(x, 8.1, -51.2),
						rgb(255, 213, 74),
						Enum.Material.Neon
					)
					table.insert(eyes, eye)
				end
				play(eyes[1], "Whisper", 0.8, 0.9)
				task.wait(2.2)
				for _, eye in eyes do
					eye:Destroy()
				end
			end,
		},
	}
	scareLoop(scares)
end

-- Placa da escada do porão (crítico, bug 8): na boca da escada, vista de quem chega pelo hall.
function Dressing.basementSign(root: Instance)
	local folder = Build.folder(root, "BasementStairSign")
	local plaque = Build.sign(
		folder,
		"BasementStairSign",
		V3(-16, 6.2, 56.6),
		Vector3.zAxis,
		Vector2.new(4.4, 0.9),
		"ESCADA DO PORÃO",
		{
			textColor = rgb(214, 196, 160),
			background = rgb(46, 31, 22),
			lit = false,
			font = Enum.Font.Merriweather,
			pixelsPerStud = 70,
		}
	)
	plaque.CanQuery = false
end

function Dressing.build(root: Instance)
	for _, name in { "LivingDressing", "SafeDoorCarvings", "RoomScares", "BasementStairSign", "FloorDressing" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	Dressing.living(root)
	Dressing.safeDoor(root)
	Dressing.scares(root)
	Dressing.basementSign(root)
	local floors = Build.folder(root, "FloorDressing")
	local rng = Random.new(31)
	-- Cômodos do cap. 1 (sala, cozinha, jantar, biblioteca); o hall e o corredor têm tapete.
	Dressing.floorboards(floors, -43.5, -8.5, -19.5, 11.5, 0, rng)
	Dressing.floorboards(floors, 8.5, 43.5, -19.5, 11.5, 0, rng)
	Dressing.floorboards(floors, -43.5, -8.5, -51.5, -20.5, 0, rng)
	Dressing.floorboards(floors, -43.5, -8.5, -83.5, -52.5, 0, rng)
end

return Dressing
