--!strict
-- Ganchos da campanha usados pelas vantagens pagas (Segunda Chance, Continuação) e pela bateria por nível.
local BatteryModel = require("@game/ReplicatedStorage/Shared/Game/BatteryModel")
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local TestKit = require("../TestKit")

local function party(count: number, stage: number?): Session.State
	local state = Session.new(9009, { minPlayers = 3, maxPlayers = 8, downedSeconds = 45, relayWindow = 12 })
	for id = 1, count do
		Session.join(state, id)
	end
	state.stage = (stage or 1) - 1
	Session.beginStage(state)
	return state
end

local spec: TestKit.Spec = {
	name = "CampaignPerks",
	run = function(t)
		t.it("second chance revives only a downed member, before the timer ends", function()
			local s = party(3)
			t.expect((Session.selfRevive(s, 1, 10))).toBe(false)
			Session.capture(s, 1, 10)
			t.expect(s.members[1].status).toBe("Downed")
			t.expect((Session.selfRevive(s, 1, 10 + 60))).toBe(false)
			t.expect((Session.selfRevive(s, 1, 13))).toBe(true)
			t.expect(s.members[1].status).toBe("Active")
			t.expect((Session.selfRevive(s, 1, 14))).toBe(false)
		end)
		t.it("the last survivor with a second chance does not end the run", function()
			local s = party(3)
			Session.capture(s, 1, 10)
			Session.capture(s, 2, 10)
			Session.capture(s, 3, 10, 5)
			t.expect(s.phase).toBe("Playing")
			Session.tick(s, 12)
			t.expect(s.phase).toBe("Playing")
			t.expect((Session.selfRevive(s, 3, 13))).toBe(true)
			t.expect(s.members[3].risingUntil).toBeNil()
			t.expect(s.phase).toBe("Playing")
		end)
		t.it("an expired second-chance window lets the defeat happen", function()
			local s = party(3)
			Session.capture(s, 1, 10)
			Session.capture(s, 2, 10)
			Session.capture(s, 3, 10, 5)
			Session.tick(s, 16)
			t.expect(s.phase).toBe("Lost")
		end)
		t.it("continue repeats the lost stage with the whole team", function()
			local s = party(3, 2)
			t.expect(s.stage).toBe(2)
			t.expect((Session.retryStage(s))).toBe(false)
			for id = 1, 3 do
				Session.capture(s, id, 10)
			end
			Session.tick(s, 100)
			t.expect(s.phase).toBe("Lost")
			local ok = Session.retryStage(s)
			t.expect(ok).toBe(true)
			t.expect(s.phase).toBe("Intermission")
			t.expect(s.stage).toBe(1)
			t.expect((Session.beginStage(s))).toBe(true)
			t.expect(s.stage).toBe(2)
			for id = 1, 3 do
				t.expect(s.members[id].status).toBe("Active")
			end
		end)
		t.it("lithium battery drains slower, never faster", function()
			local normal = BatteryModel.new(1)
			local lithium = BatteryModel.new(1)
			BatteryModel.setOn(normal, true)
			BatteryModel.setOn(lithium, true)
			BatteryModel.step(normal, 10)
			BatteryModel.step(lithium, 10, 1 / 1.75)
			t.expect(lithium.charge > normal.charge).toBe(true)
			local abuse = BatteryModel.new(1)
			BatteryModel.setOn(abuse, true)
			BatteryModel.step(abuse, 10, 5)
			t.expect(abuse.charge).toBeCloseTo(normal.charge)
		end)
	end,
}

return spec
