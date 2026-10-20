--!strict
local TestKit = require("../TestKit")

return {
	name = "HouseTaskProps",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		local Props = require("@game/ServerScriptService/Server/World/HouseTaskProps")
		local CoinFinish = require("@game/ServerScriptService/Server/World/HouseCollectibleFinish")
		local Activities = require("@game/ServerScriptService/Server/Campaign/HouseActivities")
		local Plan = require("@game/ServerScriptService/Server/Campaign/HousePlan")
		local PuzzleProps = require("@game/ServerScriptService/Server/World/PuzzleProps")
		local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

		t.it("recognizable small props stay nonphysical and within a bounded geometry budget", function()
			for _, item in { "hall_key", "power_fuse", "flashlight", "photo", "mask", "book", "clock" } do
				local model = Instance.new("Model")
				local ok, failure = pcall(function()
					Props.build(model, Vector3.zero, item, if item == "book" then "clue" else "collect")
					local count = 0
					for _, object in model:GetDescendants() do
						if object:IsA("BasePart") then
							count += 1
							assert(
								not object.CanCollide and not object.CanQuery and not object.CanTouch,
								`Visual prop affects interaction or physics: {item}/{object.Name}`
							)
							assert(#object:GetTags() == 0, "Decorative prop became an interaction target")
						end
					end
					assert(count > 0 and count <= 20, `Unexpected geometry budget for {item}: {count}`)
					if item == "power_fuse" then
						local fuse = model:FindFirstChild("FuseBody") :: Part
						t.expect(fuse.Shape).toBe(Enum.PartType.Cylinder)
						assert(fuse.Position.Y - fuse.Size.Y / 2 >= 1.7, "Fuse intersects pedestal top")
					elseif item == "hall_key" then
						local segments = 0
						for _, object in model:GetChildren() do
							if object.Name == "KeyBow" then
								segments += 1
							end
						end
						t.expect(segments).toBe(10)
					end
				end)
				model:Destroy()
				assert(ok, tostring(failure))
			end
		end)

		t.it("all eight chapters retain target transforms tags and solve visibility", function()
			local root = Instance.new("Folder")
			local ok, failure = pcall(function()
				for chapter = 1, 8 do
					local plan = Plan.create(42, chapter, 1, "Standard")
					local built = Activities.build(root, plan, 12)
					local states: any = {}
					for _, spec in plan.activities do
						states[spec.id] = { spec = spec, solved = false, progress = 0 }
					end
					Activities.refresh(built, states)
					task.wait()
					for id, target in built.targets do
						local focus: BasePart = target.focus
						-- Móvel de busca (HiddenStash): posição própria; mesmo contrato de interação.
						if target.search then
							assert(focus:HasTag(Tags.Interactable), "Missing search interaction tag")
							t.expect(focus:GetAttribute(Tags.Attr.InteractId)).toBe(id)
							t.expect(focus:GetAttribute(Tags.Attr.InteractDistance)).toBe(12)
							assert(not focus.CanCollide and focus.CanQuery, "Search query contract changed")
							continue
						end
						-- Puzzles do cap. 1 (HouseMiniPuzzles): tábuas e banquinhos se mexem por desenho.
						if target.handle then
							assert(focus:HasTag(Tags.Interactable), "Missing mini puzzle interaction tag")
							t.expect(focus:GetAttribute(Tags.Attr.InteractId)).toBe(id)
							assert((focus:GetAttribute(Tags.Attr.InteractDistance) :: number) >= 12, "Mini reach")
							assert(not focus.CanCollide and focus.CanQuery, "Mini puzzle query contract changed")
							continue
						end
						local spec = states[target.taskId].spec
						local count = if spec.kind == "puzzle" then 4 elseif spec.kind == "repair" then 3 else 1
						local expected = Vector3.new(spec.x, spec.y or 0, spec.z)
							+ Vector3.new(
								(target.button - (count + 1) / 2) * 1.8,
								2
									+ (
										if target.piano
											then PuzzleProps.KEY_SIZE.Y / 2
											elseif spec.kind == "collect" then 0.8
											else 0.4
									),
								0.5
							)
						assert((focus.Position - expected).Magnitude < 0.001, `Target moved: {chapter}/{id}`)
						assert(focus:HasTag(Tags.Interactable), "Missing original interaction tag")
						t.expect(focus:GetAttribute(Tags.Attr.InteractId)).toBe(id)
						t.expect(focus:GetAttribute(Tags.Attr.InteractDistance)).toBe(12)
						assert(not focus.CanCollide and focus.CanQuery, "Original query contract changed")
					end
					for _, state in states do
						state.solved, state.progress = true, 3
					end
					Activities.refresh(built, states)
					task.wait()
					for _, target in built.targets do
						local spec = states[target.taskId].spec
						if target.search or target.handle then
							-- Resolvida, nenhum móvel abre mais.
							t.expect(target.focus:GetAttribute(Tags.Attr.InteractEnabled)).toBe(false)
							continue
						end
						if spec.kind == "collect" then
							for _, object in target.focus.Parent:GetDescendants() do
								if
									object:IsA("BasePart")
									and object.Name ~= "Station"
									and object.Name ~= "AntiquePedestal"
								then
									t.expect(object.Transparency).toBe(1)
								end
							end
						-- Teclas do piano (PuzzleStyles) ficam à mostra: são as teclas de verdade.
						elseif (spec.kind == "repair" or spec.kind == "puzzle") and not target.piano then
							t.expect(target.focus.Transparency).toBe(1)
						end
					end
				end
			end)
			root:Destroy()
			assert(ok, tostring(failure))
		end)

		t.it("clue and activate targets hide behind the prop and mirror their state color", function()
			local cases: { { kind: string, item: string?, indicator: string } } = {
				{ kind = "clue", item = "book", indicator = "BookRibbon" },
				{ kind = "activate", item = nil, indicator = "LockLamp" },
			}
			for _, case in cases do
				local model = Instance.new("Model")
				model.Name, model.Parent = "TaskMirrorFixture", workspace
				local ok, failure = pcall(function()
					local p = Vector3.new(5400, 0, 0)
					Props.build(model, p, case.item, case.kind)
					local target = Instance.new("Part")
					target.Name = "TaskMirrorFixture_1"
					target.Size, target.CFrame = Vector3.new(1.2, 0.8, 0.9), CFrame.new(p + Vector3.new(0, 2.4, 0.5))
					target.Anchored, target.CanCollide, target.CanQuery = true, false, true
					target.Parent = model
					task.wait()
					target.Transparency = 0
					target.Color = Color3.fromRGB(219, 171, 80)
					task.wait()
					t.expect(target.Transparency).toBe(1)
					local indicator = model:FindFirstChild(case.indicator) :: BasePart
					t.expect(indicator.Color).toBe(target.Color)
					local params = RaycastParams.new()
					params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { model }
					local hit = workspace:Raycast(target.Position + Vector3.zAxis * 4, -Vector3.zAxis * 8, params)
					assert(hit and hit.Instance == target, `Prop intercepted the interaction ray: {case.kind}`)
				end)
				model:Destroy()
				assert(ok, tostring(failure))
			end
		end)

		t.it("decorated controls keep raycasts on the original target and mirror its state color", function()
			local model = Instance.new("Model")
			model.Name, model.Parent = "TaskControlFixture", workspace
			local ok, failure = pcall(function()
				local p = Vector3.new(5200, 0, 0)
				Props.build(model, p, "power", "repair")
				local target = Instance.new("Part")
				target.Name = "TaskControlFixture_1"
				target.Size, target.CFrame = Vector3.new(1.2, 0.8, 0.9), CFrame.new(p + Vector3.new(-1.8, 2.4, 0.5))
				target.Anchored, target.CanCollide, target.CanQuery = true, false, true
				target.Parent = model
				task.wait()
				target.Transparency = 0
				target.Color = Color3.fromRGB(63, 105, 76)
				task.wait()
				local button = model:FindFirstChild("ControlButton") :: BasePart
				t.expect(button.Color).toBe(target.Color)
				t.expect(target.Transparency).toBe(1)
				local params = RaycastParams.new()
				params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { model }
				local hit = workspace:Raycast(target.Position + Vector3.zAxis * 4, -Vector3.zAxis * 8, params)
				assert(hit and hit.Instance == target, "Decorative controls intercepted the interaction ray")
			end)
			model:Destroy()
			assert(ok, tostring(failure))
		end)

		t.it("coin relief follows the original body without changing rewards or collection geometry", function()
			local p = Instance.new("Part")
			p.Size, p.CFrame, p.Anchored = Vector3.new(0.35, 2, 2), CFrame.new(4800, 8, 0), true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			p:SetAttribute("Value", 37)
			p:SetAttribute("Xp", 11)
			p:SetAttribute("Gem", false)
			local size, cf = p.Size, p.CFrame
			p.Parent = workspace
			local ok, failure = pcall(function()
				CoinFinish.coin(p)
				CoinFinish.coin(p)
				t.expect(#p:GetChildren()).toBe(1)
				t.expect(p.Size).toBe(size)
				t.expect(p.CFrame).toBe(cf)
				t.expect(p.Transparency).toBe(1)
				t.expect(p:GetAttribute("Value")).toBe(37)
				t.expect(p:GetAttribute("Xp")).toBe(11)
				t.expect(p:GetAttribute("Gem")).toBe(false)
				local parts: { [BasePart]: CFrame } = {}
				for _, object in p:GetDescendants() do
					if object:IsA("BasePart") then
						assert(
							not object.CanCollide and not object.CanQuery and not object.CanTouch and object.Massless,
							"Coin relief changes physics or interaction"
						)
						parts[object] = cf:ToObjectSpace(object.CFrame)
					end
				end
				p.CFrame = cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 1, 0)
				task.wait(0.15)
				local count = 0
				for part, offset in parts do
					count += 1
					assert(
						(part.Position - (p.CFrame * offset).Position).Magnitude < 0.01,
						"Coin relief did not follow body"
					)
				end
				t.expect(count).toBe(7)
			end)
			p:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
