--!strict
local Preferences = {}
Preferences.Keys = {
	"bob",
	"tilt",
	"shake",
	"fov",
	"flashes",
	"retro",
	"vhs",
	"haptics",
	"master",
	"music",
	"effects",
	"breathing",
	"ambient",
}
function Preferences.sanitize(raw: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, key in Preferences.Keys do
		local value = raw[key]
		if type(value) == "number" and value == value and value >= 0 and value <= 1 then
			out[key] = value
		end
	end
	return out
end
function Preferences.category(clip: string): string
	if string.sub(clip, 1, 5) == "Music" then
		return "music"
	end
	if string.sub(clip, 1, 6) == "Breath" or clip == "Gasp" then
		return "breathing"
	end
	if string.sub(clip, 1, 3) == "Amb" or clip == "WindInterior" or clip == "Machinery" then
		return "ambient"
	end
	return "effects"
end
return table.freeze(Preferences)
