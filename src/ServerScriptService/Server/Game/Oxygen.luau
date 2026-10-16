--!strict
-- Oxigênio independente de fôlego/bateria; relógio e consumo simulados só pelo servidor.
export type State = { value: number, holding: boolean, readyAt: number, held: number, dead: boolean }
local Oxygen = {}
function Oxygen.new(): State
	return { value = 100, holding = false, readyAt = 0, held = 0, dead = false }
end
function Oxygen.request(state: State, hold: boolean, now: number): boolean
	if not hold then
		if state.holding then
			state.readyAt = now + 2
		end
		state.holding, state.held = false, 0
		return true
	end
	if state.dead or state.value < 35 or now < state.readyAt then
		return false
	end
	state.holding = true
	return true
end
function Oxygen.step(state: State, dt: number, now: number): boolean
	if state.dead then
		return false
	end
	if state.holding then
		state.held += dt
		state.value = math.max(0, state.value - 12.5 * dt)
		if state.value <= 0 or state.held >= 8 then
			state.dead, state.holding, state.value = true, false, 0
			return true
		end
	elseif now >= state.readyAt then
		state.value = math.min(100, state.value + 20 * dt)
	end
	return false
end
return Oxygen
