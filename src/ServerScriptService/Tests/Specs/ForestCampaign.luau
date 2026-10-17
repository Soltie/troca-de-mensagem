--!strict
local Plan = require("@game/ServerScriptService/Server/Campaign/ForestPlan")
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local TestKit = require("../TestKit")
return {
	name = "ForestCampaign",
	run = function(t: TestKit.Context)
		t.it("forest seeds are reproducible, reject displaced objectives and keep every repair step", function()
			for seed = 1, 30 do
				for chapter = 6, 8 do
					for _, mode in { "Story", "Standard" } do
						local plan = Plan.create(seed, chapter, 2, mode)
						t.expect((Plan.validate(plan))).toBe(true)
						t.expect(plan).toEqual(Plan.create(seed, chapter, 2, mode))
						for _, spec in plan.activities do
							t.expect(math.abs(spec.x) < 70 and spec.z >= 600 and spec.z < 880).toBe(true)
							if spec.kind == "repair" then
								t.expect(spec.order).toEqual({ 1, 2, 3 })
							end
						end
						plan.activities[1].z = 0
						t.expect((Plan.validate(plan))).toBe(false)
					end
				end
			end
		end)
		t.it("house evacuation waits for downed teammates and leads to forest instead of victory", function()
			local state = Session.new(42, Config.Campaign, "Story", true)
			Session.join(state, 1)
			Session.join(state, 2)
			state.stage, state.phase = 5, "Extracting"
			state.members[1].status, state.members[2].status = "Active", "Active"
			Session.capture(state, 2, 0)
			Session.escape(state, 1)
			t.expect(state.phase).toBe("Extracting")
			Session.tick(state, Config.Campaign.downedSeconds + 1)
			t.expect(state.phase).toBe("Intermission")
			t.expect((Session.beginStage(state))).toBe(true)
			t.expect(state.stage).toBe(6)
			t.expect(Session.count(state, "Active")).toBe(2)
		end)
		t.it("forest defeat restores its checkpoint and final rescue needs a real extraction", function()
			local state = Session.new(42, Config.Campaign, "Story", true)
			Session.join(state, 1)
			state.stage, state.phase = 6, "Intermission"
			Session.beginStage(state)
			Session.act(state, 1, "task_1", 1, 0)
			Session.eliminate(state, 1)
			t.expect(state.phase).toBe("Lost")
			Session.retryStage(state)
			Session.beginStage(state)
			t.expect(state.stage).toBe(7)
			t.expect(state.inventory.forest_fuse).toBe(nil)
			state.stage, state.phase = 7, "Intermission"
			Session.beginStage(state)
			assert(state.plan, "Expected forest plan")
			for _, spec in state.plan.activities do
				for _, button in spec.order do
					t.expect((Session.act(state, 1, spec.id, button, 0))).toBe(true)
				end
			end
			t.expect(state.phase).toBe("Extracting")
			Session.escape(state, 1)
			t.expect(state.phase).toBe("Won")
		end)
	end,
} :: TestKit.Spec
