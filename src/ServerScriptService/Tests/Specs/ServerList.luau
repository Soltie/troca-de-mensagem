--!strict
local ServerList = require("@game/ReplicatedStorage/Shared/Game/ServerList")
local TestKit = require("../TestKit")

local JOB_A = "aaaaaaaa-0000-0000-0000-000000000001"
local JOB_B = "bbbbbbbb-0000-0000-0000-000000000002"
local JOB_C = "cccccccc-0000-0000-0000-000000000003"
local SELF = "ffffffff-0000-0000-0000-00000000000f"

local function entry(job: string, players: number, phase: string, updated: number): ServerList.Entry
	return { job = job, players = players, max = 8, mode = "", phase = phase, stage = 0, updated = updated }
end

local testSpec: TestKit.Spec = {
	name = "ServerList",
	run = function(t)
		t.it("validates job ids and decodes only sane records", function()
			t.expect(ServerList.validJob(JOB_A)).toBe(true)
			t.expect(ServerList.validJob("studio")).toBe(false)
			t.expect(ServerList.validJob("../../etc/passwd-0000-0000-0000-0000")).toBe(false)
			t.expect(ServerList.decode("x", JOB_A)).toBeNil()
			t.expect(ServerList.decode({ players = 3, max = 8, updated = 1 }, "nope")).toBeNil()
			t.expect(ServerList.decode({ players = 0 / 0, max = 8, updated = 1 }, JOB_A)).toBeNil()
			local decoded = ServerList.decode(
				{ players = 12, max = 8, updated = 5, phase = "Hacked", mode = "Story", stage = 77 },
				JOB_A
			)
			t.expect(decoded ~= nil).toBe(true)
			if decoded then
				t.expect(decoded.players).toBe(8)
				t.expect(decoded.phase).toBe("Lobby")
				t.expect(decoded.mode).toBe("Story")
				t.expect(decoded.stage).toBe(9)
			end
		end)
		t.it("joinable refuses self, stale and full servers", function()
			local now = 1000
			t.expect((ServerList.joinable(entry(JOB_A, 3, "Lobby", now), JOB_A, now))).toBe(false)
			local _, stale = ServerList.joinable(entry(JOB_A, 3, "Lobby", now - ServerList.TTL - 1), SELF, now)
			t.expect(stale).toBe("server_gone")
			local _, full = ServerList.joinable(entry(JOB_A, 8, "Lobby", now), SELF, now)
			t.expect(full).toBe("server_full")
			t.expect((ServerList.joinable(entry(JOB_A, 7, "Playing", now), SELF, now))).toBe(true)
		end)
		t.it("sorts open lobbies first, then fuller servers, hiding self and stale", function()
			local now = 500
			local list = ServerList.sorted({
				entry(JOB_A, 6, "Playing", now),
				entry(JOB_B, 2, "Lobby", now),
				entry(JOB_C, 8, "Lobby", now),
				entry(SELF, 4, "Lobby", now),
				entry("dddddddd-0000-0000-0000-000000000004", 5, "Lobby", now - 999),
			}, SELF, now)
			t.expect(#list).toBe(3)
			t.expect(list[1].job).toBe(JOB_B)
			t.expect(list[2].job).toBe(JOB_A)
			t.expect(list[3].job).toBe(JOB_C)
		end)
	end,
}

return testSpec
