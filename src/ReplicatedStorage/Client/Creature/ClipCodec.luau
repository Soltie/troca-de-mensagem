--!strict
--[[
	Decodifica os clipes gerados por tools/tungtung/bake.js (TungTungClips). Módulo puro: só números,
	sem CFrame, para rodar também nos testes do Lune. O cliente monta os CFrames a partir daqui.

	Formato de cada quadro (int16 little-endian):
	  para cada osso de Bones: quaternion x, y, z, w (escala 32767)
	  para cada osso de posBones: x, y, z (escala 32767 = PosRange studs)
]]

export type RawClip = { fps: number, frames: number, loop: boolean, posBones: { string }, data: string }

export type Decoded = {
	fps: number,
	frames: number,
	loop: boolean,
	duration: number,
	boneCount: number,
	-- rot[(quadro - 1) * boneCount * 4 + (osso - 1) * 4 + 1 .. 4] = x, y, z, w
	rot: { number },
	-- pos[osso][(quadro - 1) * 3 + 1 .. 3] = x, y, z (só ossos com deslocamento)
	pos: { [number]: { number } },
}

local ClipCodec = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LOOKUP: { [number]: number } = {}
for index = 1, #ALPHABET do
	LOOKUP[string.byte(ALPHABET, index)] = index - 1
end

function ClipCodec.base64Decode(text: string): buffer
	local length = #text
	local padding = 0
	if string.sub(text, -2) == "==" then
		padding = 2
	elseif string.sub(text, -1) == "=" then
		padding = 1
	end
	local size = (length // 4) * 3 - padding
	local out = buffer.create(size)
	local cursor = 0
	for index = 1, length, 4 do
		local a = LOOKUP[string.byte(text, index)] or 0
		local b = LOOKUP[string.byte(text, index + 1)] or 0
		local c = LOOKUP[string.byte(text, index + 2)] or 0
		local d = LOOKUP[string.byte(text, index + 3)] or 0
		local value = a * 262144 + b * 4096 + c * 64 + d
		if cursor < size then
			buffer.writeu8(out, cursor, bit32.rshift(value, 16))
		end
		if cursor + 1 < size then
			buffer.writeu8(out, cursor + 1, bit32.band(bit32.rshift(value, 8), 255))
		end
		if cursor + 2 < size then
			buffer.writeu8(out, cursor + 2, bit32.band(value, 255))
		end
		cursor += 3
	end
	return out
end

function ClipCodec.decode(clip: RawClip, bones: { string }, posRange: number): Decoded
	local data = ClipCodec.base64Decode(clip.data)
	local boneCount = #bones
	local posIndex: { number } = {}
	for _, name in clip.posBones do
		local found = table.find(bones, name)
		assert(found, `[ClipCodec] unknown position bone {name}`)
		table.insert(posIndex, found)
	end
	local stride = boneCount * 8 + #posIndex * 6
	assert(buffer.len(data) == stride * clip.frames, "[ClipCodec] clip size does not match its header")
	local rot = table.create(clip.frames * boneCount * 4)
	local pos: { [number]: { number } } = {}
	for _, bone in posIndex do
		pos[bone] = table.create(clip.frames * 3)
	end
	local offset = 0
	for _ = 1, clip.frames do
		for _ = 1, boneCount * 4 do
			table.insert(rot, buffer.readi16(data, offset) / 32767)
			offset += 2
		end
		for _, bone in posIndex do
			local list = pos[bone]
			for _ = 1, 3 do
				table.insert(list, buffer.readi16(data, offset) / 32767 * posRange)
				offset += 2
			end
		end
	end
	return {
		fps = clip.fps,
		frames = clip.frames,
		loop = clip.loop,
		duration = (clip.frames - 1) / clip.fps,
		boneCount = boneCount,
		rot = rot,
		pos = pos,
	}
end

-- Quadros vizinhos e mistura para o tempo `time` (s). Clipes em laço dão a volta; os outros param no fim.
function ClipCodec.locate(decoded: Decoded, time: number): (number, number, number)
	local duration = decoded.duration
	local t = if decoded.loop and duration > 0 then time % duration else math.clamp(time, 0, duration)
	local position = t * decoded.fps
	local a = math.clamp(math.floor(position), 0, decoded.frames - 1)
	local b = math.min(a + 1, decoded.frames - 1)
	return a + 1, b + 1, position - a
end

-- Quaternion (x, y, z, w) de um osso num quadro.
function ClipCodec.rotation(decoded: Decoded, frame: number, bone: number): (number, number, number, number)
	local base = (frame - 1) * decoded.boneCount * 4 + (bone - 1) * 4
	local rot = decoded.rot
	return rot[base + 1], rot[base + 2], rot[base + 3], rot[base + 4]
end

-- Translação de um osso num quadro (0, 0, 0 se o osso não se desloca).
function ClipCodec.position(decoded: Decoded, frame: number, bone: number): (number, number, number)
	local list = decoded.pos[bone]
	if not list then
		return 0, 0, 0
	end
	local base = (frame - 1) * 3
	return list[base + 1], list[base + 2], list[base + 3]
end

return ClipCodec
