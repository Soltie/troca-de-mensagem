--!strict
local Levels = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
local Plan = require("@game/ServerScriptService/Server/Campaign/HousePlan")
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Catacomb = require("@game/ReplicatedStorage/Shared/Game/CatacombLayout")
local TestKit = require("../TestKit")
return {
	name = "HouseLevels",
	run = function(t: TestKit.Context)
		t.it("story keeps all interior objectives and no randomized passages", function()
			for chapter = 1, 5 do
				local a, b = Levels.create(42, chapter, "Story"), Plan.create(42, chapter, 1, "Story")
				t.expect(a.outdoor).toBe(false)
				t.expect(a.serviceStair).toBe(false)
				t.expect(#a.passages).toBe(0)
				for _, spec in b.activities do
					local p = { x = spec.x, y = spec.y or 0, z = spec.z }
					local below = Catacomb.inside(Catacomb.Catacomb, p, 1) or Catacomb.inside(Catacomb.Chapel, p, 1)
					t.expect(math.abs(spec.x) < 44 or below).toBe(true)
				end
			end
		end)
		t.it("many seeds include a guaranteed outdoor level and reproducible passages/lookout", function()
			local variants: { [string]: boolean } = {}
			for seed = 1, 120 do
				local level = Levels.create(seed, 3, "Standard")
				t.expect(level).toEqual(Levels.create(seed, 3, "Standard"))
				t.expect(level.outdoor).toBe(true)
				t.expect(#level.passages >= 2 and #level.passages <= 16).toBe(true)
				variants[level.theme] = true
				for _, passage in level.passages do
					t.expect(passage.width >= 10 and passage.width <= 24).toBe(true)
				end
				local plan = Plan.create(seed, 3, 2, "Standard")
				t.expect((Plan.validate(plan))).toBe(true)
				plan.activities[1].x += 1
				t.expect((Plan.validate(plan))).toBe(false)
			end
			local count = 0
			for _ in variants do
				count += 1
			end
			t.expect(count).toBe(3)
		end)
		t.it("energy repair requires three ordered server actions and preserves completed steps", function()
			local s = Session.new(42, Config.Campaign, "Standard", true)
			Session.join(s, 1)
			s.stage = 1
			Session.beginStage(s)
			local plan = s.plan
			assert(plan, "Missing plan")
			for i = 1, 3 do
				Session.act(s, 1, plan.activities[i].id, 1, 0)
			end
			local repair = plan.activities[4]
			t.expect(repair.kind).toBe("repair")
			t.expect((Session.act(s, 1, repair.id, 3, 1))).toBe(false)
			Session.act(s, 1, repair.id, 1, 2)
			t.expect(s.tasks[repair.id].solved).toBe(false)
			t.expect((Session.act(s, 1, repair.id, 3, 3))).toBe(false)
			t.expect(s.tasks[repair.id].progress).toBe(1)
			Session.act(s, 1, repair.id, 2, 4)
			Session.act(s, 1, repair.id, 3, 5)
			t.expect(s.tasks[repair.id].solved).toBe(true)
			t.expect((Session.act(s, 1, repair.id, 3, 6))).toBe(false)
		end)
	end,
} :: TestKit.Spec
