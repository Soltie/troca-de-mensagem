--!strict
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Plan = require("@game/ServerScriptService/Server/Campaign/HousePlan")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Modes = require("@game/ReplicatedStorage/Shared/Game/GameModes")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local Oxygen = require("@game/ServerScriptService/Server/Game/Oxygen")
local TestKit = require("../TestKit")
return {
	name = "StoryMode",
	run = function(t: TestKit.Context)
		t.it("solo starts with one vote, ties wait, outsiders do not vote", function()
			t.expect((Modes.winner({ [1] = "Story" }, { [1] = {} }, Config.Campaign.minPlayers))).toBe("Story")
			t.expect((Modes.winner({ [1] = "Story", [2] = "Standard" }, { [1] = {}, [2] = {} }, 1))).toBe(nil)
			t.expect((Modes.winner({ [99] = "Story" }, { [1] = {} }, 1))).toBe(nil)
		end)
		t.it("finishes all five chapters with 1, 2 and 6 survivors and no duplicated pickups", function()
			for _, count in { 1, 2, 6 } do
				for _, mode in { "Story", "Standard" } do
					local s = Session.new(90312, Config.Campaign, mode, true)
					for id = 1, count do
						t.expect((Session.join(s, id))).toBe(true)
					end
					for chapter = 1, 5 do
						t.expect((Session.beginStage(s))).toBe(true)
						local plan = s.plan
						assert(plan, "Expected house plan")
						t.expect((Plan.validate(plan))).toBe(true)
						t.expect((Session.act(s, 1, plan.activities[2].id, 1, 1))).toBe(false)
						for _, spec in plan.activities do
							if spec.kind == "puzzle" or spec.kind == "repair" then
								local wrong = spec.order[1] % 4 + 1
								t.expect((Session.act(s, 1, spec.id, wrong, 1))).toBe(false)
								for _, button in spec.order do
									t.expect((Session.act(s, 1, spec.id, button, 1))).toBe(true)
								end
							else
								t.expect((Session.act(s, 1, spec.id, 1, 1))).toBe(true)
							end
							t.expect((Session.act(s, 1, spec.id, 1, 1))).toBe(false)
						end
						t.expect(s.phase).toBe(if chapter == 5 then "Extracting" else "Intermission")
					end
					t.expect(s.inventory.artifact).toBe(1)
					for id = 1, count do
						Session.escape(s, id)
					end
					t.expect(s.phase).toBe("Won")
				end
			end
		end)
		t.it("many seeds retain prerequisites, room bounds and reproducible four-symbol solutions", function()
			for seed = 1, 120 do
				for chapter = 1, 5 do
					local a = Plan.create(seed, chapter, 1, "Standard")
					local b = Plan.create(seed, chapter, 6, "Standard")
					t.expect((Plan.validate(a))).toBe(true)
					t.expect(a.activities).toEqual(b.activities)
					local occupied: { [string]: boolean } = {}
					for _, activity in a.activities do
						if activity.kind ~= "hide" and activity.kind ~= "breath" then
							local point = `{activity.x}:{activity.y}:{activity.z}`
							t.expect(occupied[point]).toBe(nil)
							occupied[point] = true
						end
						t.expect(math.abs(activity.x) <= 100 and activity.z >= -112 and activity.z <= 80).toBe(true)
						t.expect(
							activity.y == -16
								or activity.y == 0
								or activity.y == 8
								or activity.y == 16
								or activity.y == 32
						).toBe(true)
						if activity.kind == "puzzle" then
							local seen = {}
							for _, symbol in activity.order do
								seen[symbol] = true
							end
							for symbol = 1, 4 do
								t.expect(seen[symbol]).toBe(true)
							end
						end
					end
				end
			end
		end)
		t.it("checkpoint restores the same code and removes unfinished chapter items", function()
			local s = Session.new(123, Config.Campaign, "Standard", true)
			Session.join(s, 1)
			Session.beginStage(s)
			local before = s.plan
			Session.act(s, 1, "task_1", 1, 1)
			Session.act(s, 1, "task_2", 1, 1)
			t.expect(s.inventory.flashlight).toBe(1)
			Session.eliminate(s, 1)
			t.expect(s.phase).toBe("Lost")
			Session.retryStage(s)
			Session.beginStage(s)
			t.expect(s.plan).toEqual(before)
			t.expect(s.inventory.flashlight).toBe(nil)
		end)
		t.it("oxygen consumes eight seconds, cancels with cooldown, and cannot spam silence", function()
			local o = Oxygen.new()
			t.expect(Oxygen.request(o, true, 0)).toBe(true)
			Oxygen.step(o, 6, 6)
			t.expect(o.value).toBe(25)
			Oxygen.request(o, false, 6)
			t.expect(Oxygen.request(o, true, 6.1)).toBe(false)
			Oxygen.step(o, 1, 7)
			t.expect(o.value).toBe(25)
			Oxygen.step(o, 1, 9)
			t.expect(o.value).toBe(45)
			t.expect(Oxygen.request(o, true, 9)).toBe(true)
			t.expect(Oxygen.step(o, 8, 17)).toBe(true)
			t.expect(o.dead).toBe(true)
			t.expect(Oxygen.request(o, true, 18)).toBe(false)
		end)
		t.it("v4 migration preserves wallet purchases and old story separately from new house", function()
			local old: any = Schema.template()
			old.schemaVersion, old.house = 4, nil
			old.wallet.fichas, old.owned.lanterna_elias = 1234, true
			old.story.cleared["1"] = 100
			old.purchases.receipt = 200
			local migrated = Schema.migrate(old)
			t.expect(migrated.wallet.fichas).toBe(1234)
			t.expect(migrated.owned.lanterna_elias).toBe(true)
			t.expect(migrated.story.cleared["1"]).toBe(100)
			t.expect(migrated.house.cleared["1"]).toBe(nil)
			t.expect(migrated.purchases.receipt).toBe(200)
		end)
		t.it("preferences reject corruption and preserve fractional audio volumes", function()
			local Prefs = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
			local migrated = Schema.migrate({
				house = { preferences = { music = 0.75, master = 1, bad = 1, ambient = 0 / 0, effects = 2 } },
			})
			t.expect(migrated.house.preferences.music).toBe(0.75)
			t.expect(migrated.house.preferences.bad).toBe(nil)
			t.expect(migrated.house.preferences.ambient).toBe(nil)
			t.expect(Prefs.category("Breath1")).toBe("breathing")
			t.expect(Prefs.category("MusicChase")).toBe("music")
		end)
		t.it("house rejects seventh player and disconnect cannot lose essential team items", function()
			local s = Session.new(42, Config.Campaign, "Story", true)
			for id = 1, 6 do
				t.expect((Session.join(s, id))).toBe(true)
			end
			t.expect((Session.join(s, 7))).toBe(false)
			Session.beginStage(s)
			Session.act(s, 1, "task_1", 1, 0)
			Session.act(s, 1, "task_2", 1, 0)
			Session.leave(s, 1)
			t.expect(s.inventory.flashlight).toBe(1)
			t.expect(s.phase).toBe("Playing")
		end)
		t.it("five chapter scenes fit their shared server interval", function()
			t.expect(#Story.Chapters).toBe(5)
			for _, scene in Story.Scenes do
				t.expect(Shots.duration(scene)).toBe(Story.SceneSeconds)
			end
		end)
	end,
} :: TestKit.Spec
