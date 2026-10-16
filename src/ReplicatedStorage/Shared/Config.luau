--!strict
--[[
	Constantes do projeto. Só valores, nada de lógica nem APIs do Roblox.
	Tudo é congelado: tentar alterar em runtime gera erro.
]]

local TableUtil = require("./Util/TableUtil")
local Types = require("./Types")

local Config = {
	-- Modo cooperativo; false seleciona o protótipo solo para regressão/polish.
	Campaign = {
		Enabled = true,
		Seed = nil :: number?,
		minPlayers = 1,
		maxPlayers = 6,
		downedSeconds = 45,
		relayWindow = 12,
		LobbySeconds = 5,
		StageIntroSeconds = 3,
		SpawnTimeout = 35,
		IntermissionSeconds = 6,
		ActionCooldown = 0.5,
		ReviveSeconds = 4,
		MedicReviveSeconds = 2.5,
		ReviveGrace = 6,
		SpawnGrace = 8,
		CaptureRecovery = 2,
		ThreatInterval = 25,
		BlackoutSeconds = 5,
		ScoutRange = 40,
	},
	-- Nível mínimo de log exibido.
	House = { Enabled = true, EscapeSeconds = 150, BreathKey = "Z", FalseExitChance = 0.2, FalseExitCooldown = 35 },
	-- Moedas da casa (CoinService): espalhadas a cada capítulo; cada uma paga Fichas + XP na hora.
	Coins = {
		Enabled = true,
		PerRoom = 2,
		YardCoins = 8,
		Value = 2,
		Xp = 1,
		GemValue = 15,
		GemXp = 10,
		PickupRadius = 4.5,
	},
	LogLevel = "Info" :: Types.LogLevel,

	Net = {
		-- Pasta criada pelo servidor em ReplicatedStorage com todos os remotes.
		RemotesFolderName = "Remotes",
		-- Tempo máximo (s) que o cliente espera um remote aparecer.
		ClientWaitTimeout = 15,
		-- Rate limit padrão por jogador, por remote (token bucket).
		DefaultRateLimit = { capacity = 10, refillPerSecond = 5 },
	},

	Data = {
		-- Nome base do DataStore. No Studio (modo real) recebe o sufixo "_Studio".
		StoreName = "PlayerData_v1",
		SchemaVersion = 5,
		AutosaveInterval = 120,
		RetryAttempts = 3,
		RetryBaseDelay = 1,
		-- Só afeta o Studio. "auto": usa DataStore real se houver acesso, senão mock.
		-- "mock": sempre mock. "real": exige acesso (erro se não houver).
		StudioMode = "mock" :: "auto" | "mock" | "real",
		KickOnLoadFailure = true,
		-- BindToClose tem ~30s no total; deixamos folga.
		ShutdownTimeout = 25,
	},

	Debug = {
		-- Painel de debug (FPS, fase, criatura). F3 alterna durante o jogo.
		ShowHud = false,
	},

	-- ===================== SUBESTAÇÃO 9 (jogo) =====================

	Game = {
		FusesTotal = 3,
		-- Duração (s) da cartela de introdução; o jogador fica parado nesse tempo.
		IntroDuration = 9,
		-- O Vigia acorda no 1º fusível ou depois deste tempo (s) de jogo, o que vier antes.
		AwakenAfter = 120,
		-- Distância máxima de interação (studs) + folga aceita pelo servidor (latência).
		InteractDistance = 8,
		InteractTolerance = 2.5,
		-- Atraso (s) entre o 3º fusível e a energia voltar (faíscas, tensão).
		PowerOnDelay = 1.6,
		-- Semente fixa para posições dos fusíveis (nil = aleatório por rodada).
		FuseSeed = nil :: number?,
	},

	Player = {
		WalkSpeed = 14,
		SprintSpeed = 21,
		CrouchSpeed = 5.5,
		JumpHeight = 2.4,
		FieldOfView = 72,
		-- Aceleração/frenagem (studs/s por segundo) do WalkSpeed: o corpo tem peso.
		Acceleration = 26,
		Deceleration = 40,
		-- Fôlego em segundos de corrida; recarga por segundo parado/andando.
		StaminaMax = 5,
		StaminaRegen = 0.7,
		StaminaMinToSprint = 1,
		-- Ao zerar o fôlego: anda mais devagar por ExhaustedTime (s), ofegante.
		ExhaustedTime = 2.4,
		ExhaustedSpeed = 7,
		-- Acima desta velocidade (studs/s) o servidor considera que o jogador está fazendo barulho.
		NoiseSpeed = 13,
		NoiseRadius = 28,
		-- Agachado: quanto o corpo desce (studs) e a margem de teto exigida para levantar.
		CrouchDrop = 1.7,
		StandClearance = 0.3,
		-- Agachado o Vigia enxerga menos (multiplica alcance de visão e "sentido" de perto).
		CrouchSightFactor = 0.7,
		-- Validação de velocidade no servidor: tolerância (multiplica o limite) e tempo acima do
		-- limite antes de corrigir a posição (lag e empurrões não punem).
		SpeedTolerance = 1.4,
		SpeedGrace = 1.2,
		-- Segurar a respiração (só escondido): duração máxima, recarga e raio do barulho do arquejo.
		HoldBreathMax = 6,
		HoldBreathCooldown = 3,
		GaspNoiseRadius = 24,
	},

	-- Lanterna com bateria (servidor simula; cliente mostra nos LEDs da lanterna).
	Battery = {
		StartCharge = 0.85,
		-- Carga cheia dura 1/DrainPerSecond segundos de luz contínua.
		DrainPerSecond = 1 / 170,
		-- Desligada, a pilha "descansa" e recupera devagar até RechargeCap (a missão nunca trava).
		RechargePerSecond = 1 / 40,
		RechargeCap = 0.35,
		MinToTurnOn = 0.04,
		LowLevel = 0.2,
		PickupAmount = 0.6,
		-- Quantas pilhas aparecem por rodada (sorteadas entre os pontos de Features.BatterySpots).
		PickupsPerRound = 3,
	},

	-- Medo (só no cliente; não tem barra: dirige efeitos). Ver Shared/Game/FearModel.
	Fear = {
		-- Velocidade (1/s) com que o medo sobe/desce até o alvo do momento.
		RiseRate = 1.6,
		DecayRate = 0.14,
		ProximityRange = 42,
		ProximityWeight = 0.55,
		VisibleWeight = 0.22,
		ChaseFloor = 0.75,
		DarkWeight = 0.16,
		HiddenNearRange = 14,
		HiddenNearWeight = 0.25,
		-- Em lugar seguro (aceso, ameaça longe) o alvo não passa disto.
		SafeCeiling = 0.12,
		SpikeMax = 0.6,
		SpikeDecay = 0.09,
		-- Níveis com histerese: entra no nível ao passar de `enter`, sai abaixo de `exit`.
		Levels = {
			{ enter = 0.3, exit = 0.22 },
			{ enter = 0.55, exit = 0.45 },
			{ enter = 0.8, exit = 0.68 },
		},
	},

	-- Diretor de tensão (cliente; eventos só de apresentação). Ver Shared/Game/TensionDirector.
	Tension = {
		TickInterval = 0.25,
		-- Distância do Vigia que já conta como "tensão".
		TensionRange = 34,
		-- Intervalo mínimo (s) entre eventos em cada estado e chance média de evento por segundo.
		GapAnticipation = 16,
		GapTension = 10,
		ChancePerSecond = 0.12,
		-- Calmaria depois de uma perseguição (s, sem sustos).
		RecoveryTime = 16,
		-- Silêncio antes de certos sustos (s).
		SilenceBefore = 1.4,
	},

	Camera = {
		-- Balanço (amplitude em studs, ciclos por stud andado).
		BobAmplitude = 0.11,
		BobSprintAmplitude = 0.2,
		BobCrouchAmplitude = 0.06,
		BobFrequency = 0.36,
		-- Respiração parada (amplitude em studs, ciclos/s).
		IdleBreathAmplitude = 0.022,
		IdleBreathRate = 0.24,
		-- Inclinação lateral ao andar de lado (graus).
		StrafeTilt = 1.8,
		-- FOV: + ao correr, - com medo alto, pancada na detecção.
		SprintFov = 6,
		FearFovNarrow = 6,
		PunchFov = 9,
		-- Tremor (trauma): ângulo máximo (graus) e decaimento por segundo.
		ShakeMaxAngle = 2.4,
		TraumaDecay = 1.3,
		-- Pouso: velocidade de queda (studs/s) mínima para impacto e a que dá impacto máximo.
		LandingMinSpeed = 16,
		LandingMaxSpeed = 55,
		-- Altura do olho agachado (o quanto desce) e velocidade da transição.
		CrouchEyeDrop = 1.9,
		CrouchSpeed = 8,
	},

	-- Esconderijos (armários) e detecção do jogador escondido.
	Hide = {
		-- O Vigia "viu entrar" se te enxergou há menos disto (s) quando você entrou.
		SawEntryWindow = 1.2,
		-- Perto do armário por NoticeTime (s) sem você prender a respiração = te acha.
		NoticeRange = 6.5,
		NoticeTime = 2.6,
		ExitCooldown = 0.8,
	},

	Puzzle = {
		Breakers = 3,
		ErrorNoiseRadius = 46,
		ErrorCooldown = 1.2,
	},

	Doors = {
		CrackAngle = 18,
		OpenNoise = 18,
		CrackNoise = 6,
		RattleNoise = 14,
		UnlockTime = 1.3,
	},

	-- Objetos que caem (barulho que atrai o Vigia), com limites para não virar spam.
	Fallables = {
		-- Passar perto (studs) mais rápido que TriggerSpeed derruba; agachado/devagar não.
		TriggerRadius = 2.8,
		TriggerSpeed = 8,
		NoiseRadius = 34,
		Cooldown = 10,
		GlobalCooldown = 5,
		ResetAfter = 6,
	},

	Checkpoint = {
		-- Depois de continuar do checkpoint, o Vigia espera isto (s) antes de caçar.
		GraceTime = 6,
		-- Cartela curta ao continuar (s).
		IntroDuration = 3,
	},

	Creature = {
		Height = 7.5,
		-- Agente de pathfinding (raio/altura). O corredor e as portas foram medidos para isto.
		AgentRadius = 1.3,
		AgentHeight = 7.6,
		PatrolSpeed = 9,
		PatrolSpeedPerFuse = 0.7,
		InvestigateSpeed = 9,
		ChaseSpeed = 17,
		ChaseSpeedPerFuse = 0.5,
		HuntSpeed = 17,
		-- Visão: alcance no escuro / com a lanterna do jogador ligada; campo de visão (graus).
		SightRange = 35,
		SightRangeFlashlight = 50,
		SightFov = 100,
		-- Abaixo desta distância ele percebe o jogador mesmo de costas (se houver linha de visão).
		CloseSenseRange = 7,
		-- Perde o rastro após este tempo (s) sem ver; segue a última posição por GraceTime (s).
		LoseSightTime = 5,
		GraceTime = 1.5,
		SearchTime = 4,
		CaptureRange = 3.6,
		-- Com 2+ fusíveis, a cada StalkInterval (s) ele "fareja" a posição aproximada do jogador.
		StalkFromFuses = 2,
		StalkInterval = 25,
		BrainInterval = 0.2,
		RepathInterval = 0.5,
		DoorOpenRange = 5,
		DoorOpenPause = 0.6,
	},

	Visual = {
		-- Frequência (Hz) com que o modelo visual da criatura acompanha a posição real (stop-motion).
		CreatureStepRate = 12,
		-- Poses por segundo de cada animação da criatura.
		PoseRate = {
			Idle = 3,
			Patrol = 8,
			Investigate = 9,
			Chase = 12,
			Search = 4,
			Capture = 10,
		},
		-- Frequência das piscadas de luz e efeitos 2D em passos.
		FlickerRate = 12,
		-- Quadros por segundo das animações de porta/portão no servidor.
		DoorFrames = 4,
		GateFrames = 6,
	},

	Art = {
		SurfacePartLimit = 160,
		TextureLimit = 360,
		TextureStuds = 5,
		DustRange = 32,
		ScreenRange = 55,
	},

	Effects = {
		ScanlineSpacing = 3,
		ScanlineTransparency = 0.91,
		GrainDots = 48,
		-- Desfoque máximo (pânico) e névoa mínima/máxima (studs) conforme o perigo.
		PanicBlur = 3.5,
		DangerFogEnd = 64,
	},

	-- Valores iniciais das opções de conforto (menu O; V e B são atalhos).
	Comfort = {
		retro = true, -- scanlines, granulação, vinheta fixa
		vhs = true, -- carimbo de hora, linha de tracking, aberração cromática
		bob = true, -- balanço da câmera ao andar e respiração parada
		tilt = true, -- inclinação lateral
		shake = true, -- tremores
		fov = true, -- FOV dinâmico (corrida, medo, susto)
		flashes = true, -- clarões e falhas de tela fortes
		haptics = true, -- vibração do controle
	},
}

return TableUtil.deepFreeze(Config)
