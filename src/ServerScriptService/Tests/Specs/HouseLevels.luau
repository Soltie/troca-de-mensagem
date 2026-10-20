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
		t.it("fuses, mask, photo and lighter change rooms between runs but never share one", function()
			local fuseRooms: { [string]: boolean } = {}
			for seed = 1, 40 do
				for _, chapter in { 2, 3, 5 } do
					local plan = Plan.create(seed, chapter, 1, "Story")
					t.expect((Plan.validate(plan))).toBe(true)
					t.expect(Plan.create(seed, chapter, 1, "Story")).toEqual(plan)
					local used: { [string]: boolean } = {}
					for _, spec in plan.activities do
						local pooled = spec.item == "mask"
							or spec.item == "photo"
							or spec.item == "lighter"
							or string.find(spec.item or "", "fuse_", 1, true) ~= nil
						if pooled then
							t.expect(used[spec.room]).toBeNil()
							used[spec.room] = true
						end
						if spec.item == "fuse_1" then
							fuseRooms[spec.room] = true
						end
					end
				end
			end
			local count = 0
			for _ in fuseRooms do
				count += 1
			end
			-- Fusíveis da Família: o da Dona Cida varia entre os dois lugares favoritos dela.
			t.expect(count >= 2).toBe(true)
			-- Fora da lista o plano é recusado.
			local plan = Plan.create(1, 2, 1, "Story")
			plan.activities[1].room = "Attic"
			t.expect((Plan.validate(plan))).toBe(false)
		end)
		t.it("the office clock always asks for 03:12", function()
			for seed = 1, 10 do
				local plan = Plan.create(seed, 3, 1, "Story")
				t.expect(table.concat(plan.activities[5].order, ",")).toBe("1,4,2,3")
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
			-- Fusíveis e o óleo do gerador (tarefa 4) antes do reparo.
			for i = 1, 4 do
				Session.act(s, 1, plan.activities[i].id, 1, 0)
			end
			local repair = plan.activities[5]
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
