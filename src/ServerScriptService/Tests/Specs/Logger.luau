--!strict
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local TestKit = require("../TestKit")
local Types = require("@game/ReplicatedStorage/Shared/Types")

type Entry = { level: Types.LogLevel, line: string }

-- Captura a saída do Logger durante `body` e SEMPRE restaura o estado global
-- (no Studio o Logger é compartilhado com o jogo em execução).
local function capture(level: Types.LogLevel, body: () -> ()): { Entry }
	local entries: { Entry } = {}
	local previousLevel: Types.LogLevel = Logger.getLevel()
	Logger.setLevel(level)
	Logger.setSink(function(entryLevel: Types.LogLevel, line: string)
		table.insert(entries, { level = entryLevel, line = line })
	end)
	local ok, err = pcall(body :: () -> any)
	Logger.setSink(nil)
	Logger.setLevel(previousLevel)
	if not ok then
		error(err, 0)
	end
	return entries
end

local spec: TestKit.Spec = {
	name = "Logger",
	run = function(t)
		t.it("prefixes lines with the scope and formats arguments", function()
			local entries = capture("Debug", function()
				Logger.new("Server").info("boot OK (%d services)", 2)
			end)
			t.expect(#entries).toBe(1)
			t.expect(entries[1].line).toBe("[Server] boot OK (2 services)")
			t.expect(entries[1].level).toBe("Info")
		end)

		t.it("does not format when there are no extra arguments", function()
			local entries = capture("Debug", function()
				Logger.new("X").info("100% literal")
			end)
			t.expect(entries[1].line).toBe("[X] 100% literal")
		end)

		t.it("filters by minimum level", function()
			local entries = capture("Warn", function()
				local log = Logger.new("X")
				log.debug("hidden")
				log.info("hidden")
				log.warn("shown")
				log.error("shown too")
			end)
			t.expect(#entries).toBe(2)
			t.expect(entries[2].line).toBe("[X] ERROR: shown too")
		end)
	end,
}

return spec
