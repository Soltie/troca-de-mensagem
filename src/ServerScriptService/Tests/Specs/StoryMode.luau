--!strict
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Plan = require("@game/ServerScriptService/Server/Campaign/StoryPlan")
local Generator = require("@game/ServerScriptService/Server/Campaign/CampaignGenerator")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Modes = require("@game/ReplicatedStorage/Shared/Game/GameModes")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local TestKit = require("../TestKit")
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")

return {
	name = "StoryMode",
	run = function(t: TestKit.Context)
		t.it("starts either mode only when both partners agree, and waits for a solo player", function()
			local members = { [1] = {}, [2] = {} }
			local minimum = Config.Campaign.minPlayers
			t.expect((Modes.winner({ [1] = "Story" }, { [1] = {} }, minimum))).toBe(nil)
			t.expect((Modes.winner({ [1] = "Story" }, members, minimum))).toBe(nil)
			t.expect((Modes.winner({ [1] = "Story", [2] = "Standard" }, members, minimum))).toBe(nil)
			t.expect((Modes.winner({ [1] = "Story", [2] = "Story" }, members, minimum))).toBe("Story")
			t.expect((Modes.winner({ [1] = "Standard", [2] = "Standard" }, members, minimum))).toBe("Standard")
		end)
		t.it("requires the minimum team and an absolute majority; ignores outsider votes", function()
			local votes: Modes.Votes = { [1] = "Story", [2] = "Story", [99] = "Standard" }
			t.expect((Modes.winner(votes, { [1] = {}, [2] = {} }, 3))).toBe(nil)
			t.expect((Modes.winner(votes, { [1] = {}, [2] = {}, [3] = {} }, 3))).toBe("Story")
			t.expect(
				(
					Modes.winner(
						{ [1] = "Story", [2] = "Story", [3] = "Standard", [4] = "Standard" },
						{ [1] = {}, [2] = {}, [3] = {}, [4] = {} },
						3
					)
				)
			).toBe(nil)
			t.expect((Modes.winner({}, { [1] = {}, [2] = {}, [3] = {} }, 3))).toBe(nil)
		end)
		t.it("keeps every room route objective and code fixed across chapters and party sizes", function()
			local first = Plan.create(1, 3).sector
			for players = 2, 8 do
				for stage = 1, 3 do
					local plan = Plan.create(stage, players)
					t.expect((Generator.validate(plan))).toBe(true)
					t.expect(plan.sector).toEqual(first)
					t.expect(plan.activities).toEqual(Plan.create(stage, 3).activities)
				end
			end
		end)
		t.it("plays all story chapters in order and reaches cooperative extraction", function()
			for players = 2, 8 do
				local state = Session.new(Story.MapSeed, Config.Campaign, "Story")
				for id = 1, players do
					Session.join(state, id)
				end
				for stage = 1, 3 do
					t.expect((Session.beginStage(state))).toBe(true)
					t.expect((Session.act(state, 1, "task_3", 1, 1))).toBe(false)
					local plan = state.plan :: Generator.Plan
					for _, activity in plan.activities do
						if activity.kind == "sequence" then
							for _, button in activity.order do
								Session.act(state, 1, activity.id, button, 1)
							end
						elseif activity.kind == "relay" then
							Session.act(state, 1, activity.id, 1, 1)
							Session.act(state, 2, activity.id, 1, 2)
						else
							while not state.tasks[activity.id].solved do
								Session.act(state, 1, activity.id, state.tasks[activity.id].progress + 1, 1)
							end
						end
					end
					t.expect(state.phase).toBe(if stage == 3 then "Extracting" else "Intermission")
				end
				for id = 1, players do
					Session.escape(state, id)
				end
				t.expect(state.phase).toBe("Won")
			end
		end)
		t.it("retains a changing map and unordered tasks in standard mode", function()
			local a = Generator.create(123, 1, 3)
			local b = Generator.create(124, 1, 3)
			t.expect(TableUtil.deepEqual(a.sector.rooms, b.sector.rooms)).toBe(false)
			local state = Session.new(123, { minPlayers = 3, maxPlayers = 8, downedSeconds = 45, relayWindow = 12 })
			for id = 1, 3 do
				Session.join(state, id)
			end
			Session.beginStage(state)
			local plan = state.plan :: Generator.Plan
			local activity = plan.activities[3]
			t.expect(
				(Session.act(state, 1, activity.id, if activity.kind == "sequence" then activity.order[1] else 1, 1))
			)
				.toBe(true)
		end)
		t.it("fits each cinematic inside the server's protected interval", function()
			for _, sequence in Story.Scenes do
				t.expect(Shots.duration(sequence)).toBe(Story.SceneSeconds)
			end
		end)
	end,
} :: TestKit.Spec
