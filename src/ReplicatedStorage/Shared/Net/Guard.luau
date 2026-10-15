--!strict
--[[
	Validação de argumentos vindos do cliente. Tudo que chega por remote é `unknown`:
	o cliente pode mandar qualquer tipo, NaN, infinito, strings gigantes, tabelas com
	metatables, argumentos a mais etc.

		local validate = Guard.args({ Guard.string({ maxLength = 32 }), Guard.optional(Guard.integer()) })
		local ok, reason = validate(table.pack(...))

	Puro (exceto Guard.instanceOf, que usa :IsA): roda no Roblox e no Lune.
]]

export type Validator = (value: unknown) -> (boolean, string?)

export type NumberOptions = {
	min: number?,
	max: number?,
	integer: boolean?,
}

export type StringOptions = {
	minLength: number?,
	-- Padrão: 200 (strings longas são um vetor comum de abuso).
	maxLength: number?,
	-- Padrão Lua (string.match) que a string inteira deve satisfazer.
	pattern: string?,
}

local DEFAULT_MAX_STRING = 200

local Guard = {}

local function fail(expected: string, value: unknown): (boolean, string?)
	return false, `expected {expected}, got {typeof(value)}`
end

function Guard.number(options: NumberOptions?): Validator
	local opts: NumberOptions = options or {}
	return function(value: unknown)
		if type(value) ~= "number" then
			return fail("number", value)
		end
		local n = value :: number
		if n ~= n then
			return false, "number is NaN"
		end
		if n == math.huge or n == -math.huge then
			return false, "number is not finite"
		end
		if opts.integer and n % 1 ~= 0 then
			return false, "number is not an integer"
		end
		if opts.min and n < opts.min then
			return false, `number below min {opts.min}`
		end
		if opts.max and n > opts.max then
			return false, `number above max {opts.max}`
		end
		return true, nil
	end
end

function Guard.integer(options: NumberOptions?): Validator
	local opts: NumberOptions = options or {}
	return Guard.number({ min = opts.min, max = opts.max, integer = true })
end

function Guard.string(options: StringOptions?): Validator
	local opts: StringOptions = options or {}
	local maxLength = opts.maxLength or DEFAULT_MAX_STRING
	return function(value: unknown)
		if type(value) ~= "string" then
			return fail("string", value)
		end
		local s = value :: string
		local length = utf8.len(s)
		if length == nil then
			return false, "string is not valid UTF-8"
		end
		if length > maxLength then
			return false, `string longer than {maxLength}`
		end
		if opts.minLength and length < opts.minLength then
			return false, `string shorter than {opts.minLength}`
		end
		if opts.pattern and string.match(s, opts.pattern) ~= s then
			return false, "string does not match pattern"
		end
		return true, nil
	end
end

function Guard.boolean(): Validator
	return function(value: unknown)
		if type(value) ~= "boolean" then
			return fail("boolean", value)
		end
		return true, nil
	end
end

-- Aceita somente um dos valores listados (comparação com ==).
function Guard.literal(...: string | number | boolean): Validator
	local allowed = table.pack(...)
	return function(value: unknown)
		for index = 1, allowed.n do
			if value == allowed[index] then
				return true, nil
			end
		end
		return false, "value is not one of the allowed literals"
	end
end

function Guard.optional(validator: Validator): Validator
	return function(value: unknown)
		if value == nil then
			return true, nil
		end
		return validator(value)
	end
end

-- Array denso (1..n) sem metatable, com no máximo `maxLength` itens (padrão 100).
function Guard.array(itemValidator: Validator, maxLength: number?): Validator
	local limit = maxLength or 100
	return function(value: unknown)
		if type(value) ~= "table" then
			return fail("array", value)
		end
		local tbl = value :: { [any]: unknown }
		if getmetatable(tbl :: any) ~= nil then
			return false, "array has a metatable"
		end
		local count = 0
		for key in tbl do
			count += 1
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "array has non-sequential keys"
			end
		end
		if count ~= #tbl then
			return false, "array has holes"
		end
		if count > limit then
			return false, `array longer than {limit}`
		end
		for index = 1, count do
			local ok, reason = itemValidator(tbl[index])
			if not ok then
				return false, `item #{index}: {reason}`
			end
		end
		return true, nil
	end
end

-- Roblox: aceita somente Instances da classe indicada (usa :IsA).
function Guard.instanceOf(className: string): Validator
	return function(value: unknown)
		if typeof(value) ~= "Instance" then
			return fail(className, value)
		end
		if not (value :: any):IsA(className) then
			return false, `expected {className}, got {(value :: any).ClassName}`
		end
		return true, nil
	end
end

-- Valida a lista de argumentos de um remote. Rejeita argumentos a mais.
-- Use com table.pack(...) para preservar nils: validate(table.pack(...)).
function Guard.args(validators: { Validator }): (args: { n: number, [number]: unknown }) -> (boolean, string?)
	local expected = #validators
	return function(args)
		if args.n > expected then
			return false, `too many arguments (expected at most {expected}, got {args.n})`
		end
		for index, validator in validators do
			local ok, reason = validator(args[index])
			if not ok then
				return false, `arg #{index}: {reason}`
			end
		end
		return true, nil
	end
end

return Guard
