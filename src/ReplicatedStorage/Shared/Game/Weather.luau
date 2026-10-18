--!strict
-- Chuva e relâmpagos: números puros (sem engine), testados no Lune. O RainController aplica no cliente.
local Weather = {}

Weather.RainRate = 2700 -- gotas/s em qualidade Alta, ao ar livre (somando as células)
Weather.SplashRate = 400 -- respingos/s no chão em volta da câmera
Weather.MinBudget = 0.3 -- qualidade Baixa ainda chove (menos), só sem os efeitos opcionais
Weather.IndoorVolume = 0.35 -- chuva ouvida de dentro de casa, abafada
Weather.FlashPeak = 0.22 -- brilho extra máximo do relâmpago (ColorCorrection.Brightness)

-- Rajadas lentas: a intensidade varia sem padrão perceptível (0,75 a 1,15).
function Weather.gust(now: number): number
	return 0.95 + 0.2 * math.sin(now * 0.21) * math.sin(now * 0.073 + 1.3)
end

-- `outdoor` 0..1 (sob telhado = 0); `particles` = orçamento da qualidade visual (0..1).
function Weather.rate(base: number, particles: number, outdoor: number, gust: number): number
	local budget = math.max(Weather.MinBudget, math.clamp(particles, 0, 1))
	return math.floor(base * budget * math.clamp(outdoor, 0, 1) * math.clamp(gust, 0.6, 1.2) + 0.5)
end

function Weather.volume(outdoor: number): number
	local o = math.clamp(outdoor, 0, 1)
	return Weather.IndoorVolume + (1 - Weather.IndoorVolume) * o
end

-- Próximo relâmpago entre 35 e 80 s; `roll` em 0..1.
function Weather.strikeInterval(roll: number): number
	return 35 + math.clamp(roll, 0, 1) * 45
end

-- O trovão chega depois do clarão (tempestade a alguns quilômetros).
function Weather.thunderDelay(roll: number): number
	return 1.2 + math.clamp(roll, 0, 1) * 2.8
end

-- Clarão duplo e curto, depois cai a zero; `t` = segundos desde o relâmpago.
function Weather.flash(t: number): number
	if t < 0 or t >= 0.6 then
		return 0
	elseif t < 0.06 then
		return 1
	elseif t < 0.12 then
		return 0.15
	elseif t < 0.18 then
		return 0.75
	end
	return 0.75 * (1 - (t - 0.18) / 0.42)
end

return table.freeze(Weather)
