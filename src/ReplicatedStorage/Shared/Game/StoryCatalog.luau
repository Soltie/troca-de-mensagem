--!strict
local House = require("./HouseCatalog")
local TableUtil = require("../Util/TableUtil")
local Shots = require("./CinematicShots")
export type Chapter = House.Chapter
local scenes: { Shots.Sequence } = {}
local lines: { { string } } = {}
for index, chapter in House.Chapters do
	local y = if index == 3 then 36 elseif index >= 4 then -12 else 5
	table.insert(scenes, {
		name = `StoryHouse{index}`,
		shots = {
			{
				label = chapter.title,
				from = { x = 0, y = y, z = 8 },
				to = { x = 0, y = y, z = 3 },
				lookFrom = { x = 0, y = y, z = -30 },
				lookTo = { x = 0, y = y, z = -30 },
				duration = 4,
				fov = 65,
				ease = "linear",
				handheld = 0,
				cut = "static",
			},
		},
	})
	table.insert(lines, {
		chapter.subtitle,
		"Concluam o objetivo marcado. Os itens essenciais pertencem à equipe.",
		"Escutem a casa. Respirem antes que o oxigênio acabe.",
	})
end
return TableUtil.deepFreeze({
	Title = "TUNG TUNG SAHUR: THE CURSED HOUSE",
	MapSeed = 90312,
	SceneSeconds = 4,
	Chapters = House.Chapters,
	Scenes = scenes,
	SceneLines = lines,
	Ending = "VOCÊS QUEIMARAM MINHA CASA...\nMAS NÃO ACABARAM COMIGO.\nCONTINUA...",
})
