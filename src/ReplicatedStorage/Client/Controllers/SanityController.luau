--!strict
--[[
	Sanidade no escuro (ideia I, inspirada em Amnesia). Ficar no breu gasta a sanidade: a visão perde cor e treme,
	a imagem embaça por ondas e sussurros crescem. Com a lanterna acesa o desgaste é lento; perto de uma vela,
	lamparina ou lâmpada acesa a sanidade volta rápido. Nunca mata: só empurra o jogador a procurar luz.
	Com sanidade muito baixa, de tempos em tempos as luzes falham e a lanterna engasga (alucinação).
	Só no cliente; respeita as opções de conforto (tremor e flashes).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FlashlightController = require("./FlashlightController")
local GameUi = require("./GameUiController")
local SettingsController = require("./SettingsController")
local WorldFxController = require("./WorldFxController")

local player = Players.LocalPlayer

local SanityController = {
	Name = "SanityController",
}

-- Segundos para ir de 1 a 0 no breu, com lanterna acesa, e para voltar de 0 a 1 perto de luz.
local DARK_SECONDS = 45
local FLASHLIGHT_SECONDS = 150
local RECOVER_SECONDS = 10

local phase: GameState.Phase = "Loading"
local sanity = 1
local loss = 0
local grade: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil
local nextHallucinationAt = 0
local hinted = false
local chapter = 0
local rng = Random.new()

-- Luz em volta (soma das luzes acesas da casa, pelo brilho e pela distância; velas contam, mas pouco).
-- Abaixo de DARK é breu; acima de LIT recupera.
local DARK = 0.08
local LIT = 0.2
local lights: { [Light]: BasePart } = {}
local levelClock = 0
local lastLevel = 1

local function track(instance: Instance)
	if instance:IsA("Light") and instance.Parent and instance.Parent:IsA("BasePart") then
		lights[instance] = instance.Parent
	end
end

local function lightLevel(position: Vector3): number
	levelClock += 1
	if levelClock % 15 ~= 1 then
		return lastLevel
	end
	local total = 0
	for light, part in lights do
		if not light.Parent or not part.Parent then
			lights[light] = nil
			continue
		end
		if not light.Enabled or light.Brightness < 0.05 then
			continue
		end
		local range = (light :: any).Range or 0
		local d = (part.Position - position).Magnitude
		if d < range then
			local k = 1 - d / range
			total += light.Brightness * k * k
		end
	end
	lastLevel = total
	return total
end

local function stage(): number
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
	local value = state and state:GetAttribute("Stage")
	return if type(value) == "number" then value else 0
end

local function update(dt: number)
	local current = stage()
	if current ~= chapter then
		chapter = current
		sanity = 1
		hinted = false
	end
	local hidden = player:GetAttribute("Hidden")
	local inside = type(hidden) == "string" and hidden ~= ""
	-- Só conta depois de ter a lanterna (no começo do capítulo 1 o escuro não é culpa de ninguém) e nunca durante a
	-- revista do armário (a imagem embaçando atrapalharia o ritmo).
	local active = phase == "Playing"
		and player:GetAttribute("CinematicActive") ~= true
		and player:GetAttribute("CampaignStatus") == "Active"
		and player:GetAttribute("HasFlashlight") == true
		and player:GetAttribute("BreathTestAt") == nil
	if active then
		local camera = workspace.CurrentCamera
		local level = if camera then lightLevel(camera.CFrame.Position) else 1
		if level < DARK and not FlashlightController.isOn() then
			-- No armário o escuro conta pela metade (você se escondeu de propósito).
			sanity -= dt / DARK_SECONDS * (if inside then 0.5 else 1)
		elseif level < LIT then
			-- Só a lanterna ou uma vela longe: desgaste lento.
			sanity -= dt / FLASHLIGHT_SECONDS
		else
			sanity += dt / RECOVER_SECONDS
		end
	else
		sanity += dt / RECOVER_SECONDS
	end
	sanity = math.clamp(sanity, 0, 1)
	local target = 1 - sanity
	loss += (target - loss) * math.min(1, dt * 2)
	AudioController.setSanity(loss)

	local g, b = grade, blur
	if g then
		g.Enabled = loss > 0.03
		g.Saturation = -0.65 * loss
		-- 20/10: sem escurecer tanto (antes -0,06 e 0,18): no escuro somava com o grade da cena e virava preto.
		-- A perda de sanidade se lê pela cor lavada e pelo embaçamento, não por apagar o caminho.
		g.Contrast = 0.08 * loss
		g.Brightness = -0.02 * loss
		g.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 214, 235), loss * 0.5)
	end
	local now = os.clock()
	if b then
		-- Ondas de embaçamento: vão e voltam devagar, mais fortes quanto menos sanidade.
		local wave = 0.5 + 0.5 * math.sin(now * 0.9) * math.sin(now * 0.37)
		b.Enabled = loss > 0.08
		b.Size = 8 * loss * loss * wave
	end
	if loss > 0.25 and SettingsController.get("shake") then
		CameraController.addTrauma(dt * 0.4 * loss * loss)
	end
	-- Primeira vez no escuro de verdade: uma frase explica o que fazer.
	if not hinted and loss > 0.55 then
		hinted = true
		-- Com a lanterna na mão (desligada), a dica manda ligá-la; "procure uma vela" só para quem não tem lanterna.
		GameUi.caption(
			if player:GetAttribute("HasFlashlight") == true
				then "Está escuro demais. Ligue a lanterna (F) ou fique perto de uma chama."
				else "Está escuro demais. Procure uma vela, uma lamparina ou uma lâmpada acesa.",
			6
		)
	end
	-- Alucinações com a sanidade no fim.
	if loss > 0.85 and now >= nextHallucinationAt then
		nextHallucinationAt = now + rng:NextNumber(18, 32)
		AudioController.play("Whisper", 1, rng:NextNumber(0.7, 0.9))
		FlashlightController.flicker(0.8)
		WorldFxController.surge(1.2)
		CameraController.addTrauma(0.3)
	end
end

function SanityController.Init()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SanityGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	grade = cc
	local bl = Instance.new("BlurEffect")
	bl.Name = "SanityBlur"
	bl.Enabled = false
	bl.Size = 0
	bl.Parent = Lighting
	blur = bl
end

function SanityController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	-- Luzes do mundo (as da lanterna ficam fora: estão na câmera/rig, não na casa).
	task.spawn(function()
		local world = workspace:WaitForChild("CursedHouse", 30)
		if world then
			for _, instance in world:GetDescendants() do
				track(instance)
			end
		end
		workspace.DescendantAdded:Connect(function(instance)
			local root = workspace:FindFirstChild("CursedHouse")
			if root and instance:IsDescendantOf(root) then
				track(instance)
			end
		end)
	end)
	RunService.Heartbeat:Connect(update)
end

-- Depuração (Studio).
function SanityController.debugState(): { [string]: any }
	return { sanity = sanity, loss = loss, light = lastLevel }
end

return SanityController
