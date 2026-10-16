--!strict
local ClipCodec = require("@game/ReplicatedStorage/Client/Creature/ClipCodec")
local TungTungClips = require("@game/ReplicatedStorage/Client/Creature/TungTungClips")
local TestKit = require("../TestKit")

local EXPECTED = { walk = true, run = true, slash = true, strafe = true, sheath = true }

local testSpec: TestKit.Spec = {
	name = "TungTungClips",
	run = function(t)
		t.it("base64 decodes known bytes", function()
			local data = ClipCodec.base64Decode("TWFu")
			t.expect(buffer.len(data)).toBe(3)
			t.expect(buffer.tostring(data)).toBe("Man")
			t.expect(buffer.tostring(ClipCodec.base64Decode("TWE="))).toBe("Ma")
			t.expect(buffer.tostring(ClipCodec.base64Decode("TQ=="))).toBe("M")
		end)
		t.it("has every clip the creature uses", function()
			for name in EXPECTED do
				t.expect((TungTungClips.Clips :: any)[name] ~= nil).toBe(true)
			end
			t.expect(#TungTungClips.Bones).toBe(28)
		end)
		t.it("decodes unit quaternions for every bone and frame", function()
			for name, raw in TungTungClips.Clips :: any do
				local decoded = ClipCodec.decode(raw, TungTungClips.Bones, TungTungClips.PosRange)
				t.expect(decoded.frames).toBe(raw.frames)
				for frame = 1, decoded.frames do
					for bone = 1, decoded.boneCount do
						local x, y, z, w = ClipCodec.rotation(decoded, frame, bone)
						local norm = math.sqrt(x * x + y * y + z * z + w * w)
						if math.abs(norm - 1) > 0.002 then
							error(`{name} frame {frame} bone {bone} has norm {norm}`)
						end
					end
				end
			end
		end)
		t.it("loops wrap and one-shots clamp at the end", function()
			local walk = ClipCodec.decode(TungTungClips.Clips.walk, TungTungClips.Bones, TungTungClips.PosRange)
			local a, b, alpha = ClipCodec.locate(walk, walk.duration + 0.5 / walk.fps)
			t.expect(a).toBe(1)
			t.expect(b).toBe(2)
			t.expect(alpha).toBeCloseTo(0.5)
			local slash = ClipCodec.decode(TungTungClips.Clips.slash, TungTungClips.Bones, TungTungClips.PosRange)
			local last, next, _ = ClipCodec.locate(slash, 99)
			t.expect(last).toBe(slash.frames)
			t.expect(next).toBe(slash.frames)
		end)
		t.it("looping clips stay in place (root motion removed)", function()
			local hips = table.find(TungTungClips.Bones, "mixamorig:Hips") :: number
			for _, name in { "walk", "run", "strafe" } do
				local decoded = ClipCodec.decode((TungTungClips.Clips :: any)[name], TungTungClips.Bones, 16)
				local x1, _, z1 = ClipCodec.position(decoded, 1, hips)
				local x2, _, z2 = ClipCodec.position(decoded, decoded.frames, hips)
				t.expect(math.abs(x2 - x1) < 0.05).toBe(true)
				t.expect(math.abs(z2 - z1) < 0.05).toBe(true)
			end
		end)
	end,
}

return testSpec
