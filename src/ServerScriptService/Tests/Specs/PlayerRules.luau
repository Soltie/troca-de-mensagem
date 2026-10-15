--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local PlayerRules = require("@game/ServerScriptService/Server/Game/PlayerRules")
local TestKit = require("../TestKit")

local P = Config.Player

local spec: TestKit.Spec = {
	name = "PlayerRules",
	run = function(t)
		t.it("crouching lowers the speed limit", function()
			t.expect(PlayerRules.maxSpeed("Crouch") < PlayerRules.maxSpeed("Stand")).toBe(true)
			t.expect(PlayerRules.walkSpeed("Crouch")).toBe(P.CrouchSpeed)
			t.expect(PlayerRules.walkSpeed("Stand")).toBe(P.WalkSpeed)
		end)

		t.it("tolerates short bursts and corrects sustained overspeed", function()
			local check = PlayerRules.newSpeedCheck()
			local limit = PlayerRules.maxSpeed("Stand")
			t.expect(PlayerRules.checkSpeed(check, limit, limit, 0)).toBe("ok")
			t.expect(PlayerRules.checkSpeed(check, limit * 3, limit, 1)).toBe("over")
			t.expect(PlayerRules.checkSpeed(check, limit * 3, limit, 1 + P.SpeedGrace * 0.5)).toBe("over")
			t.expect(PlayerRules.checkSpeed(check, limit * 3, limit, 1 + P.SpeedGrace)).toBe("correct")
			-- Volta ao normal: zera a contagem.
			t.expect(PlayerRules.checkSpeed(check, limit, limit, 5)).toBe("ok")
			t.expect(check.overSince).toBeNil()
			-- NaN não é tratado como excesso.
			t.expect(PlayerRules.checkSpeed(check, 0 / 0, limit, 6)).toBe("ok")
		end)

		t.it("holding breath: max duration, forced gasp and cooldown", function()
			local b = PlayerRules.newBreath()
			t.expect(PlayerRules.holdBreath(b, 0)).toBe(true)
			t.expect(PlayerRules.holdBreath(b, 0.1)).toBe(false)
			t.expect(PlayerRules.stepBreath(b, P.HoldBreathMax - 0.1)).toBeNil()
			t.expect(PlayerRules.stepBreath(b, P.HoldBreathMax)).toBe("gasp")
			t.expect(b.holding).toBe(false)
			t.expect(PlayerRules.holdBreath(b, P.HoldBreathMax + 0.5)).toBe(false)
			t.expect(PlayerRules.holdBreath(b, P.HoldBreathMax + P.HoldBreathCooldown)).toBe(true)
		end)

		t.it("voluntary release has a shorter cooldown and no gasp", function()
			local b = PlayerRules.newBreath()
			PlayerRules.holdBreath(b, 0)
			PlayerRules.releaseBreath(b, 2)
			t.expect(b.holding).toBe(false)
			t.expect(PlayerRules.stepBreath(b, 100)).toBeNil()
			t.expect(PlayerRules.holdBreath(b, 2 + P.HoldBreathCooldown * 0.5)).toBe(true)
		end)
	end,
}

return spec
