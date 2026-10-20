--!strict
--[[
	Captura de verdade no modo História ("virar móvel"). Puro, testado no Lune.

	- Cap. 1: sem captura de verdade (só a pancada que derruba).
	- Casa (caps. 2 a 5): a PRIMEIRA captura da partida é a cena inteira (o Tung arrasta pelo pé até a máquina da
	  oficina e joga no funil). As seguintes: puxa a vítima para dentro da parede de madeira (a máquina se ouve longe,
	  serragem cai do teto). Nos dois casos o jogador vira um móvel (cadeira, banquinho ou abajur) num cômodo sorteado.
	- Floresta (caps. 6 a 8): sem máquina; o toque do bastão vira toco ou boneco de graveto ali mesmo.
	- Resgate: "três batidas" (segurar E ~3 s perto do móvel).
	- Com 2+ jogadores o móvel endurece em 60 s (vira espectador até o próximo capítulo). Solo: a captura é a derrota.

	Tempos do arraste e do arremesso combinados com o Animador (clipes "drag" e "throw"). O servidor marca no Root do
	Tung: DragTarget + DragSerial, DragCut (corte para a boca da máquina), ThrowTarget + ThrowSerial, WallSerial.
]]

local CaptureRules = {}

export type Kind = "none" | "machine" | "wall" | "stump"

-- Espera o susto (jumpscare, no máximo 2,2 s) antes de começar a arrastar.
CaptureRules.PreDrag = 2.3
-- Arraste: anda de costas a DragSpeed studs/s por no máximo DragMax s (ciclo do clipe: DragCycle s).
CaptureRules.DragSpeed = 6
CaptureRules.DragCycle = 1.4
CaptureRules.DragMax = 3.5
-- Corte para a boca da máquina (fade).
CaptureRules.Cut = 0.4
-- Arremesso: o jogador some no funil no impacto; o clipe acaba em ThrowEnd.
CaptureRules.ThrowImpact = 0.55
CaptureRules.ThrowEnd = 1.2
-- Parede: arrasta um pouco e some na madeira.
CaptureRules.WallDrag = 1.4
-- Floresta: vira toco no lugar depois do susto.
CaptureRules.StumpDelay = 0.6
-- Resgate e endurecimento.
CaptureRules.RescueSeconds = 3
CaptureRules.HardenSeconds = 60

CaptureRules.HouseFurniture = { "chair", "stool", "lamp" }
CaptureRules.ForestFurniture = { "stump", "twig" }

function CaptureRules.kind(story: boolean, stage: number, firstOfRun: boolean): Kind
	if not story or stage <= 1 then
		return "none"
	end
	if stage >= 6 then
		return "stump"
	end
	return if firstOfRun then "machine" else "wall"
end

-- Segundos do começo da captura até o móvel aparecer (a derrota solo espera isto).
function CaptureRules.duration(kind: Kind, dragSeconds: number?): number
	if kind == "machine" then
		local drag = math.clamp(dragSeconds or CaptureRules.DragMax, 0, CaptureRules.DragMax)
		return CaptureRules.PreDrag + drag + CaptureRules.Cut + CaptureRules.ThrowEnd
	elseif kind == "wall" then
		return CaptureRules.PreDrag + CaptureRules.WallDrag + CaptureRules.Cut
	elseif kind == "stump" then
		return CaptureRules.PreDrag + CaptureRules.StumpDelay
	end
	return 0
end

-- Quanto arrastar antes do corte: até a parede (livre à frente) ou até a máquina, no máximo DragMax.
function CaptureRules.dragSeconds(freeDistance: number, machineDistance: number): number
	local distance = math.max(0, math.min(freeDistance, machineDistance))
	return math.min(CaptureRules.DragMax, distance / CaptureRules.DragSpeed)
end

-- Sorteio do móvel (`roll` em [0, 1)).
function CaptureRules.furniture(kind: Kind, roll: number): string
	local list = if kind == "stump" then CaptureRules.ForestFurniture else CaptureRules.HouseFurniture
	local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[index]
end

-- Endurece só com 2+ jogadores (no solo a captura já é a derrota).
function CaptureRules.hardens(players: number, capturedFor: number): boolean
	return players >= 2 and capturedFor >= CaptureRules.HardenSeconds
end

return table.freeze(CaptureRules)
