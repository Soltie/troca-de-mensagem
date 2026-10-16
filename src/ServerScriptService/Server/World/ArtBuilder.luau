--!strict
-- Camada de arte reprodutível. Todos os acréscimos são decorativos, sem colisão/visão física.
local CollectionService = game:GetService("CollectionService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Build = require("./Build")
local Layout = require("./Layout")
local Palette = require("./Palette")
local ProceduralLayout = require("./ProceduralLayout")

local Art = {}
local V3 = Vector3.new
local DECOR = { collide = false, query = false, material = Enum.Material.Metal }

local function detail(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local part = Build.part(parent, name, size, cf, color, DECOR)
	part.CanTouch = false
	return part
end

local function cabinet(parent: Instance, position: Vector3, yaw: number, label: string)
	local model = Build.model(parent, "Switchgear")
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
	local body = detail(model, "PaintedCabinet", V3(2.5, 6.4, 0.65), cf * CFrame.new(0, 3.2, 0), Palette.WallLowerCold)
	body:SetAttribute("SurfaceStyle", "paint")
	for _, x in { -0.95, 0.95 } do
		detail(model, "Hinge", V3(0.08, 5.8, 0.04), cf * CFrame.new(x, 3.3, -0.35), Palette.MetalDark)
	end
	for y = 1, 3 do
		detail(model, "Vent", V3(1.8, 0.08, 0.04), cf * CFrame.new(0, 1 + y * 0.19, -0.36), Palette.Black)
	end
	detail(model, "Handle", V3(0.12, 0.7, 0.12), cf * CFrame.new(0.8, 3.5, -0.4), Palette.Brass)
	local sign = Build.sign(
		model,
		"AssetPlate",
		(cf * CFrame.new(0, 5.5, -0.36)).Position,
		cf.LookVector,
		Vector2.new(2, 0.48),
		label,
		{ textColor = Palette.Paper, background = Palette.MetalDark, thickness = 0.02 }
	)
	sign.CanQuery = false
	-- Medidor com escala e ponteiro. A leitura é visual, sem interação nova.
	local face = detail(model, "MeterFace", V3(1.2, 0.85, 0.04), cf * CFrame.new(-0.25, 4.15, -0.36), Palette.Paper)
	face.Material = Enum.Material.SmoothPlastic
	for x = -2, 2 do
		detail(model, "Tick", V3(0.035, 0.14, 0.02), cf * CFrame.new(-0.25 + x * 0.2, 4.35, -0.39), Palette.Black)
	end
	detail(
		model,
		"Needle",
		V3(0.04, 0.4, 0.02),
		cf * CFrame.new(-0.35, 4.1, -0.4) * CFrame.Angles(0, 0, -0.5),
		Palette.Red
	)
end

local function dressRooms(root: Instance)
	for index, room in Layout.Rooms do
		if room.id == "Switchyard" then
			continue
		end
		local folder = Build.model(root, room.id)
		-- Condutos altos, fora da altura de portas e janelas e longe dos alvos da campanha.
		local x = room.x1 - 0.7
		local z = (room.z0 + room.z1) / 2
		local length = room.z1 - room.z0 - 2
		detail(folder, "Conduit", V3(0.12, 0.12, length), CFrame.new(x, 9.8, z), Palette.Metal)
		for _, endZ in { room.z0 + 1, room.z1 - 1 } do
			detail(folder, "Junction", V3(0.65, 0.6, 0.22), CFrame.new(x, 9.8, endZ), Palette.MetalDark)
		end
		local plaque = Build.sign(
			folder,
			"SectorPlate",
			V3(room.x0 + 0.57, 8, room.z0 + 2.7),
			Vector3.xAxis,
			Vector2.new(3.1, 0.9),
			string.format("S9 / %02d", index),
			{ textColor = Palette.Paper, background = Palette.WallLowerCold, thickness = 0.04 }
		)
		plaque.CanQuery = false
		-- Desgaste do rodapé em pequenos trechos, sem cobrir aberturas/placas existentes.
		for i = 1, 3 do
			local stain = detail(
				folder,
				"DampMark",
				V3(0.018, 0.3 + i * 0.17, 0.4 + i * 0.28),
				CFrame.new(room.x1 - 0.512, 0.35 + i * 0.08, room.z0 + 1.4 + i * 0.7),
				Palette.Trim
			)
			stain.Transparency = 0.35
		end
		local dust =
			detail(folder, "DustAnchor", V3(0.1, 0.1, 0.1), CFrame.new((room.x0 + room.x1) / 2, 8.3, z), Palette.Paper)
		dust.Transparency = 1
		CollectionService:AddTag(dust, "ArtDust")
	end
	cabinet(root, V3(-66.5, 0, -39), 90, "AUX / 09-04")
	cabinet(root, V3(-37.8, 0, -72), 90, "PROTEÇÃO / 132")
	cabinet(root, V3(36.8, 0, -69), -90, "LINHA / 09-02")
	-- Manchas de óleo junto às máquinas; nunca ocupam a rota com geometria de colisão.
	for index, p in { V3(-28, 0.012, -39), V3(15, 0.012, -8), V3(-63, 0.012, -9), V3(59, 0.012, -53) } do
		for i = 1, 3 do
			local patch = detail(
				root,
				"OilStain",
				V3(1.1 + i * 0.5, 0.01, 0.6 + i * 0.4),
				CFrame.new(p + V3(i * 0.3, i * 0.002, 0)) * CFrame.Angles(0, index + i, 0),
				Palette.MetalDark
			)
			patch.Transparency = 0.28
		end
	end
end

local function surfaceKind(part: BasePart): string?
	local explicit = part:GetAttribute("SurfaceStyle")
	if type(explicit) == "string" then
		return explicit
	end
	local name = part.Name
	if name:sub(1, 5) == "Wall_" then
		return "paint"
	elseif name == "Floor" then
		return "concrete"
	elseif name == "Tile" then
		return if (math.floor(part.Position.X) + math.floor(part.Position.Z)) % 12 == 0 then "tiles" else nil
	elseif name == "Body" and part.Parent then
		return if part.Parent.Name == "Crate" then "wood" elseif part.Parent.Name == "Cabinet" then "paint" else nil
	elseif name == "Top" and part.Parent and part.Parent.Name == "Desk" then
		return "wood"
	elseif name == "Tank" or name == "Engine" or name == "ControlConsole" or name == "PaintedCabinet" then
		return "rust"
	end
	return nil
end

function Art.build(world: Instance)
	local root = Build.folder(world, "ArtDetails")
	dressRooms(root)
	local surfaces = {}
	for _, object in world:GetDescendants() do
		if not object:IsA("BasePart") then
			continue
		end
		local kind = surfaceKind(object)
		if kind then
			object:SetAttribute("SurfaceStyle", kind)
			object.Material = if kind == "concrete" and object.Material == Enum.Material.DiamondPlate
				then Enum.Material.DiamondPlate
				elseif kind == "wood" then Enum.Material.Wood
				elseif kind == "concrete" then Enum.Material.Concrete
				elseif kind == "rust" then Enum.Material.Metal
				else Enum.Material.Concrete
			table.insert(surfaces, object)
		end
		if object.Name == "Screen" or object.Name == "DeadMonitor" then
			CollectionService:AddTag(object, "ArtScreen")
		end
	end
	-- Ordem independente da enumeração do engine, distribuída por posição; orçamento rígido.
	table.sort(surfaces, function(a: BasePart, b: BasePart)
		local ap, bp = a.Position, b.Position
		local function rank(part: BasePart): number
			if part.Name:sub(1, 5) ~= "Wall_" and part.Name ~= "Tile" then
				return -1
			end
			local p = part.Position
			return (math.floor(p.X * 4) * 137 + math.floor(p.Z * 4) * 269 + math.floor(p.Y * 4) * 53) % 1009
		end
		local ar, br = rank(a), rank(b)
		if ar ~= br then
			return ar < br
		end
		if ap.Z ~= bp.Z then
			return ap.Z < bp.Z
		end
		if ap.X ~= bp.X then
			return ap.X < bp.X
		end
		return ap.Y < bp.Y
	end)
	-- A ala reconstruída por rodada usa o mesmo atlas e respeita o orçamento global.
	for i = 1, math.min(#surfaces, Config.Art.SurfacePartLimit - ProceduralLayout.SurfaceBudget) do
		CollectionService:AddTag(surfaces[i], "ArtSurface")
	end
	root:SetAttribute("SurfaceCandidates", #surfaces)
end

return Art
