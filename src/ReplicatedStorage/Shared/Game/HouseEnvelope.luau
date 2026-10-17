--!strict
-- Solo permanente recortado pela fundação em L; nunca atravessa os cômodos do porão.
local Envelope = {}
export type Rect = { x0: number, x1: number, z0: number, z1: number }
Envelope.Ground = {
	{ x0 = -108, x1 = -44, z0 = -118, z1 = 132 },
	{ x0 = 45, x1 = 108, z0 = -118, z1 = 132 },
	{ x0 = -44, x1 = 45, z0 = -118, z1 = -84.5 },
	{ x0 = -44, x1 = 45, z0 = 64, z1 = 132 },
	{ x0 = -44, x1 = -24, z0 = 12, z1 = 64 },
	{ x0 = 44, x1 = 45, z0 = -84.5, z1 = 12 },
} :: { Rect }
function Envelope.isGarden(x: number, z: number): boolean
	for _, r in Envelope.Ground do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
			return true
		end
	end
	return false
end
return table.freeze(Envelope)
