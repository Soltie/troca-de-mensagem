--!strict
local Rules = {}

function Rules.allowed(phase: string, status: string?): boolean
	return phase == "Playing" and (status == nil or status == "Active")
end

function Rules.prompt(prompt: string, alt: string?, locked: boolean, hasKey: boolean, campaign: boolean): string
	if locked and not campaign then
		return if hasKey then "[E] DESTRANCAR" else "[E] TRANCADA"
	end
	return `[E] {prompt}` .. (if alt and not campaign then `\n[Q] {alt}` else "")
end

function Rules.pickup(kind: string?): boolean
	return kind == "Fuse" or kind == "Key" or kind == "Battery" or kind == "Tape"
end

return table.freeze(Rules)
