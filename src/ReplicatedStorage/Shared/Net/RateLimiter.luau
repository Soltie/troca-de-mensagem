--!strict
--[[
	Rate limit por chave (ex.: UserId) usando token bucket.

		local limiter = RateLimiter.new({ capacity = 5, refillPerSecond = 2 })
		if not limiter.allow(player.UserId) then return end

	`capacity` = rajada máxima; `refillPerSecond` = taxa sustentada.
	Chame `reset(key)` quando o jogador sair, para não acumular memória.
	Puro: o relógio é injetável, então os testes rodam no Lune.
]]

export type Options = {
	capacity: number,
	refillPerSecond: number,
	-- Padrão: os.clock.
	clock: (() -> number)?,
}

export type RateLimiter = {
	allow: (key: any) -> boolean,
	reset: (key: any) -> (),
	size: () -> number,
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}

function RateLimiter.new(options: Options): RateLimiter
	assert(options.capacity > 0, "RateLimiter: capacity must be > 0")
	assert(options.refillPerSecond >= 0, "RateLimiter: refillPerSecond must be >= 0")

	local clock = options.clock or os.clock
	local buckets: { [any]: Bucket } = {}
	local count = 0

	local function allow(key: any): boolean
		local now = clock()
		local bucket = buckets[key]
		if bucket == nil then
			bucket = { tokens = options.capacity, updatedAt = now }
			buckets[key] = bucket
			count += 1
		else
			local elapsed = math.max(0, now - bucket.updatedAt)
			bucket.tokens = math.min(options.capacity, bucket.tokens + elapsed * options.refillPerSecond)
			bucket.updatedAt = now
		end
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end

	local function reset(key: any)
		if buckets[key] ~= nil then
			buckets[key] = nil
			count -= 1
		end
	end

	local function size(): number
		return count
	end

	return {
		allow = allow,
		reset = reset,
		size = size,
	}
end

return RateLimiter
