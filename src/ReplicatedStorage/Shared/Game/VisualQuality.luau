--!strict
-- Política estável por sessão; não mede FPS nem força os gráficos do cliente Roblox.
local Quality = {}
export type Budget = {
	name: string,
	shadows: number,
	particles: number,
	detailDistance: number,
	bloom: number,
	depth: boolean,
	grain: number,
}
local budgets: { Budget } = {
	{ name = "Baixa", shadows = 0, particles = 0, detailDistance = 48, bloom = 0, depth = false, grain = 0 },
	{ name = "Média", shadows = 1, particles = 0.45, detailDistance = 90, bloom = 0.07, depth = false, grain = 0.35 },
	{ name = "Alta", shadows = 3, particles = 1, detailDistance = 145, bloom = 0.1, depth = true, grain = 1 },
}
function Quality.resolve(preference: number, touch: boolean, savedQuality: number): number
	if preference == 0.25 then
		return 1
	end
	if preference == 0.5 then
		return 2
	end
	if preference == 1 then
		return 3
	end
	-- Automático do Roblox não expõe um nível efetivo confiável: padrão conservador médio.
	if savedQuality > 0 then
		return if savedQuality <= 3 then 1 elseif savedQuality <= 7 then 2 else 3
	end
	return if touch then 1 else 2
end
function Quality.budget(level: number, shaders: boolean): Budget
	local source = budgets[math.clamp(math.floor(level), 1, 3)]
	return {
		name = source.name,
		shadows = if shaders then source.shadows else 0,
		particles = if shaders then source.particles else 0,
		detailDistance = source.detailDistance,
		bloom = if shaders then source.bloom else 0,
		depth = shaders and source.depth,
		grain = if shaders then source.grain else 0,
	}
end
return table.freeze(Quality)
