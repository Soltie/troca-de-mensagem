--!strict
local Threat = require("@game/ReplicatedStorage/Shared/Game/ForestThreat")
local Forest = require("@game/ReplicatedStorage/Shared/Game/ForestCatalog")
local Layout = require("@game/ServerScriptService/Server/World/ForestLayout")
local Plan = require("@game/ServerScriptService/Server/Campaign/ForestPlan")
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Cinema = require("@game/ReplicatedStorage/Shared/Game/ForestCinema")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local TestKit = require("../TestKit")
return {
	name = "ForestHorror",
	run = function(t: TestKit.Context)
		t.it("forest pressure escalates without changing the house or moving a stationary creature", function()
			t.expect(Threat.speed(5, "Chase", 18)).toBe(18)
			t.expect(Threat.speed(8, "Search", 0)).toBe(0)
			t.expect(Threat.speed(8, "Chase", 18) < Config.Player.SprintSpeed).toBe(true)
			t.expect(Threat.speed(8, "Patrol", 8) > Threat.speed(6, "Patrol", 8)).toBe(true)
			for chapter = 6, 8 do
				t.expect(Threat.dark(0, chapter)).toBe(true)
				t.expect(Threat.dark(7, chapter)).toBe(false)
			end
		end)
		t.it("dense tree pockets coexist with every objective approach and six shelter entrances", function()
			for seed = 1, 20 do
				local clear = Layout.clearings(seed)
				for chapter = 6, 8 do
					for _, mode in { "Story", "Standard" } do
						for _, spec in Plan.create(seed, chapter, 6, mode).activities do
							t.expect(Layout.reserved(spec.x, spec.z + 5, clear)).toBe(true)
						end
					end
				end
				for _, hide in Forest.Hides do
					t.expect(Layout.reserved(hide.x, hide.z + 6, clear)).toBe(true)
				end
				local pockets = 0
				for x = -65, 65, 5 do
					for z = 550, 850, 5 do
						if not Layout.reserved(x, z, clear) then
							pockets += 1
						end
					end
				end
				t.expect(pockets > 150).toBe(true)
			end
		end)
		t.it(
			"new forest tasks reject skipped dependencies, retain puzzle progress and still reach extraction",
			function()
				for _, mode in { "Story", "Standard" } do
					for _, players in { 1, 2, 6 } do
						local state = Session.new(42, Config.Campaign, mode, true)
						for id = 1, players do
							Session.join(state, id)
						end
						state.stage, state.phase = 5, "Intermission"
						for chapter = 6, 8 do
							Session.beginStage(state)
							t.expect(state.stage).toBe(chapter)
							local plan = state.plan
							assert(plan, "Missing plan")
							t.expect(#plan.activities >= 8).toBe(true)
							t.expect((Session.act(state, 1, plan.activities[#plan.activities].id, 1, 0))).toBe(false)
							for _, spec in plan.activities do
								if spec.kind == "puzzle" then
									t.expect(#spec.order).toBe(4)
									Session.act(state, 1, spec.id, spec.order[1], 0)
									Session.act(state, 1, spec.id, spec.order[1], 1)
									t.expect(state.tasks[spec.id].progress).toBe(1)
									for step = 2, 4 do
										Session.act(state, 1, spec.id, spec.order[step], step)
									end
								else
									for _, button in spec.order do
										t.expect((Session.act(state, 1, spec.id, button, 0))).toBe(true)
									end
								end
							end
						end
						t.expect(state.phase).toBe("Extracting")
						for id = 1, players do
							Session.escape(state, id)
						end
						t.expect(state.phase).toBe("Won")
					end
				end
			end
		)
		t.it("the complete two-pursuer epilogue fits before the automatic lobby return", function()
			local captions = Cinema.captions
			assert(captions, "Epilogue captions missing")
			t.expect(#Cinema.shots).toBe(4)
			t.expect(Shots.duration(Cinema) + 8 < Config.Campaign.EndingSeconds).toBe(true)
			t.expect(string.find(captions[3], "Crocodilo Armadilho", 1, true) ~= nil).toBe(true)
			t.expect(string.find(captions[4], "A MANSÃO DO ARMADILHO", 1, true) ~= nil).toBe(true)
		end)
	end,
} :: TestKit.Spec
