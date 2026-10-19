--!strict
--[[
	Registro de áudio. Origem, licença e uso de cada ID: docs/ASSETS.md.
	Todos foram verificados carregando no Studio (ContentProvider:PreloadAsync -> Success).
	rbxasset:// = arquivos que já vêm com o cliente Roblox (sem upload).
	PSE = Pro Sound Effects, APM = APM Music (bibliotecas licenciadas pela Roblox, gratuitas).

	`region` = trecho (s) do arquivo usado como amostra (Sound.PlaybackRegion), para tirar um
	golpe só de arquivos com várias versões.
]]

export type Clip = {
	id: string,
	volume: number,
	speed: number?,
	region: { number }?,
}

local Audio: { [string]: Clip } = {
	-- Ambiências
	AmbExterior = { id = "rbxassetid://9112834179", volume = 0.24 }, -- PSE Neighborhood Ambience 4 (noite, grilos)
	AmbInterior = { id = "rbxassetid://9112839511", volume = 0.15, speed = 0.4 }, -- PSE Oil Refinery Ambience 2 (grave)
	AmbRain = { id = "rbxassetid://9112856553", volume = 0.32 }, -- PSE Rain On Window 3 (chuva média, laço)
	AmbThunder = { id = "rbxassetid://9120018692", volume = 0.55 }, -- PSE Thunder Distant Rumble 1 (trovão distante)
	WindInterior = { id = "rbxassetid://9125742262", volume = 0.12, speed = 0.45 }, -- PSE Plasma Trails Airy Whooshing (vento em frestas)
	Machinery = { id = "rbxassetid://9118748093", volume = 0.18, speed = 0.6 }, -- PSE Rumble Constant Roar (máquinas com energia)
	Drips = { id = "rbxassetid://9120527007", volume = 0.35 }, -- PSE Water Drip Single Drops Into Tin Bucket 2
	CreakWood = { id = "rbxassetid://9114496002", volume = 0.4 }, -- PSE Floor Creaks Short Med Wood Creaks 19
	CreakMetal = { id = "rbxassetid://9116770610", volume = 0.35 }, -- PSE Metal Popping Constant Muffled Buckling 8
	Whisper = { id = "rbxassetid://9043347008", volume = 0.35 }, -- APM "DISTURBED WHISPERS 02"
	RadioStatic = { id = "rbxassetid://9119974504", volume = 0.5 }, -- PSE Television Turn On And Off 1 (chiado)
	LampBuzz = { id = "rbxassetid://9112823813", volume = 0.25 }, -- PSE Light Bulb Buzz 2
	GeneratorHum = { id = "rbxassetid://9112889082", volume = 0.5 }, -- PSE Transformer Hum 1

	-- Música por estado (calma / tensão / perseguição / alívio)
	Music = { id = "rbxassetid://1837172508", volume = 0.13 }, -- APM "The Fear Within" (calma inquieta)
	MusicTension = { id = "rbxassetid://1843867314", volume = 0.2 }, -- APM "Tension Repeat Drones 29"
	MusicChase = { id = "rbxassetid://1837843534", volume = 0.3 }, -- APM "Deliberate Pain (Fast Bass)"
	MusicRelief = { id = "rbxassetid://1843755486", volume = 0.18 }, -- APM "Mid-Tone Drone 51"
	Heartbeat = { id = "rbxassetid://9043365842", volume = 0.6 }, -- APM "HEARTBEAT 02 96BPM"

	-- Corpo do jogador
	StepConcrete = { id = "rbxassetid://9114523629", volume = 0.5, region = { 0, 0.3 } }, -- PSE Foot Stomp 7
	StepWood = { id = "rbxassetid://9120880067", volume = 0.55, region = { 0, 0.3 } }, -- PSE Wood Grab Muted Thuds 15
	StepMetal = { id = "rbxassetid://9120102763", volume = 0.35, region = { 0, 0.25 } }, -- PSE Toggle Switch Metal Industrial 18
	StepWater = { id = "rbxassetid://9125701986", volume = 0.45, region = { 0.47, 0.82 } }, -- PSE Mud Puddle Splash 13
	StepFallback = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.4, region = { 0, 0.26 } }, -- Roblox (cliente)
	Land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5 }, -- Roblox (cliente)
	Breath1 = { id = "rbxassetid://9114555699", volume = 0.35 }, -- PSE Gasp Trouble Breathing 3
	Breath2 = { id = "rbxassetid://9114555659", volume = 0.35 }, -- PSE Gasp Trouble Breathing 1
	Breath3 = { id = "rbxassetid://9114555843", volume = 0.35 }, -- PSE Gasp Trouble Breathing 4
	Breath4 = { id = "rbxassetid://9114556046", volume = 0.35 }, -- PSE Gasp Trouble Breathing 7
	Gasp = { id = "rbxassetid://9114556036", volume = 0.7 }, -- PSE Gasp Trouble Breathing 8 (fôlego acabou)

	-- Criatura
	Growl = { id = "rbxassetid://9125469893", volume = 0.9, speed = 0.85 }, -- PSE Creature Growls Lion Deep Guttural
	Snarl = { id = "rbxassetid://9125475724", volume = 1.0, speed = 0.8 }, -- PSE Creature Vocal Spider Growl
	Roar = { id = "rbxassetid://9113980319", volume = 1.0, speed = 0.9 }, -- PSE Creature Mix Giant Crab Monster 1
	ChaseLoop = { id = "rbxassetid://9113985466", volume = 0.45, speed = 0.75 }, -- PSE Creature Roar Constant 3
	CreatureStep = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.9, speed = 0.45 }, -- Roblox (cliente)
	DoorBang = { id = "rbxassetid://9114432643", volume = 0.9 }, -- PSE Fire Door Frantic Knocks 2

	-- Stingers / música curta
	StingerAwaken = { id = "rbxassetid://1841353932", volume = 0.7 }, -- APM "Rising Fear Hit 2"
	StingerCapture = { id = "rbxassetid://1846887425", volume = 0.9 }, -- APM "Evil Mind 9"
	StingerWin = { id = "rbxassetid://9042971851", volume = 0.6 }, -- APM "An Ending, A Beginning Sting"

	-- Interação / mundo
	Switch = { id = "rbxassetid://9119727134", volume = 0.8 }, -- PSE Switch Impact On Flip Up Large Metal 2
	Flashlight = { id = "rbxassetid://9114479860", volume = 0.6 }, -- PSE Flashlight On Off Clicks 5
	Door = { id = "rbxassetid://9114145921", volume = 0.7 }, -- PSE Door Long Squeaks On Close 2
	DoorRattle = { id = "rbxassetid://9117906668", volume = 0.6, speed = 1.15 }, -- PSE Prison Bars Rattle 3
	DoorLatch = { id = "rbxassetid://9114435018", volume = 0.7 }, -- PSE Fire Door Latch Open And Close 9
	LockerLatch = { id = "rbxassetid://9114435018", volume = 0.55, speed = 1.35 }, -- PSE Fire Door Latch (mais agudo)
	KeyTurn = { id = "rbxassetid://9120102763", volume = 0.6, speed = 1.5 }, -- PSE Toggle Switch Metal (clique da tranca)
	BreakerToggle = { id = "rbxassetid://9120102763", volume = 0.9, speed = 0.8 }, -- PSE Toggle Switch Metal Industrial 18
	BreakerFail = { id = "rbxassetid://9125550914", volume = 0.9 }, -- PSE Engine Abuse Metal Hits 4
	Paper = { id = "rbxassetid://9114385821", volume = 0.6 }, -- PSE Fax Paper Flutter 13
	Pickup = { id = "rbxassetid://9120880067", volume = 0.5, speed = 1.4, region = { 0, 0.35 } }, -- PSE Wood Grab Muted Thuds 15
	UiBlip = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35 }, -- Roblox (cliente)
	Coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, speed = 1.35 }, -- Roblox (cliente): moeda

	-- Objetos que caem
	Fall_bucket = { id = "rbxassetid://9116502787", volume = 0.9 }, -- PSE Metal 50 Gallon Drum
	Fall_cans = { id = "rbxassetid://9120188626", volume = 0.9 }, -- PSE Toolbox Impact Wood Metal Hits Fall Crash 11
	Fall_bottles = { id = "rbxassetid://9120188618", volume = 0.9 }, -- PSE Toolbox Impact Wood Metal Hits Fall Crash 10
	Fall_pipes = { id = "rbxassetid://9116886745", volume = 0.9 }, -- PSE Metal Tank Impact 3
	Fall_extinguisher = { id = "rbxassetid://9116501934", volume = 0.9 }, -- PSE Metal 50 Gallon Drum
	Fall_box = { id = "rbxassetid://9126090979", volume = 0.9 }, -- PSE Table Falls Impact On Concrete 9
	-- Incêndio da fuga final (FireController)
	FireCrackle = { id = "rbxassetid://236387093", volume = 0.9 }, -- Fireplace Crackle (Jontizm, laço de 15 s)
	AmbFireRoar = { id = "rbxassetid://2787093357", volume = 0.5 }, -- forest fire (Festivereinhard2, laço de 44 s)
	BeamCrack = { id = "rbxassetid://9120819447", volume = 1 }, -- PSE Wood Crack Deep Clunky Scrapes Crackling 4
	WoodSplinter = { id = "rbxassetid://9126240449", volume = 0.9 }, -- PSE Wood Crack Thick Splintering Bursts Creaking 2
	GasWhoosh = { id = "rbxassetid://135097195613949", volume = 1 }, -- Fire_ignition (ImBobTheOff, 7,9 s)
	GasPour = { id = "rbxassetid://9120620371", volume = 0.55, speed = 1.5, region = { 0.6, 3.2 } }, -- PSE Wave Spraying Hiss 4 (gasolina caindo)
}

return table.freeze(Audio)
