--!strict
--[[
	Sopro que varre o corredor (ideia J, cadência do Rush do DOORS). Puro, testado no Lune.
	- Nos capítulos da casa (menos o primeiro e a fuga do incêndio), de tempos em tempos um sopro gelado corre por um
	  corredor onde há alguém. As luzes dali piscam e o vento cresce por `WarnTime` segundos antes.
	- A frente do sopro anda de uma parede à outra a `Speed` studs/s. Quem está na faixa (`HalfWidth` para cada lado,
	  no mesmo andar) quando a frente passa e não está num armário leva pancada (mesmo fluxo da captura).
	- Escapa quem entra num armário ou sai da faixa (porta de um cômodo do lado).
]]

local GustRules = {}

GustRules.RollEvery = 10
GustRules.WarnTime = 3
GustRules.Speed = 38
GustRules.HalfWidth = 4.5
GustRules.FloorGap = 6
-- Corredor curto não vale (não dá tempo de ver o sopro chegando).
GustRules.MinLength = 24
-- Segundos sem sopro no começo do capítulo e entre dois sopros (no servidor todo).
GustRules.StartGrace = 60
GustRules.Cooldown = 120
-- Chance por rolagem: ~1 sopro a cada 3-4 min quando liberado.
GustRules.Chance = 0.05

-- Capítulos com sopro: só os da casa, sem o tutorial (1) e sem a fuga do incêndio (5).
function GustRules.allowed(stage: number): boolean
	return stage >= 2 and stage <= 4
end

function GustRules.canRoll(sinceStageStart: number, sinceLastGust: number): boolean
	return sinceStageStart >= GustRules.StartGrace and sinceLastGust >= GustRules.Cooldown
end

-- Distância percorrida pela frente `elapsed` segundos depois de começar a andar (negativa durante o aviso).
function GustRules.front(elapsed: number): number
	return (elapsed - GustRules.WarnTime) * GustRules.Speed
end

-- Quanto tempo o sopro vive (aviso + travessia + um respiro).
function GustRules.duration(length: number): number
	return GustRules.WarnTime + length / GustRules.Speed + 1
end

--[[
	Posição relativa ao trilho: `along` é a distância desde o início no eixo do sopro, `side` a distância lateral e
	`rise` a diferença de altura. Retorna se o jogador está na faixa varrida.
]]
function GustRules.inLane(along: number, side: number, rise: number, length: number): boolean
	return along >= -1
		and along <= length + 1
		and math.abs(side) <= GustRules.HalfWidth
		and math.abs(rise) <= GustRules.FloorGap
end

-- A frente passou pelo jogador entre os dois instantes?
function GustRules.crossed(along: number, previousFront: number, front: number): boolean
	return previousFront < along and front >= along
end

return table.freeze(GustRules)
