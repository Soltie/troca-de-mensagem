--!strict
-- Silhueta autoral do epílogo: crocodilo de mandíbulas longas e placas de armadura.
-- Só cenário local; não cria outro inimigo nem interfere na IA desta campanha.
local Rig = {}
function Rig.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "CrocodiloArmadilho"
	local function part(name: string, p: Vector3, size: Vector3, color: Color3): BasePart
		local piece = Instance.new("Part")
		piece.Name, piece.Size, piece.CFrame = name, size, CFrame.new(p)
		piece.Color, piece.Material = color, Enum.Material.Slate
		piece.Anchored, piece.CanCollide, piece.CanQuery, piece.CanTouch = true, false, false, false
		piece.TopSurface, piece.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		piece.Parent = model
		return piece
	end
	local skin = Color3.fromRGB(57, 77, 48)
	local armor = Color3.fromRGB(69, 61, 48)
	local root = part("Pivot", Vector3.zero, Vector3.one, skin)
	root.Transparency = 1
	model.PrimaryPart = root
	part("Body", Vector3.new(0, 2.9, 0), Vector3.new(5.4, 3.2, 7), skin)
	part("Neck", Vector3.new(0, 3, -3.5), Vector3.new(3.7, 2.7, 3), skin)
	part("Head", Vector3.new(0, 4, -5), Vector3.new(4.1, 2.7, 4), skin)
	part("UpperJaw", Vector3.new(0, 3.7, -8), Vector3.new(3.5, 1, 4.6), skin)
	local jaw = part("LowerJaw", Vector3.new(0, 2.4, -7.7), Vector3.new(3.2, 0.6, 4.5), skin)
	jaw.CFrame *= CFrame.Angles(math.rad(8), 0, 0)
	for _, side in { -1, 1 } do
		part("EyeSocket", Vector3.new(side * 1.8, 5.3, -5.8), Vector3.new(0.65, 0.65, 1.1), armor)
		part("Eye", Vector3.new(side * 1.95, 5.35, -6.2), Vector3.new(0.3, 0.28, 0.5), Color3.fromRGB(190, 132, 48))
		for _, z in { -2.5, 2.5 } do
			local leg = part("Leg", Vector3.new(side * 2.8, 1.5, z), Vector3.new(1.2, 2.8, 1.8), skin)
			leg.CFrame *= CFrame.Angles(0, 0, math.rad(side * 17))
			part("Claw", Vector3.new(side * 3.2, 0.35, z - 0.8), Vector3.new(1.6, 0.5, 2.3), armor)
		end
		for tooth = 1, 5 do
			part(
				"Tooth",
				Vector3.new(side * 1.4, 3, -6 - tooth * 0.7),
				Vector3.new(0.25, 0.9, 0.25),
				Color3.fromRGB(172, 162, 125)
			)
		end
	end
	for row = 1, 5 do
		local plate = part("ArmorPlate", Vector3.new(0, 4.6, 3.8 - row * 1.3), Vector3.new(5.8, 1.1, 1.1), armor)
		plate.CFrame *= CFrame.Angles(math.rad(-14), 0, 0)
	end
	for segment = 1, 5 do
		local tail = part(
			"Tail",
			Vector3.new(0.2 * segment, 2.2 - segment * 0.25, 3 + segment * 1.5),
			Vector3.new(3.1 - segment * 0.4, 1.8 - segment * 0.2, 2.2),
			skin
		)
		tail.CFrame *= CFrame.Angles(0, math.rad(segment * 6), 0)
	end
	model.Parent = parent
	return model
end
return Rig
