--!strict
local CollectionService = game:GetService("CollectionService")
local Build = require("./Build")
local Television = {}
function Television.build(parent: Instance)
	local model = Build.model(parent, "Television")
	local options = { material = Enum.Material.Wood, collide = false, query = false }
	local function box(name: string, center: Vector3, size: Vector3, color: Color3)
		return Build.part(model, name, size, CFrame.new(center), color, options)
	end
	box("Cabinet", Vector3.new(-35, 2, -17), Vector3.new(7, 4, 2.8), Color3.fromRGB(66, 47, 36))
	box("CrtBody", Vector3.new(-35, 5.3, -17), Vector3.new(6.4, 3.6, 2.5), Color3.fromRGB(38, 36, 34))
	local screen = Build.sign(
		model,
		"BroadcastScreen",
		Vector3.new(-35.5, 5.3, -15.7),
		Vector3.zAxis,
		Vector2.new(4.5, 2.7),
		"CANAL 03\nSEM SINAL",
		{
			textColor = Color3.fromRGB(162, 205, 178),
			background = Color3.fromRGB(12, 24, 21),
			font = Enum.Font.Code,
			lit = true,
			pixelsPerStud = 90,
		}
	)
	screen.CanQuery = false
	local gui = screen:FindFirstChildOfClass("SurfaceGui")
	assert(gui, "Missing television surface")
	gui.Brightness = 0.8
	local scan = Instance.new("Frame")
	scan.Name, scan.BorderSizePixel = "Scan", 0
	scan.Size = UDim2.fromScale(1, 0.025)
	scan.BackgroundColor3, scan.BackgroundTransparency = Color3.fromRGB(160, 210, 175), 0.88
	scan.Parent = gui
	for _, y in { 4.6, 5.8 } do
		Build.cylinder(
			model,
			"Tuner",
			Vector3.new(-32.6, y, -15.6),
			Vector3.zAxis,
			0.3,
			0.5,
			Color3.fromRGB(154, 137, 104),
			{ collide = false, query = false }
		)
	end
	CollectionService:AddTag(screen, "HouseTelevision")
	Build.light(screen, "Street", Color3.fromRGB(143, 190, 165), 10, 0.25, true)
end
return Television
