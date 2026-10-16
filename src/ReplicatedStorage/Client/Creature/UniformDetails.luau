--!strict
-- Peças de acabamento seguem os ossos cinemáticos existentes, no mesmo BulkMoveTo/stop-motion.
export type Detail = { name: string, anchor: string, size: Vector3, offset: CFrame, color: Color3, metal: boolean? }
local V = Vector3.new
local details: { Detail } = {
	{
		name = "HairCrown",
		anchor = "Head",
		size = V(1.18, 0.22, 0.9),
		offset = CFrame.new(0, 0.66, 0.03),
		color = Color3.fromRGB(40, 35, 31),
	},
	{
		name = "HairNape",
		anchor = "Head",
		size = V(1.1, 0.8, 0.14),
		offset = CFrame.new(0, 0.2, 0.43),
		color = Color3.fromRGB(33, 30, 28),
	},
	{
		name = "Belt",
		anchor = "Pelvis",
		size = V(1.4, 0.16, 0.84),
		offset = CFrame.new(0, 0.05, 0),
		color = Color3.fromRGB(48, 35, 24),
	},
	{
		name = "Buckle",
		anchor = "Pelvis",
		size = V(0.27, 0.19, 0.05),
		offset = CFrame.new(0, 0.05, -0.45),
		color = Color3.fromRGB(135, 124, 91),
		metal = true,
	},
	{
		name = "Radio",
		anchor = "Pelvis",
		size = V(0.38, 0.65, 0.26),
		offset = CFrame.new(0.75, 0, -0.28),
		color = Color3.fromRGB(24, 28, 29),
	},
	{
		name = "RadioAntenna",
		anchor = "Pelvis",
		size = V(0.045, 0.7, 0.045),
		offset = CFrame.new(0.85, 0.55, -0.23),
		color = Color3.fromRGB(12, 14, 14),
	},
	{
		name = "ShirtSeam",
		anchor = "Torso",
		size = V(0.045, 2.1, 0.03),
		offset = CFrame.new(0, 0, -0.45),
		color = Color3.fromRGB(63, 66, 60),
	},
	{
		name = "GuardBadge",
		anchor = "Torso",
		size = V(0.34, 0.19, 0.035),
		offset = CFrame.new(-0.4, 0.65, -0.46),
		color = Color3.fromRGB(145, 132, 95),
		metal = true,
	},
}
for _, side in { "L", "R" } do
	local sign = if side == "L" then -1 else 1
	table.insert(details, {
		name = "Pocket" .. side,
		anchor = "Torso",
		size = V(0.5, 0.6, 0.07),
		offset = CFrame.new(sign * 0.43, 0.3, -0.46),
		color = Color3.fromRGB(37, 42, 39),
	})
	table.insert(details, {
		name = "PocketFlap" .. side,
		anchor = "Torso",
		size = V(0.53, 0.12, 0.1),
		offset = CFrame.new(sign * 0.43, 0.62, -0.49),
		color = Color3.fromRGB(51, 54, 48),
	})
	table.insert(details, {
		name = "Cuff" .. side,
		anchor = "Forearm" .. side,
		size = V(0.36, 0.4, 0.36),
		offset = CFrame.new(0, -0.65, 0),
		color = Color3.fromRGB(35, 39, 37),
	})
	table.insert(details, {
		name = "BootSole" .. side,
		anchor = "Foot" .. side,
		size = V(0.49, 0.1, 0.98),
		offset = CFrame.new(0, -0.14, 0),
		color = Color3.fromRGB(27, 25, 21),
	})
	for i = 1, 3 do
		table.insert(details, {
			name = "Finger" .. side .. i,
			anchor = "Hand" .. side,
			size = V(0.07, 0.34 + i * 0.025, 0.12),
			offset = CFrame.new(-0.12 + (i - 1) * 0.11, -0.46, 0),
			color = Color3.fromRGB(108, 86, 75),
		})
	end
end
return table.freeze(details)
