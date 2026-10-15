--!strict
--[[
	Helper mínimo para construir UI por código (sem lib declarativa).

		local label = Create("TextLabel", {
			Name = "Title",
			Text = "Olá",
			Parent = screenGui,
		}, {
			Create("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
		}) :: TextLabel

	`Parent` é aplicado por último (depois das propriedades e dos filhos),
	para não replicar/renderizar a instância pela metade.
]]

local function Create(className: string, props: { [string]: any }?, children: { any }?): Instance
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
