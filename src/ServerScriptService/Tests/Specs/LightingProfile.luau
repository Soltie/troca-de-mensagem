--!strict
local P = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local TestKit = require("../TestKit")
return {
	name = "LightingProfile",
	run = function(t)
		t.it("contains decorative fill without dimming clues or mission effects", function()
			local night, reach = P.fixture("NightLight", 0.75, 26)
			t.expect(night > 0 and night < 0.75).toBe(true)
			t.expect(reach).toBe(18)
			local _, short = P.fixture("NightLight", 0.75, 8)
			t.expect(short).toBe(8)
			local clue, clueRange = P.fixture("ObjectiveGlow", 2, 30)
			t.expect(clue).toBe(2)
			t.expect(clueRange).toBe(30)
		end)
		t.it("preserves bounded grade and visibility across interior/power blends", function()
			for i = -1, 11 do
				for j = -1, 11 do
					local grade = P.grade(i / 10, j / 10)
					for _, channel in grade.tint do
						t.expect(channel >= 0 and channel <= 255).toBe(true)
					end
					-- Contraste do ambiente (até 0,12) mais o do filtro escolhido; nunca estoura.
					t.expect(grade.contrast >= 0 and grade.contrast <= 0.12 + P.Look.contrast).toBe(true)
					t.expect(grade.contrast <= 0.3).toBe(true)
					t.expect(P.exposure(i / 10, j / 10) >= 0.08).toBe(true)
				end
			end
		end)
		t.it("the dark house stays readable without the flashlight but never bright", function()
			local dark = P.ambient(1, 0, 0)
			local powered = P.ambient(1, 1, 0)
			local forest = P.ambient(1, 1, 1)
			-- Piso de leitura: abaixo de ~38 a madeira escura vira preto; acima de ~60 a lanterna perde o papel.
			t.expect(P.luma(dark) >= 38 and P.luma(dark) <= 50).toBe(true)
			t.expect(P.luma(powered) > P.luma(dark)).toBe(true)
			t.expect(P.luma(powered) <= 60).toBe(true)
			-- Sem energia o interior é frio (luar); com energia, mais neutro.
			t.expect(dark[3] > dark[1]).toBe(true)
			for i = 1, 3 do
				t.expect(forest[i]).toBeCloseTo(P.Forest.ambient[i])
			end
			t.expect(P.ambient(0, 0, 0)[3]).toBe(P.World.ambient[3])
			-- Sem energia, entrar na casa não aumenta a exposição.
			t.expect(P.exposure(1, 0)).toBe(P.exposure(0, 0))
		end)
		t.it("chapters get colder and foggier without changing brightness", function()
			local previous = P.chapter(1)
			t.expect(P.chapter(0)).toBe(P.chapter(1))
			t.expect(P.chapter(99)).toBe(P.chapter(#P.Chapters))
			for stage = 2, #P.Chapters do
				local look = P.chapter(stage)
				t.expect(look.cold >= previous.cold).toBe(true)
				t.expect(look.fog <= previous.fog and look.fog >= 0.6).toBe(true)
				t.expect(look.saturation <= previous.saturation and look.saturation >= -0.2).toBe(true)
				previous = look
			end
			for _, indoor in { 0, 1 } do
				for _, power in { 0, 1 } do
					local warm = P.ambient(indoor, power, 0, 0)
					local chilled = P.ambient(indoor, power, 0, 1)
					-- Mesma luminância: esfriar não escurece o caminho nem dá salto de brilho.
					t.expect(P.luma(chilled)).toBeCloseTo(P.luma(warm))
					-- Dentro de casa o capítulo tardio puxa para o azul do luar (a noite lá fora já é azul).
					if indoor == 1 then
						t.expect(chilled[3] / chilled[1] > warm[3] / warm[1] - 1e-6).toBe(true)
					end
				end
			end
		end)
		t.it("presence fill lights the house only, yields to the flashlight and cutscenes", function()
			t.expect(P.fill(0, false, false)).toBe(0)
			t.expect(P.fill(1, false, false)).toBe(P.Fill.brightness)
			t.expect(P.fill(1, true, false) < P.fill(1, false, false)).toBe(true)
			t.expect(P.fill(1, false, true)).toBe(0)
			t.expect(P.fill(0.5, false, false)).toBeCloseTo(P.Fill.brightness / 2)
			-- Nunca revela o Tung a 15 studs, e se apaga quando ele chega perto.
			t.expect(P.Fill.range < 15).toBe(true)
			t.expect(P.fill(1, false, false, 40)).toBe(P.Fill.brightness)
			t.expect(P.fill(1, false, false, 4)).toBeCloseTo(P.Fill.brightness * P.Fill.nearShare)
			t.expect(P.fill(1, false, false, 12) < P.fill(1, false, false, 20)).toBe(true)
		end)
		t.it("flashlight dims smoothly on close surfaces and keeps full reach far away", function()
			t.expect(P.nearDim(0)).toBe(P.FlashlightNear.floor)
			t.expect(P.nearDim(P.FlashlightNear.full)).toBe(1)
			t.expect(P.nearDim(40)).toBe(1)
			local last = 0
			for d = 0, 14, 0.5 do
				local k = P.nearDim(d)
				t.expect(k >= last).toBe(true)
				last = k
			end
		end)
		t.it("fog recovers fully and never extends a shorter existing visibility cap", function()
			t.expect(P.fogEnd(142, 0)).toBe(142)
			t.expect(P.fogEnd(142, 1)).toBe(64)
			t.expect(P.fogEnd(40, 1)).toBe(40)
			t.expect(P.fogEnd(142, -3)).toBe(142)
			t.expect(P.fogEnd(142, 3)).toBe(64)
		end)
		t.it("outdoor fog bank comes and goes but never touches the house interior", function()
			local low, high = 1, 0
			for second = 0, 600 do
				local bank = P.fogBank(second)
				t.expect(bank >= 0 and bank <= 1).toBe(true)
				low, high = math.min(low, bank), math.max(high, bank)
				t.expect(P.fogScale(second, 0)).toBe(1)
				t.expect(P.fogScale(second, 1) >= 1 - P.FogBank.depth).toBe(true)
			end
			-- Há momentos limpos e momentos de névoa.
			t.expect(low < 0.2 and high > 0.8).toBe(true)
		end)
		t.it("adaptation does not depend on frame rate or overshoot", function()
			local fast, slow = 0, 0
			for _ = 1, 120 do
				fast = P.approach(fast, 1, 1 / 120)
			end
			for _ = 1, 12 do
				slow = P.approach(slow, 1, 1 / 12)
			end
			t.expect(fast).toBeCloseTo(slow)
			t.expect(P.approach(0.4, 1, -1)).toBe(0.4)
			t.expect(P.approach(0, 1, 100) <= 1).toBe(true)
		end)
		t.it("shadow budget excludes disabled, distant and out-of-range lights", function()
			local chosen = P.selectShadows({
				{ id = "off", enabled = false, distance = 0, range = 20 },
				{ id = "far", enabled = true, distance = 70, range = 80 },
				{ id = "range", enabled = true, distance = 40, range = 5 },
				{ id = "a", enabled = true, distance = 5, range = 20 },
				{ id = "b", enabled = true, distance = 8, range = 20 },
				{ id = "c", enabled = true, distance = 9, range = 20 },
			}, 2)
			t.expect(chosen).toEqual({ a = true, b = true })
			t.expect(P.selectShadows({}, 2)).toEqual({})
			t.expect(P.shadowBudget(2)).toBe(0)
			t.expect(P.shadowBudget(0)).toBe(2)
		end)
		t.it("comfort mode keeps every fixture steady", function()
			for tick = 0, 100 do
				t.expect(P.flicker(tick / 10, 4, true, false)).toBe(1)
				local value = P.flicker(tick / 10, 4, true, true)
				t.expect(value >= 0.48 and value <= 1).toBe(true)
			end
		end)
	end,
} :: TestKit.Spec
