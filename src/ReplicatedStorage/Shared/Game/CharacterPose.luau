--!strict
--[[
	Matemática pura das poses procedurais dos jogadores (CharacterAnimatorController) e do olhar
	replicado (PresenceService). Ângulos em graus na rede; radianos só no cálculo das pernas.

	Rede: o cliente manda o pitch do olhar quantizado em passos de PITCH_STEP, no máximo a cada
	SEND_INTERVAL e só quando muda. O servidor revalida com quantizePitch antes de gravar o atributo.
]]

local CharacterPose = {}

CharacterPose.MAX_PITCH = 70
CharacterPose.PITCH_STEP = 2
CharacterPose.SEND_INTERVAL = 0.125
-- Mesmo sem mudança, reenvia de vez em quando (o atributo some quando o personagem renasce).
CharacterPose.HEARTBEAT = 3
-- Dobra máxima do agachamento (coxa à frente / canela para trás).
CharacterPose.MAX_CROUCH = math.rad(72)

-- Pitch do olhar em graus, limitado e arredondado para o passo da rede.
function CharacterPose.quantizePitch(degrees: number): number
	if degrees ~= degrees then
		return 0
	end
	local limited = math.clamp(degrees, -CharacterPose.MAX_PITCH, CharacterPose.MAX_PITCH)
	local step = CharacterPose.PITCH_STEP
	local q = math.floor(limited / step + 0.5) * step
	return math.clamp(q, -CharacterPose.MAX_PITCH, CharacterPose.MAX_PITCH)
end

-- Manda o pitch agora? `last` = último enviado (nil = nunca), `since` = segundos desde o envio.
function CharacterPose.shouldSend(last: number?, current: number, since: number): boolean
	if since < CharacterPose.SEND_INTERVAL then
		return false
	end
	if last == nil then
		return true
	end
	return last ~= current or since >= CharacterPose.HEARTBEAT
end

--[[
	Agachamento com o pé embaixo do quadril: a coxa gira +a, a canela -2a, o pé +a (fica plano).
	As pernas encurtam legLength * (1 - cos a). Retorna (a em radianos, lift): lift é quanto o corpo
	visível precisa subir quando nem a dobra máxima compensa a queda física (`drop`) do HipHeight.
]]
function CharacterPose.crouch(legLength: number, drop: number, maxAngle: number?): (number, number)
	if legLength <= 0 or drop <= 0 then
		return 0, 0
	end
	local limit = maxAngle or CharacterPose.MAX_CROUCH
	local ratio = math.clamp(1 - drop / legLength, -1, 1)
	local angle = math.min(math.acos(ratio), limit)
	local shortened = legLength * (1 - math.cos(angle))
	return angle, math.max(0, drop - shortened)
end

-- Inclinação do tronco (graus) pela velocidade: nada andando, até `max` correndo.
function CharacterPose.lean(speed: number, walkSpeed: number, sprintSpeed: number, max: number?): number
	if sprintSpeed <= walkSpeed then
		return 0
	end
	local t = math.clamp((speed - walkSpeed) / (sprintSpeed - walkSpeed), 0, 1)
	return t * (max or 12)
end

-- Divide o pitch entre pescoço e cintura (o tronco acompanha um pouco).
function CharacterPose.split(pitch: number): (number, number)
	return pitch * 0.65, pitch * 0.35
end

-- Aproxima `current` de `target` com taxa exponencial (rate por segundo).
function CharacterPose.approach(current: number, target: number, rate: number, dt: number): number
	local k = 1 - math.exp(-rate * math.max(dt, 0))
	return current + (target - current) * k
end

return table.freeze(CharacterPose)
