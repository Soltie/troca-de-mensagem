--!strict
--[[
	Nomes de tags (CollectionService) e atributos usados entre servidor e cliente.
	Centralizados aqui para nenhum dos lados digitar strings soltas.
]]

local Tags = {
	-- Peça "foco" de algo interagível (fusível, quadro, porta, portão, bilhete).
	Interactable = "Interactable",
	-- Luz controlada pela energia / efeitos (PointLight ou SpotLight dentro da peça).
	PowerLight = "PowerLight",

	Attr = {
		-- Interagíveis
		InteractId = "InteractId",
		InteractPrompt = "InteractPrompt",
		InteractDistance = "InteractDistance",
		InteractEnabled = "InteractEnabled",
		-- Luzes: "Lamp" | "Emergency" | "Flood" | "Beacon" | "Street" | "Exit"
		LightKind = "LightKind",
		-- true = o cliente faz a luz piscar em passos.
		Flicker = "Flicker",
		-- Jogador: lanterna ligada (o servidor grava a partir do remote SetFlashlight).
		Flashlight = "Flashlight",
		-- Criatura (na peça Root): modo atual do cérebro e se está ativa.
		CreatureMode = "Mode",
		CreatureActive = "Active",
		ThreatTargetUserId = "ThreatTargetUserId",
	},

	-- Nomes de instâncias criadas pelo servidor no Workspace.
	WorldFolder = "CursedHouse",
	CreatureModel = "Vigia",
	CreatureRoot = "Root",
}

return table.freeze(Tags)
