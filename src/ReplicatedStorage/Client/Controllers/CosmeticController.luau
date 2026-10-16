--!strict
--[[
	Cosméticos locais (cliente), lidos dos atributos que o servidor publica no Player
	(StoreService): EquipFlashlight, EquipUniform, EquipFilter.
	- Skin da lanterna: cor/material do corpo e tom do feixe (nunca alcance nem brilho).
	- Manga do braço na mão: cor da farda equipada.
	- Filtro de câmera: troca a gradação "RetroGrade" (tom, saturação, contraste).
	- Placas de título (feitas no servidor, CosmeticService): só aparecem fora da ação
	  (intro/intervalo/fim) ou para quem está esperando/assistindo; no escuro do turno, nada flutua.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local FlashlightController = require("./FlashlightController")

local player = Players.LocalPlayer

local phase: GameState.Phase = "Loading"
local accumulator = 0

local function rgb(c: StoreCatalog.RGB?, fallback: Color3): Color3
	if not c then
		return fallback
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function material(name: string?): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name or "Metal"]
	end)
	return if ok and value then value else Enum.Material.Metal
end

local function equippedItem(attribute: string, kind: StoreCatalog.ItemKind): StoreCatalog.Item
	local id = player:GetAttribute(attribute)
	local item = if type(id) == "string" then StoreCatalog.ItemById[id] else nil
	if item and item.kind == kind then
		return item
	end
	return StoreCatalog.ItemById[StoreCatalog.defaultFor(kind)]
end

local function applyFlashlight()
	local item = equippedItem("EquipFlashlight", "flashlight")
	FlashlightController.applySkin(
		rgb(item.body, Color3.fromRGB(38, 40, 44)),
		rgb(item.head, Color3.fromRGB(52, 54, 58)),
		rgb(item.beam, Color3.fromRGB(255, 232, 196)),
		material(item.material)
	)
end

local function applyUniform()
	local item = equippedItem("EquipUniform", "uniform")
	FlashlightController.applySleeve(rgb(item.shirt, Color3.fromRGB(46, 58, 54)))
end

local function applyFilter()
	local grade = Lighting:FindFirstChild("RetroGrade")
	if not grade or not grade:IsA("ColorCorrectionEffect") then
		return
	end
	local item = equippedItem("EquipFilter", "filter")
	grade.TintColor = rgb(item.tint, Color3.fromRGB(214, 228, 210))
	grade.Saturation = item.saturation or -0.32
	grade.Contrast = item.contrast or 0.16
	grade.Brightness = item.brightness or -0.01
end

local function titlesVisible(): boolean
	local status = player:GetAttribute("CampaignStatus")
	return phase ~= "Playing" or status == "Waiting" or status == "Escaped"
end

local function updateTitles()
	local show = titlesVisible()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local folder = character and character:FindFirstChild("S9Cosmetics")
		local tag = folder and folder:FindFirstChild("TitleTag")
		if tag and tag:IsA("BillboardGui") then
			-- A própria placa nunca aparece (primeira pessoa).
			tag.Enabled = show and other ~= player
		end
	end
end

local CosmeticController = {
	Name = "CosmeticController",
}

function CosmeticController.Start()
	for attribute, apply in
		{
			EquipFlashlight = applyFlashlight,
			EquipUniform = applyUniform,
			EquipFilter = applyFilter,
		} :: { [string]: () -> () }
	do
		player:GetAttributeChangedSignal(attribute):Connect(apply)
		apply()
	end
	GameState.observe(function(snapshot)
		phase = snapshot.phase
		updateTitles()
	end)
	-- Personagens novos (respawn, entrada) recebem placas: revisita algumas vezes por segundo.
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			updateTitles()
		end
	end)
end

return CosmeticController
