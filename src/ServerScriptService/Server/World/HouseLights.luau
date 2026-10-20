--!strict
--[[
	Plano de luz da casa (roda por último no HouseScenery). Só ajusta luzes existentes; não cria nem move peças.
	Direção: casa ESCURA, a lanterna é a fonte principal.
	- Luminárias elétricas (arandelas, pendentes, abajures elétricos) viram "Lamp": só acendem com a energia
	  (WorldService.setPower), mais fracas que antes.
	- Chamas (velas, lamparinas, lareira, lustre de velas) ficam acesas, porém fracas, curtas e tremulando.
	- Luzes de móveis antigos escondidos e a luz duplicada da luz noturna antiga são desligadas.
	O exterior (jardim, varanda, postes) não é tocado.
]]

local CollectionService = game:GetService("CollectionService")

local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Palette = require("./Palette")

local Lights = {}

-- Volume da casa (com o porão); fora dele nada muda.
local function inside(p: Vector3): boolean
	return p.X > -45 and p.X < 46 and p.Z > -86 and p.Z < 65 and p.Y > -17 and p.Y < 48
end

-- Elétricas: só com energia.
local ELECTRIC = {
	HallSconce = true,
	LandingSconce = true,
	CorridorPendant = true,
	StairPendant = true,
	PowerLamp = true,
}
-- Chamas: sempre acesas, fracas. Valores máximos de alcance e brilho.
local FLAME: { [string]: { number } } = {
	Candle = { 12, 0.38 },
	Flame = { 9, 0.35 },
	NightLight = { 12, 0.3 },
	LampShade = { 13, 0.38 },
	HallLampShade = { 13, 0.38 },
	HallChandelier = { 18, 0.42 },
	Fire = { 18, 0.7 },
}
-- Elétricas acesas (com energia): luz de casa velha, não de escritório.
local ELECTRIC_RANGE, ELECTRIC_BRIGHTNESS = 20, 0.42

local function holderOf(light: Light): BasePart?
	local parent = light.Parent
	return if parent and parent:IsA("BasePart") then parent else nil
end

function Lights.build(root: Instance)
	-- Só móveis antigos podem ter a luz desligada; brilho de missão/objetivo nunca é tocado.
	local old: { Instance } = {}
	for _, name in { "Furniture", "Dressing", "Furnishings" } do
		local folder = root:FindFirstChild(name)
		if folder then
			table.insert(old, folder)
		end
	end
	local function retired(holder: BasePart): boolean
		if holder.Name == "NightLight" then
			return true
		end
		if holder.Transparency < 0.99 then
			return false
		end
		for _, folder in old do
			if holder:IsDescendantOf(folder) then
				return true
			end
		end
		return false
	end
	local stats = { electric = 0, flame = 0, off = 0 }
	for _, light in root:GetDescendants() do
		if not light:IsA("PointLight") and not light:IsA("SpotLight") then
			continue
		end
		local holder = holderOf(light)
		if not holder or not inside(holder.Position) then
			continue
		end
		local name = holder.Name
		local light_ = light :: PointLight
		-- Móvel antigo escondido (trocado por modelo 3D) ou luz noturna antiga duplicada pela lamparina nova.
		if retired(holder) then
			light_.Enabled = false
			holder:SetAttribute("LightRetired", true)
			stats.off += 1
			continue
		end
		if ELECTRIC[name] then
			light_.Range = math.min(light_.Range, ELECTRIC_RANGE)
			light_.Brightness = math.min(light_.Brightness, ELECTRIC_BRIGHTNESS)
			light_.Enabled = false -- a casa começa sem energia; WorldService.setPower religa
			if holder.Transparency < 0.99 then
				-- Luminária visível com cara de apagada (o setPower troca para neon quando a energia volta).
				holder.Material, holder.Color = Enum.Material.SmoothPlastic, Palette.LampOff
			end
			holder:SetAttribute(Tags.Attr.LightKind, "Lamp")
			holder:SetAttribute(Tags.Attr.Flicker, true)
			holder:SetAttribute("BaseBrightness", light_.Brightness)
			CollectionService:AddTag(holder, Tags.PowerLight)
			stats.electric += 1
		else
			local cap = FLAME[name]
			if cap then
				light_.Range = math.min(light_.Range, cap[1])
				light_.Brightness = math.min(light_.Brightness, cap[2])
				light_.Shadows = false
				if holder:GetAttribute("BaseBrightness") ~= nil then
					holder:SetAttribute("BaseBrightness", light_.Brightness)
				end
				holder:SetAttribute(Tags.Attr.Flicker, true)
				stats.flame += 1
			end
		end
	end
	Lights.dimLamps(root)
	root:SetAttribute("HouseLightPlan", `{stats.electric} elétricas, {stats.flame} chamas, {stats.off} desligadas`)
end

-- Lampiões de óleo fracos presos na parede mais próxima (cap. 1: sem eles o corredor e a cozinha ficavam pretos
-- demais antes da energia). Chama pequena, sem sombra, tremulando; nada de luz forte.
local DIM_LAMPS: { { name: string, at: Vector3 } } = {
	{ name = "OilLampHall", at = Vector3.new(0, 5.6, -20) },
	{ name = "OilLampKitchen", at = Vector3.new(26, 5.6, -4) },
	{ name = "OilLampDining", at = Vector3.new(-26, 5.6, -36) },
	{ name = "OilLampLibrary", at = Vector3.new(-26, 5.6, -68) },
}
local LAMP_COLOR = Color3.fromRGB(255, 170, 90)

function Lights.dimLamps(root: Instance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local folder = Instance.new("Folder")
	folder.Name = "DimLamps"
	folder.Parent = root
	params.FilterDescendantsInstances = { folder }
	for _, spec in DIM_LAMPS do
		local best: RaycastResult? = nil
		for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local hit = workspace:Raycast(spec.at, dir * 24, params)
			if hit and math.abs(hit.Normal.Y) < 0.3 and (not best or hit.Distance < best.Distance) then
				best = hit
			end
		end
		if not best then
			continue
		end
		local normal = best.Normal
		local frame = CFrame.lookAt(best.Position + normal * 0.45, best.Position + normal * 2)
		local body = Instance.new("Part")
		body.Name = spec.name
		body.Size = Vector3.new(0.7, 1.1, 0.7)
		body.CFrame = frame
		body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch = true, false, false, false
		body.Material, body.Color = Enum.Material.Metal, Color3.fromRGB(58, 44, 34)
		body.CastShadow = false
		body.Parent = folder
		local glass = Instance.new("Part")
		glass.Name = "LampGlass"
		glass.Size = Vector3.new(0.5, 0.62, 0.5)
		glass.CFrame = frame * CFrame.new(0, 0.05, 0.02)
		glass.Anchored, glass.CanCollide, glass.CanQuery, glass.CanTouch = true, false, false, false
		glass.Material, glass.Color = Enum.Material.Neon, LAMP_COLOR
		glass.Transparency = 0.25
		glass.CastShadow = false
		glass.Parent = folder
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = LAMP_COLOR, 20, 0.7
		light.Shadows = false
		light.Parent = body
		body:SetAttribute(Tags.Attr.Flicker, true)
	end
end

return Lights
