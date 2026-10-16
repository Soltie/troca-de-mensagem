--!strict
--[[
	TelemetryService: analytics de economia e funil da loja (AnalyticsService da Roblox).

	- Economia: StoreService envia os eventos montados por Server/Game/EconomyEvents
	  (fontes e sumidouros de Fichas/Créditos, com saldo final, tipo de transação e SKU).
	- Funil "Store" (Server/Game/StoreFunnel): abrir loja -> ver oferta -> comprar.
	  O cliente avisa abrir/ver pelo remote "StoreTrack" (só telemetria: não muda nada no jogo);
	  a compra é marcada pelo próprio servidor quando dá certo.
	- A Roblox só aceita esses eventos de servidor PUBLICADO: no Studio nada é enviado, mas tudo
	  fica no histórico em memória (DebugBridge "analytics") para o QA conferir.
	- Falha do AnalyticsService nunca atrapalha o jogo (pcall).
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local EconomyEvents = require("../Game/EconomyEvents")
local StoreFunnel = require("../Game/StoreFunnel")
local ServerNet = require("../Net/ServerNet")

local log = Logger.new("TelemetryService")
local HISTORY_SIZE = 80
local FIELD_KEYS = { "CustomField01", "CustomField02", "CustomField03" }

local live = not RunService:IsStudio()
local funnels: { [Player]: StoreFunnel.State } = {}
local history: { { [string]: any } } = {}

local function remember(entry: { [string]: any })
	entry.at = os.clock()
	table.insert(history, entry)
	if #history > HISTORY_SIZE then
		table.remove(history, 1)
	end
end

local function customFields(values: { string }): { [string]: string }?
	if #values == 0 then
		return nil
	end
	local fields = {}
	for index, value in values do
		local key = FIELD_KEYS[index]
		if key then
			fields[(Enum.AnalyticsCustomFieldKeys :: any)[key].Name] = value
		end
	end
	return fields
end

local function funnelOf(player: Player): StoreFunnel.State
	local state = funnels[player]
	if not state then
		state = StoreFunnel.new()
		funnels[player] = state
	end
	return state
end

local function sendSteps(player: Player, state: StoreFunnel.State, steps: { StoreFunnel.Step })
	for _, step in steps do
		remember({
			type = "funnel",
			player = player.Name,
			funnel = StoreFunnel.NAME,
			session = state.session,
			step = step.step,
			name = step.name,
			fields = step.fields,
		})
		if live then
			local ok, err = pcall(function()
				AnalyticsService:LogFunnelStepEvent(
					player,
					StoreFunnel.NAME,
					state.session :: string,
					step.step,
					step.name,
					customFields(step.fields) :: any
				)
			end)
			if not ok then
				log.debug("funnel event failed: %s", tostring(err))
			end
		end
	end
end

local TelemetryService = {
	Name = "TelemetryService",
}

-- Eventos de economia já montados (EconomyEvents). Lista vazia não faz nada.
function TelemetryService.economy(player: Player, events: { EconomyEvents.Event })
	for _, event in events do
		remember({
			type = "economy",
			player = player.Name,
			flow = event.flow,
			currency = EconomyEvents.CurrencyNames[event.currency],
			amount = event.amount,
			balance = event.balance,
			transaction = event.transaction,
			sku = event.sku,
		})
		if live then
			local ok, err = pcall(function()
				AnalyticsService:LogEconomyEvent(
					player,
					(Enum.AnalyticsEconomyFlowType :: any)[event.flow],
					EconomyEvents.CurrencyNames[event.currency],
					event.amount,
					event.balance,
					event.transaction,
					event.sku
				)
			end)
			if not ok then
				log.debug("economy event failed: %s", tostring(err))
			end
		end
	end
end

function TelemetryService.storeOpened(player: Player)
	local state = funnelOf(player)
	sendSteps(player, state, StoreFunnel.open(state, HttpService:GenerateGUID(false)))
end

function TelemetryService.offerViewed(player: Player, offer: string)
	local state = funnelOf(player)
	sendSteps(player, state, StoreFunnel.view(state, offer))
end

-- Compra concluída (chamada pelo StoreService). kind: item|chest|product|pass.
function TelemetryService.purchased(player: Player, kind: string, currency: string)
	local state = funnelOf(player)
	sendSteps(player, state, StoreFunnel.purchase(state, kind, currency))
end

-- Depuração: últimos eventos (mais novos no fim).
function TelemetryService.history(): { { [string]: any } }
	return table.clone(history)
end

function TelemetryService.Start()
	ServerNet.onEvent("StoreTrack", {
		args = {
			Guard.literal("open", "view"),
			Guard.optional(Guard.string({ maxLength = 24, pattern = "[%w_]+" })),
		},
		rateLimit = { capacity = 6, refillPerSecond = 1 },
	}, function(player: Player, event: string, offer: string?)
		if event == "open" then
			TelemetryService.storeOpened(player)
		elseif offer then
			TelemetryService.offerViewed(player, offer)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		funnels[player] = nil
	end)
end

return TelemetryService
