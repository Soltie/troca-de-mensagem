--!strict
--[[
	Seção "DIFICULDADE" da aba Jogar (MainMenuController.buildPlay): liga/desliga os modificadores da partida
	(Shared/Game/Difficulty; vale para a equipe toda e paga mais Fichas) e mostra as conquistas do jogador
	(Shared/Game/Achievements). O servidor decide (DifficultyService); aqui só pede e mostra.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require("@game/ReplicatedStorage/Shared/Game/Achievements")
local Difficulty = require("@game/ReplicatedStorage/Shared/Game/Difficulty")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Components = require("./Components")
local Create = require("./Create")
local Theme = require("./Theme")

local Panel = {}

local RED = Color3.fromRGB(196, 72, 72)

local function modifiers(): string
	local state = ReplicatedStorage:FindFirstChild("CampaignState")
	local value = state and state:GetAttribute("Modifiers")
	return if type(value) == "string" then value else ""
end

-- Votos da equipe (DifficultyService): quantos votaram em cada um, quantos precisa e o voto deste jogador.
local function votes(): ({ [string]: number }, number, { string })
	local state = ReplicatedStorage:FindFirstChild("CampaignState")
	local counts: { [string]: number } = {}
	local raw = state and state:GetAttribute("ModifierVotes")
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			for id, n in decoded :: { [any]: any } do
				if type(id) == "string" and type(n) == "number" then
					counts[id] = n
				end
			end
		end
	end
	local needed = state and state:GetAttribute("ModifierNeeded")
	local mine = Players.LocalPlayer:GetAttribute("ModifierVote")
	return counts,
		if type(needed) == "number" then needed else 1,
		Difficulty.parse(if type(mine) == "string" then mine else "")
end

local function unlocked(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local raw = Players.LocalPlayer:GetAttribute("Achievements")
	if type(raw) == "string" then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(list) == "table" then
			for _, id in list :: { any } do
				if type(id) == "string" then
					out[id] = true
				end
			end
		end
	end
	return out
end

function Panel.build(parent: Instance, order: number, columns: number): Frame
	local panel = Create("Frame", {
		Name = "Difficulty",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 14),
		}),
	}) :: Frame
	Components.corner(panel, Theme.CornerLarge)
	Components.stroke(panel, Theme.Border, 1, 0.45)
	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = panel,
	})
	Components.text({
		Size = UDim2.new(1, -170, 0, 24),
		FontFace = Theme.Font,
		TextSize = 20,
		TextColor3 = Theme.TextPrimary,
		Text = "DIFICULDADE",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	Components.text({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -170, 0, 18),
		FontFace = Theme.FontBody,
		TextSize = 12,
		TextColor3 = Theme.TextSecondary,
		Text = "Cada um vota; liga o que tiver a maioria da equipe. Paga mais Fichas.",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local bonus = Components.text({
		Name = "Bonus",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(170, 28),
		FontFace = Theme.Font,
		TextSize = 15,
		TextColor3 = Theme.Gold,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	local perRow = if columns >= 2 then 4 else 2
	local toggles = Create("Frame", {
		Name = "Toggles",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = panel,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(1 / perRow, -8, 0, 74),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local buttons: { [string]: TextButton } = {}
	for index, m in Difficulty.List do
		local danger = m.id == "pesadelo"
		local button = Components.button("ghost", {
			Name = m.id,
			LayoutOrder = index,
			Text = "",
			Parent = toggles,
		}, function()
			task.spawn(function()
				pcall(function()
					Remotes.clientFunction("SetModifier", 5):InvokeServer(m.id)
				end)
			end)
		end)
		Components.text({
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 22),
			FontFace = Theme.Font,
			TextSize = 15,
			TextColor3 = if danger then RED else Theme.TextPrimary,
			Text = m.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		Components.text({
			Position = UDim2.fromOffset(10, 28),
			Size = UDim2.new(1, -20, 0, 26),
			FontFace = Theme.FontBody,
			TextSize = 11,
			TextColor3 = Theme.TextSecondary,
			Text = m.description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = button,
		})
		Components.text({
			Name = "State",
			Position = UDim2.new(0, 10, 1, -20),
			Size = UDim2.new(1, -20, 0, 16),
			FontFace = Theme.Font,
			TextSize = 12,
			TextColor3 = Theme.Gold,
			Text = `+{math.floor(m.bonus * 100 + 0.5)}% FICHAS`,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		buttons[m.id] = button
	end
	Components.text({
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Font,
		TextSize = 15,
		TextColor3 = Theme.TextPrimary,
		Text = "CONQUISTAS",
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
		Parent = panel,
	})
	local badges = Create("Frame", {
		Name = "Achievements",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = panel,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(1 / perRow, -8, 0, 46),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local cards: { [string]: Frame } = {}
	for index, a in Achievements.List do
		local card = Create("Frame", {
			Name = a.id,
			LayoutOrder = index,
			BackgroundColor3 = Theme.BgSunken,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = badges,
		}) :: Frame
		Components.corner(card, Theme.CornerSmall)
		Components.stroke(card, Theme.Border, 1, 0.5)
		Components.text({
			Name = "Title",
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 18),
			FontFace = Theme.Font,
			TextSize = 13,
			TextColor3 = Theme.TextMuted,
			Text = a.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		Components.text({
			Position = UDim2.fromOffset(8, 22),
			Size = UDim2.new(1, -16, 0, 20),
			FontFace = Theme.FontNote,
			TextSize = 10,
			TextColor3 = Theme.TextMuted,
			Text = a.description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		cards[a.id] = card
	end
	local function refresh()
		local active = Difficulty.parse(modifiers())
		local counts, needed, mine = votes()
		for id, button in buttons do
			local on = table.find(active, id) ~= nil
			local voted = table.find(mine, id) ~= nil
			Components.setVariant(button, if on then "secondary" else "ghost")
			local outline = button:FindFirstChild("Outline")
			if outline and outline:IsA("UIStroke") then
				outline.Color = if on then (if id == "pesadelo" then RED else Theme.Gold) else Theme.Border
				outline.Thickness = if on then 2 else 1
			end
			local state = button:FindFirstChild("State")
			local m = Difficulty.get(id)
			if state and state:IsA("TextLabel") and m then
				local tally = `{counts[id] or 0}/{needed} VOTOS`
				state.Text = (if on then "LIGADO · " elseif voted then "SEU VOTO · " else "")
					.. tally
					.. ` · +{math.floor(m.bonus * 100 + 0.5)}%`
			end
		end
		local total = Difficulty.factors(modifiers()).bonus
		bonus.Text = if total > 0 then `BÔNUS +{math.floor(total * 100 + 0.5)}% FICHAS` else "MODO NORMAL"
		local got = unlocked()
		for id, card in cards do
			local title = card:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				title.TextColor3 = if got[id] then Theme.Gold else Theme.TextMuted
				title.Text = (if got[id] then "★ " else "") .. (Achievements.get(id) :: any).title
			end
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if got[id] then Theme.Gold else Theme.Border
			end
		end
	end
	local connections: { RBXScriptConnection } = {}
	local state = ReplicatedStorage:FindFirstChild("CampaignState")
	if state then
		table.insert(connections, state:GetAttributeChangedSignal("Modifiers"):Connect(refresh))
		table.insert(connections, state:GetAttributeChangedSignal("ModifierVotes"):Connect(refresh))
		table.insert(connections, state:GetAttributeChangedSignal("ModifierNeeded"):Connect(refresh))
	end
	table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal("Achievements"):Connect(refresh))
	table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal("ModifierVote"):Connect(refresh))
	panel.Destroying:Connect(function()
		for _, c in connections do
			c:Disconnect()
		end
	end)
	refresh()
	return panel
end

return Panel
