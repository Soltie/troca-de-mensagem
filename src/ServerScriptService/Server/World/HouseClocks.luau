--!strict
--[[
	Enigma do relógio (cap. 3), refeito pelo crítico: a casa lembra a hora em que o Tum Tum entrou na máquina, mas
	só no escuro. O videocassete da sala pisca "03:__" e o rádio-relógio do quarto infantil pisca "__:12"; cada um
	guarda metade da hora. Os mostradores nascem apagados e o cliente (DarkClueController) acende quando a lanterna
	de quem olha está apagada. Só visual: sem colisão e fora dos raycasts.
]]

local CollectionService = game:GetService("CollectionService")

local Build = require("./Build")

local HouseClocks = {}

HouseClocks.TAG = "DarkClue"

local options = { material = Enum.Material.Wood, collide = false, query = false }

-- Mostrador digital vermelho: apagado até o cliente ver a lanterna desligada.
local function digital(parent: Instance, name: string, center: Vector3, size: Vector2, text: string)
	local display = Build.sign(parent, name, center, Vector3.zAxis, size, text, {
		textColor = Color3.fromRGB(255, 70, 52),
		background = Color3.fromRGB(14, 10, 10),
		font = Enum.Font.Code,
		lit = true,
		pixelsPerStud = 60,
	})
	display.CanQuery = false
	local gui = display:FindFirstChildOfClass("SurfaceGui")
	if gui then
		gui.Enabled = false
	end
	CollectionService:AddTag(display, HouseClocks.TAG)
	return display
end

function HouseClocks.build(parent: Instance)
	local folder = Build.folder(parent, "StoppedClocks")
	-- Videocassete embutido no móvel da TV (frente do aparador em z = −15,6): a hora.
	Build.part(folder, "Vcr", Vector3.new(4.4, 0.9, 0.3), CFrame.new(-35, 2.5, -15.5), Color3.fromRGB(30, 28, 27), {
		collide = false,
		query = false,
	})
	digital(folder, "VcrClock", Vector3.new(-34, 2.5, -15.32), Vector2.new(1.6, 0.6), "03:__")
	-- Rádio-relógio em cima da mesinha do quarto infantil (topo em y = 18,5): os minutos.
	Build.part(
		folder,
		"RadioClock",
		Vector3.new(2, 1.1, 1),
		CFrame.new(26, 19.05, -15),
		Color3.fromRGB(70, 44, 30),
		options
	)
	digital(folder, "RadioClockDisplay", Vector3.new(26, 19.1, -14.42), Vector2.new(1.6, 0.7), "__:12")
end

return HouseClocks
