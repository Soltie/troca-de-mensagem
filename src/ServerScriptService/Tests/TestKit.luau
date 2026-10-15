--!strict
--[[
	Mini framework de testes (sem dependências). Roda no Studio e no Lune.

	Um spec é um ModuleScript em Tests/Specs que retorna:
		return {
			name = "Guard",
			robloxOnly = false, -- true = usa APIs do Roblox; o runner do Lune pula
			run = function(t: TestKit.Context)
				t.describe("number", function()
					t.it("rejects NaN", function()
						t.expect((Guard.number())(0 / 0)).toBe(false)
					end)
				end)
			end,
		}

	Runners: Tests/Run.luau (Studio, via MCP) e scripts/test.luau (Lune).
]]

local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeCloseTo: (expected: number, epsilon: number?) -> (),
	-- O valor deve ser uma função que lança erro (opcionalmente contendo `substring`).
	toThrow: (substring: string?) -> (),
}

export type Context = {
	describe: (name: string, body: () -> ()) -> (),
	it: (name: string, body: () -> ()) -> (),
	expect: (value: any) -> Expectation,
}

export type Spec = {
	name: string,
	robloxOnly: boolean?,
	run: (t: Context) -> (),
}

export type Failure = {
	test: string,
	message: string,
}

export type Report = {
	passed: number,
	failed: number,
	skipped: number,
	failures: { Failure },
}

export type RunOptions = {
	includeRobloxOnly: boolean,
}

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function expect(value: any): Expectation
	return {
		toBe = function(expected: any)
			if value ~= expected then
				error(`expected {show(expected)}, got {show(value)}`, 2)
			end
		end,
		toEqual = function(expected: any)
			if not TableUtil.deepEqual(value, expected) then
				error(`expected deep equality with {show(expected)}, got {show(value)}`, 2)
			end
		end,
		toBeNil = function()
			if value ~= nil then
				error(`expected nil, got {show(value)}`, 2)
			end
		end,
		toBeTruthy = function()
			if not value then
				error(`expected truthy, got {show(value)}`, 2)
			end
		end,
		toBeFalsy = function()
			if value then
				error(`expected falsy, got {show(value)}`, 2)
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			if type(value) ~= "number" or math.abs(value - expected) > (epsilon or 1e-6) then
				error(`expected ~{expected}, got {show(value)}`, 2)
			end
		end,
		toThrow = function(substring: string?)
			if type(value) ~= "function" then
				error("toThrow expects a function", 2)
			end
			local ok, err = pcall(value)
			if ok then
				error("expected function to throw", 2)
			end
			if substring and not string.find(tostring(err), substring, 1, true) then
				error(`expected error containing {show(substring)}, got {show(tostring(err))}`, 2)
			end
		end,
	}
end

local TestKit = {}

function TestKit.run(specs: { Spec }, options: RunOptions): Report
	local report: Report = { passed = 0, failed = 0, skipped = 0, failures = {} }

	for _, spec in specs do
		if spec.robloxOnly and not options.includeRobloxOnly then
			report.skipped += 1
			continue
		end

		local path: { string } = { spec.name }
		local context: Context = {
			describe = function(name: string, body: () -> ())
				table.insert(path, name)
				body()
				table.remove(path)
			end,
			it = function(name: string, body: () -> ())
				local fullName = table.concat(path, " > ") .. " > " .. name
				local ok, err = pcall(body :: () -> any)
				if ok then
					report.passed += 1
				else
					report.failed += 1
					table.insert(report.failures, { test = fullName, message = tostring(err) })
				end
			end,
			expect = expect,
		}

		local ok, err = pcall(spec.run :: (Context) -> any, context)
		if not ok then
			report.failed += 1
			table.insert(report.failures, { test = `{spec.name} (spec body)`, message = tostring(err) })
		end
	end

	return report
end

function TestKit.format(report: Report): string
	local lines = {
		`[Tests] {report.passed} passed, {report.failed} failed, {report.skipped} skipped specs`,
	}
	for _, failure in report.failures do
		table.insert(lines, `  FAIL {failure.test}: {failure.message}`)
	end
	return table.concat(lines, "\n")
end

return TestKit
