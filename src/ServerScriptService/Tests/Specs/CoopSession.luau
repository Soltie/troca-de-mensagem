--!strict
local Session = require("@game/ServerScriptService/Server/Campaign/CoopSession")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local TestKit = require("../TestKit")

local function party(count: number, stage: number?): Session.State
	local state = Session.new(9009, Config.Campaign)
	for id = 1, count do
		Session.join(state, id)
	end
	state.stage = (stage or 1) - 1
	Session.beginStage(state)
	return state
end

local function complete(state: Session.State)
	local plan = state.plan
	assert(plan, "Expected a stage plan")
	for _, spec in plan.activities do
		if spec.kind == "sequence" then
			for _, button in spec.order do
				Session.act(state, 1, spec.id, button, 1)
			end
		elseif spec.kind == "relay" then
			Session.act(state, 1, spec.id, 1, 1)
			Session.act(state, 2, spec.id, 1, 2)
		else
			for _ = 1, 3 do
				Session.act(state, 1, spec.id, 1, 1)
			end
		end
	end
end

local spec: TestKit.Spec = {
	name = "CoopSession",
	run = function(t)
		t.it("waits for a partner, starts with two players and refuses a ninth member", function()
			local s = party(1)
			t.expect(s.phase).toBe("Lobby")
			Session.join(s, 2)
			t.expect((Session.beginStage(s))).toBe(true)
			for id = 3, 8 do
				t.expect((Session.join(s, id))).toBe(true)
			end
			t.expect((Session.join(s, 9))).toBe(false)
		end)
		t.it("downing one person does not end another person's game", function()
			local s = party(3)
			t.expect((Session.capture(s, 1, 0))).toBe(true)
			t.expect(s.phase).toBe("Playing")
			t.expect(s.members[2].status).toBe("Active")
			t.expect((Session.capture(s, 1, 0))).toBe(false)
		end)
		t.it("allows a different active member to rescue before the deadline", function()
			local s = party(3)
			Session.capture(s, 1, 0)
			t.expect((Session.revive(s, 1, 1, 1))).toBe(false)
			t.expect((Session.revive(s, 2, 1, 5))).toBe(true)
			t.expect(s.members[1].status).toBe("Active")
			t.expect((Session.revive(s, 2, 1, 6))).toBe(false)
		end)
		t.it("rejects expired rescue and returns eliminated members next stage", function()
			local s = party(3)
			Session.capture(s, 3, 0)
			t.expect((Session.revive(s, 2, 3, 45))).toBe(false)
			Session.tick(s, 45)
			t.expect(s.members[3].status).toBe("Waiting")
			complete(s)
			t.expect((Session.beginStage(s))).toBe(true)
			t.expect(s.members[3].status).toBe("Active")
		end)
		t.it("requires two distinct members at a relay when the team can cooperate", function()
			local s = party(3, 2)
			local plan = s.plan :: any
			local id = plan.activities[1].id
			t.expect((Session.act(s, 1, id, 1, 0))).toBe(true)
			t.expect((Session.act(s, 1, id, 1, 1))).toBe(false)
			t.expect((Session.act(s, 2, id, 1, 2))).toBe(true)
			t.expect(s.tasks[id].solved).toBe(true)
			t.expect((Session.act(s, 3, id, 1, 3))).toBe(false)
		end)
		t.it("expires relay approvals and clears approvals on disconnect", function()
			local s = party(3, 2)
			local id = (s.plan :: any).activities[1].id
			Session.act(s, 1, id, 1, 0)
			Session.act(s, 2, id, 1, 20)
			t.expect(s.tasks[id].solved).toBe(false)
			Session.leave(s, 2)
			t.expect(s.tasks[id].relayBy).toBeNil()
		end)
		t.it("allows a last survivor to finish relays after teammates disconnect", function()
			local s = party(3, 2)
			local id = (s.plan :: any).activities[1].id
			Session.leave(s, 2)
			Session.leave(s, 3)
			Session.act(s, 1, id, 1, 0)
			t.expect((Session.act(s, 1, id, 1, 1))).toBe(true)
			t.expect(s.tasks[id].solved).toBe(true)
		end)
		t.it("resets only the wrong sequence and rejects invalid actions", function()
			local s = party(3)
			local activity = (s.plan :: any).activities[2]
			Session.act(s, 1, activity.id, activity.order[1], 0)
			local wrong = activity.order[1]
			t.expect((Session.act(s, 1, activity.id, wrong, 1))).toBe(false)
			t.expect(s.tasks[activity.id].progress).toBe(0)
			t.expect((Session.act(s, 1, activity.id, 0 / 0, 1))).toBe(false)
			t.expect((Session.act(s, 1, activity.id, 1, math.huge))).toBe(false)
		end)
		t.it("keeps late joins waiting without changing the current puzzle plan", function()
			local s = party(3)
			local plan = s.plan
			Session.join(s, 4)
			t.expect(s.plan).toBe(plan)
			t.expect(s.members[4].status).toBe("Waiting")
			t.expect((Session.act(s, 4, "task_1", 1, 1))).toBe(false)
		end)
		t.it("requires all active survivors to escape, then completes the campaign", function()
			local s = party(3, 3)
			complete(s)
			t.expect(s.phase).toBe("Extracting")
			Session.escape(s, 1)
			t.expect(s.phase).toBe("Extracting")
			Session.escape(s, 2)
			t.expect(s.phase).toBe("Extracting")
			Session.escape(s, 3)
			t.expect(s.phase).toBe("Won")
		end)
		t.it("does not silently discard a downed teammate on the first escape", function()
			local s = party(3, 3)
			complete(s)
			Session.capture(s, 3, 0)
			Session.escape(s, 1)
			Session.escape(s, 2)
			t.expect(s.phase).toBe("Extracting")
			Session.tick(s, 45)
			t.expect(s.phase).toBe("Won")
		end)
		t.it("ends on a team wipe and requires a majority restart vote", function()
			local s = party(3)
			for id = 1, 3 do
				Session.capture(s, id, 0)
			end
			t.expect(s.phase).toBe("Lost")
			t.expect((Session.voteRestart(s, 1))).toBe(false)
			t.expect((Session.voteRestart(s, 1))).toBe(false)
			t.expect((Session.voteRestart(s, 2))).toBe(true)
		end)
		t.it("runs all stages for each party size from 2 to 8", function()
			for size = 2, 8 do
				local s = party(size)
				for stage = 1, 3 do
					t.expect(s.stage).toBe(stage)
					complete(s)
					if stage < 3 then
						t.expect((Session.beginStage(s))).toBe(true)
					end
				end
				for id = 1, size do
					Session.escape(s, id)
				end
				t.expect(s.phase).toBe("Won")
			end
		end)
		t.it("returns an empty party to a fresh lobby instead of a completed stage", function()
			local s = party(3, 3)
			for id = 1, 3 do
				Session.leave(s, id)
			end
			t.expect(s.phase).toBe("Lobby")
			t.expect(s.stage).toBe(0)
			t.expect(s.plan).toBeNil()
			for id = 4, 6 do
				Session.join(s, id)
			end
			t.expect((Session.beginStage(s))).toBe(true)
			t.expect(s.stage).toBe(1)
		end)
	end,
}

return spec
