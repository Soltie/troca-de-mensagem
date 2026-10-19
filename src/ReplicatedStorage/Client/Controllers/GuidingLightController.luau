--!strict
--[[
	Luz guia (ideia A, inspirada no DOORS): quem fica IDLE_SECONDS sem chegar perto do objetivo atual vê um contorno
	branco fino pulsando no objeto da tarefa (visível através das paredes). Item escondido: contorna os três móveis do
	cômodo, sem entregar qual é o certo. Some quando o jogador chega perto ou o objetivo muda; nunca na fuga nem em cena.
	Dica ao cair: quando o servidor registra a causa da queda (LastCaptureCause), uma frase curta explica o que deu
	errado e como evitar (na captura de verdade, repete quando o capítulo recomeça).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local GameUi = require("./GameUiController")

local player = Players.LocalPlayer

local GuidingLightController = {
	Name = "GuidingLightController",
}

local IDLE_SECONDS = 20
local NEAR = 9

local HINTS: { [string]: string } = {
	tung = "Ele te ouviu. Quando as luzes piscarem e o coração acelerar, entre num armário ou saia do caminho dele.",
	lightning = "O raio cai onde o chão brilha. Saia do campo aberto assim que vir o brilho.",
	fire = "O fogo corre atrás de você. Não pare dentro das chamas: corra pelo meio do caminho.",
	search = "Quando ele parar na porta do armário, aperte no ritmo: bem na hora em que o anel encosta no círculo.",
	gust = "Quando as luzes do corredor piscarem e o vento crescer, entre num armário ou num cômodo do lado.",
}

local phase: GameState.Phase = "Loading"
local target: Vector3? = nil
local taskId: string? = nil
local targetSince = 0
local lastNearAt = 0
local shown = false
local intensity = 0
local highlights: { Highlight } = {}
local highlightedTask: string? = nil

local function clearHighlights()
	for _, h in highlights do
		h:Destroy()
	end
	table.clear(highlights)
	highlightedTask = nil
end

-- Objetos da tarefa: o modelo dela e, se o item está escondido, os três móveis de busca.
local function targetsFor(id: string): { Instance }
	local world = workspace:FindFirstChild("CursedHouse")
	local activities = world and world:FindFirstChild("CampaignActivities")
	if not activities then
		return {}
	end
	local list: { Instance } = {}
	local searches = 0
	for n = 1, 3 do
		local box = activities:FindFirstChild(`search_{id}_{n}`)
		if box then
			table.insert(list, box)
			searches += 1
		end
	end
	if searches == 0 then
		local model = activities:FindFirstChild(id)
		if model then
			table.insert(list, model)
		end
	end
	return list
end

local function buildHighlights(id: string)
	clearHighlights()
	for _, instance in targetsFor(id) do
		local h = Instance.new("Highlight")
		h.Name = "GuidingOutline"
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Adornee = instance
		h.Parent = instance
		table.insert(highlights, h)
	end
	highlightedTask = id
end

local function update(dt: number)
	local wanted = player:GetAttribute("GuideTarget")
	local current = if typeof(wanted) == "Vector3" then wanted else nil
	local id = player:GetAttribute("GuideTaskId")
	local currentId = if type(id) == "string" then id else nil
	local now = os.clock()
	if current ~= target or currentId ~= taskId then
		target, taskId = current, currentId
		targetSince = now
		lastNearAt = now
	end
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	-- Dentro do armário o contorno some (atravessaria a porta e entregaria o escuro).
	local hidden = player:GetAttribute("Hidden")
	local active = phase == "Playing"
		and not (type(hidden) == "string" and hidden ~= "")
		and player:GetAttribute("CinematicActive") ~= true
		and player:GetAttribute("CampaignStatus") == "Active"
		and target ~= nil
		and taskId ~= nil
		and body ~= nil
		and body:IsA("BasePart")
	if type(hidden) == "string" and hidden ~= "" then
		-- Ao sair do armário a contagem recomeça do zero.
		lastNearAt = now
	end
	if active and body and body:IsA("BasePart") and target then
		if (body.Position - target).Magnitude < NEAR then
			lastNearAt = now
		end
	end
	shown = active and (now - math.max(targetSince, lastNearAt)) >= IDLE_SECONDS
	intensity += ((if shown then 1 else 0) - intensity) * math.min(1, dt * (if shown then 1.5 else 3))
	if intensity < 0.01 then
		if #highlights > 0 then
			clearHighlights()
		end
		return
	end
	if taskId and highlightedTask ~= taskId then
		buildHighlights(taskId)
	end
	-- Contorno fino respirando devagar.
	local pulse = 0.65 + 0.35 * math.sin(now * 2.4)
	for _, h in highlights do
		h.OutlineTransparency = 1 - intensity * (0.35 + 0.45 * pulse)
	end
end

function GuidingLightController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	-- Dica ao cair: a causa chega junto com o instante (evita repetir a mesma queda).
	player:GetAttributeChangedSignal("LastCaptureAt"):Connect(function()
		local cause = player:GetAttribute("LastCaptureCause")
		local text = if type(cause) == "string" then HINTS[cause] else nil
		if text then
			task.delay(1.2, function()
				GameUi.caption(text, 7)
			end)
		end
	end)
	-- Captura de verdade: a tela de derrota cobre a legenda; a dica volta quando o capítulo recomeça.
	player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
		local message = player:GetAttribute("CampaignFeedback")
		if message ~= "checkpoint_restored" and message ~= "continue_used" then
			return
		end
		local cause = player:GetAttribute("LastCaptureCause")
		local text = if type(cause) == "string" then HINTS[cause] else nil
		if text then
			task.delay(2.5, function()
				GameUi.caption(text, 8)
			end)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

-- Depuração (Studio).
function GuidingLightController.debugState(): { [string]: any }
	return { shown = shown, intensity = intensity, target = target, task = taskId, outlines = #highlights }
end

return GuidingLightController
