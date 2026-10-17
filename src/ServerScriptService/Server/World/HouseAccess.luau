--!strict
-- Barreira física acompanha a missão: a regra do servidor e a geometria usam os mesmos eventos.
local Build = require("./Build")
local Access = {}
local V3 = Vector3.new
local wood = Color3.fromRGB(86, 65, 54)
function Access.build(root: Instance)
	local old = root:FindFirstChild("ProgressionBarriers")
	if old then
		old:Destroy()
	end
	local folder = Build.folder(root, "ProgressionBarriers")
	local function barrier(name: string, base: Vector3, size: Vector3)
		local part = Build.block(folder, name, base, size, 0, wood, { material = Enum.Material.WoodPlanks })
		part:SetAttribute("MissionBarrier", name)
		return part
	end
	barrier("corridor", V3(0, 0, -52), V3(88, 16, 0.7))
	barrier("ritual", V3(0, -16, -52), V3(88, 16, 0.7))
	-- Tampa sólida do vão: não é possível cair no porão antes de obter a passagem.
	barrier("basement", V3(-16, -0.5, 38), V3(12, 0.5, 32))
	-- Escadas bloqueadas recebem um volume sólido. Pular nas laterais não contorna a missão.
	barrier("upstairs", V3(16, 0, 38), V3(11, 16, 34))
	barrier("upstairs", V3(32, 16, 38), V3(11, 16, 34))
	-- Perímetro completo e cerca do portão: o único acesso à saída é a abertura real.
	for _, side in { -1, 1 } do
		barrier("Boundary", V3(side * 108, -1, 7), V3(1, 10, 250))
		barrier("Boundary", V3(side * 58.5, 0, 98), V3(99, 10, 1))
		local limit = barrier("BoundaryCap", V3(side * 108, 9, 7), V3(1, 16, 250))
		limit.Transparency, limit.CanQuery = 1, false
	end
	barrier("Boundary", V3(0, -1, -118), V3(216, 10, 1))
	barrier("Boundary", V3(0, -1, 132), V3(216, 10, 1))
	for _, z in { -118, 132 } do
		local limit = barrier("BoundaryCap", V3(0, 9, z), V3(216, 16, 1))
		limit.Transparency, limit.CanQuery = 1, false
	end
	Build.block(
		folder,
		"FrontCourtGround",
		V3(0, -1, 81),
		V3(216, 1, 34),
		0,
		Color3.fromRGB(42, 55, 43),
		{ material = Enum.Material.Grass }
	)
	Build.block(
		folder,
		"ExitGround",
		V3(0, -1, 115),
		V3(216, 1, 34),
		0,
		Color3.fromRGB(42, 55, 43),
		{ material = Enum.Material.Grass }
	)
end
function Access.refresh(root: Instance)
	local barriers, gates = root:FindFirstChild("ProgressionBarriers"), root:FindFirstChild("MissionGates")
	if not barriers or not gates then
		return
	end
	for _, part in barriers:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local gate = gates:FindFirstChild(part.Name)
		if gate and gate:IsA("BasePart") then
			local open = not gate.CanCollide
			part.CanCollide, part.CanQuery, part.Transparency = not open, not open, if open then 1 else 0
		end
	end
end
return Access
