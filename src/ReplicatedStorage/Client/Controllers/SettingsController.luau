--!strict
--[[
	Opções de conforto do jogador (só no cliente, por sessão):
	  V = filtro retrô (scanlines, granulação, vinheta, cintilação)
	  B = movimento de câmera (balanço ao andar, tremores)
	Outros controllers leem com get() e escutam com onChanged().
]]

local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")

export type Key = "retro" | "motion"

local values: { [Key]: boolean } = {
	retro = Config.Effects.RetroOverlayDefault,
	motion = Config.Effects.CameraMotionDefault,
}
local listeners: { (key: Key, value: boolean) -> () } = {}

local SettingsController = {
	Name = "SettingsController",
}

function SettingsController.get(key: Key): boolean
	return values[key]
end

function SettingsController.set(key: Key, value: boolean)
	values[key] = value
	for _, listener in listeners do
		task.spawn(listener, key, value)
	end
end

function SettingsController.toggle(key: Key): boolean
	SettingsController.set(key, not values[key])
	return values[key]
end

function SettingsController.onChanged(listener: (key: Key, value: boolean) -> ())
	table.insert(listeners, listener)
end

function SettingsController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			SettingsController.toggle("retro")
		elseif input.KeyCode == Enum.KeyCode.B then
			SettingsController.toggle("motion")
		end
	end)
end

return SettingsController
