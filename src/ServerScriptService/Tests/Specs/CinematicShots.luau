--!strict
local CinematicShots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local TestKit = require("../TestKit")

local SEQUENCES = { CinematicShots.Opening, CinematicShots.Stage, CinematicShots.Escape, CinematicShots.Attract }

local testSpec: TestKit.Spec = {
	name = "CinematicShots",
	run = function(t)
		t.it("easing curves start at 0, end at 1 and clamp outside", function()
			local eases: { CinematicShots.Ease } = { "linear", "inOut", "out", "in" }
			for _, kind in eases do
				t.expect(CinematicShots.ease(kind :: CinematicShots.Ease, 0)).toBeCloseTo(0)
				t.expect(CinematicShots.ease(kind :: CinematicShots.Ease, 1)).toBeCloseTo(1)
				t.expect(CinematicShots.ease(kind :: CinematicShots.Ease, -3)).toBeCloseTo(0)
				t.expect(CinematicShots.ease(kind :: CinematicShots.Ease, 7)).toBeCloseTo(1)
				local previous = -1
				for i = 0, 10 do
					local value = CinematicShots.ease(kind :: CinematicShots.Ease, i / 10)
					t.expect(value >= previous).toBe(true)
					previous = value
				end
			end
		end)
		t.it("sample hits both ends of each shot", function()
			for _, sequence in SEQUENCES do
				for _, s in sequence.shots do
					local p0, l0 = CinematicShots.sample(s, 0)
					local p1, l1 = CinematicShots.sample(s, 1)
					t.expect(p0.x).toBeCloseTo(s.from.x)
					t.expect(p0.z).toBeCloseTo(s.from.z)
					t.expect(l0.y).toBeCloseTo(s.lookFrom.y)
					t.expect(p1.y).toBeCloseTo(s.to.y)
					t.expect(l1.x).toBeCloseTo(s.lookTo.x)
				end
			end
		end)
		t.it("locate walks through shots and reports the end", function()
			local seq = CinematicShots.Opening
			local first = seq.shots[1].duration
			local index, alpha, done = CinematicShots.locate(seq, 0)
			t.expect(index).toBe(1)
			t.expect(alpha).toBeCloseTo(0)
			t.expect(done).toBe(false)
			index, alpha, done = CinematicShots.locate(seq, first + 0.5)
			t.expect(index).toBe(2)
			t.expect(alpha).toBeCloseTo(0.5 / seq.shots[2].duration)
			t.expect(done).toBe(false)
			index, alpha, done = CinematicShots.locate(seq, CinematicShots.duration(seq) + 1)
			t.expect(index).toBe(#seq.shots)
			t.expect(alpha).toBe(1)
			t.expect(done).toBe(true)
		end)
		t.it("sequences fit the windows the game gives them", function()
			-- Abertura cabe na cartela solo (9 s, com folga de 1 s); etapa cabe no congelamento (>= 3 s).
			t.expect(math.abs(CinematicShots.duration(CinematicShots.Opening) - 9) <= 1).toBe(true)
			t.expect(CinematicShots.duration(CinematicShots.Stage) <= 4).toBe(true)
			t.expect(CinematicShots.duration(CinematicShots.Escape) <= 6).toBe(true)
		end)
		t.it("cameras stay outside the building and above the ground", function()
			-- Núcleo do prédio: x -68..72, z <= 0 (o interior é sorteado e não pode aparecer).
			for _, sequence in SEQUENCES do
				for _, s in sequence.shots do
					for _, p in { s.from, s.to } do
						t.expect(p.z > 2).toBe(true)
						t.expect(p.y > 2).toBe(true)
					end
					local dx, dy, dz = s.lookFrom.x - s.from.x, s.lookFrom.y - s.from.y, s.lookFrom.z - s.from.z
					t.expect(dx * dx + dy * dy + dz * dz > 4).toBe(true)
					t.expect(#s.label > 0).toBe(true)
				end
			end
		end)
		t.it("security cameras step on a 12 fps grid; handheld shots do not", function()
			for _, s in CinematicShots.Attract.shots do
				t.expect(CinematicShots.isCctv(s)).toBe(true)
			end
			t.expect(CinematicShots.isCctv(CinematicShots.Opening.shots[1])).toBe(false)
			t.expect(CinematicShots.quantize(0, 5, 12)).toBe(0)
			t.expect(CinematicShots.quantize(1, 5, 12)).toBe(1)
			-- 60 quadros em 5 s: 0.0101 ainda está no quadro 0; 0.0167 já é o quadro 1.
			t.expect(CinematicShots.quantize(0.0101, 5, 12)).toBe(0)
			t.expect(CinematicShots.quantize(1 / 60, 5, 12)).toBeCloseTo(1 / 60)
			t.expect(CinematicShots.quantize(7, 5, 12)).toBe(1)
		end)
		t.it("attract loops forever and captions split the running time", function()
			local total = CinematicShots.duration(CinematicShots.Attract)
			t.expect(CinematicShots.wrap(CinematicShots.Attract, total + 1.5)).toBeCloseTo(1.5)
			t.expect(CinematicShots.wrap(CinematicShots.Attract, -3)).toBe(0)
			local lines = { "a", "b", "c" }
			t.expect(CinematicShots.caption(lines, 0, 9)).toBe("a")
			t.expect(CinematicShots.caption(lines, 3.1, 9)).toBe("b")
			t.expect(CinematicShots.caption(lines, 9, 9)).toBe("c")
			t.expect(CinematicShots.caption(lines, 50, 9)).toBe("c")
			t.expect(CinematicShots.caption(nil, 1, 9)).toBeNil()
			t.expect(CinematicShots.caption({}, 1, 9)).toBeNil()
			t.expect(#(CinematicShots.Opening.captions or {}) > 0).toBe(true)
		end)
		t.it("tape clock formats and wraps at midnight", function()
			t.expect(CinematicShots.clock(CinematicShots.TAPE_START)).toBe("03:12:00")
			t.expect(CinematicShots.clock(CinematicShots.TAPE_START + 75.9)).toBe("03:13:15")
			t.expect(CinematicShots.clock(86400 + 5)).toBe("00:00:05")
			t.expect(CinematicShots.clock(-10)).toBe("00:00:00")
		end)
	end,
}

return testSpec
