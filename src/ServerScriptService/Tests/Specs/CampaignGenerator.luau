--!strict
local Generator = require("@game/ServerScriptService/Server/Campaign/CampaignGenerator")
local SeededRandom = require("@game/ServerScriptService/Server/Campaign/SeededRandom")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "CampaignGenerator",
	run = function(t)
		t.it("reproduces the complete plan from seed, stage and party size", function()
			t.expect(Generator.create(9182, 2, 8)).toEqual(Generator.create(9182, 2, 8))
		end)
		t.it("varies activities, sequences and routes across seeds", function()
			local signatures: { [string]: boolean } = {}
			for seed = 1, 64 do
				local plan = Generator.create(seed, 2, 5)
				local parts = table.clone(plan.closedLinks)
				for _, activity in plan.activities do
					table.insert(parts, activity.slot .. activity.kind .. table.concat(activity.order, ""))
				end
				signatures[table.concat(parts, ":")] = true
			end
			local count = 0
			for _ in signatures do
				count += 1
			end
			t.expect(count >= 60).toBe(true)
		end)
		t.it("keeps 3600 generated plans valid for every target party size and stage", function()
			for seed = 1, 200 do
				for players = 3, 8 do
					for stage = 1, 3 do
						local plan = Generator.create(seed, stage, players)
						local valid, reason = Generator.validate(plan)
						if not valid then
							error(`seed={seed} players={players} stage={stage}: {reason}`)
						end
						t.expect(#plan.activities >= players).toBe(true)
					end
				end
			end
		end)
		t.it("rejects a closure on the permanent circulation spine", function()
			local plan = Generator.create(9, 1, 3)
			plan.closedLinks = { "entry" }
			t.expect((Generator.validate(plan))).toBe(false)
		end)
		t.it("rejects duplicate stations and unknown coordinates", function()
			local plan = Generator.create(9, 1, 3)
			plan.activities[2].slot = plan.activities[1].slot
			t.expect((Generator.validate(plan))).toBe(false)
			plan = Generator.create(9, 1, 3)
			plan.activities[1].x = 10000
			t.expect((Generator.validate(plan))).toBe(false)
		end)
		t.it("rejects impossible party/stage parameters and non-finite seeds", function()
			t.expect(function()
				Generator.create(9, 0, 3)
			end).toThrow()
			t.expect(function()
				Generator.create(9, 1, 9)
			end).toThrow()
			t.expect(function()
				SeededRandom.new(math.huge)
			end).toThrow()
			t.expect(function()
				SeededRandom.new(0 / 0)
			end).toThrow()
		end)
		t.it("shuffles without changing the source array or its elements", function()
			local source = { 1, 2, 3, 4, 5 }
			local a = SeededRandom.new(55).shuffle(source)
			local b = SeededRandom.new(55).shuffle(source)
			t.expect(a).toEqual(b)
			t.expect(source).toEqual({ 1, 2, 3, 4, 5 })
			table.sort(a)
			t.expect(a).toEqual(source)
		end)
	end,
}

return spec
