--!strict
--[[
	Registro central de remotes. TODO remote do jogo é declarado em DEFINITIONS, e só aqui.

	- Servidor: Remotes.setupServer() cria a pasta ReplicatedStorage.<RemotesFolderName> com
	  todos os remotes (chamado uma vez pelo bootstrap). Depois use serverEvent/serverFunction.
	- Cliente: clientEvent/clientFunction esperam o remote aparecer (com timeout).
	- Nome desconhecido = erro imediato. Nunca crie RemoteEvent/RemoteFunction "soltos".

	Handlers no servidor devem passar por Server/Net/ServerNet (validação + rate limit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require("../Config")

export type RemoteKind = "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent"

local DEFINITIONS: { [string]: RemoteKind } = {
	-- Cliente pede para interagir com algo: (id, ação opcional "use" | "alt"). Servidor valida tudo.
	Interact = "RemoteFunction",
	-- Cliente pede lanterna ligada/desligada; o servidor decide pela bateria (afeta a visão do Vigia).
	SetFlashlight = "RemoteEvent",
	-- Cliente pede postura ("Stand" | "Crouch"); o servidor checa o teto e muda o corpo.
	SetStance = "RemoteEvent",
	-- Escondido: prender/soltar a respiração.
	SetHoldBreath = "RemoteEvent",
	-- Cliente pede nova rodada nas telas finais: "full" (do zero) ou "checkpoint".
	RequestRestart = "RemoteFunction",
}

local FOLDER_NAME = Config.Net.RemotesFolderName

local Remotes = {}

function Remotes.names(): { string }
	local names = {}
	for name in DEFINITIONS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Remotes.kindOf(name: string): RemoteKind
	local kind: RemoteKind? = DEFINITIONS[name]
	if kind then
		return kind
	end
	error(`[Remotes] unknown remote "{name}"; declare it in Shared/Net/Remotes.luau`, 3)
end

-- Cria (ou completa) a pasta de remotes. Idempotente. Somente no servidor.
function Remotes.setupServer(): Folder
	assert(RunService:IsServer(), "[Remotes] setupServer must run on the server")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		local newFolder = Instance.new("Folder")
		newFolder.Name = FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end
	assert(folder and folder:IsA("Folder"), `[Remotes] ReplicatedStorage.{FOLDER_NAME} must be a Folder`)
	for _, name in Remotes.names() do
		local kind = DEFINITIONS[name]
		local existing = folder:FindFirstChild(name)
		if existing == nil then
			local remote = Instance.new(kind)
			remote.Name = name
			remote.Parent = folder
		elseif existing.ClassName ~= kind then
			error(`[Remotes] {name} exists as {existing.ClassName}, expected {kind}`)
		end
	end
	return folder
end

local function serverRemote(name: string, kind: RemoteKind): Instance
	if Remotes.kindOf(name) ~= kind then
		error(`[Remotes] {name} is a {Remotes.kindOf(name)}, not a {kind}`, 3)
	end
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local remote = folder and folder:FindFirstChild(name)
	if remote == nil then
		error(`[Remotes] {name} not found; call Remotes.setupServer() first`, 3)
	end
	return remote
end

local function clientRemote(name: string, kind: RemoteKind, timeout: number?): Instance
	if Remotes.kindOf(name) ~= kind then
		error(`[Remotes] {name} is a {Remotes.kindOf(name)}, not a {kind}`, 3)
	end
	local limit = timeout or Config.Net.ClientWaitTimeout
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, limit)
	local remote = folder and folder:WaitForChild(name, limit)
	if remote == nil then
		error(`[Remotes] timed out after {limit}s waiting for {name}`, 3)
	end
	return remote
end

function Remotes.serverEvent(name: string): RemoteEvent
	return serverRemote(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.serverFunction(name: string): RemoteFunction
	return serverRemote(name, "RemoteFunction") :: RemoteFunction
end

function Remotes.serverUnreliableEvent(name: string): UnreliableRemoteEvent
	return serverRemote(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Remotes.clientEvent(name: string, timeout: number?): RemoteEvent
	return clientRemote(name, "RemoteEvent", timeout) :: RemoteEvent
end

function Remotes.clientFunction(name: string, timeout: number?): RemoteFunction
	return clientRemote(name, "RemoteFunction", timeout) :: RemoteFunction
end

function Remotes.clientUnreliableEvent(name: string, timeout: number?): UnreliableRemoteEvent
	return clientRemote(name, "UnreliableRemoteEvent", timeout) :: UnreliableRemoteEvent
end

return Remotes
