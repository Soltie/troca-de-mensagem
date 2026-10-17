--!strict
local Shots = require("./CinematicShots")
local sequence: Shots.Sequence = {
	name = "ForestRescue",
	title = "ANTES DO AMANHECER",
	subtitle = "O último sinal atravessou a floresta",
	captions = {
		"A van chegou. O eco ficou para trás.",
		"No rádio, nenhuma pancada. Só o amanhecer.",
		"Vocês escaparam. FIM.",
	},
	shots = {
		{
			label = "O RESGATE",
			from = { x = -20, y = 8, z = 850 },
			to = { x = -14, y = 7, z = 859 },
			lookFrom = { x = 0, y = 6, z = 886 },
			lookTo = { x = 0, y = 6, z = 886 },
			duration = 4,
			handheld = 0.06,
			fov = 54,
			ease = "inOut",
			cut = "hard",
		},
		{
			label = "O ÚLTIMO SINAL",
			from = { x = 52, y = 25, z = 740 },
			to = { x = 60, y = 30, z = 733 },
			lookFrom = { x = 82, y = 54, z = 700 },
			lookTo = { x = 82, y = 54, z = 700 },
			duration = 4,
			handheld = 0.06,
			fov = 54,
			ease = "inOut",
			cut = "hard",
		},
		{
			label = "FIM",
			from = { x = 0, y = 8, z = 855 },
			to = { x = 0, y = 12, z = 836 },
			lookFrom = { x = 0, y = 6, z = 886 },
			lookTo = { x = 0, y = 6, z = 886 },
			duration = 4,
			handheld = 0.06,
			fov = 58,
			ease = "inOut",
			cut = "hard",
		},
	},
}
return table.freeze(sequence)
