--!strict
local Rewards = require("@game/ReplicatedStorage/Shared/Game/TaskRewards")
local TestKit = require("../TestKit")
return {
	name = "TaskRewards",
	run = function(t)
		t.it("shares completion rewards and gives each helper the same fixed bonus", function()
			t.expect(Rewards.reward(false)).toEqual({ fichas = 12, xp = 24 })
			t.expect(Rewards.reward(true)).toEqual({ fichas = 20, xp = 40 })
		end)
		t.it("pays once across duplicate completion and continuation of the same stage", function()
			local ledger: Rewards.Ledger = {}
			local count = 0
			local function grant(): boolean
				count += 1
				return true
			end
			t.expect(Rewards.claim(ledger, "1:task_1", 7, grant)).toBe(true)
			t.expect(Rewards.claim(ledger, "1:task_1", 7, grant)).toBe(false)
			t.expect(count).toBe(1)
			t.expect(Rewards.claim(ledger, "1:task_1", 8, grant)).toBe(true)
			t.expect(Rewards.claim(ledger, "2:task_1", 7, grant)).toBe(true)
			t.expect(Rewards.claim({}, "1:task_1", 7, grant)).toBe(true)
		end)
		t.it("does not consume a reward if the player profile is not ready", function()
			local ledger: Rewards.Ledger = {}
			t.expect(Rewards.claim(ledger, "1:task_1", 7, function()
				return false
			end)).toBe(false)
			t.expect(Rewards.claim(ledger, "1:task_1", 7, function()
				return true
			end)).toBe(true)
		end)
	end,
} :: TestKit.Spec
