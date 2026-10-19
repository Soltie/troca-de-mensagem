--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local FearModel = require("@game/ReplicatedStorage/Shared/Game/FearModel")
local TestKit = require("../TestKit")

local F = Config.Fear

local function inputs(overrides: { [string]: any }): FearModel.Inputs
	local i: { [string]: any } = {
		creatureDistance = math.huge,
		creatureVisible = false,
		behindWall = false,
		chasing = false,
		darkness = 0,
		hidden = false,
		safe = false,
	}
	for key, value in overrides do
		i[key] = value
	end
	return i :: any
end

local function run(state: FearModel.State, i: FearModel.Inputs, seconds: number)
	local dt = 0.1
	for _ = 1, math.floor(seconds / dt) do
		FearModel.step(state, i, dt)
	end
end

local spec: TestKit.Spec = {
	name = "FearModel",
	run = function(t)
		t.it("stays calm with no threat and light", function()
			local s = FearModel.new()
			run(s, inputs({}), 10)
			t.expect(s.value).toBe(0)
			t.expect(s.level).toBe(0)
		end)

		t.it("rises with proximity, more when visible, floor during chase", function()
			local far = FearModel.target(inputs({ creatureDistance = 40 }))
			local near = FearModel.target(inputs({ creatureDistance = 8 }))
			local seen = FearModel.target(inputs({ creatureDistance = 8, creatureVisible = true }))
			t.expect(near > far).toBe(true)
			t.expect(seen > near).toBe(true)
			t.expect(FearModel.target(inputs({ chasing = true, creatureDistance = 60 })) >= F.ChaseFloor).toBe(true)
		end)

		t.it("walls between you and him soften the proximity fear", function()
			local open = FearModel.target(inputs({ creatureDistance = 10 }))
			local walled = FearModel.target(inputs({ creatureDistance = 10, behindWall = true }))
			t.expect(walled < open).toBe(true)
			t.expect(walled > 0).toBe(true)
			t.expect(
				FearModel.target(inputs({ creatureDistance = 10, behindWall = true, chasing = true })) >= F.ChaseFloor
			)
				.toBe(true)
		end)

		t.it("is always clamped to 0..1", function()
			local maxed = inputs({ creatureDistance = 0, creatureVisible = true, chasing = true, darkness = 5 })
			t.expect(FearModel.target(maxed) <= 1).toBe(true)
			local s = FearModel.new()
			FearModel.spike(s, 10)
			run(s, maxed, 5)
			t.expect(s.value <= 1 and s.value >= 0).toBe(true)
		end)

		t.it("rises fast and decays slowly", function()
			local s = FearModel.new()
			run(s, inputs({ chasing = true }), 2)
			local peak = s.value
			t.expect(peak > 0.6).toBe(true)
			run(s, inputs({}), 2)
			t.expect(s.value > peak * 0.6).toBe(true) -- 2 s depois ainda está alto
			run(s, inputs({ safe = true }), 40)
			t.expect(s.value < 0.05).toBe(true)
		end)

		t.it("safe places cap the target", function()
			local capped = FearModel.target(inputs({ creatureDistance = 10, darkness = 1, safe = true }))
			t.expect(capped <= F.SafeCeiling).toBe(true)
		end)

		t.it("spikes add on top and wear off", function()
			local s = FearModel.new()
			FearModel.spike(s, 0.4)
			t.expect(s.value).toBeCloseTo(0.4)
			run(s, inputs({}), 10)
			t.expect(s.spike < 0.4).toBe(true)
			run(s, inputs({}), 20)
			t.expect(s.spike).toBe(0)
		end)

		t.it("uses hysteresis between levels", function()
			local first = F.Levels[1]
			t.expect(FearModel.levelFor(first.enter + 0.01, 0)).toBe(1)
			-- Entre exit e enter: mantém o nível em que estava.
			local between = (first.enter + first.exit) / 2
			t.expect(FearModel.levelFor(between, 1)).toBe(1)
			t.expect(FearModel.levelFor(between, 0)).toBe(0)
			t.expect(FearModel.levelFor(first.exit - 0.01, 1)).toBe(0)
			t.expect(FearModel.levelFor(1, 0)).toBe(FearModel.MAX_LEVEL)
		end)

		t.it("reports level changes and resets", function()
			local s = FearModel.new()
			local changed = false
			for _ = 1, 30 do
				changed = FearModel.step(s, inputs({ chasing = true }), 0.1) or changed
			end
			t.expect(changed).toBe(true)
			t.expect(s.level >= 2).toBe(true)
			FearModel.reset(s)
			t.expect(s.value).toBe(0)
			t.expect(s.level).toBe(0)
		end)
	end,
}

return spec
