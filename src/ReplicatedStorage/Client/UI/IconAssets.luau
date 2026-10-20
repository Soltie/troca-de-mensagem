--!strict
--[[
	Ícones desenhados pelo Artista 3D (build/ui_icons/*.png, 128×128, brancos em fundo transparente), já enviados
	ao Roblox. Chave = kind do Icons.luau; valor = rbxassetid. Kind sem id continua no desenho em pixels.
	Os ids vêm de build/ui_icons/ids.txt (pedido de tela 021): copie cada linha "Nome=rbxassetid://..." para cá.
]]

local IconAssets: { [string]: string } = {}

return table.freeze(IconAssets)
