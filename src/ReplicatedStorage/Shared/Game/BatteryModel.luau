--!strict
--[[
	Bateria da lanterna (pura, testada no Lune). O servidor simula uma por jogador e publica a
	carga no atributo do Player; o cliente só mostra (LEDs na lanterna) e pede para ligar/desligar.

	- Ligada: gasta DrainPerSecond. Ao zerar, desliga sozinha.
	- Desligada: a pilha "descansa" e recupera devagar até RechargeCap. Assim a missão nunca trava
	  por falta de luz: no pior caso, espere no escuro uns segundos.
	- Pilhas encontradas no mapa somam PickupAmount (até 100%).
]]

local Config = require("../Config")

export type State = {
	charge: number,
	on: boolean,
}

local B = Config.Battery

local BatteryModel = {}

BatteryModel.LEDS = 4

function BatteryModel.new(charge: number?): State
	return { charge = math.clamp(charge or B.StartCharge, 0, 1), on = false }
end

function BatteryModel.canTurnOn(state: State): boolean
	return state.charge >= B.MinToTurnOn
end

-- Pede ligar/desligar. Retorna o estado final (pode recusar ligar sem carga).
function BatteryModel.setOn(state: State, want: boolean): boolean
	if want and not BatteryModel.canTurnOn(state) then
		state.on = false
		return false
	end
	state.on = want
	return state.on
end

-- Avança `dt` segundos. Retorna true se a lanterna apagou sozinha agora (carga zerou).
function BatteryModel.step(state: State, dt: number): boolean
	if dt <= 0 then
		return false
	end
	if state.on then
		state.charge = math.max(0, state.charge - B.DrainPerSecond * dt)
		if state.charge <= 0 then
			state.on = false
			return true
		end
	elseif state.charge < B.RechargeCap then
		state.charge = math.min(B.RechargeCap, state.charge + B.RechargePerSecond * dt)
	end
	return false
end

function BatteryModel.addPickup(state: State, amount: number?)
	state.charge = math.clamp(state.charge + (amount or B.PickupAmount), 0, 1)
end

-- Quantos LEDs acesos (0..4) para a carga.
function BatteryModel.leds(charge: number): number
	if charge <= 0 then
		return 0
	end
	return math.clamp(math.ceil(charge * BatteryModel.LEDS - 1e-6), 1, BatteryModel.LEDS)
end

function BatteryModel.isLow(charge: number): boolean
	return charge <= B.LowLevel
end

-- Fator de brilho da luz: cheio acima do nível baixo, cai até 35% perto do zero.
function BatteryModel.brightness(charge: number): number
	if charge >= B.LowLevel then
		return 1
	end
	return 0.35 + 0.65 * math.clamp(charge / B.LowLevel, 0, 1)
end

-- Segundos até a pilha descansada voltar a RechargeCap partindo de `charge` (desligada).
function BatteryModel.secondsToRecover(charge: number): number
	if charge >= B.RechargeCap then
		return 0
	end
	return (B.RechargeCap - charge) / B.RechargePerSecond
end

return BatteryModel
