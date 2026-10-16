--!strict
local Guide = require("@game/ReplicatedStorage/Shared/Game/PlayerGuide")
local TestKit = require("../TestKit")
return {
	name = "PlayerGuide",
	run = function(t)
		local function activity(kind: string, progress: number): Guide.Activity
			return { id = "task_1", room = "Lobby", kind = kind, solved = false, progress = progress }
		end
		t.it("advances past solved tasks and handles completed or empty chapters", function()
			local first, second = activity("repair", 3), activity("sequence", 1)
			first.solved = true
			local current, index = Guide.current({ first, second })
			t.expect(current).toBe(second)
			t.expect(index).toBe(2)
			second.solved = true
			t.expect((Guide.current({ first, second }))).toBe(nil)
			t.expect((Guide.current({}))).toBe(nil)
		end)
		t.it("explains relay confirmation only while its server window remains open", function()
			local relay = activity("relay", 1)
			relay.relayUntil = 110
			t.expect(string.find(Guide.instruction(relay, 105), "5s", 1, true) ~= nil).toBe(true)
			t.expect(string.find(Guide.instruction(relay, 111), "Venham em dupla", 1, true) ~= nil).toBe(true)
		end)
		t.it("shows rescue and waiting instructions instead of assigning inactive players a station", function()
			local repair = activity("repair", 0)
			local downed = Guide.objective("Playing", "Downed", repair)
			t.expect(downed).toBe("Você precisa de resgate")
			local escaped = Guide.objective("Extracting", "Escaped", repair)
			t.expect(escaped).toBe("Você chegou à saída")
			local lost = Guide.objective("Lost", "Downed", repair)
			t.expect(lost).toBe("O turno foi interrompido")
		end)
		t.it("explains solo relay fallback and protected wait after skipping the scene", function()
			t.expect(string.find(Guide.instruction(activity("relay", 0), 0, 1), "último ativo", 1, true) ~= nil)
				.toBe(true)
			local title = Guide.objective("Briefing", "Active", activity("repair", 0))
			t.expect(title).toBe("Prepare-se para o turno")
		end)
		t.it("preserves authored titles and directs sequences to the physical clue", function()
			local sequence = activity("sequence", 1)
			sequence.title = "Recuperar o registro do turno"
			t.expect((Guide.objective("Playing", "Active", sequence))).toBe(sequence.title)
			t.expect(string.find(Guide.instruction(sequence, 0), "placa", 1, true) ~= nil).toBe(true)
		end)
	end,
} :: TestKit.Spec
