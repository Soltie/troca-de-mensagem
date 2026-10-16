--!strict
--[[
	PresenceService: o "olhar" de cada jogador para os colegas verem (cabeça e lanterna apontando
	para onde ele olha). O cliente manda só o pitch da câmera (graus), quantizado e espaçado
	(CharacterPose.SEND_INTERVAL); aqui o valor é revalidado e vira o atributo "LookPitch" do Player.

	Puramente visual: nenhuma regra de jogo (visão do Vigia, interação, dano) lê este atributo.
	O yaw não precisa de rede: a rotação do HumanoidRootPart já replica.
]]

local Players = game:GetService("Players")

local CharacterPose = require("@game/ReplicatedStorage/Shared/Game/CharacterPose")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local ServerNet = require("../Net/ServerNet")

local ATTRIBUTE = "LookPitch"

local PresenceService = {
	Name = "PresenceService",
	ATTRIBUTE = ATTRIBUTE,
}

function PresenceService.Start()
	ServerNet.onEvent("SetLook", {
		args = { Guard.number({ min = -90, max = 90 }) },
		-- Cliente envia no máximo 8/s e só quando muda; folga para rajadas curtas.
		rateLimit = { capacity = 12, refillPerSecond = 9 },
	}, function(player: Player, pitch: number)
		player:SetAttribute(ATTRIBUTE, CharacterPose.quantizePitch(pitch))
	end)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(ATTRIBUTE, 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(ATTRIBUTE, 0)
	end
end

return PresenceService
