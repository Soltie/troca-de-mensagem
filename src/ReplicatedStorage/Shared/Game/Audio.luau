--!strict
--[[
	Registro de áudio. Origem, licença e uso de cada ID: docs/ASSETS.md.
	Todos foram verificados carregando no Studio (ContentProvider:PreloadAsync -> Success).
	rbxasset:// = arquivos que já vêm com o cliente Roblox (sem upload).
]]

export type Clip = {
	id: string,
	volume: number,
	speed: number?,
}

local Audio: { [string]: Clip } = {
	-- Ambiências
	AmbExterior = { id = "rbxassetid://9112834179", volume = 0.35 }, -- PSE Neighborhood Ambience 4 (noite, grilos)
	AmbInterior = { id = "rbxassetid://9112839511", volume = 0.22, speed = 0.4 }, -- PSE Oil Refinery Ambience 2 (grave)
	Music = { id = "rbxassetid://1837172508", volume = 0.22 }, -- APM "The Fear Within"
	Heartbeat = { id = "rbxassetid://9043365842", volume = 0.6 }, -- APM "HEARTBEAT 02 96BPM"
	LampBuzz = { id = "rbxassetid://9112823813", volume = 0.25 }, -- PSE Light Bulb Buzz 2
	GeneratorHum = { id = "rbxassetid://9112889082", volume = 0.5 }, -- PSE Transformer Hum 1

	-- Criatura
	Growl = { id = "rbxassetid://9125469893", volume = 0.9, speed = 0.85 }, -- PSE Creature Growls Lion Deep Guttural
	Snarl = { id = "rbxassetid://9125475724", volume = 1.0, speed = 0.8 }, -- PSE Creature Vocal Spider Growl
	Roar = { id = "rbxassetid://9113980319", volume = 1.0, speed = 0.9 }, -- PSE Creature Mix Giant Crab Monster 1
	ChaseLoop = { id = "rbxassetid://9113985466", volume = 0.45, speed = 0.75 }, -- PSE Creature Roar Constant 3
	CreatureStep = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.9, speed = 0.45 }, -- Roblox (cliente)

	-- Stingers / música curta
	StingerAwaken = { id = "rbxassetid://1841353932", volume = 0.7 }, -- APM "Rising Fear Hit 2"
	StingerCapture = { id = "rbxassetid://1846887425", volume = 0.9 }, -- APM "Evil Mind 9"
	StingerWin = { id = "rbxassetid://9042971851", volume = 0.6 }, -- APM "An Ending, A Beginning Sting"

	-- Interação / mundo
	Switch = { id = "rbxassetid://9119727134", volume = 0.8 }, -- PSE Switch Impact On Flip Up Large Metal 2
	Flashlight = { id = "rbxassetid://9114479860", volume = 0.6 }, -- PSE Flashlight On Off Clicks 5
	Door = { id = "rbxassetid://9114145921", volume = 0.7 }, -- PSE Door Long Squeaks On Close 2
	UiBlip = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35 }, -- Roblox (cliente)
}

return table.freeze(Audio)
