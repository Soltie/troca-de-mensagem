--!strict
local House = require("./HouseCatalog")
local TableUtil = require("../Util/TableUtil")
local Shots = require("./CinematicShots")
export type Chapter = House.Chapter
local Broadcast = require("./HouseBroadcast")
local function point(x: number, y: number, z: number): Shots.Vec
	return { x = x, y = y, z = z }
end
local function beat(label: string, a: Shots.Vec, b: Shots.Vec, look: Shots.Vec): Shots.Shot
	return {
		label = label,
		from = a,
		to = b,
		lookFrom = look,
		lookTo = look,
		duration = 4,
		fov = 54,
		ease = "inOut",
		handheld = 0.08,
		cut = "hard",
	}
end
local frames = {
	{
		beat("A PORTA SE FECHOU", point(0, 6, 9), point(0, 6, 3), point(0, 5, -28)),
		beat("A FITA", point(-29, 6, -9), point(-31, 5.5, -11), point(-35.5, 5.3, -15.7)),
	},
	{
		beat("CANAL 03 / O CHAMADO", point(-29, 6, -9), point(-31, 5.5, -11), point(-35.5, 5.3, -15.7)),
		beat("NINGUÉM RESPONDE", point(0, 6, -27), point(0, 6, -33), point(0, 6, -70)),
	},
	{
		beat("SÓTÃO / 03:12", point(0, 38, 7), point(0, 37, 0), point(0, 37, -35)),
		beat("AS LEMBRANÇAS", point(-20, 38, -25), point(-22, 37, -29), point(-34, 36, -39)),
	},
	{
		beat("SOB A CASA", point(0, -10, -8), point(0, -10, -17), point(0, -11, -46)),
		beat("O QUE FOI LEVADO", point(-20, -10, -26), point(-22, -10, -29), point(-31, -12, -39)),
	},
	{
		beat("O CORAÇÃO", point(-20, -10, -58), point(-22, -10, -61), point(-26, -13, -68)),
		beat("A ÚLTIMA SAÍDA", point(0, -10, -42), point(0, -10, -36), point(0, -11, 0)),
	},
}
local scenes: { Shots.Sequence } = {}
for index, chapter in House.Chapters do
	table.insert(scenes, {
		name = `StoryHouse{index}`,
		shots = frames[index],
		captions = Broadcast[index],
		title = string.format("CAPÍTULO %02d", index),
		subtitle = string.match(chapter.title, "·%s*(.+)") or chapter.subtitle,
	})
end
return TableUtil.deepFreeze({
	Title = "TUNG TUNG SAHUR: THE CURSED HOUSE",
	MapSeed = 90312,
	SceneSeconds = 8,
	Chapters = House.Chapters,
	Scenes = scenes,
	SceneLines = Broadcast,
	Ending = "O coração parou. A porta abriu.\nNa fita, a floresta já não está vazia.\nCONTINUA...",
})
