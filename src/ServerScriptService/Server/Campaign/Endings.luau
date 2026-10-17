--!strict
-- Resolução centralizada; apenas o final com fuga real está habilitado.
local Endings = {}
Endings.Available = table.freeze({ "house_fire", "forest_rescue" })
Endings.Pending = table.freeze({ "secret_escape", "tung_secret" })
function Endings.resolve(escaped: number, now: number, deadline: number, chapter: number?): string?
	if escaped > 0 and now <= deadline then
		return if chapter and chapter >= 6 then "forest_rescue" else "house_fire"
	end
	return nil
end
return Endings
