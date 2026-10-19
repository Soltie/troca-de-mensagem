--!strict
local FireSpread = require("@game/ReplicatedStorage/Shared/Game/FireSpread")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "FireSpread",
	run = function(t)
		local nodes = FireSpread.build(42)

		t.it("server and client build the same fire from the same seed", function()
			local again = FireSpread.build(42)
			t.expect(#again).toBe(#nodes)
			for i, node in nodes do
				t.expect(again[i].at).toBe(node.at)
				t.expect(again[i].x).toBe(node.x)
			end
		end)

		t.it("nothing burns during the head start", function()
			local start = FireSpread.Route[1]
			t.expect(FireSpread.exposure(nodes, FireSpread.HeadStart - 0.5, start[1], start[2], start[3])).toBe(0)
		end)

		t.it("the front chases along the escape route", function()
			local first, last = math.huge, -math.huge
			for _, node in nodes do
				if node.kind == "front" then
					first, last = math.min(first, node.at), math.max(last, node.at)
				end
			end
			t.expect(first).toBe(FireSpread.HeadStart)
			-- Correndo dá para sair antes da frente chegar na porta, mas parar muito não.
			t.expect(last > 20 and last < 45).toBe(true)
		end)

		t.it("standing in the fire builds heat fast; leaving cools down", function()
			local start = FireSpread.Route[1]
			local at = FireSpread.HeadStart + FireSpread.GrowSeconds + 1
			local exposure = FireSpread.exposure(nodes, at, start[1], start[2], start[3])
			t.expect(exposure > 0.9).toBe(true)
			local heat = 0
			for _ = 1, 20 do
				heat = FireSpread.heat(heat, exposure, 0.1)
			end
			t.expect(heat >= 1).toBe(true)
			t.expect(FireSpread.heat(0.5, 0, 1)).toBe(0)
		end)

		t.it("the middle of the hall stays passable before the front arrives", function()
			local early = FireSpread.frontTime(150)
			t.expect(FireSpread.exposure(nodes, early, 0, 0, 58)).toBe(0)
		end)

		t.it("spilled gasoline flares in a chain from the lighter, before the front", function()
			local fuel = { { -26, 0, -68 }, { 26, -16, -64 }, { -26, 0, -4 } }
			local decoded = FireSpread.decodeFuel(FireSpread.encodeFuel(fuel))
			assert(decoded, "fuel decodes")
			t.expect(#decoded).toBe(3)
			local gas = {}
			for _, node in FireSpread.build(42, decoded) do
				if node.kind == "gas" then
					table.insert(gas, node)
				end
			end
			t.expect(#gas).toBe(3)
			-- O mais perto do mecanismo (onde o isqueiro acende) estoura primeiro.
			t.expect(gas[1].z).toBe(-64)
			t.expect(gas[1].at < gas[2].at and gas[2].at < gas[3].at).toBe(true)
			t.expect(gas[3].at < FireSpread.HeadStart + 6).toBe(true)
			t.expect(FireSpread.decodeFuel("")).toBe(nil)
		end)

		t.it("the facade burns but never hurts", function()
			for _, node in nodes do
				if node.kind == "facade" then
					t.expect(node.radius).toBe(0)
				end
			end
		end)
	end,
}

return spec
