--!strict
--[[
	LobbyService: lista de servidores do menu inicial e entrada em outro servidor ou no de um amigo.

	- Cada servidor publica um registro curto (Shared/Game/ServerList) num MemoryStore SortedMap a cada
	  ServerList.REFRESH s, com expiração (servidor que cai some sozinho) e apaga o próprio ao fechar.
	- Remote "Lobby" (RemoteFunction, ação, argumento?):
	    "servers"         lista ordenada (sem o próprio servidor) + resumo deste servidor;
	    "join", jobId     teleporta se o registro existir, estiver vivo e com vaga;
	    "friend", userId  teleporta para o servidor do amigo (o servidor confere a amizade e onde ele está;
	                      o cliente nunca escolhe um JobId arbitrário).
	- Studio ou lugar não publicado: sem MemoryStore nem teleporte. A lista traz só este servidor e os
	  pedidos de entrada respondem "lobby_studio" (nada é publicado nem chamado fora do Studio).
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local ServerList = require("@game/ReplicatedStorage/Shared/Game/ServerList")
local ServerNet = require("../Net/ServerNet")

local log = Logger.new("LobbyService")
local MAP_NAME = "S9Servers"

local map: MemoryStoreSortedMap? = nil
local online = false

local LobbyService = {
	Name = "LobbyService",
}

local function now(): number
	return os.time()
end

-- Registro deste servidor (o mesmo formato que os outros leem).
local function selfEntry(): ServerList.Entry
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	local mode = if campaign then campaign:GetAttribute("GameMode") else nil
	return {
		job = if game.JobId ~= "" then game.JobId else "studio",
		players = #Players:GetPlayers(),
		max = Config.Campaign.maxPlayers,
		mode = if mode == "Story" or mode == "Standard" then mode else "",
		phase = if campaign then tostring(campaign:GetAttribute("Phase") or "Lobby") else "Lobby",
		stage = if campaign then tonumber(campaign:GetAttribute("Stage")) or 0 else 0,
		updated = now(),
	}
end

local function publishSelf()
	local sorted = map
	if not online or not sorted then
		return
	end
	local entry = selfEntry()
	local ok, err = pcall(function()
		sorted:SetAsync(game.JobId, {
			players = entry.players,
			max = entry.max,
			mode = entry.mode,
			phase = entry.phase,
			stage = entry.stage,
			updated = entry.updated,
		}, ServerList.TTL)
	end)
	if not ok then
		log.warn("server registry write failed: %s", tostring(err))
	end
end

local function readAll(): { ServerList.Entry }
	local entries: { ServerList.Entry } = {}
	local sorted = map
	if not online or not sorted then
		return entries
	end
	local ok, items = pcall(function()
		return sorted:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or type(items) ~= "table" then
		log.warn("server registry read failed: %s", tostring(items))
		return entries
	end
	for _, item in items do
		local entry = ServerList.decode(item.value, item.key)
		if entry then
			table.insert(entries, entry)
		end
	end
	return entries
end

local function teleport(player: Player, jobId: string): (boolean, string)
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		log.warn("teleport of %s failed: %s", player.Name, tostring(err))
		return false, "lobby_teleport_failed"
	end
	return true, "lobby_teleporting"
end

local function handle(player: Player, action: string, arg: string?): { [string]: any }
	if action == "servers" then
		local list = ServerList.sorted(readAll(), game.JobId, now())
		return { ok = true, online = online, current = selfEntry(), servers = list }
	end
	if not online then
		return { ok = false, message = "lobby_studio" }
	end
	if action == "join" and arg then
		if not ServerList.validJob(arg) then
			return { ok = false, message = "server_gone" }
		end
		for _, entry in readAll() do
			if entry.job == arg then
				local joinable, reason = ServerList.joinable(entry, game.JobId, now())
				if not joinable then
					return { ok = false, message = reason or "server_gone" }
				end
				local ok, message = teleport(player, arg)
				return { ok = ok, message = message }
			end
		end
		return { ok = false, message = "server_gone" }
	elseif action == "friend" and arg then
		local friendId = tonumber(arg)
		if not friendId or friendId <= 0 then
			return { ok = false, message = "friend_offline" }
		end
		local isFriend = false
		pcall(function()
			isFriend = player:IsFriendsWithAsync(friendId)
		end)
		if not isFriend then
			return { ok = false, message = "friend_not_friend" }
		end
		local ok, _, _, placeId, jobId = pcall(function()
			return TeleportService:GetPlayerPlaceInstanceAsync(friendId)
		end)
		if not ok or placeId ~= game.PlaceId or type(jobId) ~= "string" or jobId == "" then
			return { ok = false, message = "friend_offline" }
		end
		if jobId == game.JobId then
			return { ok = false, message = "server_self" }
		end
		local teleported, message = teleport(player, jobId)
		return { ok = teleported, message = message }
	end
	return { ok = false, message = "lobby_unknown" }
end

function LobbyService.Start()
	online = game.GameId ~= 0 and game.JobId ~= "" and not RunService:IsStudio()
	if online then
		local ok, result = pcall(function()
			return MemoryStoreService:GetSortedMap(MAP_NAME)
		end)
		if ok then
			map = result
		else
			online = false
			log.warn("memory store unavailable: %s", tostring(result))
		end
	end
	ServerNet.onInvoke("Lobby", {
		args = {
			Guard.literal("servers", "join", "friend"),
			Guard.optional(Guard.string({ maxLength = 40, pattern = "^[%w%-]+$" })),
		},
		rateLimit = { capacity = 4, refillPerSecond = 0.5 },
	}, handle)
	if online then
		task.spawn(function()
			while true do
				publishSelf()
				task.wait(ServerList.REFRESH)
			end
		end)
		game:BindToClose(function()
			local sorted = map
			if sorted then
				pcall(function()
					sorted:RemoveAsync(game.JobId)
				end)
			end
		end)
	end
	log.info("server list %s", if online then "online" else "offline (Studio/unpublished)")
end

return LobbyService
