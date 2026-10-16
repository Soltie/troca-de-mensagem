--!strict
-- Anel externo utilizável: carga ao norte, manutenção a oeste e tubulações a leste.
local Build = require("./Build")
local Layout = require("./ProceduralLayout")
local Palette = require("./Palette")
local Props = require("./Props")

local Exterior = {}
local V3 = Vector3.new
local DECOR = { collide = false, query = false, material = Enum.Material.Metal }

local function fence(parent: Instance, a: Vector3, b: Vector3)
	local height = 10 -- Acima do teto da van + salto normal: o cenário não vira atalho sobre a cerca.
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt((a + b) / 2 + V3(0, height / 2, 0), b + V3(0, height / 2, 0))
	Build.part(parent, "PerimeterFence", V3(0.2, height, length), frame, Palette.Fence, {
		material = Enum.Material.Metal,
		transparency = 0.55,
	})
	Build.part(parent, "FenceTop", V3(0.3, 0.3, length), frame * CFrame.new(0, height / 2, 0), Palette.MetalDark)
	local count = math.ceil(length / 12)
	for i = 0, count do
		Build.block(parent, "FencePost", a:Lerp(b, i / count), V3(0.4, height + 0.5, 0.4), 0, Palette.MetalDark)
	end
end

local function sign(parent: Instance, position: Vector3, facing: Vector3, text: string)
	local part = Build.sign(parent, "ExteriorSign", position, facing, Vector2.new(9, 1.8), text, {
		textColor = Palette.Paper,
		background = Palette.WallLowerCold,
		lit = true,
	})
	part.CanQuery = false
end

function Exterior.build(parent: Instance)
	local root = Build.folder(parent, "ExteriorLoop")
	for _, zone in Layout.ExteriorZones do
		local floor = Build.box(root, zone.id, V3(zone.x0, -1, zone.z0), V3(zone.x1, 0, zone.z1), Palette.Gravel, {
			material = Enum.Material.Pebble,
		})
		floor:SetAttribute("OutdoorArea", zone.id)
	end
	local b = Layout.Bounds
	fence(root, V3(b.x0, 0, b.z1), V3(b.x0, 0, b.z0))
	fence(root, V3(b.x0, 0, b.z0), V3(b.x1, 0, b.z0))
	fence(root, V3(b.x1, 0, b.z0), V3(b.x1, 0, b.z1))
	-- Encontra as cercas/paredes antigas; o portão frontal continua sendo a única saída.
	fence(root, V3(b.x0, 0, b.z1), V3(-68, 0, b.z1))
	fence(root, V3(40, 0, b.z1), V3(b.x1, 0, b.z1))

	local loading = Build.model(root, "LoadingDock")
	Build.block(loading, "DockPad", V3(-34, 0, -229), V3(32, 0.18, 5), 0, Palette.Concrete)
	for _, x in { -45, -35, -25 } do
		Props.crate(loading, V3(x, 0.18, -229), 0, 3)
		Build.block(loading, "DockBollard", V3(x, 0, -225.5), V3(0.4, 2, 0.4), 0, Palette.Hazard)
	end
	Build.block(loading, "LoadingCanopy", V3(-34, 10.8, -228), V3(34, 0.4, 7), 0, Palette.MetalDark)
	for _, x in { -50, -18 } do
		Build.block(loading, "CanopyPost", V3(x, 0, -230.5), V3(0.5, 11, 0.5), 0, Palette.MetalDark)
	end
	sign(loading, V3(-34, 8.7, -224.4), Vector3.zAxis, "RECEBIMENTO / DOCA 09")
	Props.van(root, V3(20, 0, -228), 90)
	-- Equipamentos ficam nas bordas; o eixo x=-82 permanece livre para a perseguição.
	for _, z in { -121, -165, -209 } do
		Props.pumpTank(root, V3(-91, 0, z), 6, 4)
		Build.block(root, "Drain", V3(-67, 0.015, z), V3(1.5, 0.03, 7), 0, Palette.MetalDark, DECOR)
	end
	for _, z in { -115, -159, -203 } do
		Build.block(root, "PipeSupport", V3(69, 0, z), V3(0.6, 10, 0.6), 0, Palette.MetalDark)
	end
	for _, x in { 67, 69 } do
		Props.pipe(root, V3(x, 10, -209), V3(x, 10, -97), 0.5, Palette.Rust, false)
	end
	for _, point in { V3(-93, 0, -90), V3(-93, 0, -180), V3(69, 0, -90), V3(69, 0, -218) } do
		local lamp = Props.streetLamp(root, point)
		Build.light(lamp, "Street", Palette.Sodium, 30, 0.85, true)
	end
	for _, x in { -82, 62 } do
		for z = -214, -94, 16 do
			Build.block(root, "ExteriorRouteMark", V3(x - 5, 0.015, z), V3(0.2, 0.02, 4), 0, Palette.Hazard, DECOR)
		end
	end
	for _, point in { V3(-73, 0.01, -138), V3(58, 0.01, -181), V3(-2, 0.01, -217) } do
		Build.block(root, "RainPuddle", point, V3(5, 0.02, 3), 12, Palette.Black, {
			collide = false,
			query = false,
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.25,
		})
	end
	sign(root, V3(-94.5, 7, -100), Vector3.xAxis, "VIA DE SERVIÇO / ^ DOCA")
	sign(root, V3(70.5, 7, -100), -Vector3.xAxis, "TUBULAÇÕES / ^ PÁTIO NORTE")
	sign(root, V3(-82, 7, -79), -Vector3.zAxis, "GALERIA / SAÍDA >")
	sign(root, V3(62, 7, -79), -Vector3.zAxis, "< GALERIA / SAÍDA")
end

return Exterior
