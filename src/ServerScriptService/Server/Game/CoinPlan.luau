--!strict
--[[
	Onde as moedas aparecem em cada capítulo (regra pura, testada no Lune).

	Dentro dos cômodos usamos pontos "seguros" no sistema local do cômodo (`out` = rumo à fachada):
	longe dos móveis encostados na fachada (out >= 9), da mesa do fundo e do esconderijo (11, 11).
	No corredor, uma fileira por andar; no quintal, pontos ao lado da trilha. Cada capítulo tem
	uma gema (vale mais) num cômodo sorteado.
]]

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local SeededRandom = require("../Campaign/SeededRandom")

export type Coin = { id: string, x: number, y: number, z: number, gem: boolean }

local CoinPlan = {}

-- (out, z) relativos ao centro do cômodo; ver comentário acima.
CoinPlan.RoomSpots = {
	{ -13, 8 },
	{ -4, -6 },
	{ 5, 0 },
	{ -9, 13 },
	{ 9, -14 },
}

CoinPlan.HallSpots = { { -4, -26 }, { 4, -46 }, { -4, -66 } }
CoinPlan.Levels = { -16, 0, 16, 32 }
CoinPlan.Height = 2.2

local function roomPoint(room: House.Room, spot: { number }): (number, number)
	local side = if room.x < 0 then -1 else 1
	return room.x + side * spot[1], room.z + spot[2]
end

-- `perRoom` moedas por cômodo, `yard` no quintal. Determinístico por `seed`.
function CoinPlan.create(seed: number, perRoom: number, yard: number): { Coin }
	local rng = SeededRandom.new(seed)
	local coins: { Coin } = {}
	local rooms: { House.Room } = {}
	for _, room in House.Rooms do
		if room.id ~= "Exterior" and room.id ~= "Hall" then
			table.insert(rooms, room)
		end
	end
	local gemRoom = rng.integer(1, #rooms)
	for index, room in rooms do
		local order = rng.shuffle({ 1, 2, 3, 4, 5 })
		for n = 1, math.min(perRoom, #order) do
			local x, z = roomPoint(room, CoinPlan.RoomSpots[order[n]])
			table.insert(coins, {
				id = `coin_{room.id}_{n}`,
				x = x,
				y = room.y + CoinPlan.Height,
				z = z,
				gem = index == gemRoom and n == 1,
			})
		end
	end
	for _, level in CoinPlan.Levels do
		for n, spot in CoinPlan.HallSpots do
			table.insert(
				coins,
				{ id = `coin_hall_{level}_{n}`, x = spot[1], y = level + CoinPlan.Height, z = spot[2], gem = false }
			)
		end
	end
	for n = 1, yard do
		-- Dos dois lados da trilha, entre a varanda e a saída.
		local side = if n % 2 == 0 then -1 else 1
		table.insert(coins, {
			id = `coin_yard_{n}`,
			x = side * rng.integer(20, 60),
			y = CoinPlan.Height - 0.5,
			z = rng.integer(72, 124),
			gem = false,
		})
	end
	return coins
end

return CoinPlan
