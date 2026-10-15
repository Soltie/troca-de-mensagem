--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local CreatureBrain = require("@game/ServerScriptService/Server/Game/CreatureBrain")
local TestKit = require("../TestKit")

local C = Config.Creature
local PLAYER = { name = "player-pos" }
local NOISE = { name = "noise-pos" }

local function perception(overrides: { [string]: any }): CreatureBrain.Perception
	local p: { [string]: any } = {
		now = 0,
		canSee = false,
		lineOfSight = false,
		distance = 40,
		targetPos = PLAYER,
		noisePos = nil,
		hunt = false,
		arrived = false,
	}
	for key, value in overrides do
		p[key] = value
	end
	return p :: any
end

local function awake(): CreatureBrain.Brain
	local brain = CreatureBrain.new()
	CreatureBrain.activate(brain)
	return brain
end

local spec: TestKit.Spec = {
	name = "CreatureBrain",
	run = function(t)
		t.it("stays still while dormant", function()
			local brain = CreatureBrain.new()
			local cmd = CreatureBrain.step(brain, perception({ canSee = true, lineOfSight = true, distance = 2 }))
			t.expect(cmd.mode).toBe("Dormant")
			t.expect(cmd.speed).toBe(0)
		end)

		t.it("patrols after waking up", function()
			local cmd = CreatureBrain.step(awake(), perception({}))
			t.expect(cmd.mode).toBe("Patrol")
			t.expect(cmd.target).toBeNil()
			t.expect(cmd.speed).toBe(C.PatrolSpeed)
		end)

		t.it("chases on sight and reports 'spotted' once", function()
			local brain = awake()
			local first = CreatureBrain.step(brain, perception({ canSee = true, lineOfSight = true, now = 1 }))
			t.expect(first.mode).toBe("Chase")
			t.expect(first.event).toBe("spotted")
			t.expect(first.target).toBe(PLAYER)
			t.expect(first.speed).toBe(C.ChaseSpeed)
			local second = CreatureBrain.step(brain, perception({ canSee = true, lineOfSight = true, now = 1.2 }))
			t.expect(second.event).toBeNil()
		end)

		t.it("keeps tracking briefly, then goes to the last seen spot, then searches", function()
			local brain = awake()
			CreatureBrain.step(brain, perception({ canSee = true, lineOfSight = true, now = 10 }))
			local grace = CreatureBrain.step(brain, perception({ now = 10 + C.GraceTime * 0.5, targetPos = NOISE }))
			t.expect(grace.mode).toBe("Chase")
			t.expect(grace.target).toBe(NOISE) -- ainda segue a posição real logo após perder de vista
			local memory = CreatureBrain.step(brain, perception({ now = 10 + C.GraceTime + 0.5 }))
			t.expect(memory.mode).toBe("Chase")
			t.expect(memory.target).toBe(PLAYER) -- último lugar visto
			local lost = CreatureBrain.step(brain, perception({ now = 10 + C.LoseSightTime + 0.1 }))
			t.expect(lost.mode).toBe("Search")
			t.expect(lost.event).toBe("lost")
			local back = CreatureBrain.step(brain, perception({ now = 10 + C.LoseSightTime + C.SearchTime + 0.2 }))
			t.expect(back.mode).toBe("Patrol")
		end)

		t.it("investigates noise, then searches on arrival", function()
			local brain = awake()
			local cmd = CreatureBrain.step(brain, perception({ noisePos = NOISE }))
			t.expect(cmd.mode).toBe("Investigate")
			t.expect(cmd.target).toBe(NOISE)
			t.expect(cmd.speed).toBe(C.InvestigateSpeed)
			local going = CreatureBrain.step(brain, perception({ now = 1 }))
			t.expect(going.target).toBe(NOISE)
			local arrived = CreatureBrain.step(brain, perception({ now = 2, arrived = true }))
			t.expect(arrived.mode).toBe("Search")
		end)

		t.it("captures only when close AND with line of sight", function()
			local brain = awake()
			local blocked = CreatureBrain.step(brain, perception({ distance = 2, lineOfSight = false }))
			t.expect(blocked.mode ~= "Capture").toBe(true)
			t.expect(blocked.event).toBeNil()
			local caught =
				CreatureBrain.step(brain, perception({ distance = C.CaptureRange - 0.1, lineOfSight = true }))
			t.expect(caught.mode).toBe("Capture")
			t.expect(caught.event).toBe("capture")
			local after = CreatureBrain.step(brain, perception({ canSee = true, lineOfSight = true, distance = 1 }))
			t.expect(after.mode).toBe("Capture")
			t.expect(after.event).toBeNil() -- não dispara a captura de novo
			t.expect(after.speed).toBe(0)
		end)

		t.it("hunts without seeing once the power is back", function()
			local brain = awake()
			local cmd = CreatureBrain.step(brain, perception({ hunt = true }))
			t.expect(cmd.mode).toBe("Chase")
			t.expect(cmd.speed).toBe(C.HuntSpeed)
			t.expect(cmd.event).toBeNil()
		end)

		t.it("gets faster with each fuse", function()
			t.expect(CreatureBrain.speedFor("Patrol", 2, false)).toBeCloseTo(C.PatrolSpeed + 2 * C.PatrolSpeedPerFuse)
			t.expect(CreatureBrain.speedFor("Chase", 3, false)).toBeCloseTo(C.ChaseSpeed + 3 * C.ChaseSpeedPerFuse)
			t.expect(CreatureBrain.speedFor("Search", 3, false)).toBe(0)
		end)
	end,
}

return spec
