--!strict
-- Silhuetas reconhecíveis para pistas/objetos. Detalhes não roubam o raycast do alvo.
local Build = require("./Build")
local Props = {}
local V3 = Vector3.new
local brass = Color3.fromRGB(190, 153, 78)
local paper = Color3.fromRGB(204, 190, 147)
local dark = Color3.fromRGB(46, 43, 46)
local function part(parent: Instance, name: string, p: Vector3, size: Vector3, color: Color3)
	return Build.block(parent, name, p, size, 0, color, { collide = false, query = false })
end
function Props.build(parent: Instance, p: Vector3, item: string?, kind: string)
	local center = p + V3(0, 1.8, 0)
	if item and string.find(item, "key", 1, true) then
		part(parent, "KeyShaft", center + V3(0, 0, 0.9), V3(0.25, 0.2, 2), brass)
		part(parent, "KeyTooth", center + V3(0.3, 0, 1.6), V3(0.7, 0.2, 0.3), brass)
	elseif kind == "repair" then
		part(parent, "FuseCabinet", p + V3(0, 1, -0.8), V3(7, 3, 0.5), dark)
		for i = 1, 3 do
			part(parent, "CeramicFuse", center + V3((i - 2) * 1.8, 0, 0), V3(0.5, 1.7, 0.5), paper)
		end
	elseif item == "clock" then
		Build.cylinder(
			parent,
			"ClockFace",
			center + V3(0, 1, -0.3),
			Vector3.zAxis,
			0.4,
			3,
			paper,
			{ collide = false, query = false }
		)
		part(parent, "ClockHand", center + V3(0, 0.2, 0), V3(0.12, 1.1, 0.12), dark)
		part(parent, "ClockHand", center + V3(0, 1, 0), V3(0.9, 0.12, 0.12), dark)
	elseif item == "photo" then
		part(parent, "PhotoFrame", center, V3(3, 2.6, 0.25), brass)
		part(parent, "PhotoPaper", center + V3(0, 0.2, 0.2), V3(2.6, 2.2, 0.12), paper)
		for i = -1, 1 do
			part(parent, "FamilySilhouette", center + V3(i * 0.7, 0.4, 0.36), V3(0.5, 1.2, 0.1), dark)
		end
	elseif item == "mask" then
		part(parent, "PorcelainMask", center, V3(2.5, 3, 0.6), paper)
		for _, side in { -1, 1 } do
			part(parent, "MaskEye", center + V3(side * 0.65, 1.7, 0.6), V3(0.5, 0.35, 0.12), dark)
		end
	elseif kind == "clue" then
		part(parent, "OpenBookLeft", center + V3(-0.9, 0, 0), V3(1.8, 0.2, 2.6), paper)
		part(parent, "OpenBookRight", center + V3(0.9, 0, 0), V3(1.8, 0.2, 2.6), paper)
	elseif item == "artifact" then
		local gem = part(parent, "HouseHeart", center + V3(0, 0.6, 0), V3(2, 2, 2), Color3.fromRGB(137, 63, 70))
		gem.CFrame *= CFrame.Angles(0, 0, math.rad(45))
	elseif item and string.find(item, "fuse", 1, true) then
		part(parent, "FuseBody", center, V3(2.4, 0.7, 0.7), paper)
		for _, side in { -1, 1 } do
			part(parent, "FuseCap", center + V3(side, 0, 0), V3(0.4, 0.7, 0.7), brass)
		end
	elseif item == "flashlight" then
		part(parent, "FlashlightBody", center, V3(2.8, 0.7, 0.8), dark)
		part(parent, "FlashlightLens", center + V3(1.2, 0, 0), V3(0.3, 1.1, 1.2), brass)
	end
end
return Props
