--!strict
--[[
	Recompensas do modo história (O Último Turno). Puro: o RewardService aplica no fim de cada capítulo.

	Por capítulo:
	  first     1ª vitória da conta (grande; capítulos 2 e 3 trazem cosmético exclusivo);
	  again     repetições (menor, mantém o modo valendo a pena);
	  flawless  1ª vitória sem ninguém da equipe ser pego (Créditos + consumível).
	Os 3 capítulos vencidos dão o título "O Último Turno". O passe Arquivo do Elias dobra Fichas, XP e
	Créditos dos capítulos (itens e consumíveis não dobram).
]]

local Economy = require("./Economy")
local StoreCatalog = require("./StoreCatalog")
local Types = require("../Types")

type Data = Types.PlayerData
type Reward = StoreCatalog.Reward

export type ChapterReward = { first: Reward, again: Reward, flawless: Reward }
export type Outcome = { first: boolean, flawless: boolean, completed: boolean }

local StoryRewards = {}

StoryRewards.Chapters = table.freeze({
	{
		first = { fichas = 400, creditos = 20, xp = 300 },
		again = { fichas = 120, xp = 120 },
		flawless = { creditos = 30, consumables = { pilha_extra = 2 } },
	},
	{
		first = { fichas = 550, creditos = 30, xp = 400, item = "farda_ronda" },
		again = { fichas = 150, xp = 150 },
		flawless = { creditos = 40, consumables = { segunda_chance = 1 } },
	},
	{
		first = { fichas = 800, creditos = 50, xp = 600, item = "lanterna_elias" },
		again = { fichas = 200, xp = 200 },
		flawless = { creditos = 60, consumables = { continuar = 1 } },
	},
	{ first = { fichas = 450, xp = 350 }, again = { fichas = 100, xp = 100 }, flawless = { creditos = 20 } },
	{ first = { fichas = 600, xp = 450 }, again = { fichas = 150, xp = 150 }, flawless = { creditos = 30 } },
	{ first = { fichas = 350, xp = 250 }, again = { fichas = 100, xp = 100 }, flawless = { creditos = 20 } },
	{ first = { fichas = 450, xp = 350 }, again = { fichas = 100, xp = 100 }, flawless = { creditos = 20 } },
	{ first = { fichas = 600, xp = 450 }, again = { fichas = 150, xp = 150 }, flawless = { creditos = 30 } },
} :: { ChapterReward })

StoryRewards.CompletionItem = "titulo_ultimo_turno"
StoryRewards.PassMultiplier = 2

local function scaled(reward: Reward, multiplier: number): Reward
	local copy = table.clone(reward)
	if copy.fichas then
		copy.fichas = math.floor(copy.fichas * multiplier + 0.5)
	end
	if copy.xp then
		copy.xp = math.floor(copy.xp * multiplier + 0.5)
	end
	if copy.creditos then
		copy.creditos = math.floor(copy.creditos * multiplier + 0.5)
	end
	return copy
end

function StoryRewards.cleared(data: Data, chapter: number): boolean
	return data.house.cleared[tostring(chapter)] ~= nil
end

-- Quantos capítulos a conta já venceu (para o menu).
function StoryRewards.clearedCount(data: Data): number
	local count = 0
	for chapter = 1, #StoryRewards.Chapters do
		if StoryRewards.cleared(data, chapter) then
			count += 1
		end
	end
	return count
end

-- O que a próxima vitória deste capítulo vale (para o menu): "first" ou "again".
function StoryRewards.preview(data: Data, chapter: number, hasPass: boolean?): (string, Reward?)
	local def = StoryRewards.Chapters[chapter]
	if not def then
		return "none", nil
	end
	local multiplier = if hasPass then StoryRewards.PassMultiplier else 1
	if StoryRewards.cleared(data, chapter) then
		return "again", scaled(def.again, multiplier)
	end
	return "first", scaled(def.first, multiplier)
end

--[[
	Capítulo vencido. `flawless` = ninguém da equipe foi pego no capítulo.
	Retorna (concedido, desfecho) ou (nil, nil) para capítulo inexistente.
]]
function StoryRewards.award(
	data: Data,
	chapter: number,
	flawless: boolean,
	hasPass: boolean?,
	now: number
): (Economy.Granted?, Outcome?)
	local def = StoryRewards.Chapters[chapter]
	if not def then
		return nil, nil
	end
	local key = tostring(chapter)
	local multiplier = if hasPass then StoryRewards.PassMultiplier else 1
	local first = data.house.cleared[key] == nil
	local granted = Economy.applyReward(data, scaled(if first then def.first else def.again, multiplier))
	if first then
		data.house.cleared[key] = now
	end
	local firstFlawless = flawless and data.house.flawless[key] == nil
	if firstFlawless then
		data.house.flawless[key] = now
		Economy.applyReward(data, scaled(def.flawless, multiplier), granted)
	end
	local completed = false
	if StoryRewards.clearedCount(data) >= #StoryRewards.Chapters and not data.owned[StoryRewards.CompletionItem] then
		Economy.applyReward(data, { item = StoryRewards.CompletionItem }, granted)
		completed = true
	end
	return granted, { first = first, flawless = firstFlawless, completed = completed }
end

return table.freeze(StoryRewards)
