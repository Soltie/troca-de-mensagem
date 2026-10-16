--!strict
local CoinPlan = require("@game/ServerScriptService/Server/Game/CoinPlan")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local TestKit = require("../TestKit")

local function roomCount(): number
	local count = 0
	for _, room in House.Rooms do
		if room.id ~= "Exterior" and room.id ~= "Hall" then
			count += 1
		end
	end
	return count
end

local testSpec: TestKit.Spec = {
	name = "CoinPlan",
	run = function(t)
		t.it("is deterministic per seed and varies between chapters", function()
			local a = CoinPlan.create(90312, 2, 8)
			local b = CoinPlan.create(90312, 2, 8)
			t.expect(a).toEqual(b)
			local c = CoinPlan.create(90313, 2, 8)
			local same = true
			for index, coin in a do
				if coin.x ~= c[index].x or coin.z ~= c[index].z then
					same = false
				end
			end
			t.expect(same).toBe(false)
		end)
		t.it("places the expected amount with exactly one gem and unique ids", function()
			local coins = CoinPlan.create(7, 2, 8)
			t.expect(#coins).toBe(roomCount() * 2 + #CoinPlan.Levels * #CoinPlan.HallSpots + 8)
			local gems, ids = 0, {}
			for _, coin in coins do
				if coin.gem then
					gems += 1
				end
				t.expect(ids[coin.id]).toBe(nil)
				ids[coin.id] = true
			end
			t.expect(gems).toBe(1)
		end)
		t.it("keeps room coins inside their room and away from the facade furniture strip", function()
			for seed = 1, 20 do
				for _, coin in CoinPlan.create(seed, 2, 0) do
					local id = string.match(coin.id, "^coin_(%a+)_")
					for _, room in House.Rooms do
						if room.id == id then
							local side = if room.x < 0 then -1 else 1
							local out = (coin.x - room.x) * side
							t.expect(math.abs(coin.x - room.x) <= 16).toBe(true)
							t.expect(math.abs(coin.z - room.z) <= 15).toBe(true)
							t.expect(out <= 9).toBe(true)
							t.expect(coin.y - room.y).toBeCloseTo(CoinPlan.Height)
						end
					end
				end
			end
		end)
		t.it("puts yard coins beside the trail, outside the house", function()
			for _, coin in CoinPlan.create(3, 0, 12) do
				if string.find(coin.id, "yard", 1, true) then
					t.expect(math.abs(coin.x) >= 20).toBe(true)
					t.expect(coin.z >= 72 and coin.z <= 124).toBe(true)
				end
			end
		end)
	end,
}

return testSpec
