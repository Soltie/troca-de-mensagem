--!strict
local TestKit = require("../TestKit")

return {
	name = "HousePrimitiveFinish",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		local Finish = require("@game/ServerScriptService/Server/World/HousePrimitiveFinish")
		local function folder(parent: Instance, name: string): Folder
			local f = Instance.new("Folder")
			f.Name, f.Parent = name, parent
			return f
		end
		local function body(parent: Instance, name: string, size: Vector3): Part
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = name, size, CFrame.new(4200, 8, 0)
			p.Anchored, p.Parent = true, parent
			return p
		end
		t.it("new campaign bases keep references collision and lamps across rebuilds", function()
			local root = folder(workspace, "PrimitiveFinishFixture")
			local ok, failure = pcall(function()
				Finish.build(root)
				local campaign = folder(root, "CampaignActivities")
				local p = body(campaign, "AntiquePedestal", Vector3.new(4, 1.7, 2))
				p:SetAttribute("Contract", "preserved")
				local light = Instance.new("PointLight")
				light.Brightness, light.Parent = 0.9, p
				local cf, size = p.CFrame, p.Size
				task.wait()
				Finish.build(root)
				local finishes = root:FindFirstChild("PrimitiveFinish") :: Folder
				local visuals = finishes:GetChildren()
				t.expect(#visuals).toBe(1)
				local visual = visuals[1] :: Model
				local mesh = visual:FindFirstChild("FinishMesh") :: MeshPart
				t.expect((visual:FindFirstChild("Source") :: ObjectValue).Value).toBe(p)
				t.expect(p.CFrame).toBe(cf)
				t.expect(p.Size).toBe(size)
				t.expect(p.CanCollide and p.CanQuery).toBe(true)
				t.expect(p:GetAttribute("Contract")).toBe("preserved")
				t.expect(light.Parent).toBe(p)
				assert(math.abs(light.Brightness - 0.9) < 0.001, "Finish changed lamp brightness")
				t.expect(mesh.CanCollide or mesh.CanTouch or mesh.CanQuery).toBe(false)
				assert((mesh.Size - size).Magnitude < 0.001, "Finish changes pedestal envelope")
				campaign:Destroy()
				t.expect(#finishes:GetChildren()).toBe(0)
			end)
			root:Destroy()
			assert(ok, tostring(failure))
		end)

		t.it("old block bookshelves become a multi-mesh shelf inside the same collision volume", function()
			local root = folder(workspace, "BookshelfFinishFixture")
			local ok, failure = pcall(function()
				local furnishings = folder(root, "Furnishings")
				local p = body(furnishings, "Bookshelf", Vector3.new(3, 8, 1.3))
				local size, cf = p.Size, p.CFrame
				Finish.build(root)
				local finishes = root:FindFirstChild("PrimitiveFinish") :: Folder
				local found = finishes:FindFirstChild("BookshelfVisual")
				assert(found and found:IsA("Model"), "Bookshelf was not finished")
				local visual = found :: Model
				local _, extent = visual:GetBoundingBox()
				assert((extent - size).Magnitude < 0.05, "Shelf does not fill the old volume")
				for _, mesh in visual:GetDescendants() do
					if mesh:IsA("BasePart") then
						t.expect(mesh.CanCollide or mesh.CanQuery or mesh.CanTouch).toBe(false)
					end
				end
				t.expect(p.Transparency).toBe(1)
				t.expect(p.CanCollide and p.CanQuery).toBe(true)
				t.expect(p.CFrame).toBe(cf)
				t.expect(p.Size).toBe(size)
			end)
			root:Destroy()
			assert(ok, tostring(failure))
		end)

		t.it("dynamic skins follow moving bodies without changing interaction or visibility contracts", function()
			local root = folder(workspace, "DynamicFinishFixture")
			local ok, failure = pcall(function()
				local dynamics = folder(root, "DynamicMansion")
				local p = body(dynamics, "HeavyCrate", Vector3.new(5, 3.6, 3))
				p:SetAttribute("MansionId", "fixture")
				p:SetAttribute("MansionEnabled", true)
				game:GetService("CollectionService"):AddTag(p, "FinishContractFixture")
				Finish.build(root)
				local finishes = root:FindFirstChild("PrimitiveFinish") :: Folder
				local visual = finishes:FindFirstChild("HeavyCrateVisual") :: Model
				local mesh = visual:FindFirstChild("FinishMesh") :: MeshPart
				local size, cf = p.Size, p.CFrame
				local relative = cf:ToObjectSpace(mesh.CFrame)
				t.expect(#finishes:GetChildren()).toBe(2) -- dois caixotes empilhados
				p.CFrame = cf * CFrame.new(4.5, 0, 0) * CFrame.Angles(0, 0.7, 0)
				task.wait(0.15)
				local expected = p.CFrame * relative
				assert((mesh.Position - expected.Position).Magnitude < 0.01, "Skin did not follow moving body")
				assert(mesh.CFrame.LookVector:Dot(expected.LookVector) > 0.999, "Skin did not rotate with body")
				p.Transparency = 0.8
				task.wait()
				assert(math.abs(mesh.Transparency - 0.8) < 0.001, "Skin ignores body visibility")
				t.expect(p.Size).toBe(size)
				t.expect(p.CanCollide and p.CanQuery).toBe(true)
				t.expect(p:GetAttribute("MansionEnabled")).toBe(true)
				t.expect(p:GetAttribute("MansionId")).toBe("fixture")
				t.expect(game:GetService("CollectionService"):HasTag(p, "FinishContractFixture")).toBe(true)
				t.expect(mesh.Anchored or mesh.CanCollide or mesh.CanQuery or mesh.CanTouch).toBe(false)
				assert(mesh.Massless, "Visual skin adds mass")
			end)
			root:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
