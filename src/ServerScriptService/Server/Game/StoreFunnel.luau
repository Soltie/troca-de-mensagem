--!strict
--[[
	Funil da loja (regras puras, testadas no Lune): abrir loja -> ver oferta -> comprar.
	Funil recorrente da Roblox: cada abertura da loja é uma sessão (funnelSessionId = GUID).

	- 1 OpenStore: o cliente abriu a loja (nova sessão a cada abertura).
	- 2 ViewOffer: o jogador ESCOLHEU olhar uma oferta (aba ou categoria com algo à venda, ou as
	  chances de um baú). A aba que já abre na tela não conta: assim o passo 2 mede interesse.
	- 3 Purchase: uma compra deu certo nesta sessão (Fichas, Créditos ou Robux).
	Cada passo é registrado no máximo uma vez por sessão (repetidos só gastariam o limite de
	eventos). Sem sessão aberta (ex.: recibo depois de sair do jogo), o funil não registra nada.
]]

export type State = { session: string?, step: number }

export type Step = {
	step: number,
	name: string,
	-- Até 3 campos personalizados (CustomField01..03), já como texto.
	fields: { string },
}

local StoreFunnel = {}

StoreFunnel.NAME = "Store"
StoreFunnel.STEP_NAMES = table.freeze({ "OpenStore", "ViewOffer", "Purchase" })

-- Ofertas que contam como "ver item" (abas com algo à venda e categorias da loja).
StoreFunnel.OFFERS = table.freeze({
	shop = true,
	season = true,
	chests = true,
	robux = true,
	odds = true,
	flashlight = true,
	uniform = true,
	filter = true,
	title = true,
} :: { [string]: boolean })

function StoreFunnel.new(): State
	return { session = nil, step = 0 }
end

local function advance(state: State, step: number, fields: { string }): { Step }
	if not state.session or state.step >= step then
		return {}
	end
	state.step = step
	return { { step = step, name = StoreFunnel.STEP_NAMES[step], fields = fields } }
end

-- Abriu a loja: começa uma sessão nova com `sessionId`.
function StoreFunnel.open(state: State, sessionId: string): { Step }
	state.session = sessionId
	state.step = 0
	return advance(state, 1, {})
end

function StoreFunnel.view(state: State, offer: string): { Step }
	if not StoreFunnel.OFFERS[offer] then
		return {}
	end
	return advance(state, 2, { `Offer - {offer}` })
end

-- `kind` = item | chest | product | pass; `currency` = fichas | creditos | robux.
function StoreFunnel.purchase(state: State, kind: string, currency: string): { Step }
	return advance(state, 3, { `Kind - {kind}`, `Currency - {currency}` })
end

return StoreFunnel
