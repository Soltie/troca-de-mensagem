--!strict
-- Pictogramas próprios em primitivas; sem imagens externas nem dependência de emoji.
local Create = require("./Create")
local Icons = {}
function Icons.draw(parent: Instance, kind: string, color: Color3)
	local function box(x: number, y: number, w: number, h: number, rotation: number?): Frame
		return Create("Frame", {
			Parent = parent,
			Name = "IconShape",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation or 0,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}) :: Frame
	end
	if kind == "Battery" then
		local body = box(3, 6, 17, 12)
		body.BackgroundTransparency = 1
		Create("UIStroke", { Parent = body, Color = color, Thickness = 1.5 })
		box(21, 9, 2, 6)
		box(6, 9, 8, 6)
	elseif kind == "Stamina" then
		box(11, 3, 4, 10, 28)
		box(8, 11, 9, 3)
		box(10, 12, 4, 10, 28)
	else
		for _, x in { 4, 14 } do
			local lung = box(x, 8, 7, 12)
			Create("UICorner", { Parent = lung, CornerRadius = UDim.new(1, 0) })
		end
		box(11, 4, 3, 9)
	end
end
return Icons
