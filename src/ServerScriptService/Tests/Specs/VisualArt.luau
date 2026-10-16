--!strict
local TestKit = require("../TestKit")
return {
	name = "VisualArt",
	robloxOnly = true,
	run = function(t)
		t.it("added set dressing cannot block movement, sight or interactions", function()
			local root = workspace:FindFirstChild("Substation9")
			local art = root and root:FindFirstChild("ArtDetails")
			assert(art, "art details must exist during Play")
			for _, part in art:GetDescendants() do
				if part:IsA("BasePart") then
					t.expect(part.CanCollide).toBe(false)
					t.expect(part.CanQuery).toBe(false)
					t.expect(part:GetAttribute("InteractId")).toBe(nil)
				end
			end
		end)
		t.it("surface allocation stays within budget and covers every indoor room", function()
			local Config = require("@game/ReplicatedStorage/Shared/Config")
			local Layout = require("@game/ServerScriptService/Server/World/Layout")
			local surfaces = game:GetService("CollectionService"):GetTagged("ArtSurface")
			t.expect(#surfaces <= Config.Art.SurfacePartLimit).toBe(true)
			for _, room in Layout.Rooms do
				if room.id == "Switchyard" then
					continue
				end
				local count = 0
				for _, part in surfaces do
					if part:IsA("BasePart") then
						local p = part.Position
						if p.X >= room.x0 and p.X <= room.x1 and p.Z >= room.z0 and p.Z <= room.z1 then
							count += 1
						end
					end
				end
				t.expect(count > 0).toBe(true)
			end
		end)
		t.it("uniform attachments have valid anchors and follow every stop-motion pose", function()
			local Rig = require("@game/ReplicatedStorage/Client/Creature/Rig")
			local Poses = require("@game/ReplicatedStorage/Client/Creature/Poses")
			local Details = require("@game/ReplicatedStorage/Client/Creature/UniformDetails")
			local container = Instance.new("Folder")
			local rig = Rig.build(container)
			local ok, problem = pcall(function()
				for _, animation in { "Idle", "Walk", "Chase", "Search", "Capture" } do
					for _, pose in (Poses :: any)[animation] do
						local frames = Rig.solve(rig, CFrame.new(10, 0, 20), pose, 35)
						t.expect(#frames).toBe(#rig.order)
						for _, detail in Details do
							assert(rig.parts[detail.anchor], "missing detail anchor")
							local part = rig.parts[detail.name]
							t.expect(part.CanCollide or part.CanQuery or part.CanTouch).toBe(false)
							local index = table.find(rig.order, part)
							assert(index, "detail missing from BulkMoveTo")
							t.expect((frames[index].Position - Vector3.new(10, 0, 20)).Magnitude < 15).toBe(true)
						end
					end
				end
			end)
			container:Destroy()
			assert(ok, tostring(problem))
		end)
	end,
} :: TestKit.Spec
