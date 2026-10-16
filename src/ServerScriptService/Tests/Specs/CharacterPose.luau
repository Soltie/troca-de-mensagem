--!strict
local CharacterPose = require("@game/ReplicatedStorage/Shared/Game/CharacterPose")
local TestKit = require("../TestKit")

local testSpec: TestKit.Spec = {
	name = "CharacterPose",
	run = function(t)
		t.it("quantizes pitch to the network step and clamps it", function()
			t.expect(CharacterPose.quantizePitch(0)).toBe(0)
			t.expect(CharacterPose.quantizePitch(4.9)).toBe(4)
			t.expect(CharacterPose.quantizePitch(-5.2)).toBe(-6)
			t.expect(CharacterPose.quantizePitch(500)).toBe(CharacterPose.MAX_PITCH)
			t.expect(CharacterPose.quantizePitch(-500)).toBe(-CharacterPose.MAX_PITCH)
			t.expect(CharacterPose.quantizePitch(0 / 0)).toBe(0)
		end)
		t.it("sends only on change, never faster than the interval", function()
			t.expect(CharacterPose.shouldSend(nil, 0, 0)).toBe(false)
			t.expect(CharacterPose.shouldSend(nil, 0, 0.2)).toBe(true)
			t.expect(CharacterPose.shouldSend(9, 9, 0.5)).toBe(false)
			t.expect(CharacterPose.shouldSend(9, 12, 0.05)).toBe(false)
			t.expect(CharacterPose.shouldSend(9, 12, 0.2)).toBe(true)
			-- Batimento: reenvia o mesmo valor depois de HEARTBEAT segundos.
			t.expect(CharacterPose.shouldSend(9, 9, CharacterPose.HEARTBEAT)).toBe(true)
		end)
		t.it("crouch bends just enough, then lifts the visible body", function()
			local angle, lift = CharacterPose.crouch(2, 0)
			t.expect(angle).toBe(0)
			t.expect(lift).toBe(0)
			-- Queda pequena: dobra sem levantar e as pernas encurtam exatamente a queda.
			angle, lift = CharacterPose.crouch(2, 0.4)
			t.expect(lift).toBeCloseTo(0)
			t.expect(2 * (1 - math.cos(angle))).toBeCloseTo(0.4)
			-- Queda grande: para na dobra máxima e o resto vira lift.
			angle, lift = CharacterPose.crouch(1.7, 1.6)
			t.expect(angle).toBeCloseTo(CharacterPose.MAX_CROUCH)
			t.expect(lift).toBeCloseTo(1.6 - 1.7 * (1 - math.cos(CharacterPose.MAX_CROUCH)))
			t.expect(lift > 0).toBe(true)
		end)
		t.it("leans only above walking speed", function()
			t.expect(CharacterPose.lean(8, 10, 18)).toBe(0)
			t.expect(CharacterPose.lean(14, 10, 18)).toBeCloseTo(6)
			t.expect(CharacterPose.lean(40, 10, 18)).toBeCloseTo(12)
			t.expect(CharacterPose.lean(40, 10, 10)).toBe(0)
		end)
		t.it("splits pitch between neck and waist and approaches smoothly", function()
			local neck, waist = CharacterPose.split(40)
			t.expect(neck + waist).toBeCloseTo(40)
			t.expect(neck > waist).toBe(true)
			local value = CharacterPose.approach(0, 10, 8, 1 / 60)
			t.expect(value > 0 and value < 10).toBe(true)
			t.expect(CharacterPose.approach(0, 10, 8, 10)).toBeCloseTo(10)
			t.expect(CharacterPose.approach(3, 10, 8, 0)).toBe(3)
		end)
	end,
}

return testSpec
