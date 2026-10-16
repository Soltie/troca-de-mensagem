--!strict
--[[
	Opções de conforto do jogador (só no cliente, por sessão). Valores iniciais em Config.Comfort.
	  retro    scanlines, granulação, vinheta fixa            (atalho V)
	  vhs      carimbo de hora, tracking, aberração cromática
	  bob      balanço ao andar e respiração parada           (atalho B liga/desliga bob+tilt+shake)
	  tilt     inclinação lateral
	  shake    tremores
	  fov      FOV dinâmico (corrida, medo, susto)
	  flashes  clarões e falhas de tela fortes
	  haptics  vibração do controle
	O menu (tecla O) fica no GameUiController; os outros controllers leem com get().
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Create = require("../UI/Create")

export type Key = "retro" | "vhs" | "bob" | "tilt" | "shake" | "fov" | "flashes" | "haptics"

-- Ordem do menu.
local KEYS: { Key } = { "bob", "tilt", "shake", "fov", "flashes", "retro", "vhs", "haptics" }

-- Tabela "aberta" (chave dinâmica): o tipo Key garante as chaves válidas na API.
local values: { [string]: boolean } = {}
for _, key in KEYS do
	values[key] = (Config.Comfort :: any)[key] ~= false
end
local listeners: { (key: Key, value: boolean) -> () } = {}
local menu: TextLabel? = nil

local function refreshMenu()
	if not menu then
		return
	end
	local lines = { Text.Options.title, "" }
	-- Haptics ainda não tem executor: só expor as sete opções que já funcionam.
	for i = 1, 7 do
		local key = KEYS[i]
		table.insert(
			lines,
			string.format("[%d] %s: %s", i, (Text.Options :: any)[key], if values[key] then Text.On else Text.Off)
		)
	end
	table.insert(lines, "\n[1-7] ALTERNAR   [O] FECHAR")
	menu.Text = table.concat(lines, "\n")
end

local SettingsController = {
	Name = "SettingsController",
	KEYS = KEYS,
}

function SettingsController.get(key: Key): boolean
	return values[key]
end

function SettingsController.set(key: Key, value: boolean)
	if values[key] == value then
		return
	end
	values[key] = value
	refreshMenu()
	for _, listener in listeners do
		task.spawn(listener, key, value)
	end
end

function SettingsController.toggle(key: Key): boolean
	SettingsController.set(key, not values[key])
	return values[key]
end

-- Atalho B: movimento de câmera inteiro (balanço, inclinação e tremor) de uma vez.
function SettingsController.toggleMotion(): boolean
	local next = not (values["bob"] or values["tilt"] or values["shake"])
	SettingsController.set("bob", next)
	SettingsController.set("tilt", next)
	SettingsController.set("shake", next)
	return next
end

function SettingsController.motionEnabled(): boolean
	return values["bob"] or values["tilt"] or values["shake"]
end

function SettingsController.onChanged(listener: (key: Key, value: boolean) -> ())
	table.insert(listeners, listener)
end

function SettingsController.Init()
	local gui = Create("ScreenGui", {
		Name = "ComfortOptions",
		ResetOnSpawn = false,
		DisplayOrder = 90,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	menu = Create("TextLabel", {
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 310),
		BackgroundColor3 = Color3.fromRGB(15, 19, 17),
		BackgroundTransparency = 0.08,
		TextColor3 = Color3.fromRGB(215, 225, 205),
		TextSize = 16,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = false,
		Parent = gui,
	}, { Create("UIPadding", { PaddingLeft = UDim.new(0, 18) }) }) :: TextLabel
	refreshMenu()
end

function SettingsController.Start()
	-- O também é zoom da câmera padrão; InputBegan chega processado e perdia o atalho.
	ContextActionService:BindActionAtPriority("S9ComfortOptions", function(_, state)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and menu then
			menu.Visible = not menu.Visible
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			SettingsController.toggle("retro")
		elseif input.KeyCode == Enum.KeyCode.B then
			SettingsController.toggleMotion()
		elseif menu and menu.Visible then
			local numberKeys = {
				Enum.KeyCode.One,
				Enum.KeyCode.Two,
				Enum.KeyCode.Three,
				Enum.KeyCode.Four,
				Enum.KeyCode.Five,
				Enum.KeyCode.Six,
				Enum.KeyCode.Seven,
			}
			local index = table.find(numberKeys, input.KeyCode)
			if index then
				SettingsController.toggle(KEYS[index])
			end
		end
	end)
end

return SettingsController
