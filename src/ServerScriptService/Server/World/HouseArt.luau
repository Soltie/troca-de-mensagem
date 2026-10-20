--!strict
--[[
	Modelos 3D do artista (ReplicatedStorage.Assets.HouseArt, importados no place; não estão no repositório). Escala
	de 1 stud = 0,28 m, pivô no centro da base e frente virada para −Z. Quem monta o mundo tenta o modelo de verdade
	e, se ele não existe (build do Rojo, testes no Lune), fica com as peças primitivas de sempre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HouseArt = {}

function HouseArt.get(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("HouseArt")
	local model = art and art:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

-- Clona o modelo `name` em `parent` com o pivô em `pivot` (frente = LookVector do pivô). Peças ancoradas, fora dos
-- raycasts; a colisão fica como o artista deixou. Devolve nil se o modelo não existe.
function HouseArt.place(parent: Instance, name: string, pivot: CFrame): Model?
	local source = HouseArt.get(name)
	if not source then
		return nil
	end
	local clone = source:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			-- Modelo de arte não roda código.
			d:Destroy()
		end
	end
	clone:PivotTo(pivot)
	clone.Parent = parent
	return clone
end

-- Monta as peças primitivas dentro de uma pasta e, se o modelo de arte existir, troca a pasta por ele.
function HouseArt.swap(parent: Instance, name: string, pivot: CFrame, primitives: (folder: Instance) -> ()): Model?
	local folder = Instance.new("Folder")
	folder.Name = `{name}Primitive`
	folder.Parent = parent
	primitives(folder)
	local art = HouseArt.place(parent, name, pivot)
	if art then
		folder:Destroy()
	end
	return art
end

return HouseArt
