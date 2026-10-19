--!strict
--[[
	Medo do jogador (0..1). Puro (testado no Lune); o FearController alimenta e lê.
	Não há barra na tela: o valor só dirige efeitos (batimento, respiração, vinheta, FOV,
	tremor, distorção, abafamento, sussurros e alucinações).

	- `target(inputs)`: quanto medo a situação do momento "pede" (proximidade do Vigia,
	  perseguição, escuridão, esconderijo com ele perto). Lugar seguro limita o alvo.
	- `step`: o valor base sobe rápido e desce devagar até o alvo (suavização assimétrica);
	  sustos (`spike`) somam por cima e decaem sozinhos.
	- Níveis 0..3 com histerese: sobe ao passar de `enter`, só desce abaixo de `exit`.
]]

local Config = require("../Config")

export type Inputs = {
	-- math.huge quando o Vigia está inativo.
	creatureDistance: number,
	-- Há linha de visão entre a câmera e o Vigia.
	creatureVisible: boolean,
	-- Há parede entre vocês (ouve, mas não vê): a proximidade assusta menos.
	behindWall: boolean,
	chasing: boolean,
	-- 0 = bem iluminado .. 1 = breu (lanterna apagada, sem luz por perto).
	darkness: number,
	hidden: boolean,
	-- Aceso e longe da ameaça.
	safe: boolean,
}

export type State = {
	value: number,
	base: number,
	spike: number,
	level: number,
}

local F = Config.Fear

local FearModel = {}

FearModel.MAX_LEVEL = #F.Levels

function FearModel.new(): State
	return { value = 0, base = 0, spike = 0, level = 0 }
end

function FearModel.target(inputs: Inputs): number
	local target = 0
	if inputs.creatureDistance < F.ProximityRange then
		local near = 1 - inputs.creatureDistance / F.ProximityRange
		target += near ^ 1.5 * F.ProximityWeight * (if inputs.behindWall then F.WallFactor else 1)
	end
	if inputs.creatureVisible then
		target += F.VisibleWeight
	end
	if inputs.chasing then
		target = math.max(target, F.ChaseFloor)
	end
	target += math.clamp(inputs.darkness, 0, 1) * F.DarkWeight
	if inputs.hidden and inputs.creatureDistance < F.HiddenNearRange then
		target += F.HiddenNearWeight
	end
	if inputs.safe then
		target = math.min(target, F.SafeCeiling)
	end
	return math.clamp(target, 0, 1)
end

-- Susto pontual (detecção, barulho alto, alucinação). Soma por cima do valor base.
function FearModel.spike(state: State, amount: number)
	state.spike = math.clamp(state.spike + amount, 0, F.SpikeMax)
	state.value = math.clamp(state.base + state.spike, 0, 1)
end

-- Nível 0..3 a partir do valor, respeitando a histerese a partir do nível atual.
function FearModel.levelFor(value: number, current: number): number
	local level = current
	while level < #F.Levels and value >= F.Levels[level + 1].enter do
		level += 1
	end
	while level > 0 and value < F.Levels[level].exit do
		level -= 1
	end
	return level
end

-- Avança `dt` segundos. Retorna true se o nível mudou.
function FearModel.step(state: State, inputs: Inputs, dt: number): boolean
	local target = FearModel.target(inputs)
	local rate = if target > state.base then F.RiseRate else F.DecayRate
	state.base += (target - state.base) * (1 - math.exp(-rate * math.max(dt, 0)))
	state.spike = math.max(0, state.spike - F.SpikeDecay * dt)
	state.value = math.clamp(state.base + state.spike, 0, 1)
	local level = FearModel.levelFor(state.value, state.level)
	local changed = level ~= state.level
	state.level = level
	return changed
end

-- Volta ao zero (nova rodada / checkpoint).
function FearModel.reset(state: State)
	state.value = 0
	state.base = 0
	state.spike = 0
	state.level = 0
end

return FearModel
