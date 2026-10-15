--!strict
--[[
	Tenta executar `fn` até `attempts` vezes, com backoff exponencial entre as tentativas.

		local ok, value, err = Retry.run(function()
			return store:GetAsync(key)
		end, { attempts = 3, baseDelay = 1 })

	Puro: a espera é injetável (`wait`), então os testes rodam no Lune sem dormir.
]]

export type Options = {
	attempts: number,
	-- Atraso antes da 2ª tentativa; dobra a cada falha.
	baseDelay: number,
	maxDelay: number?,
	-- Padrão: task.wait (Roblox).
	wait: ((seconds: number) -> ())?,
	onRetry: ((attempt: number, err: string, delay: number) -> ())?,
}

local Retry = {}

function Retry.delayFor(attempt: number, baseDelay: number, maxDelay: number?): number
	local delay = baseDelay * 2 ^ (attempt - 1)
	return if maxDelay then math.min(delay, maxDelay) else delay
end

-- Retorna (true, valor, nil) no sucesso ou (false, nil, últimoErro) se todas falharem.
function Retry.run<T>(fn: () -> T, options: Options): (boolean, T?, string?)
	assert(options.attempts >= 1, "Retry.run: attempts must be >= 1")
	local wait: (seconds: number) -> () = options.wait or function(seconds: number)
		task.wait(seconds)
	end
	local lastError = "unknown error"
	for attempt = 1, options.attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result, nil
		end
		lastError = tostring(result)
		if attempt < options.attempts then
			local delay = Retry.delayFor(attempt, options.baseDelay, options.maxDelay)
			if options.onRetry then
				options.onRetry(attempt, lastError, delay)
			end
			wait(delay)
		end
	end
	return false, nil, lastError
end

return Retry
