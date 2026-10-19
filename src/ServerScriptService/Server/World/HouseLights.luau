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
	root:SetAttribute("HouseLightPlan", `{stats.electric} elétricas, {stats.flame} chamas, {stats.off} desligadas`)
end

return Lights
