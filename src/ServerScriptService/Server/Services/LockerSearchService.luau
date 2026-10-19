--!strict
--[[
	Revista do armário (ideia C; regras puras em Shared/Game/BreathTest). Quando o Tung Tung alcança alguém escondido,
	CampaignRuntime chama `begin` em vez de capturar: ele fica parado na porta e o jogador segura a respiração no
	ritmo (remote BreathPress com o instante do aperto). O placar vai nos atributos do jogador:
	BreathTestAt (início, hora do servidor), BreathTestSeed, BreathTestScore ("HM-.."), BreathTestEnd ("pass"|"fail").
	Sair do armário no meio conta como falha. O resultado volta pelo callback (`true` = passou).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BreathTest = require("@game/ReplicatedStorage/Shared/Game/BreathTest")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local ServerNet = require("../Net/ServerNet")

local LockerSearchService = {
	Name = "LockerSearchService",
}

type Test = {
	startAt: number,
	times: { number },
	results: { BreathTest.Result? },
	done: (boolean) -> (),
}

local tests: { [Player]: Test } = {}
local rng = Random.new()

local function hidden(player: Player): boolean
	local id = player:GetAttribute("Hidden")
	return type(id) == "string" and id ~= ""
end

local function finish(player: Player, test: Test, passed: boolean)
	if tests[player] ~= test then
		return
	end
	tests[player] = nil
	player:SetAttribute("BreathTestEnd", if passed then "pass" else "fail")
	player:SetAttribute("BreathTestAt", nil)
	task.spawn(test.done, passed)
end

local function settle(player: Player, test: Test)
	player:SetAttribute("BreathTestScore", BreathTest.encode(test.results))
	local outcome = BreathTest.outcome(test.results)
	if outcome then
		finish(player, test, outcome == "pass")
	end
end

-- Começa a revista. Retorna true se há uma revista correndo para o jogador (a captura deve esperar).
function LockerSearchService.begin(player: Player, done: (passed: boolean) -> ()): boolean
	if tests[player] then
		return true
	end
	if not hidden(player) then
		return false
	end
	local seed = rng:NextInteger(0, 999)
	local test: Test = {
		startAt = workspace:GetServerTimeNow(),
		times = BreathTest.times(seed),
		results = {},
		done = done,
	}
	tests[player] = test
	player:SetAttribute("BreathTestEnd", nil)
	player:SetAttribute("BreathTestSeed", seed)
	player:SetAttribute("BreathTestScore", BreathTest.encode(test.results))
	player:SetAttribute("BreathTestAt", test.startAt)
	return true
end

function LockerSearchService.isRunning(player: Player): boolean
	return tests[player] ~= nil
end

local function onPress(player: Player, claimed: number)
	local test = tests[player]
	if not test then
		return
	end
	-- Usa o instante do aperto informado pelo cliente (compensa o atraso da rede), dentro de uma folga curta.
	local now = workspace:GetServerTimeNow()
	local at = if math.abs(now - claimed) <= 0.6 then claimed else now
	BreathTest.press(test.times, test.results, at - test.startAt)
	settle(player, test)
end

function LockerSearchService.Start()
	ServerNet.onEvent("BreathPress", {
		args = { Guard.number() },
		rateLimit = { capacity = 6, refillPerSecond = 4 },
	}, onPress)
	RunService.Heartbeat:Connect(function()
		if next(tests) == nil then
			return
		end
		local now = workspace:GetServerTimeNow()
		for player, test in tests do
			if not player.Parent or player:GetAttribute("CampaignStatus") ~= "Active" then
				-- Rodada recomeçou ou o jogador saiu: some sem resultado.
				tests[player] = nil
				player:SetAttribute("BreathTestAt", nil)
				continue
			end
			if not hidden(player) then
				finish(player, test, false)
				continue
			end
			if BreathTest.expire(test.times, test.results, now - test.startAt) > 0 then
				settle(player, test)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		tests[player] = nil
	end)
end

return LockerSearchService
