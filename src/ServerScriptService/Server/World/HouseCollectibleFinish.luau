--!strict
-- Cunhagem decorativa: o corpo original continua responsável pela coleta, valor e animação.
local Finish = {}

function Finish.coin(body: BasePart)
	if body:GetAttribute("Gem") == true or body:FindFirstChild("CoinFinish") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CoinFinish"
	local brass = Color3.fromRGB(166, 123, 54)
	body.Color, body.Material = brass, Enum.Material.Metal
	-- Mantém o corpo de coleta original; só a moeda visível deixa de ter 2 studs de diâmetro.
	body.Transparency = 1
	local diameter, thickness = 0.9, 0.12
	local disc = Instance.new("Part")
	disc.Name, disc.Shape = "CoinBody", Enum.PartType.Cylinder
	disc.Size, disc.CFrame = Vector3.new(thickness, diameter, diameter), body.CFrame
	disc.Color, disc.Material = brass, Enum.Material.Metal
	disc.Anchored, disc.Massless = false, true
	disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = false, false, false, false
	disc.Parent = folder
	local discWeld = Instance.new("WeldConstraint")
	discWeld.Part0, discWeld.Part1, discWeld.Parent = body, disc, disc
	for _, side in { -1, 1 } do
		for index = 1, 2 do
			local part = Instance.new("Part")
			part.Name = if index == 1 then "RaisedRim" else "StampedFace"
			part.Shape = Enum.PartType.Cylinder
			local faceDiameter = diameter * (if index == 1 then 0.94 else 0.8)
			part.Size = Vector3.new(0.012, faceDiameter, faceDiameter)
			part.CFrame = body.CFrame * CFrame.new(side * (thickness / 2 + index * 0.01), 0, 0)
			part.Color = if index == 1 then Color3.fromRGB(207, 166, 86) else Color3.fromRGB(127, 89, 38)
			part.Material = Enum.Material.Metal
			part.Anchored, part.Massless = false, true
			part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
			part.Parent = folder
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = body, part, part
		end
		local stamp = Instance.new("Part")
		stamp.Name = "MintMark"
		stamp.Size = Vector3.new(0.012, diameter * 0.28, diameter * 0.28)
		stamp.CFrame = body.CFrame * CFrame.new(side * (thickness / 2 + 0.035), 0, 0) * CFrame.Angles(math.pi / 4, 0, 0)
		stamp.Color, stamp.Material = brass, Enum.Material.Metal
		stamp.Anchored, stamp.Massless = false, true
		stamp.CanCollide, stamp.CanQuery, stamp.CanTouch, stamp.CastShadow = false, false, false, false
		stamp.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = body, stamp, stamp
	end
	folder.Parent = body
end

return Finish
