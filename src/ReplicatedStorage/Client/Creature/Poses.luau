--!strict
--[[
	Poses-chave do Vigia (graus). Não há interpolação: o controller mostra uma pose por vez,
	a ~8–12 poses por segundo (stop-motion), enquanto a posição real se move liso no servidor.

	Convenções (ver Rig.luau):
	  spine  < 0 = curva para frente        neck > 0 = cabeça para cima
	  hip    > 0 = perna para frente         knee < 0 = dobra para trás
	  shoulder > 0 = braço para frente       elbow < 0 = dobra
	  roll/yaw em graus; bob = deslocamento vertical (studs); step = toca o som de passo
]]

export type Pose = {
	spine: number,
	spineRoll: number,
	neck: number,
	neckYaw: number,
	neckRoll: number,
	lShoulder: number,
	lShoulderRoll: number,
	lElbow: number,
	rShoulder: number,
	rShoulderRoll: number,
	rElbow: number,
	lHip: number,
	lKnee: number,
	rHip: number,
	rKnee: number,
	bob: number,
	step: boolean,
}

local function pose(values: { [string]: any }): Pose
	local p: { [string]: any } = {
		spine = -24,
		spineRoll = 0,
		neck = 14,
		neckYaw = 0,
		neckRoll = 0,
		lShoulder = 4,
		lShoulderRoll = -4,
		lElbow = -10,
		rShoulder = 4,
		rShoulderRoll = 4,
		rElbow = -10,
		lHip = 0,
		lKnee = -6,
		rHip = 0,
		rKnee = -6,
		bob = 0,
		step = false,
	}
	for key, value in values do
		assert(p[key] ~= nil, `unknown pose key {key}`)
		p[key] = value
	end
	return table.freeze(p) :: any
end

local Poses: { [string]: { Pose } } = {
	Notice = {
		pose({ spine = -10, neck = 30, lShoulder = 32, rShoulder = 42, bob = 0.12 }),
		pose({ spine = -36, neck = 8, lShoulder = 75, rShoulder = 70, lElbow = -35, rElbow = -30 }),
	},
	Sniff = {
		pose({ spine = -32, neck = 24, neckYaw = -30, rShoulder = 26 }),
		pose({ spine = -30, neck = 28, neckYaw = 32, lShoulder = 20 }),
	},
	DoorBang = {
		pose({ rShoulder = 110, rElbow = -70, spine = -18 }),
		pose({ rShoulder = 90, rElbow = -4, spine = -40, bob = -0.1 }),
	},
	Lunge = {
		pose({ spine = -48, lShoulder = 115, rShoulder = 120, lElbow = -20, rElbow = -25 }),
		pose({ spine = -62, lShoulder = 140, rShoulder = 138, bob = -0.25 }),
	},
	Idle = {
		pose({}),
		pose({ spine = -27, neck = 22, neckRoll = 9, rElbow = -22, bob = -0.05 }),
	},
	Search = {
		pose({ spine = -18, neck = 8, neckYaw = 45, neckRoll = 6 }),
		pose({ spine = -18, neck = 10, neckYaw = 40, neckRoll = 12 }),
		pose({ spine = -20, neck = 8, neckYaw = -45, neckRoll = -6 }),
		pose({ spine = -20, neck = 12, neckYaw = -38, neckRoll = -14 }),
	},
	Walk = {
		pose({
			lHip = 24,
			lKnee = -8,
			rHip = -18,
			rKnee = -26,
			lShoulder = -16,
			rShoulder = 22,
			bob = -0.12,
			step = true,
		}),
		pose({ spine = -27, lHip = 2, lKnee = -4, rHip = 10, rKnee = -48, neckRoll = 6, bob = 0.05 }),
		pose({
			rHip = 24,
			rKnee = -8,
			lHip = -18,
			lKnee = -26,
			rShoulder = -16,
			lShoulder = 22,
			bob = -0.12,
			step = true,
		}),
		pose({ spine = -27, rHip = 2, rKnee = -4, lHip = 10, lKnee = -48, neckRoll = -6, bob = 0.05 }),
	},
	Chase = {
		pose({
			spine = -44,
			neck = 34,
			lHip = 38,
			lKnee = -10,
			rHip = -30,
			rKnee = -40,
			lShoulder = 70,
			rShoulder = 40,
			lElbow = -24,
			rElbow = -40,
			bob = -0.2,
			step = true,
		}),
		pose({
			spine = -48,
			neck = 38,
			neckRoll = 10,
			lHip = 6,
			rHip = 18,
			rKnee = -70,
			lShoulder = 84,
			rShoulder = 62,
			lElbow = -10,
			rElbow = -18,
			bob = 0.1,
		}),
		pose({
			spine = -44,
			neck = 34,
			rHip = 38,
			rKnee = -10,
			lHip = -30,
			lKnee = -40,
			rShoulder = 70,
			lShoulder = 40,
			rElbow = -24,
			lElbow = -40,
			bob = -0.2,
			step = true,
		}),
		pose({
			spine = -48,
			neck = 38,
			neckRoll = -10,
			rHip = 6,
			lHip = 18,
			lKnee = -70,
			rShoulder = 84,
			lShoulder = 62,
			rElbow = -10,
			lElbow = -18,
			bob = 0.1,
		}),
	},
	Capture = {
		pose({
			spine = -10,
			neck = 24,
			lShoulder = 120,
			lShoulderRoll = -34,
			rShoulder = 120,
			rShoulderRoll = 34,
			lElbow = -30,
			rElbow = -30,
		}),
		pose({
			spine = -14,
			neck = 30,
			neckRoll = 14,
			lShoulder = 128,
			lShoulderRoll = -40,
			rShoulder = 112,
			rShoulderRoll = 28,
			lElbow = -18,
			rElbow = -44,
			bob = 0.1,
		}),
	},
}

return table.freeze(Poses)
