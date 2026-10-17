--!strict
--[[
	QA de layout no Studio: o atributo MenuViewportQA = "844x390" no LocalPlayer simula a tela de um
	aparelho de toque (menu e loja usam essa área no centro da janela). Fora do Studio não faz nada.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ViewportQA = {}

ViewportQA.ATTRIBUTE = "MenuViewportQA"

function ViewportQA.size(): (number?, number?)
	if not RunService:IsStudio() then
		return nil, nil
	end
	local player = Players.LocalPlayer
	local raw = if player then player:GetAttribute(ViewportQA.ATTRIBUTE) else nil
	if type(raw) ~= "string" then
		return nil, nil
	end
	local width, height = string.match(raw, "^(%d+)x(%d+)$")
	return tonumber(width), tonumber(height)
end

return ViewportQA
