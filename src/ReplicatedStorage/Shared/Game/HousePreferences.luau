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
	"shaders",
	"quality",
}
-- Mantém o transporte numérico existente. Qualidade: 0 auto, 0.25 baixa, 0.5 média, 1 alta.
function Preferences.valid(key: string, value: any): boolean
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
		return false
	end
	if key == "quality" then
		return value == 0 or value == 0.25 or value == 0.5 or value == 1
	elseif key == "shaders" then
		return value == 0 or value == 1
	end
	return table.find(Preferences.Keys, key) ~= nil
end
function Preferences.sanitize(raw: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, key in Preferences.Keys do
		local value = raw[key]
		if Preferences.valid(key, value) then
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
