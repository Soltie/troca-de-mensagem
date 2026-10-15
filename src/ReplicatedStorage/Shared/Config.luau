--!strict
--[[
	Constantes do projeto. Só valores, nada de lógica nem APIs do Roblox.
	Tudo é congelado: tentar alterar em runtime gera erro.
]]

local TableUtil = require("./Util/TableUtil")
local Types = require("./Types")

local Config = {
	-- Nível mínimo de log exibido.
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
		SchemaVersion = 1,
		AutosaveInterval = 120,
		RetryAttempts = 3,
		RetryBaseDelay = 1,
		-- Só afeta o Studio. "auto": usa DataStore real se houver acesso, senão mock.
		-- "mock": sempre mock. "real": exige acesso (erro se não houver).
		StudioMode = "auto" :: "auto" | "mock" | "real",
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
		WalkSpeed = 10,
		SprintSpeed = 16,
		JumpHeight = 2.4,
		FieldOfView = 72,
		-- Fôlego em segundos de corrida; recarga por segundo parado/andando.
		StaminaMax = 5,
		StaminaRegen = 0.7,
		StaminaMinToSprint = 1,
		-- Acima desta velocidade (studs/s) o servidor considera que o jogador está fazendo barulho.
		NoiseSpeed = 13,
		NoiseRadius = 28,
	},

	Creature = {
		Height = 7.5,
		-- Agente de pathfinding (raio/altura). O corredor e as portas foram medidos para isto.
		AgentRadius = 1.3,
		AgentHeight = 7.6,
		PatrolSpeed = 6,
		PatrolSpeedPerFuse = 0.7,
		InvestigateSpeed = 9,
		ChaseSpeed = 12.5,
		ChaseSpeedPerFuse = 0.5,
		HuntSpeed = 13.5,
		-- Visão: alcance no escuro / com a lanterna do jogador ligada; campo de visão (graus).
		SightRange = 30,
		SightRangeFlashlight = 55,
		SightFov = 120,
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

	Effects = {
		-- Valores iniciais das opções de conforto (V e B alternam em jogo).
		RetroOverlayDefault = true,
		CameraMotionDefault = true,
		ScanlineSpacing = 3,
		ScanlineTransparency = 0.84,
		GrainDots = 70,
		HeadBobAmount = 0.12,
	},
}

return TableUtil.deepFreeze(Config)
