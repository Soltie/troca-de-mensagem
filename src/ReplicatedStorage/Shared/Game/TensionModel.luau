--!strict
--[[
	Diretor de tensão (ideia D, Alien: Isolation). Puro, testado no Lune.
	Mede a tensão da partida (0..1) e alterna três fases:
	- Build: a tensão sobe com o Tung Tung por perto, perseguindo, pancadas e eventos (sopro, revista). Se fica
	  calmo demais por `QuietMax` s, pede uma provocação (ele vai investigar perto de alguém).
	- Peak: tensão no alto. Dura até `PeakMax` s ou até a tensão cair abaixo de `PeakEnd`.
	- Relax: folga de `RelaxTime` s. O Tung se afasta, sopros e sustos esperam, a tensão cai rápido.
	- Qualquer pancada leva direto à folga.
]]

local TensionModel = {}

TensionModel.PeakAt = 0.85
TensionModel.PeakMax = 30
TensionModel.PeakEnd = 0.5
TensionModel.RelaxTime = 20
TensionModel.QuietBelow = 0.2
TensionModel.QuietMax = 70
TensionModel.ProvokeCooldown = 60
-- Quanto cada coisa soma: por segundo (perto, perseguindo) e de uma vez (pancada, evento).
TensionModel.NearRate = 0.12
TensionModel.ChaseRate = 0.25
TensionModel.HitBump = 0.4
TensionModel.EventBump = 0.25
TensionModel.Decay = 0.04
TensionModel.RelaxDecay = 0.08

export type Phase = "Build" | "Peak" | "Relax"
export type State = {
	tension: number,
	phase: Phase,
	phaseSince: number,
	quietSince: number,
	lastProvokeAt: number,
}
export type Input = {
	now: number,
	-- Distância do Tung Tung ao jogador mais perto (math.huge se ele está parado/inativo).
	distance: number,
	chasing: boolean,
	hits: number,
	events: number,
}
export type Output = {
	-- Mudou de fase neste passo (nil se não mudou).
	entered: Phase?,
	provoke: boolean,
}

function TensionModel.new(now: number): State
	return { tension = 0, phase = "Build", phaseSince = now, quietSince = now, lastProvokeAt = -math.huge }
end

-- 0 longe (40+ studs) a 1 colado (8 studs).
function TensionModel.proximity(distance: number): number
	return math.clamp(1 - (distance - 8) / 32, 0, 1)
end

local function enter(state: State, phase: Phase, now: number): Phase
	state.phase, state.phaseSince = phase, now
	if phase == "Build" then
		state.quietSince = now
	end
	return phase
end

function TensionModel.step(state: State, dt: number, input: Input): Output
	local now = input.now
	local near = TensionModel.proximity(input.distance)
	local rise = near * TensionModel.NearRate * dt
		+ (if input.chasing then TensionModel.ChaseRate * dt else 0)
		+ input.hits * TensionModel.HitBump
		+ input.events * TensionModel.EventBump
	local fall = if state.phase == "Relax"
		then TensionModel.RelaxDecay * dt
		elseif near <= 0 and not input.chasing then TensionModel.Decay * dt
		else 0
	state.tension = math.clamp(state.tension + rise - fall, 0, 1)

	local entered: Phase? = nil
	local provoke = false
	local hit = input.hits > 0 and state.phase ~= "Relax"
	if hit then
		-- Alguém levou pancada: folga, venha de onde vier.
		entered = enter(state, "Relax", now)
	elseif state.phase == "Build" then
		if state.tension >= TensionModel.PeakAt then
			entered = enter(state, "Peak", now)
		elseif state.tension >= TensionModel.QuietBelow then
			state.quietSince = now
		elseif
			now - state.quietSince >= TensionModel.QuietMax
			and now - state.lastProvokeAt >= TensionModel.ProvokeCooldown
		then
			provoke = true
			state.lastProvokeAt = now
			state.quietSince = now
		end
	elseif state.phase == "Peak" then
		-- Dura até PeakMax, ou até ele perder o grupo (a tensão cai abaixo de PeakEnd).
		if now - state.phaseSince >= TensionModel.PeakMax or state.tension < TensionModel.PeakEnd then
			entered = enter(state, "Relax", now)
		end
	elseif now - state.phaseSince >= TensionModel.RelaxTime then
		entered = enter(state, "Build", now)
	end
	return { entered = entered, provoke = provoke }
end

-- Eventos opcionais (sopro, sustos) só quando não está no pico nem na folga.
function TensionModel.allowsEvents(state: State): boolean
	return state.phase == "Build"
end

return table.freeze(TensionModel)
